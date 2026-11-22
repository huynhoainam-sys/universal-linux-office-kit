#!/usr/bin/env bash
# Recover an indefinitely spinning QR login without deleting Zalo chat data.
set -Eeuo pipefail
umask 077

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
DATA_DIR="$CONFIG_HOME/ZaloData"
MODE="${1:-recover}"

if [[ "$EUID" -eq 0 ]]; then
  echo '[ZALO-LOGIN] Chạy bằng tài khoản đăng nhập desktop, không dùng sudo.' >&2
  exit 1
fi

case "$MODE" in
  recover|--dry-run) [[ $# -le 1 ]] || exit 2 ;;
  --restore) [[ $# -eq 2 ]] || { echo 'Cách dùng: zalo-login-recover.sh --restore DUONG_DAN_BACKUP' >&2; exit 2; } ;;
  *) echo 'Cách dùng: zalo-login-recover.sh [--dry-run | --restore DUONG_DAN_BACKUP]' >&2; exit 2 ;;
esac

# Moving a live SQLite database can corrupt the session. Ask the user to close
# the app first; do not kill an unknown process or tamper with its files.
if pgrep -f '[Z]alo-x86_64.AppImage|[z]alo-for-linux' >/dev/null 2>&1; then
  echo '[ZALO-LOGIN] Đóng tất cả cửa sổ Zalo rồi chạy lại. Không di chuyển database đang mở.' >&2
  exit 1
fi

if [[ "$MODE" == --restore ]]; then
  BACKUP="$2"
  case "$BACKUP" in
    "$CONFIG_HOME"/ZaloData.login-backup-*) ;;
    *) echo '[ZALO-LOGIN] Chỉ phục hồi bản backup do script tạo trong XDG_CONFIG_HOME.' >&2; exit 2 ;;
  esac
  [[ ! -L "$BACKUP" && -d "$BACKUP/ZaloData" ]] || {
    echo '[ZALO-LOGIN] Không tìm thấy thư mục dữ liệu trong backup.' >&2; exit 1;
  }
  if [[ -e "$DATA_DIR" || -L "$DATA_DIR" ]]; then
    echo '[ZALO-LOGIN] Đã có ZaloData mới. Để tránh ghi đè dữ liệu, hãy sao lưu nó riêng trước khi phục hồi.' >&2
    exit 1
  fi
  mv -- "$BACKUP/ZaloData" "$DATA_DIR"
  echo "[ZALO-LOGIN] Đã khôi phục dữ liệu từ $BACKUP"
  exit 0
fi

if [[ ! -e "$DATA_DIR" && ! -L "$DATA_DIR" ]]; then
  echo '[ZALO-LOGIN] Chưa có ZaloData cũ; có thể đăng nhập lại trực tiếp.'
  exit 0
fi

if [[ "$MODE" == --dry-run ]]; then
  echo "[ZALO-LOGIN] Sẽ di chuyển $DATA_DIR sang thư mục sao lưu cùng phân vùng, không xóa file."
  exit 0
fi

# mktemp creates a private destination under the *same* config filesystem, so
# mv is atomic even for a large database and cannot overwrite an old snapshot.
BACKUP="$(mktemp -d "$CONFIG_HOME/ZaloData.login-backup-$(date +%Y%m%d-%H%M%S)-XXXXXX")"
if ! mv -- "$DATA_DIR" "$BACKUP/ZaloData"; then
  rmdir -- "$BACKUP" 2>/dev/null || true
  echo '[ZALO-LOGIN] Không thể lưu dữ liệu hiện tại; dừng sửa lỗi.' >&2
  exit 1
fi
echo "[ZALO-LOGIN] Đã lưu nguyên trạng dữ liệu cũ tại: $BACKUP"
echo '[ZALO-LOGIN] Mở Zalo và quét QR lại; bản dữ liệu cũ vẫn được giữ nguyên.'
echo "[ZALO-LOGIN] Nếu cần khôi phục: đóng Zalo, chuyển ZaloData mới sang nơi an toàn, rồi chạy:"
printf '[ZALO-LOGIN] bash %q --restore %q\n' "${BASH_SOURCE[0]}" "$BACKUP"
