#!/bin/bash
# shotline -- Installer fuer Omarchy.
#
#   ./install.sh            installiert alles
#   ./install.sh uninstall  entfernt alles wieder
#
# Der Installer fasst nur eigene Dateien und einen klar markierten Block in
# bindings.lua an. Ein uninstall stellt den vorherigen Zustand her.
#
# Tasten lassen sich beim Aufruf ueberschreiben:
#   SHOT_KEY="SUPER + SHIFT + P" ./install.sh

set -euo pipefail

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION="${1:-install}"

PLUGIN_ID="olivgrau.shotline"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"
BIN_DIR="$HOME/.local/bin"
HYPR_BINDINGS="$HOME/.config/hypr/bindings.lua"

SHOT_KEY="${SHOT_KEY:-SUPER + SHIFT + K}"
FINISH_KEY="${FINISH_KEY:-SUPER + SHIFT + L}"
UNDO_KEY="${UNDO_KEY:-SUPER + SHIFT + U}"
MARK_KEY="${MARK_KEY:-SUPER + SHIFT + Z}"
MENU_KEY="${MENU_KEY:-SUPER + SHIFT + I}"

BEGIN="-- >>> shotline >>>"
END="-- <<< shotline <<<"

say() { printf '\033[32m▸\033[0m %s\n' "$1"; }
warn() { printf '\033[33m!\033[0m %s\n' "$1"; }

backup() {
  [[ -f $1 ]] && cp "$1" "$1.shotline-bak.$(date +%s)"
  return 0
}

strip_block() {
  local file="$1"
  [[ -f $file ]] || return 0
  if grep -qF -e "$BEGIN" "$file"; then
    backup "$file"
    sed -i "/$(sed 's/[][\.*^$/]/\\&/g' <<<"$BEGIN")/,/$(sed 's/[][\.*^$/]/\\&/g' <<<"$END")/d" "$file"
  fi
}

append_block() {
  local file="$1" body="$2"
  strip_block "$file"
  printf '\n%s\n%s\n%s\n' "$BEGIN" "$body" "$END" >>"$file"
}

# --------------------------------------------------------------- uninstall

if [[ $ACTION == "uninstall" ]]; then
  say "entferne den Starter"
  rm -f "$BIN_DIR/shotline" "$BIN_DIR/shotline-render"

  if [[ -e $PLUGIN_DIR ]]; then
    say "entferne das Shell-Plugin"
    omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    rm -rf "$PLUGIN_DIR"
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi

  say "setze die Tastenbelegung zurueck"
  strip_block "$HYPR_BINDINGS"
  hyprctl reload >/dev/null 2>&1 || true

  say "shotline entfernt. Aufgenommene Serien bleiben liegen."
  exit 0
fi

# ----------------------------------------------------------------- install

for tool in grim slurp jq python; do
  command -v "$tool" >/dev/null 2>&1 || { warn "$tool fehlt. Bitte zuerst installieren."; exit 1; }
done
command -v hyprpicker >/dev/null 2>&1 || warn "hyprpicker fehlt: der Bildschirm friert waehrend der Auswahl nicht ein."
command -v "${SHOTLINE_EDITOR:-tensaku}" >/dev/null 2>&1 \
  || warn "tensaku fehlt: Markieren und Unkenntlichmachen stehen nicht zur Verfuegung."

say "verlinke die CLI nach $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sfn "$ROOT/bin/shotline" "$BIN_DIR/shotline"
ln -sfn "$ROOT/bin/shotline-render" "$BIN_DIR/shotline-render"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR liegt nicht im PATH. Die Tastenkuerzel nutzen den vollen Pfad, das genuegt." ;;
esac

say "installiere das Shell-Plugin ($PLUGIN_ID)"
mkdir -p "$HOME/.config/omarchy/plugins"
rm -rf "$PLUGIN_DIR"
# Das Repo-Wurzelverzeichnis ist das Plugin-Verzeichnis: manifest.json liegt
# hier. Der Symlink laesst Aenderungen im Repo sofort in omarchy-shell wirken.
ln -sfn "$ROOT" "$PLUGIN_DIR"

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$ROOT" >/dev/null || { warn "manifest.json ist ungueltig"; exit 1; }
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || warn "konnte die Plugins nicht neu einlesen"
  omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 \
    || warn "aktiviere es selbst: omarchy plugin enable $PLUGIN_ID"
fi

# Belegte Tasten meldet der Installer, statt sie stillschweigend zu ueberschreiben.
check_key() {
  local key="$1" name="$2" mods=0 last
  command -v hyprctl >/dev/null 2>&1 || return 0
  IFS='+' read -r -a parts <<<"${key// /}"
  last="${parts[-1]}"
  for part in "${parts[@]::${#parts[@]}-1}"; do
    case "${part^^}" in
      SUPER) mods=$((mods + 64)) ;;
      SHIFT) mods=$((mods + 1)) ;;
      CTRL | CONTROL) mods=$((mods + 4)) ;;
      ALT) mods=$((mods + 8)) ;;
    esac
  done
  if hyprctl binds -j 2>/dev/null \
     | jq -e --argjson m "$mods" --arg k "${last^^}" \
       '.[] | select(.modmask == $m and (.key | ascii_upcase) == $k)' >/dev/null 2>&1; then
    warn "$key ist bereits belegt ($name). Setze eine andere Taste: ${name}=\"SUPER + SHIFT + ...\" ./install.sh"
  fi
}

check_key "$SHOT_KEY" SHOT_KEY
check_key "$FINISH_KEY" FINISH_KEY
check_key "$UNDO_KEY" UNDO_KEY
check_key "$MARK_KEY" MARK_KEY
check_key "$MENU_KEY" MENU_KEY

say "traegt die Tastenkuerzel in bindings.lua ein"
mkdir -p "$(dirname "$HYPR_BINDINGS")"
touch "$HYPR_BINDINGS"
append_block "$HYPR_BINDINGS" "$(cat <<BINDINGS
o.bind("$SHOT_KEY", "Shotline: Shot", "$BIN_DIR/shotline shot")
o.bind("$FINISH_KEY", "Shotline: Serie abschliessen", "$BIN_DIR/shotline finish --open")
o.bind("$UNDO_KEY", "Shotline: letzten Shot verwerfen", "$BIN_DIR/shotline undo")
o.bind("$MARK_KEY", "Shotline: letzten Shot markieren", "$BIN_DIR/shotline annotate")
o.bind("$MENU_KEY", "Shotline: Menue", "$BIN_DIR/shotline menu")
BINDINGS
)"
hyprctl reload >/dev/null 2>&1 || true

cat <<DONE

$(say "fertig")

  $SHOT_KEY    naechsten Screenshot aufnehmen und kommentieren
  $MARK_KEY    letzten Shot markieren (Stift, Blur), danach Kommentar
  $UNDO_KEY    letzten Shot verwerfen
  $MENU_KEY    Menue mit allen Aktionen
  $FINISH_KEY  Serie ablegen, HTML oeffnen, Agenten-Prompt kopieren

  Das Bar-Widget "Shotline" zeigt den Zaehler der laufenden Session.
  Fehlt es in der Bar:  omarchy bar set

DONE
