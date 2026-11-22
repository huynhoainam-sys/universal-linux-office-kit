#!/usr/bin/env bash
# Capture an actual Ubuntu 24.04 XTerm session with the safe --dry-run option.
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
mkdir -p ubuntu-captures
export DISPLAY=:98
Xvfb :98 -screen 0 1366x830x24 -nolisten tcp >ubuntu-captures/xvfb.log 2>&1 &
xvfb_pid=$!
term_pid=''
cleanup() {
  [[ -z "$term_pid" ]] || kill "$term_pid" 2>/dev/null || true
  kill "$xvfb_pid" 2>/dev/null || true
}
trap cleanup EXIT
sleep 2

xterm -display :98 -fa 'DejaVu Sans Mono' -fs 12 -geometry 108x31+25+25 \
  -bg '#1b2836' -fg '#d9e4eb' -cr '#90b6c7' -T 'NAMHH · Ubuntu 24.04 · dry-run' \
  -e bash -c 'UI_STAGE_DELAY=2 FORCE_COLOR=1 TERM=xterm-256color bash setup.sh --repair-desktop --dry-run --yes --no-open-report --report "$PWD/ubuntu-captures/report.txt"; printf "\n  Ubuntu 24.04 test finished — dry-run, no packages installed.\n"; sleep 18' &
term_pid=$!

# Distinct points in a genuine terminal session, not manually drawn mockups.
sleep 4
import -display :98 -window root ubuntu-captures/01-ubuntu-terminal.png
sleep 7
import -display :98 -window root ubuntu-captures/02-ubuntu-progress.png
sleep 12
import -display :98 -window root ubuntu-captures/03-ubuntu-result.png

test -s ubuntu-captures/report.html
test -s ubuntu-captures/03-ubuntu-result.png

# Capture the user-facing report rendered by Chrome on Ubuntu when available.
chrome="$(command -v google-chrome || command -v chromium || command -v chromium-browser || true)"
if [[ -n "$chrome" ]]; then
  "$chrome" --headless --no-sandbox --disable-gpu --hide-scrollbars \
    --screenshot="$PWD/ubuntu-captures/04-html-report.png" --window-size=1280,1050 \
    "file://$PWD/ubuntu-captures/report.html" >/dev/null 2>&1 || true
  "$chrome" --headless --no-sandbox --disable-gpu --hide-scrollbars \
    --screenshot="$PWD/ubuntu-captures/05-html-report-full.png" --window-size=1280,5200 \
    "file://$PWD/ubuntu-captures/report.html" >/dev/null 2>&1 || true
fi

printf '%s\n' 'Ubuntu 24.04 screenshots captured from the actual dry-run session.'
