#!/bin/bash
# shotline -- installer for Omarchy.
#
#   ./install.sh            install everything
#   ./install.sh uninstall  remove everything it added
#
# The installer only touches its own files and one clearly marked block in
# bindings.lua. An uninstall restores the previous state.
#
# Keys can be overridden on the command line:
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
  say "removing the launcher"
  rm -f "$BIN_DIR/shotline" "$BIN_DIR/shotline-render"

  if [[ -e $PLUGIN_DIR ]]; then
    say "removing the shell plugin"
    omarchy plugin disable "$PLUGIN_ID" >/dev/null 2>&1 || true
    rm -rf "$PLUGIN_DIR"
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  fi

  say "reverting the key bindings"
  strip_block "$HYPR_BINDINGS"
  hyprctl reload >/dev/null 2>&1 || true

  say "shotline removed. Captured series are left untouched."
  exit 0
fi

# ----------------------------------------------------------------- install

for tool in grim slurp jq python; do
  command -v "$tool" >/dev/null 2>&1 || { warn "$tool is missing. Please install it first."; exit 1; }
done
command -v hyprpicker >/dev/null 2>&1 || warn "hyprpicker is missing: the screen will not freeze during selection."
command -v "${SHOTLINE_EDITOR:-tensaku}" >/dev/null 2>&1 \
  || warn "tensaku is missing: annotating and blurring will not be available."

say "linking the CLI into $BIN_DIR"
mkdir -p "$BIN_DIR"
ln -sfn "$ROOT/bin/shotline" "$BIN_DIR/shotline"
ln -sfn "$ROOT/bin/shotline-render" "$BIN_DIR/shotline-render"

case ":$PATH:" in
  *":$BIN_DIR:"*) ;;
  *) warn "$BIN_DIR is not on PATH. The key bindings use the full path, so that is fine." ;;
esac

say "installing the shell plugin ($PLUGIN_ID)"
mkdir -p "$HOME/.config/omarchy/plugins"
rm -rf "$PLUGIN_DIR"
# The repo root is the plugin directory: manifest.json lives here. The symlink
# lets changes in the repo take effect in omarchy-shell right away.
ln -sfn "$ROOT" "$PLUGIN_DIR"

if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$ROOT" >/dev/null || { warn "manifest.json is invalid"; exit 1; }
fi

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || warn "could not rescan the plugins"
  omarchy plugin enable "$PLUGIN_ID" >/dev/null 2>&1 \
    || warn "enable it yourself: omarchy plugin enable $PLUGIN_ID"
fi

# The installer reports taken keys instead of silently overriding them.
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
    warn "$key is already taken ($name). Pick another: ${name}=\"SUPER + SHIFT + ...\" ./install.sh"
  fi
}

check_key "$SHOT_KEY" SHOT_KEY
check_key "$FINISH_KEY" FINISH_KEY
check_key "$UNDO_KEY" UNDO_KEY
check_key "$MARK_KEY" MARK_KEY
check_key "$MENU_KEY" MENU_KEY

say "writing the key bindings into bindings.lua"
mkdir -p "$(dirname "$HYPR_BINDINGS")"
touch "$HYPR_BINDINGS"
append_block "$HYPR_BINDINGS" "$(cat <<BINDINGS
o.bind("$SHOT_KEY", "Shotline: shot", "$BIN_DIR/shotline shot")
o.bind("$FINISH_KEY", "Shotline: finish series", "$BIN_DIR/shotline finish --open")
o.bind("$UNDO_KEY", "Shotline: discard last shot", "$BIN_DIR/shotline undo")
o.bind("$MARK_KEY", "Shotline: annotate last shot", "$BIN_DIR/shotline annotate")
o.bind("$MENU_KEY", "Shotline: menu", "$BIN_DIR/shotline menu")
BINDINGS
)"
hyprctl reload >/dev/null 2>&1 || true

cat <<DONE

$(say "done")

  $SHOT_KEY    capture the next screenshot and comment on it
  $MARK_KEY    annotate the last shot (pen, blur), then the comment
  $UNDO_KEY    discard the last shot
  $MENU_KEY    menu with every action
  $FINISH_KEY  file the series away, open the HTML, copy the agent prompt

  The bar widget "Shotline" shows the counter of the running session.
  Missing from the bar?  omarchy bar set

DONE
