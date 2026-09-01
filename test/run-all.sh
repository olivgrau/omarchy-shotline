#!/bin/bash
# Runs every test. Works without a Wayland session.
set -uo pipefail
HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"
FAILED=0

echo "== Renderer (Python) =="
"${PYTHON:-python}" "$HERE/test_render.py" 2>&1 | tail -4 || FAILED=1

echo
echo "== CLI (Bash, end-to-end) =="
"$HERE/test_cli.sh" || FAILED=1

echo "== Manifest =="
if command -v omarchy-plugin-validate >/dev/null 2>&1; then
  omarchy-plugin-validate "$ROOT" && echo "manifest.json is valid" || FAILED=1
else
  jq -e . "$ROOT/manifest.json" >/dev/null && echo "manifest.json is valid JSON (validator missing)" || FAILED=1
fi

echo "== Shell syntax =="
bash -n "$ROOT/bin/shotline" && bash -n "$ROOT/install.sh" && echo "bash ok" || FAILED=1

exit $FAILED
