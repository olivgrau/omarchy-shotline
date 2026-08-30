#!/bin/bash
#
# End-to-End-Test der CLI. Alle Aussenkontakte (slurp, grim, hyprctl,
# Dialoge, Zwischenablage, Notification) sind Stubs im PATH, damit der Test
# ohne Wayland-Sitzung laeuft und nie ein echtes Fenster oeffnet.

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

# Schreibt eine minimale, gueltige PNG-Datei an den Zielpfad.
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
# Nur die PNG-Signatur, kein IHDR: so testet der Fall ohne echte Bildgroesse.
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
# Der echte Dialog gibt das Label ohne fuehrendes Symbol zurueck.
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

chmod +x "$STUBS"/*

export PATH="$STUBS:/usr/bin:/bin"
export STUB_CLIPBOARD="$WORK/clipboard.txt"
export STUB_NOTIFY="$WORK/notify.log"

# Jeder Fall bekommt einen frischen Zustand.
fresh() {
  export SHOTLINE_STATE_DIR="$WORK/state-$RANDOM$RANDOM"
  unset SHOTLINE_GEOMETRY STUB_SLURP_OUTPUT STUB_INPUT STUB_SELECT
}

run() { "$CLI" "$@" 2>&1; }

echo
echo "shotline -- End-to-End"
echo

# ------------------------------------------------------------------- faelle

echo "Zustand"
fresh
out=$(run status --json)
check "status ohne Session meldet inaktiv" '[[ $(jq -r .active <<<"$out") == false ]]'
check "status ohne Session zaehlt null" '[[ $(jq -r .count <<<"$out") == 0 ]]'
out=$(run status)
contains "status im Klartext" "$out" "Keine laufende Session"

fresh
run start "Login-Flow" >/dev/null
out=$(run status --json)
check "start legt Session an" '[[ $(jq -r .active <<<"$out") == true ]]'
check "start uebernimmt den Titel" '[[ $(jq -r .title <<<"$out") == "Login-Flow" ]]'
out=$(run start "Zweite")
contains "zweiter start wird abgelehnt" "$out" "bereits eine Session"

echo
echo "Aufnahme"
fresh
export SHOTLINE_GEOMETRY="100,200 812x460"
out=$(run shot --comment "Die Login-Maske")
dir=$(jq -r .dir <<<"$(run status --json)")
check "shot startet implizit eine Session" '[[ -n $dir ]]'
check "shot legt ein PNG an" '[[ -f "$dir/01-die-login-maske.png" ]]'
check "Dateiname folgt dem Kommentar" '[[ $(basename "$out") == "01-die-login-maske.png" ]]'
check "Breite steht im JSON" '[[ $(jq -r ".shots[0].width" "$dir/session.json") == 812 ]]'
check "Hoehe steht im JSON" '[[ $(jq -r ".shots[0].height" "$dir/session.json") == 460 ]]'
check "Kommentar steht im JSON" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Die Login-Maske" ]]'
check "Fensterklasse wird erkannt" '[[ $(jq -r ".shots[0].app" "$dir/session.json") == "firefox" ]]'
check "Fenstertitel wird erkannt" '[[ $(jq -r ".shots[0].window" "$dir/session.json") == "Testfenster" ]]'
# Ein kleineres Fenster auf einem anderen Workspace darf die Erkennung nicht kapern.
check "Fenster von anderen Workspaces zaehlen nicht" '[[ $(jq -r ".shots[0].app" "$dir/session.json") != "chrome" ]]'
check "PNG ist fuer andere lesbar" '[[ $(stat -c %a "$dir/01-die-login-maske.png") == 644 ]]'
check "fehlender PNG-Header ergibt Pixelgroesse 0" '[[ $(jq -r ".shots[0].pixelWidth" "$dir/session.json") == 0 ]]'

run shot --comment "Fehler nach dem Absenden" >/dev/null
check "zweiter Shot zaehlt hoch" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'
check "zweiter Shot bekommt Nummer 02" '[[ -f "$dir/02-fehler-nach-dem-absenden.png" ]]'

run shot --comment "Größe der Prüfung" >/dev/null
check "Umlaute im Dateinamen werden ersetzt" '[[ -f "$dir/03-groesse-der-pruefung.png" ]]'

run shot --comment "" >/dev/null
check "leerer Kommentar ergibt Standardnamen" '[[ -f "$dir/04-schritt.png" ]]'

# Ein echtes PNG (1x1, per Python erzeugt) muss mit seiner Pixelgroesse ankommen.
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
check "Pixelbreite kommt aus dem PNG-Header" '[[ $(jq -r ".shots[0].pixelWidth" "$dir/session.json") == 120 ]]'
check "Pixelhoehe kommt aus dem PNG-Header" '[[ $(jq -r ".shots[0].pixelHeight" "$dir/session.json") == 80 ]]'
check "logische Auswahl bleibt daneben stehen" '[[ $(jq -r ".shots[0].width" "$dir/session.json") == 50 ]]'
run finish --target "$WORK/hidpi" --title "HiDPI" >/dev/null
contains "Markdown nennt beide Groessen" "$(cat "$WORK/hidpi/shotline-$(date +%Y-%m-%d)-hidpi/session.md")" "50x50 px (Bild: 120x80 px)"

# Ab hier wieder der einfache grim-Stub.
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
target="${!#}"
printf '\x89PNG\r\n\x1a\n' >"$target"
STUB
chmod +x "$STUBS/grim"


echo
echo "Kommentar-Dialog"
fresh
export SHOTLINE_GEOMETRY="0,0 640x480"
export STUB_INPUT="Aus dem Dialog"
run shot >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "Dialog liefert den Kommentar" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Aus dem Dialog" ]]'
unset STUB_INPUT
run shot >/dev/null
check "abgebrochener Dialog behaelt den Shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'
check "abgebrochener Dialog laesst den Kommentar leer" '[[ $(jq -r ".shots[1].comment" "$dir/session.json") == "" ]]'

echo
echo "Auswahl abgebrochen"
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT=""
out=$(run shot); rc=$?
check "Abbruch der Auswahl endet mit Fehlercode" '[[ $rc -ne 0 ]]'
contains "Abbruch wird gemeldet" "$out" "abgebrochen"
dir=$(jq -r .dir <<<"$(run status --json)")
check "Abbruch legt keinen Shot an" '[[ $(jq -r ".shots | length" "$dir/session.json") == 0 ]]'

echo
echo "Tastenbefehle waehrend der Auswahl"
# Return und Ctrl+Return beenden slurp und hinterlassen nur eine Markerdatei.
marker_dir="${XDG_RUNTIME_DIR:-/tmp}"
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT=""
cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
# Bildet den Tastenbefehl nach: kein Ergebnis, dafuer eine Markerdatei.
[[ -n ${STUB_MARKER:-} ]] && touch "${XDG_RUNTIME_DIR:-/tmp}/omarchy-capture-region-$STUB_MARKER"
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB
chmod +x "$STUBS/slurp"

export STUB_MARKER="window"
export STUB_CURSOR="900, 400"
run shot --comment "Fenster per Return" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "Return nimmt das Fenster unter dem Zeiger" '[[ $(jq -r ".shots[0].geometry" "$dir/session.json") == "0,0 1200x900" ]]'
check "Marker wird danach aufgeraeumt" '[[ ! -e "$marker_dir/omarchy-capture-region-window" ]]'

export STUB_MARKER="fullscreen"
run shot --comment "Ganzer Bildschirm" >/dev/null
check "Ctrl+Return nimmt den ganzen Bildschirm" '[[ $(jq -r ".shots[1].geometry" "$dir/session.json") == "0,0 1920x1080" ]]'
check "Fullscreen-Marker wird aufgeraeumt" '[[ ! -e "$marker_dir/omarchy-capture-region-fullscreen" ]]'

# Ein Marker aus einem frueheren Lauf darf die naechste Auswahl nicht kapern.
unset STUB_MARKER
touch "$marker_dir/omarchy-capture-region-window"
out=$(run shot --comment "Darf nicht durchgehen"); rc=$?
check "alter Marker wird vor der Auswahl geloescht" '[[ $rc -ne 0 ]]'
check "alter Marker fuehrt zu keinem Shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 2 ]]'
rm -f "$marker_dir/omarchy-capture-region-window"

# Zeiger ausserhalb jedes Fensters trifft den Monitor.
export STUB_MARKER="window"
export STUB_CURSOR="5000, 5000"
run shot --comment "Zeiger im Nichts" >/dev/null
check "Zeiger ausserhalb faellt auf den Monitor zurueck" '[[ $(jq -r ".shots[2].geometry" "$dir/session.json") == "0,0 1920x1080" ]]'
unset STUB_MARKER STUB_CURSOR

cat >"$STUBS/slurp" <<'STUB'
#!/bin/bash
[[ -n ${STUB_SLURP_OUTPUT:-} ]] || exit 1
echo "$STUB_SLURP_OUTPUT"
STUB
chmod +x "$STUBS/slurp"

echo
echo "Auswahl per slurp"
fresh
unset SHOTLINE_GEOMETRY
export STUB_SLURP_OUTPUT="10,20 300x150"
run shot --comment "Aus slurp" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "slurp-Geometrie landet im JSON" '[[ $(jq -r ".shots[0].geometry" "$dir/session.json") == "10,20 300x150" ]]'
check "slurp-Breite wird uebernommen" '[[ $(jq -r ".shots[0].width" "$dir/session.json") == 300 ]]'
unset STUB_SLURP_OUTPUT

echo
echo "Rueckgaengig und Liste"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
run shot --comment "Eins" >/dev/null
run shot --comment "Zwei" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
run undo >/dev/null
check "undo entfernt den Eintrag" '[[ $(jq -r ".shots | length" "$dir/session.json") == 1 ]]'
check "undo loescht die Bilddatei" '[[ ! -f "$dir/02-zwei.png" ]]'
check "undo laesst den ersten Shot stehen" '[[ -f "$dir/01-eins.png" ]]'
out=$(run list)
contains "list zeigt den Kommentar" "$out" "Eins"
contains "list zeigt die Groesse" "$out" "100x100"
run undo >/dev/null
out=$(run undo)
contains "undo ohne Shots meldet das" "$out" "keine Shots"

echo
echo "Abschluss"
fresh
export SHOTLINE_GEOMETRY="0,0 800x600"
run shot --comment "Startbildschirm" >/dev/null
run shot --comment "Fehlermeldung" >/dev/null
target="$WORK/agent"
out=$(run finish --target "$target" --title "Login Flow")
result="$target/shotline-$(date +%Y-%m-%d)-login-flow"
check "Zielordner traegt Datum und Titel" '[[ -d "$result" ]]'
check "session.html liegt im Ziel" '[[ -f "$result/session.html" ]]'
check "session.md liegt im Ziel" '[[ -f "$result/session.md" ]]'
check "Bilder liegen im Ziel" '[[ -f "$result/01-startbildschirm.png" ]]'
check "session.json bleibt draussen" '[[ ! -f "$result/session.json" ]]'
check "Arbeitsverzeichnis ist geraeumt" '[[ $(jq -r .active <<<"$(run status --json)") == false ]]'
contains "Ausgabe nennt den Zielpfad" "$out" "$result"
contains "Ausgabe enthaelt den Agenten-Prompt" "$out" "session.md"
contains "Prompt nennt die Anzahl" "$out" "2 Screenshots"
check "Prompt liegt in der Zwischenablage" '[[ -s "$STUB_CLIPBOARD" ]]'
contains "Zwischenablage nennt den Pfad" "$(cat "$STUB_CLIPBOARD")" "$result/session.md"
md=$(cat "$result/session.md")
contains "Markdown nennt den Titel" "$md" "Login Flow"
contains "Markdown verlinkt relativ" "$md" "](01-startbildschirm.png)"
htmlfile=$(cat "$result/session.html")
contains "HTML nennt den Titel" "$htmlfile" "Login Flow"
contains "HTML hat den Theme-Umschalter" "$htmlfile" "toggleTheme"

out=$(run prompt)
contains "prompt wiederholt den Pfad" "$out" "$result"

echo
echo "Zielordner-Merkliste"
recent="$SHOTLINE_STATE_DIR/recent-targets"
check "Zielordner wird gemerkt" '[[ $(head -1 "$recent") == "$target" ]]'
run shot --comment "Noch einer" >/dev/null
export STUB_SELECT="$target"
export STUB_INPUT="Zweiter Lauf"
run finish >/dev/null
check "Auswahl aus der Merkliste funktioniert" '[[ -d "$target/shotline-$(date +%Y-%m-%d)-zweiter-lauf" ]]'
check "Merkliste bleibt ohne Duplikate" '[[ $(grep -cxF "$target" "$recent") == 1 ]]'
unset STUB_SELECT STUB_INPUT

echo
echo "Namenskollision"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
target="$WORK/kollision"
run shot --comment "A" >/dev/null
run finish --target "$target" --title "Gleich" >/dev/null
run shot --comment "B" >/dev/null
run finish --target "$target" --title "Gleich" >/dev/null
base="shotline-$(date +%Y-%m-%d)-gleich"
check "erster Ordner bleibt bestehen" '[[ -f "$target/$base/01-a.png" ]]'
check "zweiter Ordner bekommt ein Suffix" '[[ -f "$target/$base-2/01-b.png" ]]'

echo
echo "Abbruch der Session"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
run shot --comment "Weg damit" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
run cancel >/dev/null
check "cancel loescht das Arbeitsverzeichnis" '[[ ! -d "$dir" ]]'
check "cancel beendet die Session" '[[ $(jq -r .active <<<"$(run status --json)") == false ]]'
out=$(run cancel)
contains "cancel ohne Session meldet das" "$out" "keine laufende Session"

echo
echo "Abschluss ohne Shots"
fresh
run start "Leer" >/dev/null
out=$(run finish --target "$WORK/leer")
contains "finish ohne Shots wird abgelehnt" "$out" "keine Shots"
check "finish ohne Shots legt nichts an" '[[ ! -d "$WORK/leer" ]]'

echo
echo "Schlafender Bildschirm"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
export STUB_DPMS=false
export STUB_HYPRCTL_LOG="$WORK/hyprctl.log"
: >"$STUB_HYPRCTL_LOG"
run shot --comment "Nach dem Aufwecken" >/dev/null
contains "schlafender Bildschirm wird geweckt" "$(cat "$STUB_HYPRCTL_LOG")" 'hl.dsp.dpms("on")'
dir=$(jq -r .dir <<<"$(run status --json)")
check "Shot gelingt nach dem Wecken" '[[ $(jq -r ".shots | length" "$dir/session.json") == 1 ]]'
# Aeltere Hyprland-Versionen kennen die Lua-Form nicht: dann greift die Kurzform.
: >"$STUB_HYPRCTL_LOG"
export STUB_EVAL_FAILS=1
run shot --comment "Alter Hyprland-Weg" >/dev/null
contains "Rueckfall auf die alte dpms-Kurzform" "$(cat "$STUB_HYPRCTL_LOG")" "dispatch dpms on"
unset STUB_EVAL_FAILS

unset STUB_DPMS
: >"$STUB_HYPRCTL_LOG"
run shot --comment "Wacher Bildschirm" >/dev/null
check "wacher Bildschirm wird nicht geweckt" '[[ $(grep -c "dpms" "$STUB_HYPRCTL_LOG") == 0 ]]'
check "Hardware-Cursor wird fuer die Aufnahme erzwungen" '[[ $(grep -c "keyword cursor:no_hardware_cursors 0$" "$STUB_HYPRCTL_LOG") == 1 ]]'
check "Cursor-Einstellung wird danach zurueckgesetzt" '[[ $(grep -c "keyword cursor:no_hardware_cursors 2$" "$STUB_HYPRCTL_LOG") == 1 ]]'
unset STUB_HYPRCTL_LOG

echo
echo "Haengendes grim"
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
check "haengendes grim wird abgebrochen" '[[ $rc -ne 0 ]]'
check "Abbruch dauert nur Sekunden" '[[ $elapsed -lt 10 ]]'
contains "Hinweis auf den schlafenden Bildschirm" "$out" "schlaeft vermutlich"
dir=$(jq -r .dir <<<"$(run status --json)")
check "haengendes grim legt keinen Shot an" '[[ $(jq -r ".shots | length" "$dir/session.json") == 0 ]]'
unset SHOTLINE_GRAB_TIMEOUT
cat >"$STUBS/grim" <<'STUB'
#!/bin/bash
# Nur die PNG-Signatur, kein IHDR: so testet der Fall ohne echte Bildgroesse.
target="${!#}"
printf '\x89PNG\r\n\x1a\n' >"$target"
STUB
chmod +x "$STUBS/grim"

echo
echo "Namen und Pfade"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
run shot --comment "Ein sehr langer Kommentar der auf jeden Fall abgeschnitten werden muss" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
name=$(jq -r ".shots[0].file" "$dir/session.json")
check "langer Name wird gekuerzt" '[[ ${#name} -le 48 ]]'
check "gekuerzter Name endet nicht auf einem Bindestrich" '[[ $name != *-.png ]]'

# Ein relativer Zielpfad muss absolut im Ergebnis und im Prompt landen.
mkdir -p "$WORK/relativ"
out=$(cd "$WORK" && SHOTLINE_STATE_DIR="$SHOTLINE_STATE_DIR" "$CLI" finish --target "./relativ" --title "Relativ" 2>&1)
check "relatives Ziel wird absolut aufgeloest" '[[ -d "$WORK/relativ/shotline-$(date +%Y-%m-%d)-relativ" ]]'
check "Prompt enthaelt keinen relativen Pfad" '[[ $out != *"./relativ/shotline"* ]]'
contains "Prompt nennt den absoluten Pfad" "$out" "$WORK/relativ/shotline"
contains "ein einzelner Shot steht im Singular" "$out" "liegt 1 Screenshot "

echo
echo "Markieren im Editor"
fresh
export SHOTLINE_GEOMETRY="0,0 400x300"
export STUB_EDITOR_LOG="$WORK/editor.log"
cat >"$WORK/editor-stub" <<'STUB'
#!/bin/bash
echo "$1|$2" >>"${STUB_EDITOR_LOG:-/dev/null}"
[[ ${STUB_EDITOR_FAILS:-} == 1 ]] && exit 1
# Der Editor darf das Bild ersetzen: hier durch eines mit anderer Groesse.
[[ -n ${STUB_EDITOR_REPLACEMENT:-} ]] && cp "$STUB_EDITOR_REPLACEMENT" "$1"
exit 0
STUB
chmod +x "$WORK/editor-stub"
export SHOTLINE_EDITOR_STUB="$WORK/editor-stub"

run shot --comment "Vor der Markierung" >/dev/null
dir=$(jq -r .dir <<<"$(run status --json)")
check "status meldet Markieren moeglich" '[[ $(jq -r .canAnnotate <<<"$(run status --json)") == true ]]'

: >"$STUB_EDITOR_LOG"
export STUB_INPUT="Nach der Markierung"
run annotate >/dev/null
contains "Editor bekommt die Bilddatei" "$(cat "$STUB_EDITOR_LOG")" "01-vor-der-markierung.png"
contains "Editor startet mit dem Stift" "$(cat "$STUB_EDITOR_LOG")" "|brush"
check "Kommentar wird nachgezogen" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Nach der Markierung" ]]'
check "Shot ist als markiert vermerkt" '[[ $(jq -r ".shots[0].annotated" "$dir/session.json") == true ]]'

: >"$STUB_EDITOR_LOG"
unset STUB_INPUT
run annotate >/dev/null
check "leere Eingabe behaelt den Kommentar" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Nach der Markierung" ]]'

: >"$STUB_EDITOR_LOG"
run annotate --blur >/dev/null
contains "Blur startet mit dem passenden Werkzeug" "$(cat "$STUB_EDITOR_LOG")" "|blur"

# Ein Editor, der zuschneidet, aendert die Bildgroesse: sie wird neu gemessen.
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
check "Bildgroesse wird nach dem Editor neu gemessen" '[[ $(jq -r ".shots[0].pixelWidth" "$dir/session.json") == 640 ]]'
unset STUB_EDITOR_REPLACEMENT

# Abbruch im Editor darf nichts veraendern.
run shot --comment "Bleibt so" >/dev/null
export STUB_EDITOR_FAILS=1
export STUB_INPUT="Darf nicht ankommen"
out=$(run annotate); rc=$?
check "abgebrochener Editor endet mit Fehlercode" '[[ $rc -ne 0 ]]'
check "abgebrochener Editor laesst den Kommentar stehen" '[[ $(jq -r ".shots[1].comment" "$dir/session.json") == "Bleibt so" ]]'
check "abgebrochener Editor setzt kein Markiert-Kennzeichen" '[[ $(jq -r ".shots[1].annotated" "$dir/session.json") == null ]]'
unset STUB_EDITOR_FAILS STUB_INPUT

# Ein bestimmter Shot laesst sich gezielt waehlen.
: >"$STUB_EDITOR_LOG"
run annotate --index 1 >/dev/null
contains "Index waehlt den ersten Shot" "$(cat "$STUB_EDITOR_LOG")" "01-vor-der-markierung.png"
out=$(run annotate --index 9)
contains "unbekannter Index wird abgelehnt" "$out" "keinen Shot Nummer 9"

fresh
out=$(run annotate)
contains "annotate ohne Session meldet das" "$out" "keine laufende Session"

echo
echo "Menue"
fresh
export SHOTLINE_GEOMETRY="0,0 100x100"
export STUB_SELECT_LOG="$WORK/menu.log"
: >"$STUB_SELECT_LOG"
export STUB_SELECT="Naechster Shot"
run menu >/dev/null
menu_leer=$(cat "$STUB_SELECT_LOG")
check "Menue ohne Shots bietet nur die Aufnahme" '[[ $(grep -c "markieren" <<<"$menu_leer") == 0 ]]'
contains "Menue bietet den naechsten Shot" "$menu_leer" "Naechster Shot"
dir=$(jq -r .dir <<<"$(run status --json)")
check "Menue-Auswahl nimmt einen Shot auf" '[[ $(jq -r ".shots | length" "$dir/session.json") == 1 ]]'

: >"$STUB_SELECT_LOG"
export STUB_SELECT="Letzten markieren"
export STUB_INPUT="Aus dem Menue markiert"
: >"$STUB_EDITOR_LOG"
run menu >/dev/null
menu_voll=$(cat "$STUB_SELECT_LOG")
contains "Menue bietet Markieren" "$menu_voll" "Letzten markieren"
contains "Menue bietet Unkenntlichmachen" "$menu_voll" "Letzten unkenntlich machen"
contains "Menue bietet den Abschluss" "$menu_voll" "Serie abschliessen"
contains "Menue bietet das Verwerfen" "$menu_voll" "Serie verwerfen"
check "Menue-Eintraege tragen ein Symbol vor dem Label" '[[ $(grep -cP "^\\S+\\tLetzten markieren$" <<<"$menu_voll") == 1 ]]'
check "Menue startet den Editor" '[[ -s "$STUB_EDITOR_LOG" ]]'
check "Menue zieht den Kommentar nach" '[[ $(jq -r ".shots[0].comment" "$dir/session.json") == "Aus dem Menue markiert" ]]'

export STUB_SELECT="Letzten verwerfen"
run menu >/dev/null
check "Menue verwirft den letzten Shot" '[[ $(jq -r ".shots | length" "$dir/session.json") == 0 ]]'

export STUB_SELECT=""
out=$(run menu); rc=$?
check "abgebrochenes Menue endet ohne Fehler" '[[ $rc -eq 0 ]]'
unset STUB_SELECT STUB_INPUT STUB_SELECT_LOG

echo
echo "Bedienhilfen"
fresh
out=$(run --help)
contains "Hilfe nennt shot" "$out" "shot"
contains "Hilfe nennt finish" "$out" "finish"
contains "Hilfe nennt annotate" "$out" "annotate"
contains "Hilfe nennt menu" "$out" "menu"
out=$(run quatsch 2>&1); rc=$?
check "unbekannter Befehl endet mit Code 2" '[[ $rc -eq 2 ]]'

echo
printf 'Ergebnis: \033[32m%d bestanden\033[0m, ' "$PASSED"
if ((FAILED > 0)); then
  printf '\033[31m%d gescheitert\033[0m\n\n' "$FAILED"
  exit 1
fi
printf '0 gescheitert\n\n'
