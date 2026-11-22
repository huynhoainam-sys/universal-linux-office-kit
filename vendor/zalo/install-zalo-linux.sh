#!/usr/bin/env bash
set -Eeuo pipefail

REPO="${ZALO_REPO:-VN-Linux-Family/zalo-for-linux}"
VARIANT="${ZALO_VARIANT:-chat}"
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$ROOT_DIR/zalo-download.sh"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux"
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
APPIMAGE="$APP_DIR/Zalo-x86_64.AppImage"
API="https://api.github.com/repos/$REPO/releases/latest"
ZALO_UI_COLOR=0
ZALO_UI_VISIBLE=0
ZALO_UI_STAGE=0
ZALO_UI_TOTAL=6
ZALO_RESET=$'\033[0m'
ZALO_BLUE=$'\033[38;5;109m'
ZALO_CYAN=$'\033[38;5;110m'
ZALO_GREEN=$'\033[38;5;108m'
ZALO_YELLOW=$'\033[38;5;179m'
ZALO_RED=$'\033[38;5;167m'
ZALO_MUTED=$'\033[38;5;245m'

zalo_ui_init() {
  if [[ -t 1 || "${FORCE_COLOR:-0}" == 1 ]]; then ZALO_UI_VISIBLE=1; fi
  if (( ZALO_UI_VISIBLE )) && [[ ! -v NO_COLOR && "${TERM:-}" != dumb ]]; then ZALO_UI_COLOR=1; fi
}
zalo_ui_print() {
  local color="$1"; shift
  if (( ZALO_UI_COLOR )); then printf '%b%s%b\n' "$color" "$*" "$ZALO_RESET"
  else printf '%s\n' "$*"; fi
}
zalo_ui_banner() {
  (( ZALO_UI_VISIBLE )) || return 0
  zalo_ui_print "$ZALO_CYAN" '  NAMHH  /  ZALO LINUX CHAT KIT'
  zalo_ui_print "$ZALO_MUTED" '  Ubuntu · Linux Mint  |  AppImage đã xác minh'
  zalo_ui_print "$ZALO_MUTED" '  Design: huynhoainam@gmail.com'
  zalo_ui_print "$ZALO_MUTED" '  ─────────────────────────────────────────────────'
  printf '\n'
}
zalo_ui_stage() {
  (( ZALO_UI_STAGE += 1 ))
  (( ZALO_UI_VISIBLE )) || return 0
  local indicator
  printf -v indicator '  [%02d/%02d]  %s' "$ZALO_UI_STAGE" "$ZALO_UI_TOTAL" "$*"
  zalo_ui_print "$ZALO_BLUE" "$indicator"
}
zalo_ui_finish() {
  (( ZALO_UI_VISIBLE )) || return 0
  zalo_ui_print "$ZALO_GREEN" "  HOÀN TẤT  ·  $ZALO_UI_STAGE/$ZALO_UI_TOTAL bước (100%)"
}
die(){ zalo_ui_print "$ZALO_RED" "[ZALO-ERROR] $*" >&2; exit 1; }
info(){
  local color="$ZALO_CYAN"
  case "$*" in
    *'đã xác minh'*|*'Đã cài'*|*'khớp SHA'*|*'thành công'*) color="$ZALO_GREEN" ;;
    *'không'*|*'chặn'*|*'sai'*|*'dự phòng'*) color="$ZALO_YELLOW" ;;
  esac
  zalo_ui_print "$color" "[ZALO] $*"
}
zalo_ui_init
zalo_ui_banner
zalo_ui_stage 'Kiểm tra hệ điều hành và kiến trúc'
[[ "$(uname -m)" == "x86_64" ]] || die "Bản này dành cho Intel/AMD x86_64"
[[ "$VARIANT" == "full" || "$VARIANT" == "chat" ]] || die "ZALO_VARIANT chỉ nhận full hoặc chat"
zalo_ui_stage 'Kiểm tra và bổ sung thư viện còn thiếu'
if ! command -v apt-get >/dev/null || ! command -v sudo >/dev/null; then
  command -v curl >/dev/null || die "Thiếu curl; cài curl thủ công"
  command -v python3 >/dev/null || die "Thiếu python3; cài python3 thủ công"
else
  need=()
  command -v curl >/dev/null || need+=(curl)
  command -v python3 >/dev/null || need+=(python3)
  command -v xclip >/dev/null || need+=(xclip)
  command -v wl-paste >/dev/null || need+=(wl-clipboard)
  command -v update-desktop-database >/dev/null || need+=(desktop-file-utils)
  command -v notify-send >/dev/null || need+=(libnotify-bin)
  [[ "$(dpkg-query -W -f='${Status}' ca-certificates 2>/dev/null || true)" == 'install ok installed' ]] || need+=(ca-certificates)
  # Current upstream AppImages provide native calling on Linux (no Wine/i386).
  for pkg in libopus0 pulseaudio-utils; do
    [[ "$(dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null || true)" == 'install ok installed' ]] || need+=("$pkg")
  done
  if ! ldconfig -p 2>/dev/null | grep -F 'libfuse.so.2' >/dev/null; then
    if apt-cache show libfuse2t64 >/dev/null 2>&1; then need+=(libfuse2t64); else need+=(libfuse2); fi
  fi
  if (( ${#need[@]} )); then
    info "Cài dependency: ${need[*]}"
    sudo apt-get update
    sudo apt-get install -y "${need[@]}"
  fi
fi
mkdir -p "$APP_DIR" "$BIN_DIR" "$DESKTOP_DIR"
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

# Keep chat data before replacing a working binary, but avoid exhausting a
# nearly-full disk. ZALO_BACKUP=off disables this automatic data snapshot.
backup_before_update() {
  [[ -x "$APPIMAGE" ]] || return 0
  [[ "${ZALO_BACKUP:-auto}" != off ]] || return 0
  local required=0 free=0 path kb
  for path in "${XDG_CONFIG_HOME:-$HOME/.config}"/{ZaloData,ZaloApp,Zalo} "${XDG_DATA_HOME:-$HOME/.local/share}"/{ZaloData,Zalo}; do
    if [[ -d "$path" ]]; then
      kb="$(du -sk -- "$path" | awk '{print $1}')"
      required=$((required + kb))
    fi
  done
  (( required > 0 )) || return 0
  free="$(df -Pk "$APP_DIR" | awk 'NR==2 {print $4}')"
  if (( free < required * 2 + 262144 )); then
    info "Dung lượng trống không đủ để backup dữ liệu Zalo an toàn (${required} KiB); giữ bản AppImage trước để rollback."
    if [[ "${ZALO_BACKUP:-auto}" == always ]]; then die 'ZALO_BACKUP=always yêu cầu đủ dung lượng để backup'; fi
    return 0
  fi
  if ! bash "$ROOT_DIR/backup-zalo-linux.sh"; then
    die 'Sao lưu Zalo thất bại; chưa thay AppImage hiện tại'
  fi
}
# Thu thập metadata tự động. Nếu API bị HTTP 403 hoặc JSON lỗi, fallback sang
# một release chính thức đã xác minh tên file và SHA-256 (không xóa bản đang cài).
zalo_ui_stage 'Chọn bản phát hành có SHA-256'
metadata=""
release_available=0
if curl --fail --location --silent --show-error --connect-timeout 20 "$API" -o "$tmp"; then
  release_available=1
  metadata="$(python3 - "$tmp" "$VARIANT" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding='utf-8'))
suffix='-Full-x86_64.AppImage' if sys.argv[2]=='full' else '-x86_64.AppImage'
a=[x for x in d.get('assets',[]) if x.get('name','').endswith(suffix) and '+ZaDark-' in x['name'] and (sys.argv[2]=='full' or '-Full-' not in x['name'])]
if not a: raise SystemExit('Không tìm thấy AppImage ZaDark x86_64 đúng biến thể trong release mới nhất')
if len(a) != 1: raise SystemExit('Có nhiều AppImage ZaDark cùng biến thể; cần chọn thủ công')
x=a[0]
print(d.get('tag_name','unknown')); print(x['name']); print(x['browser_download_url']); print(x.get('digest') or '-')
PY
)" || metadata=""
else
  info "Không truy cập được GitHub Releases API; thử bản dự phòng đã xác minh."
fi
if [[ -n "$metadata" ]]; then
  readarray -t META <<< "$metadata"
  (( ${#META[@]} == 4 )) || die "Metadata release thiếu trường; giữ nguyên bản đang cài"
  TAG="${META[0]}"; NAME="${META[1]}"; URL="${META[2]}"; DIGEST="${META[3]}"
else
  if (( release_available )); then
    die "GitHub API hoạt động nhưng release mới nhất không có bản $VARIANT phù hợp. Dùng ZALO_VARIANT=chat để cài bản mới; không tự hạ xuống release cũ."
  fi
  [[ "$REPO" == "VN-Linux-Family/zalo-for-linux" ]] || die "Không có fallback đã xác minh cho ZALO_REPO=$REPO"
  TAG="26.11.10"
  if [[ "$VARIANT" == "full" ]]; then
    TAG="26.10.11"
    NAME="Zalo-26.10.11+ZaDark-26.2.1-e80931a-Full-x86_64.AppImage"
    URL="https://github.com/VN-Linux-Family/zalo-for-linux/releases/download/26.10.11/Zalo-26.10.11%2BZaDark-26.2.1-e80931a-Full-x86_64.AppImage"
    DIGEST="sha256:daaee9684daf60bec96eb097bd4fcb623980452d3805ccc949dddaf5da3ea77b"
  else
    NAME="Zalo-26.11.10+ZaDark-26.3-836500e-x86_64.AppImage"
    URL="https://github.com/VN-Linux-Family/zalo-for-linux/releases/download/26.11.10/Zalo-26.11.10%2BZaDark-26.3-836500e-x86_64.AppImage"
    DIGEST="sha256:eb2dfd4119f14fbf9d5990a3078b2769672032a070187d9e0c2ca20578391916"
  fi
  info "Dùng release dự phòng cố định $TAG vì GitHub API không truy cập được."
fi
info "Release $TAG — $NAME"
if [[ "$VARIANT" == full ]] && command -v apt-get >/dev/null && command -v sudo >/dev/null; then
  info 'Bản full cũ yêu cầu thư viện 32-bit; chỉ cài khi người dùng chọn full.'
  sudo dpkg --add-architecture i386
  sudo apt-get update
  sudo apt-get install -y libgl1 libgl1:i386 libegl1 libegl1:i386 libvulkan1 libvulkan1:i386 mesa-vulkan-drivers mesa-vulkan-drivers:i386
fi
zalo_ui_stage 'Tải AppImage và kiểm tra tính toàn vẹn'
if ! download_zalo_appimage "$URL" "$APPIMAGE.part" "$DIGEST"; then
  rm -f "$APPIMAGE.part"
  if [[ -x "$APPIMAGE" ]]; then
    info 'Các nguồn tải bị chặn hoặc checksum sai; giữ nguyên Zalo đã cài. Không xóa dữ liệu.'
    zalo_ui_print "$ZALO_YELLOW" '  ⚠ Dừng cập nhật an toàn: bản đang cài được giữ nguyên.'
    exit 0
  fi
  die "Không tải được AppImage từ GitHub và mirror có SHA-256. Kiểm tra proxy FPT, hoặc cung cấp ZALO_OFFLINE_APPIMAGE đã xác minh; chưa thay đổi dữ liệu Zalo."
fi
zalo_ui_stage 'Backup dữ liệu và cập nhật AppImage'
backup_before_update
chmod 0755 "$APPIMAGE.part"
if [[ -f "$APPIMAGE" ]]; then
  ln -f -- "$APPIMAGE" "$APPIMAGE.previous.tmp"
  mv -f -- "$APPIMAGE.previous.tmp" "$APPIMAGE.previous"
fi
mv -f -- "$APPIMAGE.part" "$APPIMAGE"
zalo_ui_stage 'Tạo launcher, icon và tích hợp desktop'
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
info "Đã cài $APPIMAGE"
info "Chạy: $BIN_DIR/zalo-linux"
zalo_ui_finish
