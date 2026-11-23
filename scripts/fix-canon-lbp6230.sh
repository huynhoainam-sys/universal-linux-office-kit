#!/usr/bin/env bash
# Targeted Canon LBP6230/6240 CUPS repair. Never deletes queues or touches
# non-matching printers. Supports official two-client download with SHA-256.
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CANON_PPD_DIR="${CANON_PPD_DIR:-/etc/cups/ppd}"
CANON_ARCHIVE=''
TARGET_QUEUE=''
APPLY=0
DRY_RUN=0
FULL=0
ACCEPT_LICENSE=0
TEMP_DOWNLOAD_DIR=''
CANON_OFFICIAL_URL='https://gdlp01.c-wss.com/gds/0/0100005950/11/linux-UFRIILT-drv-v510-m17n.tar.gz'
CANON_OFFICIAL_REDIRECT='https://pdisp01.c-wss.com/gdl/WWUFORedirectTarget.do?id=MDEwMDAwNTk1MDEx&cmp=ACB&lang=EN'
# Hash calculated from the official Canon release dated 20-Aug-2026.
CANON_OFFICIAL_SHA256='199ff0dd12c75d5f521c27c25d729e260d25f8fcaa98c1aa7ae11a9d989d6976'

usage() {
  cat <<'EOF'
NAMHH · sửa Canon LBP6230/6240 trên Ubuntu
Usage: bash scripts/fix-canon-lbp6230.sh [options]
  (no options)          Diagnose queues, current driver and available Canon driver
  --full                Install official driver and repair all wrong Canon LBP6230/6240 queues
  --accept-canon-license Confirm you have read/accepted Canon's software license
  --archive FILE        Canon UFRII LT V5.10 official .tar.gz (download manually)
  --queue NAME          Repair exactly one LBP6230/6240 CUPS queue
  --apply               Authorize driver installation / queue driver replacement
  --dry-run             Show plan only, without changing anything
  -h, --help            Show help

Official driver: https://vn.canon/en/support/0100595001
Expected file: linux-UFRIILT-drv-v510-m17n.tar.gz

Examples:
  bash scripts/fix-canon-lbp6230.sh
  bash scripts/fix-canon-lbp6230.sh --full --apply --accept-canon-license
  bash scripts/fix-canon-lbp6230.sh --archive "$HOME/Downloads/linux-UFRIILT-drv-v510-m17n.tar.gz" --apply
  bash scripts/fix-canon-lbp6230.sh --queue LBP6230-6240 --dry-run
  bash scripts/fix-canon-lbp6230.sh --queue LBP6230-6240 --apply

NOTE: --full repairs only LBP6230/6240 queues with a wrong HP Designjet PPD.
It preserves device URIs, other printer queues and original PPD backups.
No test page is printed automatically.
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
  elif (( APPLY && ! DRY_RUN )) && command -v sudo >/dev/null 2>&1 && sudo test -f "$ppd"; then
    # CUPS commonly keeps /etc/cups/ppd root-readable only. On --full the
    # user has requested a privileged repair, so read its model via sudo.
    sudo sed -n 's/^\*NickName: "\(.*\)"/\1/p' "$ppd" | head -n 1
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
  # Checked directly in Canon V5.10 .deb: CNRCUPSLBP6230ZNK.ppd has
  # *NickName: "Canon LBP6230/6240" (without the words UFRII LT).
  lpinfo -m 2>/dev/null | grep -Ei '^[^[:space:]]*CNRCUPSLBP6230ZNK\.ppd[[:space:]]+Canon[[:space:]]+LBP6230/6240([[:space:]]|$)' || true
}

verify_official_archive() {
  [[ -f "$1" ]] || return 1
  local digest
  digest="$(sha256sum -- "$1" | cut -d' ' -f1)"
  [[ "$digest" == "$CANON_OFFICIAL_SHA256" ]]
}

download_official_driver() {
  if (( DRY_RUN || ! APPLY )); then
    printf '[DRY-RUN] Sẽ dùng Canon UFRII LT V5.10, tải qua curl rồi wget; SHA-256 được kiểm tra.\n'
    return 0
  fi
  if [[ -f "$HOME/Downloads/linux-UFRIILT-drv-v510-m17n.tar.gz" ]] &&
    verify_official_archive "$HOME/Downloads/linux-UFRIILT-drv-v510-m17n.tar.gz"; then
    CANON_ARCHIVE="$HOME/Downloads/linux-UFRIILT-drv-v510-m17n.tar.gz"
    printf 'Dùng file Canon đã tải và khớp checksum.\n'
    return 0
  fi
  TEMP_DOWNLOAD_DIR="$(mktemp -d)" || return 1
  CANON_ARCHIVE="$TEMP_DOWNLOAD_DIR/linux-UFRIILT-drv-v510-m17n.tar.gz"
  local url method
  for url in "$CANON_OFFICIAL_URL" "$CANON_OFFICIAL_REDIRECT"; do
    for method in curl wget; do
      rm -f -- "$CANON_ARCHIVE"
      printf 'Tải Canon chính thức qua %s (%s) ...\n' "$method" "${url%%/*}"
      if [[ "$method" == curl ]] && command -v curl >/dev/null 2>&1; then
        curl --fail --location --silent --show-error --proto '=https' --proto-redir '=https' \
          --connect-timeout 20 --max-time 180 --retry 1 --output "$CANON_ARCHIVE" "$url" || continue
      elif [[ "$method" == wget ]] && command -v wget >/dev/null 2>&1; then
        wget --quiet --https-only --timeout=25 --tries=2 --output-document="$CANON_ARCHIVE" "$url" || continue
      else
        continue
      fi
      if verify_official_archive "$CANON_ARCHIVE"; then
        printf 'Đã tải gói Canon, SHA-256 khớp bản chính thức.\n'
        return 0
      fi
      printf 'Checksum không khớp; từ chối file tải.\n' >&2
    done
  done
  printf 'Không tải được gói Canon. Hãy tải thủ công từ https://vn.canon/en/support/0100595001\n' >&2
  return 1
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
  if ! verify_official_archive "$CANON_ARCHIVE"; then
    printf 'SHA-256 Canon UFRII LT không khớp bản V5.10 chính thức; từ chối cài.\n' >&2
    return 1
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
  if [[ "${current_model,,}" == *'canon lbp6230/6240'* ]]; then
    printf 'Driver đã đúng; không sửa thêm.\n'
    return 0
  fi
  if (( DRY_RUN || ! APPLY )); then
    printf '[DRY-RUN] Sao lưu PPD cũ rồi cập nhật driver; giữ nguyên device URI.\n'
    return 0
  fi
  ppd="$CANON_PPD_DIR/$TARGET_QUEUE.ppd"
  if [[ ! -f "$ppd" ]] && ! sudo test -f "$ppd"; then
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

repair_all_wrong_queues() {
  if (( DRY_RUN || ! APPLY )); then
    printf '[DRY-RUN] Sẽ chỉ sửa hàng đợi Canon LBP6230/6240 có driver HP Designjet.\n'
    return 0
  fi
  local line queue model count=0 errors=0
  while IFS= read -r line; do
    [[ "$line" == 'device for '*': '* ]] || continue
    queue="${line#device for }"; queue="${queue%%:*}"
    is_target_queue "$queue" || continue
    model="$(queue_model "$queue")"
    if [[ "$model" == "Không đọc được PPD ("* || -z "$model" ]]; then
      printf '[CHƯA XÁC MINH] %s: không đọc được driver CUPS; không sửa mù.\n' "$queue" >&2
      (( errors+=1 ))
      continue
    fi
    if [[ "${model,,}" == *'hp designjet'* ]]; then
      TARGET_QUEUE="$queue"
      if repair_queue; then (( count+=1 )); else (( errors+=1 )); fi
    fi
  done < <(lpstat -v 2>/dev/null || true)
  printf '\nCanon: đã sửa %d hàng đợi nhầm HP; lỗi %d.\n' "$count" "$errors"
  if (( count == 0 )); then
    printf 'Không thay đổi hàng đợi nào: kiểm tra driver hiện tại và URI trước khi in thử.\n'
  fi
  (( errors == 0 ))
}

main() {
  while (($#)); do
    case "$1" in
      --archive) CANON_ARCHIVE="${2:?Thiếu đường dẫn archive}"; shift 2 ;;
      --queue) TARGET_QUEUE="${2:?Thiếu tên hàng đợi}"; shift 2 ;;
      --full) FULL=1; shift ;;
      --accept-canon-license) ACCEPT_LICENSE=1; shift ;;
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
  if (( FULL )) && [[ -n "$TARGET_QUEUE" ]]; then
    printf 'Dùng --full hoặc --queue, không chọn cả hai.\n' >&2
    return 2
  fi
  if (( FULL && APPLY && ! DRY_RUN && ! ACCEPT_LICENSE )); then
    printf 'Đọc giấy phép tại https://vn.canon/en/support/0100595001 rồi chạy thêm --accept-canon-license.\n' >&2
    return 2
  fi
  trap '[[ -z "$TEMP_DOWNLOAD_DIR" ]] || rm -r -- "$TEMP_DOWNLOAD_DIR"' EXIT
  show_queues
  if (( FULL )) && [[ -z "$CANON_ARCHIVE" ]] && [[ -z "$(canon_models)" ]]; then
    download_official_driver || return $?
  fi
  [[ -z "$CANON_ARCHIVE" ]] || install_driver || return $?
  show_driver
  if (( FULL )); then
    repair_all_wrong_queues
  elif [[ -n "$TARGET_QUEUE" ]]; then
    repair_queue
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
