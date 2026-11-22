#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
require_platform() { return 0; }
repair_package_state() { warn 'Proxy APT update timeout; continuing with cached packages'; return 1; }
backup_desktop_settings() { BACKUP_DIR="$TEMP/backup"; mkdir -p -- "$BACKUP_DIR"; }
module_base() { warn 'Optional base tool unavailable'; }
module_vietnamese_input() {
  printf '%s\n' unikey >> "$TEMP/flow"
  [[ "${SIMULATE_UNIKEY_FAILURE:-0}" != 1 ]]
}
module_flameshot() { printf '%s\n' flameshot >> "$TEMP/flow"; }
module_zalo() { printf '%s\n' zalo >> "$TEMP/flow"; }
module_office() { warn 'WPS download blocked; continue without replacing Office'; }
module_media() { warn 'Optional codecs unavailable'; }
module_everyday() { warn 'Optional file previewer unavailable'; }
verify() { return 0; }

main --profile desktop --yes --no-open-report --report "$TEMP/report.txt"
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'unikey,flameshot,zalo,' ]]
grep -q '^Warnings: 5$' "$TEMP/report.txt"
grep -q '^Failures: 0$' "$TEMP/report.txt"

# A single core failure must still allow the two remaining critical apps.
SIMULATE_UNIKEY_FAILURE=1
WARNINGS=() FAILURES=()
: > "$TEMP/flow"
if main --profile desktop --yes --no-open-report --report "$TEMP/report.txt"; then
  echo 'FAIL: missing Unikey must result in a visible failure status' >&2
  exit 1
fi
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'unikey,flameshot,zalo,' ]]
grep -q '^Failures: 1$' "$TEMP/report.txt"
echo 'PASS: proxy/optional failures do not block Unikey, Flameshot or Zalo; critical failures remain visible'
