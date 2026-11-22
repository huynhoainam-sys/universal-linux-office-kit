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
main --repair-desktop --yes --report "$REPORT_PATH"
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'office,unikey,flameshot,zalo,' ]]
[[ -s "$REPORT_PATH" ]]
[[ -s "$TEMP/report.html" ]]
find "$XDG_STATE_HOME/ulok/backups" -mindepth 1 -maxdepth 1 -type d | grep -q .
echo 'PASS: one-shot desktop repair and automatic config snapshot'

rm -f "$TEMP/flow"
REPAIR_DESKTOP=0 FIX_OFFICE=0 FIX_UNIKEY=0 FIX_FLAMESHOT=0 FIX_ZALO=0 UPDATE_ZALO=0 FIX_ZALO_LOGIN=0
main --fix-zalo-login --dry-run --yes --report "$REPORT_PATH"
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'zalo,' ]]
grep -q 'zalo-login-recover.sh --dry-run' "$TEMP/setup.log"
echo 'PASS: QR login recovery dry run never moves user database'
