#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
export DISPLAY=:1111
require_platform() { return 0; }
backup_desktop_settings() { BACKUP_DIR="$TEMP/backup"; mkdir -p -- "$BACKUP_DIR"; }
module_office_suites() { return 0; }
xdg-open() { printf '%s\n' "$*" > "$TEMP/opened.txt"; }

main --fix-office --yes --report "$TEMP/report.txt"
[[ -s "$TEMP/report.html" ]]
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -s "$TEMP/opened.txt" ]] && break
  sleep 0.05
done
[[ "$(<"$TEMP/opened.txt")" == "$TEMP/report.html" ]] || { echo 'FAIL: HTML report did not auto-open' >&2; exit 1; }

OPEN_HTML_REPORT=1 FIX_OFFICE=0
rm -f -- "$TEMP/opened.txt"
main --fix-office --no-open-report --yes --report "$TEMP/report.txt"
[[ ! -e "$TEMP/opened.txt" ]] || { echo 'FAIL: --no-open-report ignored' >&2; exit 1; }
echo 'PASS: HTML report auto-opens on desktop, and can be disabled'
