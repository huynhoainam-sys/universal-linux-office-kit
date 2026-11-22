#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT

# Dry-run must exercise the same everyday profile without changing host packages.
(
  export FORCE_COLOR=1 TERM=xterm-256color
  source "$ROOT/setup.sh"
  LOG_PATH="$TEMP/setup.log"
  require_platform() { ID=ubuntu; VERSION_ID=24.04; return 0; }
  main --profile desktop --dry-run --yes --no-open-report \
    --report "$TEMP/desktop.txt"
) >"$TEMP/terminal.txt"
[[ -s "$TEMP/desktop.html" ]]
grep -q '^Profile: desktop$' "$TEMP/desktop.txt"
grep -q 'Module: everyday desktop' "$TEMP/setup.log"
grep -q 'Module: Zalo Linux' "$TEMP/setup.log"
grep -q '12/12' "$TEMP/terminal.txt"
grep -q 'ĐÃ MÔ PHỎNG' "$TEMP/terminal.txt"
grep -q 'Sao lưu Backups' "$TEMP/desktop.html"
grep -q 'Chia sẻ Windows / NAS' "$TEMP/desktop.html"
grep -q 'smb://server/share' "$TEMP/desktop.html"
if grep -q 'Module: dev\|Module: official third-party apps\|Module: flatpak' "$TEMP/setup.log"; then
  echo 'FAIL: developer/third-party tools leaked into desktop profile' >&2
  exit 1
fi
echo 'PASS: everyday desktop dry-run keeps dev tools optional and reports Windows migration features'
