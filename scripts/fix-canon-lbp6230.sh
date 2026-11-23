#!/usr/bin/env bash
# Targeted Canon LBP6230/6240 CUPS repair. Never deletes queues or touches
# non-matching printers. Installation requires Canon's official local archive.
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CANON_PPD_DIR="${CANON_PPD_DIR:-/etc/cups/ppd}"
CANON_ARCHIVE=''
TARGET_QUEUE=''
APPLY=0
DRY_RUN=0

usage() {
  cat <<'EOF'
NAMHH · sửa Canon LBP6230/6240 trên Ubuntu
Usage: bash scripts/fix-canon-lbp6230.sh [options]
  (no options)          Diagnose queues, current driver and available Canon driver
  --archive FILE        Canon UFRII LT V5.10 official .tar.gz (download manually)
  --queue NAME          Repair exactly one LBP6230/6240 CUPS queue
  --apply               Authorize driver installation / queue driver replacement
  --dry-run             Show plan only, without changing anything
  -h, --help            Show help

Official driver: https://vn.canon/en/support/0100595001
Expected file: linux-UFRIILT-drv-v510-m17n.tar.gz

Examples:
  bash scripts/fix-canon-lbp6230.sh
  bash scripts/fix-canon-lbp6230.sh --archive "$HOME/Downloads/linux-UFRIILT-drv-v510-m17n.tar.gz" --apply
  bash scripts/fix-canon-lbp6230.sh --queue LBP6230-6240 --dry-run
  bash scripts/fix-canon-lbp6230.sh --queue LBP6230-6240 --apply

NOTE: Only remaps the selected CUPS queue to the installed Canon PPD.
It preserves its device URI, other printer queues and the original PPD backup.
EOF
}

is_target_queue() {
  [[ "$1" =~ ^LBP6230[-_]6240([-_][0-9]+)?$ ]]
}

queue_exists() {
  lpstat -v "$1" >/dev/null 2>&1
}

queue_model() {
  local ppd="$CANON_PPD_DIR/$1.ppd"
  if [[ -r "$ppd" ]]; then
    sed -n 's/^\*NickName: "\(.*\)"/\1/p' "$ppd" | head -n 1
  else
    printf 'Không đọc được PPD (%s)\n' "$ppd"
  fi
}

show_queues() {
  printf '\n=== HÀNG ĐỢI MÁY IN HIỆN TẠI ===\n'
  local found=0 line queue uri model
  while IFS= read -r line; do
    [[ "$line" == 'device for '*': '* ]] || continue
    queue="${line#device for }"; queue="${queue%%:*}"
    uri="${line#*: }"
    is_target_queue "$queue" || continue
    found=1
    model="$(queue_model "$queue")"
    printf '%s\n  Driver: %s\n  URI: %s\n' "$queue" "$model" "$uri"
    if [[ "${model,,}" == *'hp designjet'* ]]; then
      printf '  [SAI DRIVER] Canon đang dùng HP Designjet PostScript.\n'
    elif [[ "${model,,}" == *canon* && "${model,,}" == *'6230'* ]]; then
      printf '  [CANON] Kiểm tra lại bằng trang in thử.\n'
    fi
  done < <(lpstat -v 2>/dev/null || true)
  if (( ! found )); then
    printf 'Chưa tìm thấy hàng đợi tên LBP6230-6240.\n'
  fi
  printf '\nGiữ nguyên các máy in khác (ví dụ Toshiba).\n'
}

canon_models() {
  # lpinfo -m format: model_identifier + whitespace + model description.
  # Only accept the LBP6230/6240 Canon UFRII LT model, never generic HP/PS.
  lpinfo -m 2>/dev/null | grep -Ei '^[^[:space:]]+[[:space:]]+Canon.*LBP6230(/LBP6240|/6240|[- ]?6240)?.*UFR.?II[[:space:]]*LT' || true
}

show_driver() {
  printf '\n=== DRIVER CANON KHẢ DỤNG ===\n'
  local candidates
  candidates="$(canon_models)"
  if [[ -n "$candidates" ]]; then
    printf '%s\n' "$candidates"
  else
    printf 'Chưa tìm thấy Canon LBP6230/6240 UFRII LT trong CUPS.\n'
    printf 'Tải bản V5.10 chính thức: https://vn.canon/en/support/0100595001\n'
  fi
}

install_driver() {
  [[ -f "$CANON_ARCHIVE" ]] || { printf 'Không tìm thấy: %s\n' "$CANON_ARCHIVE" >&2; return 1; }
  case "${CANON_ARCHIVE##*/}" in linux-UFRIILT-drv-v5*.tar.gz) ;; *)
    printf 'Chỉ nhận archive Canon UFRII LT V5.x chính thức cho dòng LBP6230/6240.\n' >&2
    return 2 ;;
  esac
  if (( DRY_RUN || ! APPLY )); then
    printf '[DRY-RUN] Sẽ cài từ: %s\n' "$CANON_ARCHIVE"
    return 0
  fi
  # Reuse Office Kit's package validation and APT isolation. Unlike a full
  # setup invocation, this action does not reinstall any unrelated apps.
  # shellcheck source=../setup.sh
  source "$ROOT_DIR/setup.sh"
  CANON_UFRII_ARCHIVE="$CANON_ARCHIVE"
  LOG_PATH="${ROOT_DIR}/canon-repair.log"
  DRY_RUN=0
  if ! module_canon_ufrii; then
    printf 'Lỗi cài driver; xem %s\n' "$LOG_PATH" >&2
    return 1
  fi
  printf 'Driver đã được xử lý. Kiểm tra bằng lpinfo -m.\n'
}

repair_queue() {
  if ! is_target_queue "$TARGET_QUEUE"; then
    printf 'Từ chối chỉnh hàng đợi khác dòng LBP6230/6240: %s\n' "$TARGET_QUEUE" >&2
    return 2
  fi
  if ! queue_exists "$TARGET_QUEUE"; then
    printf 'Không tìm thấy hàng đợi: %s\n' "$TARGET_QUEUE" >&2
    return 1
  fi
  local -a matches=()
  local line driver model current_model ppd backup
  while IFS= read -r line; do [[ -n "$line" ]] && matches+=("$line"); done < <(canon_models)
  if ((${#matches[@]} != 1)); then
    printf 'Cần đúng một model Canon UFRII LT trong CUPS; tìm thấy %d.\n' "${#matches[@]}" >&2
    printf 'Cài đúng driver V5.10, hoặc dùng Canon Printer Setup Utility để chọn model.\n' >&2
    return 1
  fi
  driver="${matches[0]%%[[:space:]]*}"
  model="${matches[0]#* }"
  current_model="$(queue_model "$TARGET_QUEUE")"
  printf '\nHàng đợi: %s\nHiện tại: %s\nThay bằng: %s\n' "$TARGET_QUEUE" "$current_model" "$model"
  if [[ "${current_model,,}" == *canon* && "${current_model,,}" == *'6230'* && "${current_model,,}" == *'ufrii lt'* ]]; then
    printf 'Driver đã đúng; không sửa thêm.\n'
    return 0
  fi
  if (( DRY_RUN || ! APPLY )); then
    printf '[DRY-RUN] Sao lưu PPD cũ rồi cập nhật driver; giữ nguyên device URI.\n'
    return 0
  fi
  ppd="$CANON_PPD_DIR/$TARGET_QUEUE.ppd"
  if [[ ! -f "$ppd" ]]; then
    printf 'Không thấy PPD để sao lưu; từ chối thay đổi hàng đợi.\n' >&2
    return 1
  fi
  backup="${ppd}.namhh.$(date +%Y%m%d-%H%M%S-%N).bak"
  if ! sudo cp -p -- "$ppd" "$backup"; then
    printf 'Không sao lưu được PPD; chưa thay đổi hàng đợi.\n' >&2
    return 1
  fi
  if ! sudo lpadmin -p "$TARGET_QUEUE" -m "$driver"; then
    printf 'Không đổi được driver. PPD cũ đã lưu tại: %s\n' "$backup" >&2
    return 1
  fi
  printf 'Đã gán driver Canon cho %s. Backup: %s\n' "$TARGET_QUEUE" "$backup"
  printf 'In một trang thử; chưa xóa hàng đợi cũ hoặc chỉnh máy in khác.\n'
}

main() {
  while (($#)); do
    case "$1" in
      --archive) CANON_ARCHIVE="${2:?Thiếu đường dẫn archive}"; shift 2 ;;
      --queue) TARGET_QUEUE="${2:?Thiếu tên hàng đợi}"; shift 2 ;;
      --apply) APPLY=1; shift ;;
      --dry-run) DRY_RUN=1; shift ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; return 2 ;;
    esac
  done
  if ! command -v lpstat >/dev/null 2>&1 || ! command -v lpinfo >/dev/null 2>&1; then
    printf 'Thiếu CUPS tools (lpstat/lpinfo). Cài cups-client trước.\n' >&2
    return 1
  fi
  show_queues
  [[ -z "$CANON_ARCHIVE" ]] || install_driver || return $?
  show_driver
  [[ -z "$TARGET_QUEUE" ]] || repair_queue
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
