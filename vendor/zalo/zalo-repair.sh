#!/usr/bin/env bash
set -Eeuo pipefail

APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux"
APPIMAGE="$APP_DIR/Zalo-x86_64.AppImage"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
echo "[ZALO-REPAIR] Không xóa database chat; chỉ sửa runtime/launcher/dependency."

if command -v apt-get >/dev/null && command -v sudo >/dev/null; then
  need=()
  command -v curl >/dev/null || need+=(curl)
  command -v python3 >/dev/null || need+=(python3)
  command -v xclip >/dev/null || need+=(xclip)
  command -v wl-paste >/dev/null || need+=(wl-clipboard)
  command -v update-desktop-database >/dev/null || need+=(desktop-file-utils)
  command -v notify-send >/dev/null || need+=(libnotify-bin)
  if ! ldconfig -p 2>/dev/null | grep -F 'libfuse.so.2' >/dev/null; then
    apt-cache show libfuse2t64 >/dev/null 2>&1 && need+=(libfuse2t64) || need+=(libfuse2)
  fi
  if (( ${#need[@]} )); then sudo apt-get update && sudo apt-get install -y "${need[@]}"; fi
fi

[[ -f "$APPIMAGE" ]] || { echo "Chưa có AppImage; chạy lại install-zalo-linux.sh" >&2; exit 1; }
chmod 0755 "$APPIMAGE"
# Keep interrupted downloads for diagnosis; repair never removes user chat data.
mkdir -p "$BIN_DIR"
install -m 0755 "$ROOT_DIR/zalo-launcher.sh" "$BIN_DIR/zalo-linux"
chmod 0755 "$BIN_DIR/zalo-linux"
ICON_PATH="$APP_DIR/zalo.png"
icon_tmp="$(mktemp -d)"
if (cd "$icon_tmp" && "$APPIMAGE" --appimage-extract 'app/pc-dist/favicon-512x512.png' >/dev/null 2>&1) && [[ -s "$icon_tmp/squashfs-root/app/pc-dist/favicon-512x512.png" ]]; then
  cp "$icon_tmp/squashfs-root/app/pc-dist/favicon-512x512.png" "$ICON_PATH"
else
  echo "[ZALO] Không trích xuất được icon; dùng icon hệ thống." >&2
fi
rm -r -- "$icon_tmp"
if [[ -s "$ICON_PATH" ]]; then DESKTOP_ICON="$ICON_PATH"; else DESKTOP_ICON=applications-internet; fi
mkdir -p "$DESKTOP_DIR"
cat > "$DESKTOP_DIR/zalo-linux.desktop" <<EOF
[Desktop Entry]
Name=Zalo Linux
Comment=Zalo messaging client for Linux
Exec=$BIN_DIR/zalo-linux %U
Icon=$DESKTOP_ICON
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
StartupWMClass=zalo
EOF
command -v update-desktop-database >/dev/null && update-desktop-database "$DESKTOP_DIR" || true
if ! ldconfig -p 2>/dev/null | grep -F 'libfuse.so.2' >/dev/null; then export APPIMAGE_EXTRACT_AND_RUN=1; fi
"$APPIMAGE" --appimage-version >/dev/null 2>&1 || echo "[WARN] AppImage không trả version; thử rollback nếu app không mở."
echo "Đã sửa launcher/runtime. Dữ liệu chat không bị xóa."
