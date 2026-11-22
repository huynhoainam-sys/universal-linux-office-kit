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
main --repair-desktop --yes --report "$REPORT_PATH"
[[ "$(tr '\n' ',' < "$TEMP/flow")" == 'unikey,flameshot,zalo,' ]]
[[ -s "$REPORT_PATH" ]]
find "$XDG_STATE_HOME/ulok/backups" -mindepth 1 -maxdepth 1 -type d | grep -q .
echo 'PASS: one-shot desktop repair and automatic config snapshot'
