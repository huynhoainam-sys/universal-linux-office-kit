#!/usr/bin/env bash
# Managed by Zalo Linux Chat Kit. Installed into ~/.local/bin/zalo-linux.
set -Eeuo pipefail

APPIMAGE="${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux/Zalo-x86_64.AppImage"
[[ -x "$APPIMAGE" ]] || { echo '[ZALO] AppImage không tồn tại hoặc chưa có quyền chạy' >&2; exit 1; }

if ! ldconfig -p 2>/dev/null | grep -F 'libfuse.so.2' >/dev/null; then
  export APPIMAGE_EXTRACT_AND_RUN=1
fi

declare -a options=()
desktop="${XDG_CURRENT_DESKTOP:-}"
if [[ "${XDG_SESSION_TYPE:-}" == wayland && "${desktop,,}" == *gnome* ]]; then
  # Many Electron builds still behave more consistently with IBus on XWayland.
  # Only affect this application, never the user's global input configuration.
  export GTK_IM_MODULE=ibus
  export XMODIFIERS=@im=ibus
  export QT_IM_MODULE=ibus
  case "${ZALO_OZONE_PLATFORM:-x11}" in
    x11) [[ -n "${DISPLAY:-}" ]] && options+=(--ozone-platform=x11) ;;
    wayland) options+=(--ozone-platform=wayland) ;;
    auto) ;;
    *) echo 'ZALO_OZONE_PLATFORM phải là x11, wayland hoặc auto' >&2; exit 2 ;;
  esac
fi

# Electron AppImage sometimes cannot use the setuid sandbox. This compatibility
# fallback is less secure; set ZALO_SANDBOX=1 to try upstream sandboxing.
if [[ "${ZALO_SANDBOX:-0}" != 1 ]]; then options+=(--no-sandbox); fi
exec "$APPIMAGE" "${options[@]}" "$@"
