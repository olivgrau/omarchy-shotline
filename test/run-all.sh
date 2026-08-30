#!/bin/bash
# Faehrt alle Tests. Ohne Wayland-Sitzung nutzbar.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
FAILED=0

echo "== Renderer (Python) =="
"${PYTHON:-python}" "$HERE/test_render.py" 2>&1 | tail -4 || FAILED=1

echo
echo "== CLI (Bash, End-to-End) =="
"$HERE/test_cli.sh" || FAILED=1

echo "== Manifest =="
if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$ROOT" && echo "manifest.json ist gueltig" || FAILED=1
else
  jq -e . "$ROOT/manifest.json" >/dev/null && echo "manifest.json ist gueltiges JSON (Validator fehlt)" || FAILED=1
fi

echo "== Shell-Syntax =="
bash -n "$ROOT/bin/shotline" && bash -n "$ROOT/install.sh" && echo "bash ok" || FAILED=1

exit $FAILED
