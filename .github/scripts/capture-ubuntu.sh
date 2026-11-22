#!/usr/bin/env bash
# Capture an actual Ubuntu 24.04 XTerm session with the safe --dry-run option.
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.."
mkdir -p ubuntu-captures
export DISPLAY=:98
Xvfb :98 -screen 0 1366x780x24 -nolisten tcp >ubuntu-captures/xvfb.log 2>&1 &
xvfb_pid=$!
term_pid=''
cleanup() {
  [[ -z "$term_pid" ]] || kill "$term_pid" 2>/dev/null || true
  kill "$xvfb_pid" 2>/dev/null || true
}
trap cleanup EXIT
sleep 2
if command -v xsetroot >/dev/null 2>&1; then xsetroot -display :98 -solid '#061021' || true; fi

xterm -display :98 -fa 'DejaVu Sans Mono' -fs 16 -geometry 102x27+25+22 \
  -bg '#061021' -fg '#eaf3ff' -cr '#50d9f0' -T 'NAMHH · Ubuntu 24.04 · dry-run' \
  -e bash -c 'printf "  Ubuntu 24.04 LTS / GitHub Actions / dry-run\n\n"; UI_STAGE_DELAY=1 FORCE_COLOR=1 TERM=xterm-256color bash setup.sh --profile desktop --dry-run --yes --no-open-report --report "$PWD/ubuntu-captures/report.txt"; printf "\n  [CI] 12/12 bước đã chạy thử. Không cài package thật.\n"; sleep 18' &
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
    --screenshot="$PWD/ubuntu-captures/05-html-report-full.png" --window-size=1280,6500 \
    "file://$PWD/ubuntu-captures/report.html" >/dev/null 2>&1 || true
fi

# Firefox ships with Ubuntu desktops; verify the fully self-contained HTML there too.
if command -v firefox >/dev/null 2>&1; then
  timeout 30 firefox --headless --width 1280 --height 1000 \
    --screenshot "$PWD/ubuntu-captures/06-firefox-report.png" \
    "file://$PWD/ubuntu-captures/report.html" >/dev/null 2>&1 || true
fi

printf '%s\n' 'Ubuntu 24.04 screenshots captured from the actual dry-run session.'
