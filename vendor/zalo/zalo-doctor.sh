#!/usr/bin/env bash
set -Eeuo pipefail
warn=0
pass(){ printf '[ OK ] %s\n' "$*"; }
fail(){ printf '[WARN] %s\n' "$*"; warn=$((warn+1)); }
[[ "$(uname -m)" == "x86_64" ]] && pass "Kiến trúc x86_64" || fail "Không phải x86_64"
pass "$(ldd --version | head -1)"
if ldconfig -p 2>/dev/null | grep -F 'libfuse.so.2' >/dev/null; then
  pass "FUSE 2"
else
  echo '[NOTE] Thiếu FUSE 2; launcher sẽ dùng APPIMAGE_EXTRACT_AND_RUN=1'
fi
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux"
[[ -x "$APP_DIR/Zalo-x86_64.AppImage" ]] && pass "AppImage executable" || fail "Thiếu AppImage hoặc chưa có quyền chạy"
[[ ! -e "$APP_DIR/Zalo-x86_64.AppImage.part" ]] && pass "Không có file tải dở" || fail "Có file tải dở; chạy repair"
command -v curl >/dev/null && pass "curl" || fail "Thiếu curl"
command -v python3 >/dev/null && pass "python3" || fail "Thiếu python3"
if [[ -n "${WAYLAND_DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == wayland ]]; then
  command -v wl-paste >/dev/null && pass "Wayland clipboard: wl-clipboard" || fail "Thiếu wl-clipboard; dán ảnh Ctrl+V có thể lỗi"
elif [[ -n "${DISPLAY:-}" || "${XDG_SESSION_TYPE:-}" == x11 ]]; then
  command -v xclip >/dev/null && pass "X11 clipboard: xclip" || fail "Thiếu xclip; dán ảnh Ctrl+V có thể lỗi"
else
  echo '[NOTE] Không xác định được phiên đồ họa để kiểm tra clipboard'
fi
for d in "${XDG_CONFIG_HOME:-$HOME/.config}/ZaloData" "${XDG_CONFIG_HOME:-$HOME/.config}/ZaloApp" "${XDG_CONFIG_HOME:-$HOME/.config}/Zalo" "${XDG_DATA_HOME:-$HOME/.local/share}/ZaloData" "${XDG_DATA_HOME:-$HOME/.local/share}/Zalo"; do
  if [[ -d "$d" ]]; then pass "Dữ liệu local: $d ($(du -sh "$d" | awk '{print $1}'))"; fi
done
FREE="$(df -Pk "$HOME" | awk 'NR==2 {print $4}')"
(( FREE > 1048576 )) && pass "Trống > 1 GiB" || fail "Nên có ít nhất 1 GiB trống"
pgrep -f '[Z]alo-x86_64.AppImage' >/dev/null 2>&1 && pass "AppImage đang chạy" || echo '[NOTE] AppImage chưa chạy'
echo "[NOTE] Doctor chỉ kiểm tra runtime/clipboard; không xác nhận ảnh cũ đã đồng bộ."
(( warn )) && { echo "Có $warn cảnh báo."; exit 1; }
echo "[NOTE] Ảnh mới hiện nhưng ảnh cũ thiếu: xem TROUBLESHOOTING.md."
echo "Kiểm tra runtime hoàn tất."
