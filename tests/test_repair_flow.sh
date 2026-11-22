#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_CONFIG_HOME="$TEMP/home/.config" XDG_STATE_HOME="$TEMP/home/.local/state"
mkdir -p "$HOME"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
REPORT_PATH="$TEMP/report.txt"
require_platform() { return 0; }
module_vietnamese_input() { echo unikey >> "$TEMP/flow"; }
module_flameshot() { echo flameshot >> "$TEMP/flow"; }
module_zalo() { echo zalo >> "$TEMP/flow"; }
module_office_suites() { echo office >> "$TEMP/flow"; }
module_outlook_web() { echo outlook >> "$TEMP/flow"; }
main --repair-desktop --yes --report "$REPORT_PATH"
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'office,outlook,unikey,flameshot,zalo,' ]]
[[ -s "$REPORT_PATH" ]]
[[ -s "$TEMP/report.html" ]]
find "$XDG_STATE_HOME/ulok/backups" -mindepth 1 -maxdepth 1 -type d | grep -q .
echo 'PASS: one-shot desktop repair and automatic config snapshot'

rm -f "$TEMP/flow"
REPAIR_DESKTOP=0 FIX_OFFICE=0 FIX_OUTLOOK=0 FIX_UNIKEY=0 FIX_FLAMESHOT=0 FIX_ZALO=0 UPDATE_ZALO=0 FIX_ZALO_LOGIN=0
main --fix-zalo-login --dry-run --yes --report "$REPORT_PATH"
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'zalo,' ]]
grep -q 'zalo-login-recover.sh --dry-run' "$TEMP/setup.log"
echo 'PASS: QR login recovery dry run never moves user database'

# Losing Zalo to a proxy must never undo a working Unikey/Flameshot setup.
rm -f "$TEMP/flow"
WARNINGS=() FAILURES=()
DRY_RUN=0 FIX_ZALO_LOGIN=0 FIX_ZALO=0 UPDATE_ZALO=0 FIX_UNIKEY=0 FIX_FLAMESHOT=0 FIX_OFFICE=0 FIX_OUTLOOK=0
module_zalo() { echo zalo >> "$TEMP/flow"; return 1; }
restore_desktop_settings() { echo rollback > "$TEMP/unwanted-rollback"; }
if main --repair-desktop --yes --no-open-report --report "$REPORT_PATH"; then
  echo 'FAIL: Zalo failure was not reported' >&2
  exit 1
fi
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'office,outlook,unikey,flameshot,zalo,' ]]
[[ ! -e "$TEMP/unwanted-rollback" ]] || { echo 'FAIL: Zalo failure reverted working desktop settings' >&2; exit 1; }
echo 'PASS: partial repair preserves already repaired Unikey/Flameshot and keeps a backup'
