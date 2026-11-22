#!/usr/bin/env bash
# Managed by Universal Linux Office Kit
# Microsoft provides Outlook on Linux via the web, not a native Linux client.
set -Eeuo pipefail

url='https://outlook.office.com/mail/'
for browser in microsoft-edge-stable microsoft-edge google-chrome-stable google-chrome chromium chromium-browser; do
  if command -v "$browser" >/dev/null 2>&1; then
    exec "$browser" "--app=$url"
  fi
done
if command -v firefox >/dev/null 2>&1; then
  exec firefox --new-window "$url"
fi
if command -v xdg-open >/dev/null 2>&1; then
  exec xdg-open "$url"
fi
printf '%s\n' 'NAMHH: Không tìm thấy trình duyệt để mở Outlook Web.' >&2
exit 1
