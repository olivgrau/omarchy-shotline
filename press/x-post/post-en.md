# X post — English

Two options: a thread (more reach, more work) or a single post. Character
counts are given per tweet, all within the free 280-character limit.

---

## Option A — Thread (6 posts)

### 1/6 · attach `video/shotline.mp4` · 265 chars

```
I stopped writing 200-word bug reports for my coding agent.

Now I screenshot the app step by step, comment each shot, and hand the agent
one file.

4 bugs → 4 screenshots → 1 markdown file it can actually read.

Built it as an Omarchy plugin. It's called Shotline.
```

### 2/6 · no media · 244 chars

```
Finding the bug was never the hard part.

Describing it is: "in the detail sheet, top right, next to the customer name,
the date renders US-style, and further down that's why the duration is
negative…"

Three sentences a screenshot does in one.
```

### 3/6 · attach `screenshots/02-comment-dialog.png` · 232 chars

```
SUPER+SHIFT+K freezes the screen. Drag a region — the size is right there
while you drag. A click grabs the whole window.

The comment box opens immediately, with the size in the prompt.

Type, hit enter, back to the app. Next step.
```

### 4/6 · attach `screenshots/04-annotation.png` · 242 chars

```
Need to point at something?

A pen appears in the bar as soon as there's a shot to mark. Click it and the
screenshot opens with the brush — or the blur tool, for anything that
shouldn't be in a repo.

Save, and you're back in the comment box.
```

### 5/6 · attach `screenshots/05-session-html-light.png` and `screenshots/07-session-md.png` · 256 chars

```
SUPER+SHIFT+L closes the series.

Pick the target folder, and it writes:
· session.html — for you, light/dark
· session.md — for the agent, relative image paths
· the PNGs next to them

The prompt telling your agent what to do is already in your clipboard.
```

### 6/6 · no media · 192 chars

```
Bash, Python stdlib, a QML bar widget. No runtime beyond grim, slurp and jq.
149 tests, all green, none of them touching your real desktop.

MIT licensed.

github.com/olivgrau/omarchy-shotline
```

---

## Option B — Single post · attach `video/shotline.mp4` · 277 chars

```
Explaining a bug to a coding agent takes longer than finding it.

So I built Shotline: screenshot the app step by step, comment each shot, mark
what matters.

Out comes one markdown file for the agent, plus the prompt.

Omarchy plugin, MIT.
github.com/olivgrau/omarchy-shotline
```

---

## Alt text for the images

Copy these into X's alt text field — it matters for reach and for people using
screen readers.

| Image | Alt text |
|---|---|
| `01-app-with-bugs.png` | Dark rental dashboard listing six bookings. The filter says "Status: Paid" but pending and cancelled rows are visible, and the total only sums the paid ones. |
| `02-comment-dialog.png` | The same dashboard with a small input box floating over it, asking for a comment on shot 5 and showing the captured size of 1588 by 962 pixels. |
| `03-bar-widget.png` | Close-up of a status bar showing a camera icon with the number 4 next to it, and a pen icon beside it. |
| `04-annotation.png` | Booking detail rows with two red boxes drawn on them: one around two dates in US format labelled "US format?", one around a duration of minus 7 hours labelled "negative". |
| `05-session-html-light.png` | A generated HTML report titled "Pedalio rentals", listing four screenshots with their comments, first entry expanded. |
| `06-session-html-dark.png` | The same generated report in dark mode. |
| `07-session-md.png` | Terminal-style view of session.md: a heading per step, the image path, capture size, window name and the comment as a quote. |
| `08-agent-prompt.png` | Terminal output after finishing a series: the target path and the ready-made prompt pointing the agent at session.md. |

---

## Posting notes

- **Video first.** The 30-second MP4 carries the idea better than any single
  screenshot. `video/shotline.gif` is the fallback where MP4 is awkward.
- **Best time:** weekday mornings, Europe. The Omarchy crowd is largely
  European and posts early.
- **Hashtags:** none in the main post. If you want them, put `#Omarchy
  #Hyprland #Linux` in a reply so they don't eat the hook.
- **Worth tagging:** the Omarchy account, if you want it seen by that
  community. Don't tag more than one.
- **One caveat:** `02-comment-dialog.png` shows the dialog in German
  ("was passiert hier?"), because the CLI speaks German. If that bothers you
  for an English thread, either drop that image or say the word and the UI
  strings get translated.
