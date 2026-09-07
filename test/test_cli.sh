#!/bin/bash
#
# End-to-end test of the CLI. Every outside contact (slurp, grim, hyprctl,
# dialogs, clipboard, notifications) is a stub on PATH, so the test runs
# without a Wayland session and never opens a real window.

set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
CLI="$ROOT/bin/shotline"

WORK=$(mktemp -d)
STUBS="$WORK/stubs"
mkdir -p "$STUBS"
trap 'rm -rf "$WORK"' EXIT

PASSED=0
FAILED=0

ok() { PASSED=$((PASSED + 1)); printf '  \033[32mok\033[0m   %s\n' "$1"; }
no() { FAILED=$((FAILED + 1)); printf '  \033[31mFAIL\033[0m %s\n' "$1"; [[ -n ${2:-} ]] && printf '       %s\n' "$2"; }

check() { # check <name> <bedingung-als-string>
  if eval "$2"; then ok "$1"; else no "$1" "$2"; fi
}

contains() { # contains <name> <haystack> <needle>
  if [[ $2 == *"$3"* ]]; then ok "$1"; else no "$1" "erwartet: $3"; fi
}

# ------------------------------------------------------------------- stubs

cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB

# Writes a minimal, valid PNG file to the target path.
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
# Only the PNG signature, no IHDR: this covers the case without a real image size.
target="${!#}"
printf '\x89PNG\r\n\x1a\n' >"$target"
STUB

cat >"$STUBS/hyprctl" <<'STUB'
#!/bin/bash
echo "$*" >>"${STUB_HYPRCTL_LOG:-/dev/null}"
case "$1" in
  monitors) echo "[{\"focused\":true,\"dpmsStatus\":${STUB_DPMS:-true},\"x\":0,\"y\":0,\"width\":1920,\"height\":1080,\"scale\":1,\"transform\":0,\"activeWorkspace\":{\"id\":1}}]" ;;
  clients)  echo '[{"hidden":false,"workspace":{"id":1},"at":[0,0],"size":[1200,900],"class":"firefox","title":"Testfenster"},
                    {"hidden":false,"workspace":{"id":7},"at":[0,0],"size":[800,600],"class":"chrome","title":"Anderer Workspace"}]' ;;
  getoption) echo '{"int":2}' ;;
  cursorpos) echo "${STUB_CURSOR:-100, 100}" ;;
  eval) [[ ${STUB_EVAL_FAILS:-} == 1 ]] && exit 1; echo "ok" ;;
  *) exit 0 ;;
esac
STUB

cat >"$STUBS/hyprpicker" <<'STUB'
#!/bin/bash
sleep 5
STUB

cat >"$STUBS/omarchy-menu-input" <<'STUB'
#!/bin/bash
[[ -n ${STUB_INPUT:-} ]] || exit 1
echo "$STUB_INPUT"
STUB

cat >"$STUBS/omarchy-menu-select" <<'STUB'
#!/bin/bash
# The real dialog returns the label without its leading icon.
cat >"${STUB_SELECT_LOG:-/dev/null}"
[[ -n ${STUB_SELECT:-} ]] || exit 1
echo "$STUB_SELECT"
STUB

cat >"$STUBS/wl-copy" <<'STUB'
#!/bin/bash
cat >"${STUB_CLIPBOARD:-/dev/null}"
STUB

cat >"$STUBS/notify-send" <<'STUB'
#!/bin/bash
echo "$*" >>"${STUB_NOTIFY:-/dev/null}"
STUB

# These Omarchy commands live in /usr/bin and would be reachable from inside
# the test. Without stubs the test would send real notifications, talk to the
# running shell, or open a browser.
cat >"$STUBS/omarchy-notification-send" <<'STUB'
#!/bin/bash
echo "$*" >>"${STUB_NOTIFY:-/dev/null}"
STUB

cat >"$STUBS/omarchy-shell" <<'STUB'
#!/bin/bash
echo "$*" >>"${STUB_SHELL_LOG:-/dev/null}"
STUB

for stub in omarchy-launch-browser xdg-open tensaku; do
  cat >"$STUBS/$stub" <<'STUB'
#!/bin/bash
echo "$0 $*" >>"${STUB_OPEN_LOG:-/dev/null}"
STUB
done

chmod +x "$STUBS"/*

export PATH="$STUBS:/usr/bin:/bin"
export STUB_CLIPBOARD="$WORK/clipboard.txt"
export STUB_NOTIFY="$WORK/notify.log"

# Every case gets a fresh state.
fresh() {
  export SHOTLINE_STATE_DIR="$WORK/state-$RANDOM$RANDOM"
  unset SHOTLINE_GEOMETRY STUB_SLURP_OUTPUT STUB_INPUT STUB_SELECT
}

run() { "$CLI" "$@" 2>&1; }

echo
echo "shotline -- end-to-end"
echo

# ------------------------------------------------------------------- cases

echo "State"
fresh
out=$(run status --json)
check "status without a session reports inactive" '[[ $(jq -r .active <<<"$out") == false ]]'
check "status without a session counts zero" '[[ $(jq -r .count <<<"$out") == 0 ]]'
out=$(run status)
contains "status in plain words" "$out" "No session running"

fresh
run start "Login-Flow" >/dev/null
out=$(run status --json)
check "start creates a session" '[[ $(jq -r .active <<<"$out") == true ]]'
check "start takes the title" '[[ $(jq -r .title <<<"$out") == "Login-Flow" ]]'
out=$(run start "Zweite")
contains "a second start is refused" "$out" "already running"

echo
echo "Capture"
fresh
export SHOTLINE_GEOMETRY="100,200 812x460"
out=$(run shot --comment "Die Login-Maske")
dir=$(jq -r .dir <<<"$(run status --json)")
check "shot starts a session implicitly" '[[ -n $dir ]]'
check "shot writes a PNG" '[[ -f "$dir/01-die-login-maske.png" ]]'
check "the file name follows the comment" '[[ $(basename "$out") == "01-die-login-maske.png" ]]'
check "width lands in the JSON" '[[ $(jq -r ".shots[0].width" "$dir/session.json") == 812 ]]'
check "height lands in the JSON" '[[ $(jq -r ".shots[0].height" "$dir/session.json") == 460 ]]'
check "the comment lands in the JSON" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Die Login-Maske" ]]'
check "the window class is detected" '[[ $(jq -r ".shots[0].app" "$dir/session.json") == "firefox" ]]'
check "the window title is detected" '[[ $(jq -r ".shots[0].window" "$dir/session.json") == "Testfenster" ]]'
# A smaller window on another workspace must not hijack the detection.
check "windows on other workspaces do not count" '[[ $(jq -r ".shots[0].app" "$dir/session.json") != "chrome" ]]'
check "the PNG mode follows the umask" '[[ $(stat -c %a "$dir/01-die-login-maske.png") == $(printf "%o" "$((0666 & ~0$(umask)))") ]]'
# A running session holds raw screenshots. No other user on the machine reads
# them, no matter how permissive the umask is.
check "the state directory is private" '[[ $(stat -c %a "$SHOTLINE_STATE_DIR") == 700 ]]'
check "the sessions directory is private" '[[ $(stat -c %a "$SHOTLINE_STATE_DIR/sessions") == 700 ]]'
check "the session directory is private" '[[ $(stat -c %a "$dir") == 700 ]]'
check "a missing PNG header yields pixel size 0" '[[ $(jq -r ".shots[0].pixelWidth" "$dir/session.json") == 0 ]]'

run shot --comment "Fehler nach dem Absenden" >/dev/null
check "the second shot counts up" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'
check "the second shot gets number 02" '[[ -f "$dir/02-fehler-nach-dem-absenden.png" ]]'

# Deliberately German: comments with umlauts have to survive the file name.
run shot --comment "Größe der Prüfung" >/dev/null
check "umlauts in the file name are spelled out" '[[ -f "$dir/03-groesse-der-pruefung.png" ]]'

run shot --comment "" >/dev/null
check "an empty comment yields a default name" '[[ -f "$dir/04-step.png" ]]'

echo
echo "Permissions"
# The property, not the constant: whatever the umask is, a screenshot never
# becomes wider than it allows, and the working directory stays at 700.
# No subshells here -- the counters in check() have to reach the summary.
umask_before=$(umask)

umask 077
fresh
export SHOTLINE_GEOMETRY="100,200 812x460"
run shot --comment "Geheim" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "a strict umask keeps the PNG private" '[[ $(stat -c %a "$dir/01-geheim.png") == 600 ]]'
check "a strict umask keeps the state directory private" '[[ $(stat -c %a "$SHOTLINE_STATE_DIR") == 700 ]]'

umask 000
fresh
export SHOTLINE_GEOMETRY="100,200 812x460"
run shot --comment "Offen" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "a permissive umask still shields the state directory" '[[ $(stat -c %a "$SHOTLINE_STATE_DIR") == 700 ]]'
check "a permissive umask still shields the session directory" '[[ $(stat -c %a "$dir") == 700 ]]'

umask "$umask_before"

# An older version left the directory at 755. Starting up repairs it.
fresh
mkdir -p "$SHOTLINE_STATE_DIR/sessions"
chmod 755 "$SHOTLINE_STATE_DIR" "$SHOTLINE_STATE_DIR/sessions"
run status >/dev/null
check "a world-readable state directory from an older version is repaired" \
  '[[ $(stat -c %a "$SHOTLINE_STATE_DIR") == 700 ]]'

# A real PNG (built with Python) has to arrive with its pixel size.
fresh
export SHOTLINE_GEOMETRY="0,0 50x50"
real_png="$WORK/real.png"
python - "$real_png" <<'PYPNG'
import binascii, struct, sys
def chunk(tag, data):
    payload = tag + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", binascii.crc32(payload) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", 120, 80, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", b"\x78\x9c\x63\x60\x00\x00\x00\x02\x00\x01")
png += chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PYPNG
cat >"$STUBS/grim" <<STUB
#!/bin/bash
cp "$real_png" "\${!#}"
STUB
chmod +x "$STUBS/grim"
run shot --comment "Echtes Bild" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "pixel width comes from the PNG header" '[[ $(jq -r ".shots[0].pixelWidth" "$dir/session.json") == 120 ]]'
check "pixel height comes from the PNG header" '[[ $(jq -r ".shots[0].pixelHeight" "$dir/session.json") == 80 ]]'
check "the logical selection stays alongside" '[[ $(jq -r ".shots[0].width" "$dir/session.json") == 50 ]]'
run finish --target "$WORK/hidpi" --title "HiDPI" >/dev/null
contains "the markdown names both sizes" "$(cat "$WORK/hidpi/shotline-$(date +%Y-%m-%d)-hidpi/session.md")" "50x50 px (image: 120x80 px)"

# Back to the simple grim stub from here on.
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
target="${!#}"
printf '\x89PNG\r\n\x1a\n' >"$target"
STUB
chmod +x "$STUBS/grim"


echo
echo "Comment dialog"
fresh
export SHOTLINE_GEOMETRY="0,0 640x480"
export STUB_INPUT="Aus dem Dialog"
run shot >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "the dialog delivers the comment" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Aus dem Dialog" ]]'
unset STUB_INPUT
run shot >/dev/null
check "a cancelled dialog keeps the shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'
check "a cancelled dialog leaves the comment empty" '[[ $(jq -r ".shots[1].comment" "$dir/session.json") == "" ]]'

echo
echo "Selection cancelled"
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT=""
out=$(run shot); rc=$?
check "a cancelled selection exits non-zero" '[[ $rc -ne 0 ]]'
contains "the cancellation is reported" "$out" "cancelled"
dir=$(jq -r .dir <<<"$(run status --json)")
check "a cancellation creates no shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 0 ]]'

echo
echo "Keys during the selection"
# Return and Ctrl+Return end slurp and leave nothing but a marker file.
# The test brings its own runtime directory: it must never read or write the
# markers of the desktop session this runs in.
export XDG_RUNTIME_DIR="$WORK/runtime"
mkdir -p "$XDG_RUNTIME_DIR"
marker_dir="$XDG_RUNTIME_DIR"
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT=""
cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
# Mimics the key binding: no result, but a marker file. The fallback matches
# the CLI's: this user's state directory, never world-writable /tmp.
[[ -n ${STUB_MARKER:-} ]] && touch "${XDG_RUNTIME_DIR:-$SHOTLINE_STATE_DIR}/omarchy-capture-region-$STUB_MARKER"
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB
chmod +x "$STUBS/slurp"

export STUB_MARKER="window"
export STUB_CURSOR="900, 400"
run shot --comment "Window via Return" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "Return takes the window under the pointer" '[[ $(jq -r ".shots[0].geometry" "$dir/session.json") == "0,0 1200x900" ]]'
check "the marker is cleaned up afterwards" '[[ ! -e "$marker_dir/omarchy-capture-region-window" ]]'

export STUB_MARKER="fullscreen"
run shot --comment "Ganzer Bildschirm" >/dev/null
check "Ctrl+Return takes the whole screen" '[[ $(jq -r ".shots[1].geometry" "$dir/session.json") == "0,0 1920x1080" ]]'
check "the fullscreen marker is cleaned up" '[[ ! -e "$marker_dir/omarchy-capture-region-fullscreen" ]]'

# A marker from an earlier run must not hijack the next selection.
unset STUB_MARKER
touch "$marker_dir/omarchy-capture-region-window"
out=$(run shot --comment "Darf nicht durchgehen"); rc=$?
check "a stale marker is cleared before the selection" '[[ $rc -ne 0 ]]'
check "a stale marker leads to no shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'
rm -f "$marker_dir/omarchy-capture-region-window"

# Without XDG_RUNTIME_DIR the marker has to fall back to this user's own state
# directory. A fallback to world-writable /tmp would let any local process turn
# a selection the user cancelled into a capture of the whole screen.
# The stub writes to the state directory only, so the CLI finds the marker
# exactly when its fallback points there.
cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
[[ -n ${STUB_MARKER:-} ]] && touch "$SHOTLINE_STATE_DIR/omarchy-capture-region-$STUB_MARKER"
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB
chmod +x "$STUBS/slurp"

# This case needs its own session; the block continues with the old one after.
runtime_before="$XDG_RUNTIME_DIR"
state_before="$SHOTLINE_STATE_DIR"
dir_before="$dir"
unset XDG_RUNTIME_DIR
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT="" STUB_MARKER="fullscreen"
run shot --comment "Ohne Runtime-Dir" >/dev/null
fallback_dir=$(jq -r .dir <<<"$(run status --json)")
check "without XDG_RUNTIME_DIR the marker falls back to the state directory" \
  '[[ $(jq -r ".shots[0].geometry" "$fallback_dir/session.json") == "0,0 1920x1080" ]]'
check "the fallback marker is cleaned up too" \
  '[[ ! -e "$SHOTLINE_STATE_DIR/omarchy-capture-region-fullscreen" ]]'

export XDG_RUNTIME_DIR="$runtime_before"
export SHOTLINE_STATE_DIR="$state_before"
dir="$dir_before"
cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
[[ -n ${STUB_MARKER:-} ]] && touch "${XDG_RUNTIME_DIR:-$SHOTLINE_STATE_DIR}/omarchy-capture-region-$STUB_MARKER"
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB
chmod +x "$STUBS/slurp"

# A pointer outside every window hits the monitor.
export STUB_MARKER="window"
export STUB_CURSOR="5000, 5000"
run shot --comment "Zeiger im Nichts" >/dev/null
check "a pointer outside falls back to the monitor" '[[ $(jq -r ".shots[2].geometry" "$dir/session.json") == "0,0 1920x1080" ]]'
unset STUB_MARKER STUB_CURSOR

cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB
chmod +x "$STUBS/slurp"

echo
echo "Selection via slurp"
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT="10,20 300x150"
run shot --comment "Aus slurp" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "slurp geometry lands in the JSON" '[[ $(jq -r ".shots[0].geometry" "$dir/session.json") == "10,20 300x150" ]]'
check "slurp width is taken over" '[[ $(jq -r ".shots[0].width" "$dir/session.json") == 300 ]]'
unset STUB_SLURP_OUTPUT

echo
echo "Undo and list"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
run shot --comment "Eins" >/dev/null
run shot --comment "Zwei" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
run undo >/dev/null
check "undo removes the entry" '[[ $(jq -r ".shots | length" "$dir/session.json") == 1 ]]'
check "undo deletes the image file" '[[ ! -f "$dir/02-zwei.png" ]]'
check "undo leaves the first shot alone" '[[ -f "$dir/01-eins.png" ]]'
out=$(run list)
contains "list shows the comment" "$out" "Eins"
contains "list shows the size" "$out" "100x100"
run undo >/dev/null
out=$(run undo)
contains "undo without shots says so" "$out" "no shots"

echo
echo "Finishing"
fresh
export SHOTLINE_GEOMETRY="0,0 800x600"
run shot --comment "Startbildschirm" >/dev/null
run shot --comment "Fehlermeldung" >/dev/null
target="$WORK/agent"
out=$(run finish --target "$target" --title "Login Flow")
result="$target/shotline-$(date +%Y-%m-%d)-login-flow"
check "the target folder carries date and title" '[[ -d "$result" ]]'
check "session.html is in the target" '[[ -f "$result/session.html" ]]'
check "session.md is in the target" '[[ -f "$result/session.md" ]]'
check "the images are in the target" '[[ -f "$result/01-startbildschirm.png" ]]'
check "session.json stays out" '[[ ! -f "$result/session.json" ]]'
check "the working directory is cleared" '[[ $(jq -r .active <<<"$(run status --json)") == false ]]'
contains "the output names the target path" "$out" "$result"
contains "the output contains the agent prompt" "$out" "session.md"
contains "the prompt names the count" "$out" "2 screenshots"
check "the prompt is in the clipboard" '[[ -s "$STUB_CLIPBOARD" ]]'
contains "the clipboard names the path" "$(cat "$STUB_CLIPBOARD")" "$result/session.md"
md=$(cat "$result/session.md")
contains "the markdown names the title" "$md" "Login Flow"
contains "the markdown links relatively" "$md" "](01-startbildschirm.png)"
htmlfile=$(cat "$result/session.html")
contains "the HTML names the title" "$htmlfile" "Login Flow"
contains "the HTML has the theme toggle" "$htmlfile" "toggleTheme"

out=$(run prompt)
contains "prompt repeats the path" "$out" "$result"

echo
echo "Target shortlist"
recent="$SHOTLINE_STATE_DIR/recent-targets"
check "the target folder is remembered" '[[ $(head -1 "$recent") == "$target" ]]'
run shot --comment "Noch einer" >/dev/null
export STUB_SELECT="$target"
export STUB_INPUT="Zweiter Lauf"
run finish >/dev/null
check "picking from the shortlist works" '[[ -d "$target/shotline-$(date +%Y-%m-%d)-zweiter-lauf" ]]'
check "the shortlist stays free of duplicates" '[[ $(grep -cxF "$target" "$recent") == 1 ]]'
unset STUB_SELECT STUB_INPUT

echo
echo "Name collision"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
target="$WORK/kollision"
run shot --comment "A" >/dev/null
run finish --target "$target" --title "Gleich" >/dev/null
run shot --comment "B" >/dev/null
run finish --target "$target" --title "Gleich" >/dev/null
base="shotline-$(date +%Y-%m-%d)-gleich"
check "the first folder survives" '[[ -f "$target/$base/01-a.png" ]]'
check "the second folder gets a suffix" '[[ -f "$target/$base-2/01-b.png" ]]'

echo
echo "Cancelling the session"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
run shot --comment "Weg damit" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
run cancel >/dev/null
check "cancel deletes the working directory" '[[ ! -d "$dir" ]]'
check "cancel ends the session" '[[ $(jq -r .active <<<"$(run status --json)") == false ]]'
out=$(run cancel)
contains "cancel without a session says so" "$out" "no session running"

echo
echo "Finishing without shots"
fresh
run start "Leer" >/dev/null
out=$(run finish --target "$WORK/leer")
contains "finish without shots is refused" "$out" "no shots"
check "finish without shots creates nothing" '[[ ! -d "$WORK/leer" ]]'

echo
echo "Sleeping screen"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
export STUB_DPMS=false
export STUB_HYPRCTL_LOG="$WORK/hyprctl.log"
: >"$STUB_HYPRCTL_LOG"
run shot --comment "Nach dem Aufwecken" >/dev/null
contains "a sleeping screen is woken" "$(cat "$STUB_HYPRCTL_LOG")" 'hl.dsp.dpms("on")'
dir=$(jq -r .dir <<<"$(run status --json)")
check "the shot succeeds after waking" '[[ $(jq -r ".shots | length" "$dir/session.json") == 1 ]]'
# Older Hyprland versions do not know the Lua form: then the short form applies.
: >"$STUB_HYPRCTL_LOG"
export STUB_EVAL_FAILS=1
run shot --comment "Alter Hyprland-Weg" >/dev/null
contains "falls back to the old dpms short form" "$(cat "$STUB_HYPRCTL_LOG")" "dispatch dpms on"
unset STUB_EVAL_FAILS

unset STUB_DPMS
: >"$STUB_HYPRCTL_LOG"
run shot --comment "Wacher Bildschirm" >/dev/null
check "an awake screen is not woken" '[[ $(grep -c "dpms" "$STUB_HYPRCTL_LOG") == 0 ]]'
check "hardware cursors are forced for the capture" '[[ $(grep -c "keyword cursor:no_hardware_cursors 0$" "$STUB_HYPRCTL_LOG") == 1 ]]'
check "the cursor setting is restored afterwards" '[[ $(grep -c "keyword cursor:no_hardware_cursors 2$" "$STUB_HYPRCTL_LOG") == 1 ]]'
unset STUB_HYPRCTL_LOG

echo
echo "Hanging grim"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
export SHOTLINE_GRAB_TIMEOUT=1
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
sleep 30
STUB
chmod +x "$STUBS/grim"
start=$(date +%s)
out=$(run shot --comment "Haenger"); rc=$?
elapsed=$(( $(date +%s) - start ))
check "a hanging grim is aborted" '[[ $rc -ne 0 ]]'
check "the abort takes only seconds" '[[ $elapsed -lt 10 ]]'
contains "hint about the sleeping screen" "$out" "probably asleep"
dir=$(jq -r .dir <<<"$(run status --json)")
check "a hanging grim creates no shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 0 ]]'
unset SHOTLINE_GRAB_TIMEOUT
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
# Nur die PNG-Signatur, kein IHDR: so testet der Fall ohne echte Bildgroesse.
target="${!#}"
printf '\x89PNG\r\n\x1a\n' >"$target"
STUB
chmod +x "$STUBS/grim"

echo
echo "Quiet mode"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
: >"$STUB_NOTIFY"
run shot --comment "Mit Meldung" >/dev/null
check "normally the tool announces itself" '[[ -s "$STUB_NOTIFY" ]]'
: >"$STUB_NOTIFY"
SHOTLINE_QUIET=1 "$CLI" shot --comment "Ohne Meldung" >/dev/null 2>&1
check "SHOTLINE_QUIET mutes messages" '[[ ! -s "$STUB_NOTIFY" ]]'
dir=$(jq -r .dir <<<"$(run status --json)")
check "quiet mode still captures" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'

export STUB_SHELL_LOG="$WORK/shell.log"
: >"$STUB_SHELL_LOG"
run shot --comment "Widget stupsen" >/dev/null
contains "the bar widget gets nudged" "$(cat "$STUB_SHELL_LOG")" "io.github.olivgrau.shotline refresh"
unset STUB_SHELL_LOG

echo
echo "Names and paths"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
run shot --comment "A very long comment that definitely has to be cut off somewhere" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
name=$(jq -r ".shots[0].file" "$dir/session.json")
check "a long name gets shortened" '[[ ${#name} -le 48 ]]'
check "a shortened name does not end in a hyphen" '[[ $name != *-.png ]]'

# A relative target path has to land absolute in the result and in the prompt.
mkdir -p "$WORK/relativ"
out=$(cd "$WORK" && SHOTLINE_STATE_DIR="$SHOTLINE_STATE_DIR" "$CLI" finish --target "./relativ" --title "Relativ" 2>&1)
check "a relative target is resolved to an absolute path" '[[ -d "$WORK/relativ/shotline-$(date +%Y-%m-%d)-relativ" ]]'
check "the prompt holds no relative path" '[[ $out != *"./relativ/shotline"* ]]'
contains "the prompt names the absolute path" "$out" "$WORK/relativ/shotline"
contains "a single shot reads as singular" "$out" "There is 1 screenshot "

echo
echo "Annotating in the editor"
fresh
export SHOTLINE_GEOMETRY="0,0 400x300"
export STUB_EDITOR_LOG="$WORK/editor.log"
cat >"$WORK/editor-stub" <<'STUB'
#!/bin/bash
echo "$1|$2" >>"${STUB_EDITOR_LOG:-/dev/null}"
[[ ${STUB_EDITOR_FAILS:-} == 1 ]] && exit 1
# The editor may replace the image: here with one of a different size.
[[ -n ${STUB_EDITOR_REPLACEMENT:-} ]] && cp "$STUB_EDITOR_REPLACEMENT" "$1"
exit 0
STUB
chmod +x "$WORK/editor-stub"
export SHOTLINE_EDITOR_STUB="$WORK/editor-stub"

run shot --comment "Vor der Markierung" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "status reports annotation as possible" '[[ $(jq -r .canAnnotate <<<"$(run status --json)") == true ]]'

: >"$STUB_EDITOR_LOG"
export STUB_INPUT="Nach der Markierung"
run annotate >/dev/null
contains "the editor receives the image file" "$(cat "$STUB_EDITOR_LOG")" "01-vor-der-markierung.png"
contains "the editor starts with the pen" "$(cat "$STUB_EDITOR_LOG")" "|brush"
check "the comment is updated" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Nach der Markierung" ]]'
check "the shot is flagged as annotated" '[[ $(jq -r ".shots[0].annotated" "$dir/session.json") == true ]]'

: >"$STUB_EDITOR_LOG"
unset STUB_INPUT
run annotate >/dev/null
check "an empty entry keeps the comment" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Nach der Markierung" ]]'

: >"$STUB_EDITOR_LOG"
run annotate --blur >/dev/null
contains "blur starts with the matching tool" "$(cat "$STUB_EDITOR_LOG")" "|blur"

# An editor that crops changes the image size: it gets measured again.
big_png="$WORK/big.png"
python - "$big_png" <<'PYPNG'
import binascii, struct, sys
def chunk(tag, data):
    payload = tag + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", binascii.crc32(payload) & 0xffffffff)
png = b"\x89PNG\r\n\x1a\n"
png += chunk(b"IHDR", struct.pack(">IIBBBBB", 640, 200, 8, 2, 0, 0, 0))
png += chunk(b"IDAT", b"\x78\x9c\x63\x60\x00\x00\x00\x02\x00\x01")
png += chunk(b"IEND", b"")
open(sys.argv[1], "wb").write(png)
PYPNG
export STUB_EDITOR_REPLACEMENT="$big_png"
run annotate >/dev/null
check "the image size is measured again after the editor" '[[ $(jq -r ".shots[0].pixelWidth" "$dir/session.json") == 640 ]]'
unset STUB_EDITOR_REPLACEMENT

# Aborting in the editor must change nothing.
run shot --comment "Bleibt so" >/dev/null
export STUB_EDITOR_FAILS=1
export STUB_INPUT="Darf nicht ankommen"
out=$(run annotate); rc=$?
check "an aborted editor exits non-zero" '[[ $rc -ne 0 ]]'
check "an aborted editor leaves the comment alone" '[[ $(jq -r ".shots[1].comment" "$dir/session.json") == "Bleibt so" ]]'
check "an aborted editor sets no annotated flag" '[[ $(jq -r ".shots[1].annotated" "$dir/session.json") == null ]]'
unset STUB_EDITOR_FAILS STUB_INPUT

# A specific shot can be picked on purpose.
: >"$STUB_EDITOR_LOG"
run annotate --index 1 >/dev/null
contains "the index picks the first shot" "$(cat "$STUB_EDITOR_LOG")" "01-vor-der-markierung.png"
out=$(run annotate --index 9)
contains "an unknown index is refused" "$out" "no shot number 9"

fresh
out=$(run annotate)
contains "annotate without a session says so" "$out" "no session running"

echo
echo "Menu"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
export STUB_SELECT_LOG="$WORK/menu.log"
: >"$STUB_SELECT_LOG"
export STUB_SELECT="Next shot"
run menu >/dev/null
menu_leer=$(cat "$STUB_SELECT_LOG")
check "the menu without shots offers only capture" '[[ $(grep -c "Annotate" <<<"$menu_leer") == 0 ]]'
contains "the menu offers the next shot" "$menu_leer" "Next shot"
dir=$(jq -r .dir <<<"$(run status --json)")
check "a menu choice captures a shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 1 ]]'

: >"$STUB_SELECT_LOG"
export STUB_SELECT="Annotate last shot"
export STUB_INPUT="Annotated from the menu"
: >"$STUB_EDITOR_LOG"
run menu >/dev/null
menu_voll=$(cat "$STUB_SELECT_LOG")
contains "the menu offers annotating" "$menu_voll" "Annotate last shot"
contains "the menu offers blurring" "$menu_voll" "Blur out last shot"
contains "the menu offers finishing" "$menu_voll" "Finish series"
contains "the menu offers discarding" "$menu_voll" "Discard series"
check "menu entries carry an icon before the label" '[[ $(grep -cP "^\\S+\\tAnnotate last shot$" <<<"$menu_voll") == 1 ]]'
check "the menu starts the editor" '[[ -s "$STUB_EDITOR_LOG" ]]'
check "the menu updates the comment" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Annotated from the menu" ]]'

export STUB_SELECT="Discard last shot"
run menu >/dev/null
check "the menu discards the last shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 0 ]]'

export STUB_SELECT=""
out=$(run menu); rc=$?
check "a cancelled menu exits cleanly" '[[ $rc -eq 0 ]]'
unset STUB_SELECT STUB_INPUT STUB_SELECT_LOG

echo
echo "Usage help"
fresh
out=$(run --help)
contains "the help names shot" "$out" "shot"
contains "the help names finish" "$out" "finish"
contains "the help names annotate" "$out" "annotate"
contains "the help names menu" "$out" "menu"
out=$(run quatsch 2>&1); rc=$?
check "an unknown command exits with code 2" '[[ $rc -eq 2 ]]'

echo
printf 'Result: \033[32m%d passed\033[0m, ' "$PASSED"
if ((FAILED > 0)); then
  printf '\033[31m%d failed\033[0m\n\n' "$FAILED"
  exit 1
fi
printf '0 failed\n\n'
