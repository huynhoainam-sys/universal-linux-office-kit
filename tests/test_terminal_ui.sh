#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
REPORT_PATH="$TEMP/setup-report.txt"
export FORCE_COLOR=1 TERM=xterm
unset NO_COLOR
ui_init
UI_TOTAL=2
output="$(ui_banner; ui_stage 'Kiểm tra Ubuntu'; log 'PASS: Kiểm tra hoàn tất'; ui_stage 'Zalo'; ui_finish)"
[[ "$output" == *NAMHH* && "$output" == *huynhoainam@gmail.com* ]]
[[ "$output" == *'100%'* && "$output" == *'Zalo'* ]]
[[ "$output" == *'[01/02]'* && "$output" == *'[02/02]'* ]]
[[ "$output" != *'█'* ]] || { echo 'FAIL: visual progress bar is too busy' >&2; exit 1; }
[[ "$output" == *$'\033['* ]] || { echo 'FAIL: ANSI colors missing with FORCE_COLOR' >&2; exit 1; }
[[ -s "$LOG_PATH" ]]
if LC_ALL=C grep -q $'\033' "$LOG_PATH"; then
  echo 'FAIL: ANSI escape sequence leaked into persistent log' >&2
  exit 1
fi
export NO_COLOR=1
ui_init
plain="$(ui_banner; ui_paint "$UI_GREEN" 'PASS: Không màu')"
[[ "$plain" == *'Không màu'* ]]
[[ "$plain" != *$'\033['* ]] || { echo 'FAIL: NO_COLOR ignored' >&2; exit 1; }
echo 'PASS: branded ANSI terminal, progress and clean logs'
