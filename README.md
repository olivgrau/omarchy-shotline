# Shotline

*[Deutsche Fassung](README.de.md)*

An Omarchy plugin that captures a walkthrough of an app one step at a time.
Every screenshot gets a comment right after you take it, optional pen or blur
annotations, and the finished series lands in an agent directory as HTML plus
Markdown. The matching prompt for your AI agent ends up in the clipboard.

## Workflow

1. Press `SUPER + SHIFT + K`. The screen freezes, `slurp` shows the size of the
   selection while you drag. A click grabs a whole window. The keyboard controls
   from Omarchy's own screenshot tool work here too:

   | Key | Effect |
   |---|---|
   | drag | free selection, size is displayed |
   | click | window or monitor under the pointer |
   | `Tab` / `Ctrl+Tab` | next / previous window |
   | arrow keys | window in that direction |
   | `Return` | take the highlighted window |
   | `Ctrl+Return` | take the whole screen |
   | `Esc` | cancel |

   Omarchy provides these keys on slurp's selection layer; Shotline only reads
   the result. If they do nothing, they are missing system-wide — they will not
   work in Omarchy's own screenshot either. Restarting the Hyprland session
   restores them.

2. An input field asks for the comment. The size of the selection is part of the
   prompt, so you can confirm what you captured.
3. Annotate if needed: click the pen in the bar or press `SUPER + SHIFT + Z`.
   The screenshot opens in `tensaku` with the brush tool; *blur out last shot*
   from the menu starts with the blur tool instead. Enter saves, then the comment
   dialog comes back — leave it empty to keep the previous text.
4. Back to the app, next step, `SUPER + SHIFT + K` again.
5. `SUPER + SHIFT + L` closes the series: enter a title, pick the target
   directory from the shortlist, done.

## Bar widget

Two symbols. The camera shows the running session with its counter. The pen only
appears once there is a shot to annotate.

| | Left click | Middle click | Right click |
|---|---|---|---|
| Camera | next shot | discard last | menu |
| Pen | annotate (brush) | menu | blur out |

The menu (`SUPER + SHIFT + I` or right click) only offers what is currently
possible: next shot, annotate last, blur out last, discard last, finish series,
discard series, open last result.

## Result

```
<agent-directory>/shotline-2026-08-30-login-flow/
  01-login-screen.png
  02-error-after-submit.png
  session.html    to look at, with a light/dark toggle
  session.md      for the AI agent, relative image paths
```

The clipboard prompt points at `session.md`, states how many steps there are and
tells the agent to work through the comments as a task list.

## Installation

```bash
./install.sh
```

The installer links the CLI into `~/.local/bin`, registers the plugin under
`~/.config/omarchy/plugins/olivgrau.shotline` and writes a marked block into
`~/.config/hypr/bindings.lua`. Different keys:

```bash
SHOT_KEY="SUPER + SHIFT + P" MARK_KEY="SUPER + ALT + P" ./install.sh
```

It binds `SHOT_KEY`, `MARK_KEY`, `UNDO_KEY`, `MENU_KEY` and `FINISH_KEY`, and
warns when a key is already taken in Hyprland.

`./install.sh uninstall` reverts everything it added. Captured series stay.

## CLI

| Command | Effect |
|---------|--------|
| `shotline shot [--comment TEXT]` | pick a region, capture, comment |
| `shotline annotate [--blur] [--index N]` | annotate a shot, then update its comment |
| `shotline menu` | menu with every action |
| `shotline undo` | discard the last shot |
| `shotline list` | show the shots of the running session |
| `shotline status [--json]` | state, also used by the bar widget |
| `shotline finish [--target DIR] [--title T] [--open]` | render, file away, hand over the prompt |
| `shotline cancel` | discard the session |
| `shotline prompt` | print the last series' agent prompt again |
| `shotline open` | open the last series' `session.html` |

Without a command the CLI takes a shot. If no session is running, it starts one.

## Configuration

| Variable | Purpose |
|----------|---------|
| `SHOTLINE_DEFAULT_TARGET` | directory shown first in the target picker |
| `SHOTLINE_STATE_DIR` | working directory (default: `~/.local/state/shotline`) |
| `SHOTLINE_EDITOR` | annotation editor (default: `tensaku`) |
| `SHOTLINE_QUIET` | set to `1` to suppress every notification (scripting, screen recordings) |

Widget settings (`omarchy bar set`): `hideWhenIdle`, `showCount`, `showPen`,
`command`.

## Layout

| Path | Purpose |
|------|---------|
| `bin/shotline` | CLI: session, capture, dialogs, hand-off |
| `bin/shotline-render` | renderer: `session.json` to HTML and Markdown |
| `BarWidget.qml` | bar widget with counter and pen |
| `manifest.json` | plugin manifest, schema 1 |
| `test/` | tests |

The running session lives in `~/.local/state/shotline/sessions/<id>/` with
`session.json` and the PNGs. `finish` copies to the target first and cleans up
afterwards, so a failure along the way cannot destroy captures.

## Tests

```bash
./test/run-all.sh
```

119 tests for the CLI, 26 for the renderer. The Bash test replaces `slurp`,
`grim`, `hyprctl`, the editor and the dialogs with stubs. It runs without a
Wayland session and never opens a window.

## Requirements

`grim`, `slurp`, `jq`, `python`. Optional: `hyprpicker` (freezes the screen
during selection), `wl-clipboard` (prompt into the clipboard), `tensaku`
(annotation and blur; ships with Omarchy).

## License

MIT
