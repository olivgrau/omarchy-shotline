#!/bin/bash
# Baut das Kurzvideo fuer den X-Post aus den Screenshots.
#   ./video/build.sh          -> video/shotline.mp4 und video/shotline.gif
# Braucht ffmpeg und ImageMagick. Idempotent: raeumt seine Zwischendateien auf.

set -euo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
SHOTS="$ROOT/screenshots"
WORK="$HERE/.work"
BG='#0b0e12'
FG='#e8edf3'
DIM='#8b98a8'
ACCENT='#4ade80'
SANS=$(fc-match -f '%{file}' 'Liberation Sans')
SANS_BOLD=$(fc-match -f '%{file}' 'Liberation Sans:bold')

rm -rf "$WORK"; mkdir -p "$WORK"
trap 'rm -rf "$WORK"' EXIT

# Vollflaechige Textkarte.
card() { # card <datei> <zeile1> <zeile2> <zeile3>
  magick -size 1280x720 "xc:$BG" \
    -font "$SANS_BOLD" -fill "$FG" -pointsize 62 -gravity center \
    -annotate +0-70 "$2" \
    -font "$SANS" -fill "$DIM" -pointsize 34 \
    -annotate +0+10 "${3:-}" \
    -font "$SANS" -fill "$ACCENT" -pointsize 30 \
    -annotate +0+90 "${4:-}" \
    "$1"
}

# Screenshot mit Bildunterschrift auf 1280x720. Das ">" haelt kleine Bilder
# (etwa den Bar-Ausschnitt) in ihrer Groesse, statt sie unscharf aufzublasen.
slide() { # slide <datei> <quelle> <text>
  magick "$2" -resize '1200x540>' -background "$BG" -gravity center -extent 1280x620 \
    -background "$BG" -gravity north -extent 1280x720 \
    -font "$SANS" -fill "$FG" -pointsize 32 -gravity south -annotate +0+48 "$3" \
    -flatten "$1"
}

card "$WORK/00.png" "4 bugs. 4 screenshots." "Your agent gets all of them in one file." "Shotline for Omarchy"
slide "$WORK/01.png" "$SHOTS/01-app-with-bugs.png"      "Drag a region — the size is shown while you drag"
slide "$WORK/02.png" "$SHOTS/02-comment-dialog.png"     "Comment right away, without leaving the app"
slide "$WORK/03.png" "$SHOTS/03-bar-widget.png"         "The bar counts. The pen shows up when there is something to mark"
slide "$WORK/04.png" "$SHOTS/04-annotation.png"         "Highlight or blur, then back to the comment"
slide "$WORK/05.png" "$SHOTS/05-session-html-light.png" "One HTML page for you"
slide "$WORK/06.png" "$SHOTS/07-session-md.png"         "One Markdown file for the agent"
slide "$WORK/07.png" "$SHOTS/08-agent-prompt.png"       "And the prompt lands in your clipboard"
card "$WORK/08.png" "Shotline" "Step-by-step screenshot walkthroughs for AI agents" "github.com/olivgrau/omarchy-shotline"

durations=(3.0 3.6 3.6 2.6 3.6 3.4 3.6 3.6 3.4)
: >"$WORK/list.txt"
for i in "${!durations[@]}"; do
  n=$(printf '%02d' "$i")
  d=${durations[i]}
  out=$(printf '%s/clip%02d.mp4' "$WORK" "$i")
  fade_out=$(awk "BEGIN{printf \"%.2f\", $d - 0.45}")
  ffmpeg -loglevel error -y -loop 1 -i "$WORK/$n.png" -t "$d" \
    -vf "fade=t=in:st=0:d=0.35,fade=t=out:st=$fade_out:d=0.45,format=yuv420p" \
    -r 30 -c:v libx264 -preset medium -crf 20 "$out"
  echo "file '$out'" >>"$WORK/list.txt"
done

ffmpeg -loglevel error -y -f concat -safe 0 -i "$WORK/list.txt" -c copy "$HERE/shotline.mp4"

# GIF fuer Stellen, die kein MP4 moegen.
# Bewusst ohne palettegen/paletteuse: die Filterkette bricht bei diesem
# Material reproduzierbar ab und liefert ein GIF mit nur wenigen Frames.
ffmpeg -loglevel error -y -i "$HERE/shotline.mp4" -vf "fps=8,scale=640:-2" -loop 0 "$HERE/shotline.gif"

printf 'fertig:\n  %s (%s)\n  %s (%s)\n' \
  "$HERE/shotline.mp4" "$(du -h "$HERE/shotline.mp4" | cut -f1)" \
  "$HERE/shotline.gif" "$(du -h "$HERE/shotline.gif" | cut -f1)"
