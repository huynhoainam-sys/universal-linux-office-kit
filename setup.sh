#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="desktop"
DRY_RUN=0
ASSUME_YES=0
NO_REBOOT=0
ENABLE_UFW=0
SKIP_FLATPAK=0
SKIP_THIRD_PARTY=0
CANON_UFRII_ARCHIVE=''
FIX_UNIKEY=0
FIX_FLAMESHOT=0
FIX_ZALO=0
UPDATE_ZALO=0
FIX_ZALO_LOGIN=0
REPAIR_DESKTOP=0
FIX_OFFICE=0
ZALO_VARIANT='chat'
OFFICE_SECONDARY='auto'
BACKUP_DIR=''
REPORT_PATH="${ROOT_DIR}/setup-report.txt"
REPORT_HTML_PATH=''
OPEN_HTML_REPORT=1
UI_VERBOSE=0
LOG_PATH="${ROOT_DIR}/setup.log"
declare -a WARNINGS=()
declare -a FAILURES=()
UI_COLOR=0
UI_VISIBLE=0
UI_STAGE=0
UI_TOTAL=0
UI_STAGE_WARNINGS=0
UI_STAGE_FAILURES=0
UI_RESET=$'\033[0m'
# Restrained slate palette, readable on GNOME Terminal dark and light themes.
UI_CYAN=$'\033[38;5;110m'
UI_BLUE=$'\033[38;5;109m'
UI_GREEN=$'\033[38;5;108m'
UI_YELLOW=$'\033[38;5;179m'
UI_RED=$'\033[38;5;167m'
UI_MUTED=$'\033[38;5;245m'

ui_init() {
  UI_COLOR=0 UI_VISIBLE=0 UI_STAGE=0
  if [[ -t 1 || "${FORCE_COLOR:-0}" == 1 ]]; then UI_VISIBLE=1; fi
  if (( UI_VISIBLE )) && [[ ! -v NO_COLOR && "${TERM:-}" != dumb ]]; then UI_COLOR=1; fi
}

# Color only on stdout: setup.log, reports and redirected CI output stay plain.
ui_paint() {
  local color="$1"; shift
  if (( UI_COLOR )); then printf '%b%s%b\n' "$color" "$*" "$UI_RESET"
  else printf '%s\n' "$*"; fi
}

ui_banner() {
  (( UI_VISIBLE )) || return 0
  ui_paint "$UI_MUTED" '  ──────────────────────────────────────────────────────────'
  ui_paint "$UI_CYAN"  '    N A M H H   /   D E S K T O P   K I T'
  ui_paint "$UI_MUTED" '    UNIVERSAL LINUX OFFICE KIT  ·  UBUNTU READY'
  ui_paint "$UI_MUTED" '    Thiết kế: NAMHH  /  huynhoainam@gmail.com'
  ui_paint "$UI_MUTED" '  ──────────────────────────────────────────────────────────'
  printf '\n'
}

ui_stage_close() {
  (( UI_VISIBLE && UI_STAGE > 0 )) || return 0
  if ((${#FAILURES[@]} > UI_STAGE_FAILURES)); then
    ui_paint "$UI_RED" '           ×  Cần kiểm tra  ·  chi tiết trong báo cáo'
  elif ((${#WARNINGS[@]} > UI_STAGE_WARNINGS)); then
    ui_paint "$UI_YELLOW" '           !  Có lưu ý  ·  xem báo cáo cuối'
  else
    ui_paint "$UI_GREEN" '           ✓  Hoàn tất bước'
  fi
}

ui_stage() {
  ui_stage_close
  (( UI_STAGE += 1 ))
  UI_STAGE_WARNINGS=${#WARNINGS[@]}
  UI_STAGE_FAILURES=${#FAILURES[@]}
  (( UI_VISIBLE && UI_TOTAL > 0 )) || return 0
  local indicator percent=$((UI_STAGE * 100 / UI_TOTAL))
  printf -v indicator '  [%02d/%02d · %3d%%]  %s' "$UI_STAGE" "$UI_TOTAL" "$percent" "$*"
  ui_paint "$UI_BLUE" "$indicator"
  # Optional pause for GitHub Actions' terminal screenshot only; unset in normal installs.
  if [[ -n "${UI_STAGE_DELAY:-}" ]]; then sleep "$UI_STAGE_DELAY"; fi
}

ui_finish() {
  ui_stage_close
  (( UI_VISIBLE )) || return 0
  printf '\n'
  if ((${#FAILURES[@]})); then
    ui_paint "$UI_RED" "  CẦN KIỂM TRA  ·  ${#FAILURES[@]} lỗi / ${#WARNINGS[@]} lưu ý"
  elif (( DRY_RUN )); then
    ui_paint "$UI_CYAN" "  ĐÃ MÔ PHỎNG  ·  ${UI_STAGE}/${UI_TOTAL} bước (100%)"
  else
    ui_paint "$UI_GREEN" "  HOÀN TẤT  ·  ${UI_STAGE}/${UI_TOTAL} bước (100%)"
    ((${#WARNINGS[@]} == 0)) || ui_paint "$UI_YELLOW" "  LƯU Ý  ·  ${#WARNINGS[@]} mục cần xem lại"
  fi
  ui_paint "$UI_MUTED" "  BÁO CÁO  ·  ${REPORT_HTML_PATH##*/}"
  ui_paint "$UI_MUTED" '  HỖ TRỢ   ·  huynhoainam@gmail.com'
}

usage() {
  cat <<'EOF'
Universal Linux Office Kit
Usage: ./setup.sh [options]
  --profile minimal|office|desktop|full  What to install (default: desktop)
  --dry-run                      Print actions without changing the system
  --yes                          Skip confirmation
  --no-reboot                    Never offer reboot
  --enable-ufw                   Explicitly enable firewall (off by default)
  --skip-flatpak                 Do not install Flatpak packages
  --skip-third-party             Do not install GenOffice/Chrome/Edge/VS Code/Docker/Zoom/Zalo
  --canon-ufrii-archive PATH     Install Canon UFR II from official downloaded .tar.gz
  --fix-unikey                  Repair Vietnamese input without full setup
  --fix-flameshot               Repair Flameshot without full setup
  --fix-zalo                    Repair Zalo, or install it when missing
  --fix-zalo-login              Update Zalo, preserve old data, retry stuck QR login
  --update-zalo                 Update Zalo from its verified upstream release
  --repair-desktop              Repair Vietnamese input, Flameshot GUI and Zalo
  --fix-office                  Check office suites; prefer WPS, keep at most 2 new suites
  --zalo-variant chat|full      Zalo package (default: chat; full is legacy)
  --office-secondary auto|libreoffice|genoffice  Second office suite (default: auto)
  --report PATH                  Write report to PATH
  --report-html PATH             Write user-friendly HTML report to PATH
  --no-open-report               Do not open HTML report automatically
  --verbose                      Show technical details in terminal (always logged)
  -h, --help                     Show help
EOF
}

log() {
  local line="[$(date '+%F %T')] $*" color=''
  printf '%s\n' "$line" >> "$LOG_PATH"
  if (( UI_VISIBLE && ! UI_VERBOSE )); then
    case "$*" in
      'PASS: Báo cáo dễ đọc:'*) ui_paint "$UI_GREEN" '  ✓  Báo cáo HTML đã tạo thành công'; return 0 ;;
      'WARN:'*) ui_paint "$UI_YELLOW" "  !  ${*#WARN: }"; return 0 ;;
      'FAIL:'*) ui_paint "$UI_RED" '  ×  Có lỗi ở bước hiện tại; xem setup.log hoặc báo cáo.'; return 0 ;;
      *) return 0 ;;
    esac
  fi
  case "$*" in
    FAIL:*|*'FAIL:'*) color="$UI_RED" ;;
    WARN:*|*'WARN:'*) color="$UI_YELLOW" ;;
    PASS:*|*'PASS:'*) color="$UI_GREEN" ;;
    Module:*|*'Module:'*) color="$UI_MUTED" ;;
    *) color='' ;;
  esac
  ui_paint "$color" "$line"
}
warn() { WARNINGS+=("$*"); log "WARN: $*"; }
fail() { FAILURES+=("$*"); log "FAIL: $*"; }

run() {
  log "+ $*"
  if (( DRY_RUN )); then return 0; fi
  # Leave sudo's password prompt on /dev/tty; keep APT/dpkg chatter in setup.log.
  # This makes the installer readable without losing diagnostics on failures.
  if (( UI_VISIBLE && ! UI_VERBOSE )); then
    "$@" >>"$LOG_PATH" 2>&1
    return $?
  fi
  "$@"
}

apt_run() {
  run sudo apt-get -o Acquire::Retries=1 -o Acquire::http::Timeout=25 \
    -o Acquire::https::Timeout=25 "$@"
}

backup_desktop_settings() {
  (( DRY_RUN )) && { log '+ back up desktop settings'; return 0; }
  local state="${XDG_STATE_HOME:-$HOME/.local/state}/ulok/backups"
  mkdir -p -- "$state" || return 1
  BACKUP_DIR="$(mktemp -d "$state/desktop-$(date +%Y%m%d-%H%M%S)-XXXXXX" 2>/dev/null)" || {
    mkdir -p -- "$state"
    BACKUP_DIR="$(mktemp -d "$state/desktop-$(date +%Y%m%d-%H%M%S)-XXXXXX")" || return 1
  }
  chmod 0700 "$BACKUP_DIR"
  local file
  for file in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile" \
    "$HOME/.xinputrc" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/namhh-unikey-guard.desktop" \
    "${XDG_BIN_HOME:-$HOME/.local/bin}/namhh-unikey-guard" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/ulok-flameshot.desktop" \
    "${XDG_BIN_HOME:-$HOME/.local/bin}/ulok-flameshot"; do
    if [[ -f "$file" ]]; then
      cp -p -- "$file" "$BACKUP_DIR/$(basename "$(dirname "$file")")-$(basename "$file")"
    fi
  done
  if desktop_is_gnome && command -v gsettings >/dev/null; then
    gsettings get org.gnome.desktop.input-sources sources > "$BACKUP_DIR/gnome-input-sources.txt" 2>/dev/null || true
    gsettings get org.gnome.desktop.input-sources current > "$BACKUP_DIR/gnome-input-current.txt" 2>/dev/null || true
    gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings > "$BACKUP_DIR/gnome-shortcuts.txt" 2>/dev/null || true
  fi
  log "Desktop settings backup: $BACKUP_DIR"
}

restore_desktop_settings() {
  [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR" ]] || return 0
  local dest
  for dest in \
    "${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile" \
    "$HOME/.xinputrc" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/namhh-unikey-guard.desktop" \
    "${XDG_BIN_HOME:-$HOME/.local/bin}/namhh-unikey-guard" \
    "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/ulok-flameshot.desktop" \
    "${XDG_BIN_HOME:-$HOME/.local/bin}/ulok-flameshot"; do
    if [[ -f "$BACKUP_DIR/$(basename "$(dirname "$dest")")-$(basename "$dest")" ]]; then
      cp -p -- "$BACKUP_DIR/$(basename "$(dirname "$dest")")-$(basename "$dest")" "$dest" || warn "Không thể khôi phục $dest"
    fi
  done
  if desktop_is_gnome && command -v gsettings >/dev/null; then
    if [[ -s "$BACKUP_DIR/gnome-input-sources.txt" ]]; then
      gsettings set org.gnome.desktop.input-sources sources "$(<"$BACKUP_DIR/gnome-input-sources.txt")" || warn 'Không thể khôi phục input sources'
    fi
    if [[ -s "$BACKUP_DIR/gnome-input-current.txt" ]]; then
      gsettings set org.gnome.desktop.input-sources current "$(<"$BACKUP_DIR/gnome-input-current.txt")" || warn 'Không thể khôi phục input current'
    fi
    if [[ -s "$BACKUP_DIR/gnome-shortcuts.txt" ]]; then
      gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$(<"$BACKUP_DIR/gnome-shortcuts.txt")" || warn 'Không thể khôi phục shortcut list'
    fi
  fi
  warn "Đã thử khôi phục cấu hình desktop trước sửa từ $BACKUP_DIR. Các gói APT đã cài không bị gỡ."
}

require_platform() {
  [[ "$EUID" -ne 0 ]] || { fail 'Chạy ./setup.sh bằng tài khoản người dùng, không dùng sudo; script sẽ gọi sudo khi cần'; return 1; }
  [[ -r /etc/os-release ]] || { fail 'Không đọc được /etc/os-release'; return 1; }
  # shellcheck disable=SC1091
  source /etc/os-release
  case "${ID:-}" in
    ubuntu) log "Detected Ubuntu ${VERSION_ID:-unknown}" ;;
    linuxmint) log "Detected Linux Mint ${VERSION_ID:-unknown} (Ubuntu base: ${UBUNTU_CODENAME:-unknown})" ;;
    *) fail "Chỉ hỗ trợ Ubuntu/Linux Mint; phát hiện ${ID:-unknown}"; return 1 ;;
  esac
  command -v sudo >/dev/null || { fail 'Thiếu sudo'; return 1; }
  command -v apt-get >/dev/null || { fail 'Thiếu apt-get'; return 1; }
}

repair_package_state() {
  log 'Repairing package state before installation'
  run sudo dpkg --configure -a || warn 'dpkg --configure -a cần xử lý thủ công'
  apt_run -f install -y || warn 'apt-get -f install thất bại; các bước sau có thể bị bỏ qua'
  apt_run update || { warn 'APT update bị proxy/mirror chặn; thử cài từ cache hiện có'; return 1; }
}

install_apt() {
  local -a packages=("$@")
  local -a missing=()
  local package
  for package in "${packages[@]}"; do
    package_installed "$package" || missing+=("$package")
  done
  if ((${#missing[@]} == 0)); then
    log "APT: tất cả gói đã có, bỏ qua (${packages[*]})"
    return 0
  fi
  apt_run install -y --no-install-recommends "${missing[@]}" || { warn "Chưa cài được: ${missing[*]}"; return 1; }
}

package_installed() {
  [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" == 'install ok installed' ]]
}
desktop_is_gnome() {
  local desktop="${XDG_CURRENT_DESKTOP:-}"
  [[ "${desktop,,}" == *gnome* ]]
}
desktop_is_cinnamon() {
  local desktop="${XDG_CURRENT_DESKTOP:-}"
  [[ "${desktop,,}" == *cinnamon* ]]
}

install_deb_url() {
  local name="$1" url="$2" digest="${3:-}" target
  target="${TMPDIR:-/tmp}/${name}.deb"
  if (( ! DRY_RUN )) && package_installed "$name"; then
    log "Already installed: $name; skipping download"
    return 0
  fi
  log "Downloading official package: $name"
  if (( DRY_RUN )); then
    log "+ curl -fL --retry 3 -o $target $url"
    [[ -z "$digest" ]] || log "+ sha256sum -c ($digest)"
    log "+ sudo apt-get install -y $target"
    return 0
  fi
  run curl -fLSs --show-error --connect-timeout 20 --max-time 600 --retry 2 --retry-delay 2 -o "$target" "$url" || { warn "Không tải được: $name"; return 1; }
  if [[ -n "$digest" ]] && ! printf '%s  %s\n' "$digest" "$target" | sha256sum --check --status; then
    warn "SHA-256 không khớp: $name; không cài gói không xác minh"
    return 1
  fi
  apt_run install -y "$target" || { warn "Không cài được: $name"; return 1; }
  rm -f "$target"
}

install_microsoft_repo() {
  local key_tmp="${TMPDIR:-/tmp}/microsoft.asc"
  if (( DRY_RUN )); then
    log "+ configure packages.microsoft.com official repository"
    return 0
  fi
  curl -fsSL --retry 3 https://packages.microsoft.com/keys/microsoft.asc -o "$key_tmp" || { fail 'Microsoft signing key download failed'; return 1; }
  sudo install -d -m 0755 /etc/apt/keyrings
  sudo gpg --dearmor --yes -o /etc/apt/keyrings/microsoft.gpg "$key_tmp" || { fail 'Microsoft signing key setup failed'; return 1; }
  sudo chmod a+r /etc/apt/keyrings/microsoft.gpg
  sudo tee /etc/apt/sources.list.d/microsoft.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/code
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
  sudo tee /etc/apt/sources.list.d/microsoft-edge.sources >/dev/null <<'EOF'
Types: deb
URIs: https://packages.microsoft.com/repos/edge
Suites: stable
Components: main
Architectures: amd64,arm64,armhf
Signed-By: /etc/apt/keyrings/microsoft.gpg
EOF
  apt_run update || { fail 'Microsoft repository update failed'; return 1; }
}

module_base() {
  log 'Module: base'
  install_apt ca-certificates curl wget git gpg unzip zip p7zip-full rsync jq \
    bash-completion software-properties-common apt-transport-https \
    network-manager dnsutils ufw htop ncdu || true
  if (( ENABLE_UFW )); then
    run sudo ufw --force enable || warn 'Không bật được UFW; kiểm tra thủ công'
  else
    log 'UFW: installed if available, existing firewall state unchanged (protect VPN/remote access)'
  fi
  install_apt xdg-utils cifs-utils smbclient gvfs-backends \
    openvpn network-manager-openvpn network-manager-openvpn-gnome || true
}

office_suite_installed() {
  case "$1" in
    wps) package_installed wps-office || command -v wps >/dev/null 2>&1 ;;
    libreoffice) package_installed libreoffice-common || package_installed libreoffice || command -v libreoffice >/dev/null 2>&1 ;;
    genoffice) package_installed genoffice || command -v genoffice >/dev/null 2>&1 ;;
    *) return 2 ;;
  esac
}

office_suite_count() {
  local suite count=0
  for suite in wps libreoffice genoffice; do
    if office_suite_installed "$suite"; then ((count+=1)); fi
  done
  printf '%s\n' "$count"
}

module_office_suites() {
  local count secondary arch suite suite_label
  count="$(office_suite_count)"
  log "Office suite: phát hiện $count/2 bộ (WPS, LibreOffice, GenOffice)"
  if (( count > 2 )); then
    warn "Đã có $count bộ Office: không gỡ ứng dụng đang dùng; không cài thêm. Hãy quyết định bộ muốn giữ."
    return 0
  fi

  # WPS is first priority. Never install a third suite just to meet the preference.
  if ! office_suite_installed wps; then
    if (( count >= 2 )); then
      warn 'WPS chưa có nhưng đã đủ 2 bộ Office; giữ nguyên, không tự gỡ ứng dụng cũ.'
    elif (( SKIP_THIRD_PARTY )); then
      log 'WPS bỏ qua theo --skip-third-party'
    else
      arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
      if [[ "$arch" == amd64 ]]; then
        # Pinned to the WPS package and digest used in the Flathub packaging manifest.
        install_deb_url wps-office 'https://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/11723/wps-office_11.1.0.11723.XA_amd64.deb' 'fe6326210f69d94efdbf2728914d293036be391b93a614f58cd0e1ff1d4923b3' || warn 'Không cài được WPS; giữ các bộ đã có.'
      else
        warn "WPS .deb dành cho amd64; máy hiện dùng $arch"
      fi
    fi
  else
    log 'WPS Office đã cài; bỏ qua tải lại.'
  fi

  count="$(office_suite_count)"
  secondary="$OFFICE_SECONDARY"
  if [[ "$secondary" == auto ]]; then
    if office_suite_installed genoffice && ! office_suite_installed libreoffice; then
      secondary=genoffice
    else
      secondary=libreoffice
    fi
  fi
  if [[ "$secondary" == libreoffice ]]; then
    if office_suite_installed libreoffice; then
      log 'LibreOffice đã cài; giữ nguyên bộ thứ hai.'
    elif (( count < 2 )); then
      install_apt libreoffice libreoffice-l10n-vi libreoffice-help-vi libreoffice-gtk3 || warn 'Không cài được LibreOffice.'
    else
      log 'Đã đủ 2 bộ Office; không cài thêm LibreOffice.'
    fi
  else
    log 'GenOffice được chọn làm bộ thứ hai; không cài thêm LibreOffice.'
  fi
  for suite in wps libreoffice genoffice; do
    case "$suite" in
      wps) suite_label='WPS Office' ;;
      libreoffice) suite_label='LibreOffice' ;;
      genoffice) suite_label='GenOffice' ;;
    esac
    if office_suite_installed "$suite"; then
      log "PASS: Office đã có · $suite_label"
    else
      log "Office chưa cài · $suite_label"
    fi
  done
}

module_office() {
  log 'Module: office'
  module_office_suites
  install_apt hunspell-vi hyphen-vi mythes-vi evince poppler-utils \
    simple-scan cups system-config-printer || true
  install_apt thunderbird pdfarranger || true
  install_apt fonts-crosextra-carlito fonts-crosextra-caladea \
    fonts-liberation2 fonts-noto-color-emoji || true
  configure_office_fonts
  module_canon_ufrii || true
}

module_genoffice() {
  (( SKIP_THIRD_PARTY )) && { log 'GenOffice skipped with third-party apps'; return 0; }
  log 'Module: GenOffice'
  if (( ! DRY_RUN )) && { package_installed genoffice || command -v genoffice >/dev/null 2>&1; }; then
    log 'GenOffice already installed; skipping duplicate installer'
    return 0
  fi
  local arch glibc_version release_url dir metadata asset_url digest deb pkg deb_arch
  # Official GenOffice release, pinned 2026-10-13 for networks blocking api.github.com.
  # Update BOTH the URL and SHA256 together after verifying upstream release metadata.
  local fallback_url='https://github.com/genspark-ai/genoffice/releases/download/v0.11.727/genoffice_0.11.727_amd64.deb'
  local fallback_sha256='2e8b7c5c737d603742c6c5a60d626944cb36c9caed07e9d7cef60998122de26b'
  arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
  [[ "$arch" == amd64 ]] || { warn "GenOffice requires amd64; skipped on $arch"; return 0; }
  glibc_version="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
  if [[ -z "$glibc_version" ]] || ! dpkg --compare-versions "$glibc_version" ge 2.34; then
    warn "GenOffice requires glibc 2.34 or newer; found ${glibc_version:-unknown}"
    return 0
  fi
  release_url='https://api.github.com/repos/genspark-ai/genoffice/releases/latest'
  if (( DRY_RUN )); then
    log "+ check GenOffice latest release metadata at $release_url; on API failure use pinned v0.11.727 with SHA-256 validation"
    return 0
  fi
  dir="$(mktemp -d)" || { warn 'Could not create GenOffice temporary directory'; return 0; }
  metadata="$dir/release.json"
  deb="$dir/genoffice_amd64.deb"
  if ! command -v jq >/dev/null 2>&1 || ! curl --fail --location --silent --show-error --connect-timeout 15 --retry 1 "$release_url" -o "$metadata"; then
    warn 'GitHub API for GenOffice unavailable (or jq missing); using pinned official v0.11.727 release'
    asset_url="$fallback_url"
    digest="sha256:$fallback_sha256"
  else
    asset_url="$(jq -er '[.assets[] | select(.name | test("^genoffice_[^/]+_amd64[.]deb$"))] | if length == 1 then .[0].browser_download_url else empty end' "$metadata" 2>/dev/null)" || {
      rm -rf -- "$dir"
      warn 'GenOffice release metadata missing unique amd64 asset; skipped'
      return 0
    }
    digest="$(jq -r --arg url "$asset_url" '.assets[] | select(.browser_download_url == $url) | .digest // empty' "$metadata" 2>/dev/null)" || digest=''
  fi
  if [[ "$asset_url" != https://github.com/genspark-ai/genoffice/releases/download/* ]]; then
    rm -rf -- "$dir"
    warn 'GenOffice asset URL is not from the official GitHub repository'
    return 0
  fi
  if [[ ! "$digest" =~ ^sha256:[a-fA-F0-9]{64}$ ]]; then
    rm -rf -- "$dir"
    warn 'GenOffice release lacks trusted SHA-256; refusing unverified installer'
    return 0
  fi
  if ! curl --fail --location --retry 2 --retry-delay 2 --connect-timeout 20 "$asset_url" -o "$deb"; then
    rm -rf -- "$dir"
    warn 'GenOffice release asset download failed; check github.com/Releases network access'
    return 0
  fi
  if [[ "${digest#sha256:}" != "$(sha256sum "$deb" | awk '{print $1}')" ]]; then
    rm -rf -- "$dir"
    warn 'GenOffice SHA-256 checksum mismatch; refusing installation'
    return 0
  fi
  pkg="$(dpkg-deb -f "$deb" Package 2>/dev/null || true)"
  deb_arch="$(dpkg-deb -f "$deb" Architecture 2>/dev/null || true)"
  if [[ "$pkg" != genoffice || "$deb_arch" != amd64 ]]; then
    rm -rf -- "$dir"
    warn "GenOffice package metadata mismatch: $pkg/$deb_arch"
    return 0
  fi
  if sudo apt-get install -y "$deb"; then
    log 'PASS: GenOffice installed'
  else
    warn 'GenOffice .deb installation failed'
  fi
  rm -rf -- "$dir"
}

configure_office_fonts() {
  log 'Module: Office-compatible font aliases'
  local dir="${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig/conf.d" target
  target="$dir/60-ulok-office-aliases.conf"
  if (( DRY_RUN )); then log "+ create $target and refresh font cache"; return 0; fi
  mkdir -p -- "$dir"
  cat > "$target" <<'EOF'
<?xml version="1.0"?>
<!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
<fontconfig>
  <alias><family>Arial</family><prefer><family>Liberation Sans</family></prefer></alias>
  <alias><family>Times New Roman</family><prefer><family>Liberation Serif</family></prefer></alias>
  <alias><family>Courier New</family><prefer><family>Liberation Mono</family></prefer></alias>
  <alias><family>Calibri</family><prefer><family>Carlito</family></prefer></alias>
  <alias><family>Cambria</family><prefer><family>Caladea</family></prefer></alias>
  <alias><family>Aptos</family><prefer><family>Carlito</family></prefer></alias>
  <alias><family>Segoe UI</family><prefer><family>Noto Sans</family></prefer></alias>
</fontconfig>
EOF
  command -v fc-cache >/dev/null && fc-cache -f >/dev/null 2>&1 || true
}

module_vietnamese_input() {
  log 'Module: Vietnamese input method (Unikey)'
  if ! command -v python3 >/dev/null 2>&1; then
    install_apt python3 || return 1
  fi
  # Choose for the CURRENT desktop, even if the other input framework was installed
  # by an older run. A stray Fcitx package must not override GNOME's IBus.
  if desktop_is_cinnamon || { [[ "${ID:-}" == linuxmint ]] && ! desktop_is_gnome; }; then
    install_apt fcitx5 fcitx5-unikey || return 1
    install_apt fcitx5-config-qt im-config || warn 'Thiếu giao diện cấu hình Fcitx5; bộ gõ chính vẫn được cài'
    configure_fcitx5_unikey
  else
    install_apt ibus ibus-unikey || return 1
    install_apt ibus-gtk3 ibus-gtk4 im-config || warn 'Thiếu tích hợp IBus phụ; bộ gõ chính vẫn được cài'
    configure_ibus_unikey
  fi
}

configure_fcitx5_unikey() {
  if (( DRY_RUN )); then log '+ select Fcitx5 and add Unikey to user profile'; return 0; fi
  package_installed fcitx5-unikey || { warn 'Fcitx5 Unikey chưa cài được'; return 1; }
  if command -v im-config >/dev/null; then
    im-config -n fcitx5 >/dev/null 2>&1 || warn 'Không chọn được Fcitx5 qua im-config'
  fi
  local profile="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile" index changed=0
  mkdir -p -- "$(dirname -- "$profile")"
  if [[ ! -s "$profile" ]]; then
    cat > "$profile" <<'EOF'
[Groups/0]
Name=Default
Default Layout=us
DefaultIM=keyboard-us

[Groups/0/Items/0]
Name=keyboard-us
Layout=

[Groups/0/Items/1]
Name=unikey
Layout=

[GroupOrder]
0=Default
EOF
    changed=1
  elif ! awk '
    /^\[Groups\/0\/Items\/[0-9]+\]$/ { in_item=1; next }
    /^\[/ { in_item=0 }
    in_item && /^Name=unikey$/ { found=1 }
    END { exit !found }
  ' "$profile"; then
    if ! grep -q '^\[Groups/0\]' "$profile"; then
      warn "Profile Fcitx5 có cấu trúc khác; hãy thêm Unikey bằng fcitx5-configtool: $profile"
      return 0
    fi
    cp -p -- "$profile" "${profile}.bak-ulok-$(date +%Y%m%d-%H%M%S)"
    index="$(sed -n 's/^\[Groups\/0\/Items\/\([0-9][0-9]*\)\]$/\1/p' "$profile" | sort -n | tail -1)"
    index="$((${index:-0} + 1))"
    printf '\n[Groups/0/Items/%s]\nName=unikey\nLayout=\n' "$index" >> "$profile"
    changed=1
  fi
  # The former default (keyboard-us) kept the keyboard in English after login.
  # Keep every existing group and item; only select Unikey in the default group.
  if grep -q '^DefaultIM=' "$profile" && ! grep -qx 'DefaultIM=unikey' "$profile"; then
    if (( ! changed )); then
      cp -p -- "$profile" "${profile}.bak-ulok-$(date +%Y%m%d-%H%M%S)"
    fi
    sed -i '0,/^DefaultIM=/s/^DefaultIM=.*/DefaultIM=unikey/' "$profile"
    changed=1
  elif ! grep -q '^DefaultIM=' "$profile"; then
    if (( ! changed )); then
      cp -p -- "$profile" "${profile}.bak-ulok-$(date +%Y%m%d-%H%M%S)"
    fi
    sed -i '/^\[Groups\/0\]$/a DefaultIM=unikey' "$profile"
    changed=1
  fi
  if command -v fcitx5-remote >/dev/null; then
    (( changed )) && fcitx5-remote -r >/dev/null 2>&1 || true
    fcitx5-remote -s unikey >/dev/null 2>&1 || true
  fi
  log 'Fcitx5 Unikey configured; log out and back in to apply session environment'
}

configure_ibus_unikey() {
  if (( DRY_RUN )); then log '+ check IBus Unikey engine'; return 0; fi
  package_installed ibus-unikey || { warn 'IBus Unikey chưa cài được'; return 1; }
  if command -v im-config >/dev/null; then
    im-config -n ibus >/dev/null 2>&1 || warn 'Không chọn được IBus qua im-config'
  fi
  if pgrep -u "$(id -u)" -x fcitx5 >/dev/null 2>&1; then
    warn 'Fcitx5 vẫn chạy trong phiên GNOME; đăng xuất rồi đăng nhập lại để dùng IBus, không tự kill bộ gõ đang hoạt động'
  fi
  local component='/usr/share/ibus/component/unikey.xml' engine='' current updated
  if [[ -r "$component" ]] && command -v python3 >/dev/null; then
    engine="$(python3 - "$component" <<'PY'
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.argv[1]).getroot()
    print(root.findtext('./engines/engine/name', default=''))
except (OSError, ET.ParseError):
    pass
PY
)"
  fi
  if [[ -z "$engine" ]]; then
    warn 'Không xác định được engine IBus Unikey; thêm trong Settings > Keyboard > Input Sources'
    return 1
  fi
  log "IBus Unikey engine available: $engine"
  # These keys belong to the distro's ibus-unikey schema (not VNI-Win charset).
  # VNI is a typing METHOD; Unicode is the text ENCODING for modern applications.
  if command -v gsettings >/dev/null && \
      gsettings list-schemas 2>/dev/null | grep -qx 'org.freedesktop.ibus.engine.unikey'; then
    gsettings set org.freedesktop.ibus.engine.unikey input-method vni || warn 'Chưa đặt được kiểu gõ VNI trong phiên này'
    gsettings set org.freedesktop.ibus.engine.unikey output-charset unicode || warn 'Chưa đặt được bảng mã Unicode trong phiên này'
  fi
  if desktop_is_gnome && command -v gsettings >/dev/null; then
    current="$(gsettings get org.gnome.desktop.input-sources sources 2>/dev/null)" || current=''
    if [[ -n "$current" ]]; then
      updated="$(python3 - "$current" "$engine" <<'PY'
import ast, sys
raw = sys.argv[1].strip()
if raw.startswith('@a(ss) '):
    raw = raw[len('@a(ss) '):]
try:
    sources = ast.literal_eval(raw)
    assert isinstance(sources, list)
    assert all(isinstance(x, tuple) and len(x) == 2 for x in sources)
except (ValueError, SyntaxError, AssertionError):
    sys.exit(0)
item = ('ibus', sys.argv[2])
if item not in sources:
    sources.append(item)
print(repr(sources))
PY
)"
      if [[ -n "$updated" ]]; then
        gsettings set org.gnome.desktop.input-sources sources "$updated" || warn 'Không thêm được Unikey vào GNOME Input Sources'
        # Switch to Unikey now, rather than only adding a source the user may
        # never select. Derive the index from the updated array, not a constant.
        local unikey_index
        unikey_index="$(python3 - "$updated" "$engine" <<'PY'
import ast, sys
sources = ast.literal_eval(sys.argv[1])
print(sources.index(('ibus', sys.argv[2])))
PY
)"
        if [[ "$(gsettings writable org.gnome.desktop.input-sources current 2>/dev/null)" == true ]]; then
          gsettings set org.gnome.desktop.input-sources current "$unikey_index" || warn 'Không kích hoạt được Unikey; chọn qua Super+Space'
        fi
      else
        warn 'Không đọc được Input Sources; thêm Unikey trong Settings > Keyboard'
      fi
    fi
  fi
  install_unikey_session_guard
  log 'Chọn Unikey trong Input Sources; có thể cần đăng xuất/đăng nhập một lần'
}

install_unikey_session_guard() {
  (( DRY_RUN )) && { log '+ install NAMHH Unikey session guard'; return 0; }
  desktop_is_gnome || return 0
  local source="$ROOT_DIR/scripts/unikey-session-guard.sh"
  local launcher="${XDG_BIN_HOME:-$HOME/.local/bin}/namhh-unikey-guard"
  local autostart="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/namhh-unikey-guard.desktop"
  if [[ ! -s "$source" ]] || ! bash -n "$source"; then
    warn 'Thiếu Unikey session guard; gõ tiếng Việt vẫn có thể chọn qua Settings'
    return 0
  fi
  if [[ -e "$launcher" ]] && ! grep -q '^# NAMHH: restore a missing GNOME IBus Unikey' "$launcher"; then
    warn "Giữ nguyên tiện ích người dùng: $launcher"
    return 0
  fi
  if [[ -e "$autostart" ]] && ! grep -q '^X-NAMHH-Managed=true$' "$autostart"; then
    warn "Giữ nguyên autostart người dùng: $autostart"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$launcher")" "$(dirname -- "$autostart")"
  install -m 0755 -- "$source" "$launcher"
  cat > "$autostart" <<EOF
[Desktop Entry]
Type=Application
Name=NAMHH Unikey Session Guard
Comment=Restore a missing Unikey input source after login
Exec=$launcher
TryExec=$launcher
X-GNOME-Autostart-enabled=true
X-NAMHH-Managed=true
NoDisplay=true
EOF
  log 'NAMHH Unikey session guard enabled (repairs missing sources, preserves current layout)'
}

module_canon_ufrii() {
  [[ -n "$CANON_UFRII_ARCHIVE" ]] || { log 'Canon UFR II: no archive supplied; use --canon-ufrii-archive PATH'; return 0; }
  log 'Module: Canon UFR II printer driver'
  if (( ! DRY_RUN )) && { package_installed cnrdrvcups-ufr2 || package_installed cnrdrvcups-ufr2-uk || package_installed cnrdrvcups-ufr2-us; }; then
    log 'Canon UFR II driver already installed; skipping'
    return 0
  fi
  [[ -f "$CANON_UFRII_ARCHIVE" ]] || { fail "Không tìm thấy gói Canon: $CANON_UFRII_ARCHIVE"; return 1; }
  case "$CANON_UFRII_ARCHIVE" in *.tar.gz|*.tgz) ;; *) fail 'Gói Canon phải là .tar.gz/.tgz'; return 1 ;; esac
  local arch tmp package_dir
  arch="$(dpkg --print-architecture)"
  case "$arch" in amd64|arm64) ;; *) warn "Canon UFR II chưa hỗ trợ tự cài kiến trúc $arch"; return 0 ;; esac
  if (( DRY_RUN )); then log "+ extract Canon archive and install $arch Debian packages"; return 0; fi
  tmp="$(mktemp -d)" || { fail 'Không tạo được thư mục tạm Canon'; return 1; }
  if ! tar -tzf "$CANON_UFRII_ARCHIVE" >/dev/null || ! tar -xzf "$CANON_UFRII_ARCHIVE" -C "$tmp" --no-same-owner; then
    rm -rf -- "$tmp"; fail 'Không giải nén được gói Canon'; return 1
  fi
  # Canon's release contains Debian packages under an architecture-specific driver directory.
  local -a packages=()
  while IFS= read -r -d '' package_dir; do packages+=("$package_dir"); done < <(
    find "$tmp" -type f -name '*.deb' -print0
  )
  local -a selected=()
  local package pkg_arch pkg_name
  for package in "${packages[@]}"; do
    pkg_arch="$(dpkg-deb -f "$package" Architecture 2>/dev/null || true)"
    pkg_name="$(dpkg-deb -f "$package" Package 2>/dev/null || true)"
    if [[ "$pkg_name" == cnrdrvcups-ufr2* && ( "$pkg_arch" == "$arch" || "$pkg_arch" == all ) ]]; then
      selected+=("$package")
    fi
  done
  if ((${#selected[@]} == 0)); then
    rm -rf -- "$tmp"; fail "Gói Canon không có .deb cho $arch"; return 1
  fi
  if ! apt_run install -y "${selected[@]}"; then
    rm -rf -- "$tmp"; fail 'Không cài được driver Canon UFR II'; return 1
  fi
  rm -rf -- "$tmp"
  log 'Canon UFR II installed; add printer through system-config-printer'
}

module_media() {
  log 'Module: media'
  install_apt vlc ffmpeg file libavcodec-extra fonts-noto-core \
    fonts-noto-cjk fonts-liberation || true
  if [[ "$PROFILE" == full ]]; then
    install_apt imagemagick gimp || true
  fi
}

# Small, practical Windows-to-Ubuntu conveniences. No services are enabled,
# backup destinations selected, drives reformatted or desktop preferences reset.
module_everyday() {
  log 'Module: everyday desktop'
  install_apt file-roller deja-dup baobab gnome-disk-utility \
    ntfs-3g exfatprogs gvfs-backends || true
  install_apt gstreamer1.0-plugins-good gstreamer1.0-libav || true
  if desktop_is_gnome; then
    install_apt gnome-sushi gnome-tweaks || true
  fi
  install_apt remmina remmina-plugin-rdp remmina-plugin-vnc || true
}

module_flameshot() {
  log 'Module: Flameshot'
  # Presence of an executable is not proof that the APT package installed.
  # Older releases silently ignored failure here and printed a success report.
  if (( DRY_RUN )) || ! package_installed flameshot || ! command -v flameshot >/dev/null 2>&1; then
    if ! install_apt flameshot; then
      warn 'Flameshot installation failed; run sudo apt-get install flameshot and inspect the error (APT/mirror/dependencies)'
      return 1
    fi
  fi
  if (( ! DRY_RUN )) && ! package_installed flameshot; then
    fail 'Flameshot package is still missing after APT install'
    return 1
  fi
  if [[ "${XDG_SESSION_TYPE:-}" == wayland ]] && desktop_is_gnome; then
    install_apt xdg-desktop-portal xdg-desktop-portal-gnome || warn 'Thiếu portal Wayland; Flameshot vẫn được cài và gán phím tắt'
    # Install the matching native Wayland Qt backend; Ubuntu LTS versions vary.
    if command -v ldd >/dev/null 2>&1 && ldd "$(command -v flameshot)" 2>/dev/null | grep -q 'libQt6Core'; then
      install_apt qt6-wayland || warn 'Thiếu Qt6 Wayland plugin; thử chụp sau khi đăng xuất'
    else
      install_apt qtwayland5 || warn 'Thiếu Qt5 Wayland plugin; thử chụp sau khi đăng xuất'
    fi
  fi
  configure_flameshot_shortcut
  start_flameshot_daemon
}

start_flameshot_daemon() {
  (( DRY_RUN )) && return 0
  command -v flameshot >/dev/null 2>&1 || return 0
  if [[ -z "${DISPLAY:-}" && -z "${WAYLAND_DISPLAY:-}" ]]; then
    warn 'Không ở trong phiên đồ họa; Flameshot sẽ tự khởi chạy khi đăng nhập desktop'
    return 0
  fi
  if command -v pgrep >/dev/null 2>&1 && pgrep -u "$(id -u)" -x flameshot >/dev/null 2>&1; then
    log 'Flameshot is already running'
    return 0
  fi
  if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
    (nohup env QT_QPA_PLATFORM=wayland flameshot </dev/null >/dev/null 2>&1 &)
  else
    (nohup flameshot </dev/null >/dev/null 2>&1 &)
  fi
  log 'Flameshot startup requested for current graphical session'
}

configure_flameshot_shortcut() {
  log 'Configuring Flameshot shortcut: Ctrl+Alt+S'
  if (( DRY_RUN )); then
    log '+ create user Flameshot launcher/autostart and configure GNOME shortcut'
    return 0
  fi
  command -v flameshot >/dev/null || { warn 'Flameshot chưa cài; bỏ qua phím tắt'; return 0; }
  local launcher="${XDG_BIN_HOME:-$HOME/.local/bin}/ulok-flameshot"
  local autostart="${XDG_CONFIG_HOME:-$HOME/.config}/autostart/ulok-flameshot.desktop"
  if [[ -L "$launcher" ]] || { [[ -e "$launcher" ]] && ! grep -q '^# Managed by Universal Linux Office Kit$' "$launcher"; }; then
    warn "Giữ nguyên launcher tự tạo: $launcher"
    return 0
  fi
  mkdir -p -- "$(dirname -- "$launcher")"
  cat > "$launcher" <<'EOF'
#!/usr/bin/env bash
# Managed by Universal Linux Office Kit
set -Eeuo pipefail
if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
  export QT_QPA_PLATFORM=wayland
  # GNOME sometimes loses the screenshot portal parent window when a hotkey
  # launches the Qt GUI directly. Flameshot documents the shell/PTY workaround.
  if command -v script >/dev/null 2>&1; then
    exec script --quiet --return --command 'flameshot gui' /dev/null
  fi
fi
exec flameshot gui
EOF
  chmod 0755 "$launcher"
  if [[ ! -e "$autostart" ]] || grep -q '^X-ULOK-Managed=true$' "$autostart"; then
    mkdir -p -- "$(dirname -- "$autostart")"
    if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
      cat > "$autostart" <<'EOF'
[Desktop Entry]
Type=Application
Name=Flameshot (Universal Linux Office Kit)
TryExec=flameshot
Exec=env QT_QPA_PLATFORM=wayland flameshot
X-GNOME-Autostart-enabled=true
X-ULOK-Managed=true
EOF
    else
      cat > "$autostart" <<'EOF'
[Desktop Entry]
Type=Application
Name=Flameshot (Universal Linux Office Kit)
TryExec=flameshot
Exec=flameshot
X-GNOME-Autostart-enabled=true
X-ULOK-Managed=true
EOF
    fi
  else
    warn "Giữ nguyên autostart tự tạo: $autostart"
  fi
  if ! desktop_is_gnome; then
    warn "Tạo launcher $launcher; tự gán Ctrl+Alt+S trong Keyboard Shortcuts"
    return 0
  fi
  command -v gsettings >/dev/null || { warn 'Không có gsettings; hãy tạo phím tắt Flameshot thủ công'; return 0; }
  local schema='org.gnome.settings-daemon.plugins.media-keys' path='/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/'
  local key_schema='org.gnome.settings-daemon.plugins.media-keys.custom-keybinding'
  local current
  current="$(gsettings get "$schema" custom-keybindings 2>/dev/null)" || { warn 'Không đọc được phím tắt GNOME'; return 0; }
  # Keep all existing custom shortcuts; add this path only once.
  if [[ "$current" != *"'$path'"* ]]; then
    if [[ "$current" == '@as []' || "$current" == '[]' ]]; then
      current="['$path']"
    else
      current="${current%]}"
      current="${current}, '$path']"
    fi
    gsettings set "$schema" custom-keybindings "$current" || { warn 'Không lưu được danh sách phím tắt'; return 0; }
  fi
  gsettings set "$key_schema:$path" name 'Flameshot' && \
    gsettings set "$key_schema:$path" command "$launcher" && \
    gsettings set "$key_schema:$path" binding '<Primary><Alt>s' || warn 'Không gán được Ctrl+Alt+S cho Flameshot'
  if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
    warn 'GNOME Wayland: nếu Flameshot báo Unable to capture screen, hãy cho phép Share trong portal; thử Ubuntu on Xorg nếu lỗi vẫn tồn tại'
  fi
}

module_dev() {
  log 'Module: dev'
  install_apt build-essential pkg-config python3 python3-pip python3-venv \
    python3-dev shellcheck make tmux vim || true
  install_apt inxi gparted gnome-disk-utility nmap net-tools ethtool \
    traceroute tcpdump iperf3 smartmontools whois || true
}

module_remote() {
  log 'Module: connectivity'
  install_apt openssh-client remmina remmina-plugin-rdp remmina-plugin-vnc \
    xclip wl-clipboard || true
}

module_flatpak() {
  (( SKIP_FLATPAK )) && { log 'Flatpak skipped'; return 0; }
  log 'Module: flatpak'
  install_apt flatpak gnome-software-plugin-flatpak || true
  if command -v flatpak >/dev/null && (( ! DRY_RUN )); then
    run flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || warn 'Không thêm được Flathub'
  fi
}

module_third_party() {
  (( SKIP_THIRD_PARTY )) && { log 'Third-party apps skipped'; return 0; }
  log 'Module: official third-party apps'
  local arch
  arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
  if [[ "$arch" == amd64 ]]; then
    install_deb_url google-chrome-stable https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb || true
    install_deb_url zoom https://zoom.us/client/latest/zoom_amd64.deb || true
    # WPS is handled first by module_office_suites to enforce the two-suite cap.
  else
    warn "Chrome/Zoom/WPS direct .deb skipped on architecture: $arch"
  fi
  if [[ "$arch" == amd64 || "$arch" == arm64 ]]; then
    install_microsoft_repo || true
    install_apt code microsoft-edge-stable || true
  else
    warn "VS Code/Edge skipped on architecture: $arch"
  fi
  if [[ "${ID:-}" == ubuntu ]]; then
    local codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
    if [[ -n "$codename" ]]; then
      if (( ! DRY_RUN )); then
        sudo install -d -m 0755 /etc/apt/keyrings
        local docker_key
        docker_key="$(mktemp)"
        if ! curl -fsSL --retry 3 https://download.docker.com/linux/ubuntu/gpg -o "$docker_key"; then
          rm -f -- "$docker_key"
          warn 'Docker signing key download failed; skipping Docker repository'
          return 0
        fi
        sudo install -m 0644 "$docker_key" /etc/apt/keyrings/docker.asc
        rm -f -- "$docker_key"
        sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF
        if ! apt_run update; then
          warn 'Docker repository update failed; skipping Docker packages'
          return 0
        fi
      else
        log "+ configure Docker official repository for $codename"
      fi
      install_apt docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin || true
    else
      warn 'Ubuntu codename unavailable; Docker official repository skipped'
    fi
  else
    log 'Linux Mint detected: using Mint/Ubuntu repository Docker packages'
    install_apt docker.io docker-compose-v2 || install_apt docker.io docker-compose || true
  fi
  if getent group docker >/dev/null 2>&1 && [[ -n "${USER:-}" ]]; then
    run sudo usermod -aG docker "$USER" || warn 'Could not add user to docker group'
    warn 'Log out and log in again before using Docker without sudo'
  fi
}

module_zalo() {
  (( SKIP_THIRD_PARTY )) && { log 'Zalo skipped with third-party apps'; return 0; }
  log "Module: Zalo Linux ($ZALO_VARIANT variant)"
  local app_dir="${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux"
  local launcher="${XDG_BIN_HOME:-$HOME/.local/bin}/zalo-linux"
  local marker="$app_dir/.ulok-full-installed"
  local appimage="$app_dir/Zalo-x86_64.AppImage"
  local desktop_entry="${XDG_DATA_HOME:-$HOME/.local/share}/applications/zalo-linux.desktop"
  if (( ! DRY_RUN && ! UPDATE_ZALO )) && [[ -f "$marker" && -x "$launcher" && -x "$appimage" && -f "$desktop_entry" ]] && [[ "$(<"$marker")" == "$ZALO_VARIANT" ]]; then
    if cmp -s -- "$ROOT_DIR/vendor/zalo/zalo-launcher.sh" "$launcher" && \
      command -v xclip >/dev/null 2>&1 && command -v wl-paste >/dev/null 2>&1 && \
      package_installed libopus0 && package_installed pulseaudio-utils; then
      log 'Zalo AppImage, launcher và thư viện đã có; bỏ qua (dùng --update-zalo để cập nhật)'
      return 0
    fi
  fi
  # Bundled installer: there is no second Git clone or remote script download.
  local installer="$ROOT_DIR/vendor/zalo/install-zalo-linux.sh"
  if (( DRY_RUN )); then
    log "+ ZALO_VARIANT=$ZALO_VARIANT bash $installer (bundled)"
    return 0
  fi
  if [[ ! -s "$installer" ]]; then
    fail 'Thiếu installer Zalo tích hợp trong Office Kit; cập nhật repository'
    return 1
  fi
  if ! bash -n "$installer"; then
    fail 'Zalo installer có lỗi cú pháp Bash; không thực thi'
    return 1
  fi
  # Installer manages user data under HOME; do not run with sudo.
  local should_repair=0
  if [[ -x "$appimage" ]] && (( FIX_ZALO )); then should_repair=1; fi
  if [[ -x "$appimage" && -f "$marker" ]] && (( ! UPDATE_ZALO )) && [[ "$(<"$marker")" == "$ZALO_VARIANT" ]]; then should_repair=1; fi
  if (( should_repair )); then
    installer="$ROOT_DIR/vendor/zalo/zalo-repair.sh"
    if [[ ! -f "$installer" ]] || ! bash -n "$installer"; then
      fail 'Zalo repair script không hợp lệ'
      return 1
    fi
  fi
  if (( UI_VISIBLE && ! UI_VERBOSE )); then
    if ! ZALO_VARIANT="$ZALO_VARIANT" bash "$installer" >>"$LOG_PATH" 2>&1; then
      fail 'Cài Zalo Linux thất bại; xem setup.log để kiểm tra GitHub API/mirror'
      return 1
    fi
  elif ! ZALO_VARIANT="$ZALO_VARIANT" bash "$installer"; then
    fail 'Cài Zalo Linux thất bại; xem thông báo GitHub API/mirror ở phía trên'
    return 1
  fi
  if [[ ! -x "$launcher" || ! -x "$appimage" ]]; then
    fail 'Zalo installer kết thúc nhưng không có launcher; không ghi nhận đã cài thành công'
    return 1
  fi
  mkdir -p -- "$app_dir"
  if (( ! FIX_ZALO )) || [[ ! -f "$marker" ]]; then printf '%s\n' "$ZALO_VARIANT" > "$marker"; fi
  log 'PASS: Zalo Linux installer/repair completed'
}

verify() {
  log 'Verification'
  if (( DRY_RUN )); then log 'Dry-run: package verification skipped'; return 0; fi
  local item
  for item in curl git ufw; do
    if command -v "$item" >/dev/null 2>&1; then log "PASS: $item"; else warn "Thiếu hoặc chưa có lệnh: $item"; fi
  done
  if [[ "$PROFILE" == office || "$PROFILE" == desktop || "$PROFILE" == full ]]; then
    for item in flameshot thunderbird pdfarranger ffmpeg; do
      command -v "$item" >/dev/null 2>&1 && log "PASS: $item" || warn "Office app not found: $item"
    done
    if office_suite_installed wps; then log 'PASS: WPS Office'; else warn 'WPS Office chưa có (kiểm tra tải .deb/kiến trúc)'; fi
    if office_suite_installed libreoffice || office_suite_installed genoffice; then
      log 'PASS: bộ Office thứ hai đã có'
    else
      warn 'Chưa có bộ Office thứ hai (LibreOffice hoặc GenOffice)'
    fi
    if dpkg-query -W -f='${Status}' ibus-unikey fcitx5-unikey 2>/dev/null | grep -q 'install ok installed'; then
      log 'PASS: Vietnamese input package installed'
    else
      warn 'Chưa xác nhận được bộ gõ tiếng Việt'
    fi
  fi
  if [[ ( "$PROFILE" == desktop || "$PROFILE" == full ) && "$SKIP_THIRD_PARTY" == 0 ]]; then
    [[ -x "${XDG_BIN_HOME:-$HOME/.local/bin}/zalo-linux" ]] && log 'PASS: Zalo Linux launcher' || warn 'Zalo Linux launcher not found'
  fi
  if [[ "$PROFILE" == full && "$SKIP_THIRD_PARTY" == 0 ]]; then
    for item in google-chrome microsoft-edge code docker zoom; do
      command -v "$item" >/dev/null 2>&1 && log "PASS: $item" || warn "Optional app not found: $item"
    done
  fi
  if command -v dpkg >/dev/null; then
    local broken
    broken="$(dpkg --audit 2>/dev/null || true)"
    [[ -z "$broken" ]] && log 'PASS: dpkg audit sạch' || warn "dpkg còn gói cần xử lý: $broken"
  fi
}

write_report() {
  {
    echo "Universal Linux Office Kit report"
    echo "Generated: $(date -Is)"
    echo "Profile: ${PROFILE}"
    echo "Dry-run: ${DRY_RUN}"
    echo
    echo "Warnings: ${#WARNINGS[@]}"
    if (( ${#WARNINGS[@]} )); then printf ' - %s\n' "${WARNINGS[@]}"; fi
    echo "Failures: ${#FAILURES[@]}"
    if (( ${#FAILURES[@]} )); then printf ' - %s\n' "${FAILURES[@]}"; fi
    echo
    echo "Log: ${LOG_PATH}"
  } >"$REPORT_PATH"
  log "Report: $REPORT_PATH"
  if command -v python3 >/dev/null 2>&1 && [[ -f "$ROOT_DIR/report-html.py" ]]; then
    if python3 "$ROOT_DIR/report-html.py" --report "$REPORT_PATH" --output "$REPORT_HTML_PATH" --backup "$BACKUP_DIR" >>"$LOG_PATH" 2>&1; then
      log "PASS: Báo cáo dễ đọc: $REPORT_HTML_PATH"
      if (( OPEN_HTML_REPORT && ! DRY_RUN )) && [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        (
          if command -v xdg-open >/dev/null 2>&1; then
            xdg-open "$REPORT_HTML_PATH" || { command -v firefox >/dev/null 2>&1 && firefox "$REPORT_HTML_PATH"; }
          elif command -v firefox >/dev/null 2>&1; then
            firefox "$REPORT_HTML_PATH"
          fi
        ) >/dev/null 2>&1 </dev/null &
      fi
    else
      log 'WARN: Không xuất được báo cáo HTML; vẫn có báo cáo văn bản.'
    fi
  else
    log 'WARN: Chưa có Python 3 hoặc report-html.py; vẫn có báo cáo văn bản.'
  fi
}

main() {
  : >"$LOG_PATH"
  while (($#)); do
    case "$1" in
      --profile) PROFILE="${2:?Missing profile}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes) ASSUME_YES=1; shift ;;
      --no-reboot) NO_REBOOT=1; shift ;;
      --enable-ufw) ENABLE_UFW=1; shift ;;
      --skip-flatpak) SKIP_FLATPAK=1; shift ;;
      --skip-third-party) SKIP_THIRD_PARTY=1; shift ;;
      --canon-ufrii-archive) CANON_UFRII_ARCHIVE="${2:?Missing Canon archive path}"; shift 2 ;;
      --fix-unikey) FIX_UNIKEY=1; shift ;;
      --fix-flameshot) FIX_FLAMESHOT=1; shift ;;
      --fix-zalo) FIX_ZALO=1; shift ;;
      --fix-zalo-login) FIX_ZALO_LOGIN=1; shift ;;
      --update-zalo) UPDATE_ZALO=1; shift ;;
      --repair-desktop) REPAIR_DESKTOP=1; shift ;;
      --fix-office) FIX_OFFICE=1; shift ;;
      --zalo-variant) ZALO_VARIANT="${2:?Missing Zalo variant}"; shift 2 ;;
      --office-secondary) OFFICE_SECONDARY="${2:?Missing office secondary}"; shift 2 ;;
      --report) REPORT_PATH="${2:?Missing report path}"; shift 2 ;;
      --report-html) REPORT_HTML_PATH="${2:?Missing HTML report path}"; shift 2 ;;
      --no-open-report) OPEN_HTML_REPORT=0; shift ;;
      --verbose) UI_VERBOSE=1; shift ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; return 2 ;;
    esac
  done
  case "$PROFILE" in minimal|office|desktop|full) ;; *) fail "Profile không hợp lệ: $PROFILE"; return 2 ;; esac
  case "$ZALO_VARIANT" in chat|full) ;; *) fail "Zalo variant không hợp lệ: $ZALO_VARIANT"; return 2 ;; esac
  case "$OFFICE_SECONDARY" in auto|libreoffice|genoffice) ;; *) fail "Office secondary không hợp lệ: $OFFICE_SECONDARY"; return 2 ;; esac
  if [[ -z "$REPORT_HTML_PATH" ]]; then
    if [[ "$REPORT_PATH" == *.txt ]]; then REPORT_HTML_PATH="${REPORT_PATH%.txt}.html"
    else REPORT_HTML_PATH="${REPORT_PATH}.html"; fi
  fi
  if (( REPAIR_DESKTOP )); then FIX_UNIKEY=1; FIX_FLAMESHOT=1; FIX_ZALO=1; FIX_OFFICE=1; fi
  if (( FIX_ZALO_LOGIN )); then FIX_ZALO=1; UPDATE_ZALO=1; fi
  ui_init
  ui_banner
  if [[ "$PROFILE" == minimal && -n "$CANON_UFRII_ARCHIVE" ]]; then
    fail 'Canon UFR II cần profile office hoặc full'
    return 2
  fi
  require_platform || { write_report; return 1; }
  if (( FIX_UNIKEY || FIX_FLAMESHOT || FIX_ZALO || UPDATE_ZALO || FIX_OFFICE )); then
    UI_TOTAL=$((2 + FIX_UNIKEY + FIX_FLAMESHOT + FIX_OFFICE + ((FIX_ZALO || UPDATE_ZALO) ? 1 : 0) + FIX_ZALO_LOGIN))
    ui_stage 'Sao lưu cấu hình trước khi sửa'
    backup_desktop_settings || { fail 'Không sao lưu được cấu hình desktop'; write_report; return 1; }
    if (( FIX_OFFICE )); then ui_stage 'Kiểm tra Office · ưu tiên WPS, tối đa 2 bộ'; module_office_suites || fail 'Không thể kiểm tra bộ Office'; fi
    if (( FIX_UNIKEY )); then ui_stage 'Sửa bộ gõ tiếng Việt'; module_vietnamese_input || fail 'Sửa bộ gõ tiếng Việt thất bại'; fi
    if (( FIX_FLAMESHOT )); then ui_stage 'Flameshot GUI · Ctrl+Alt+S'; module_flameshot || fail 'Sửa Flameshot thất bại'; fi
    if (( FIX_ZALO || UPDATE_ZALO )); then
      ui_stage 'Zalo Linux AppImage'
      if module_zalo; then
        if (( FIX_ZALO_LOGIN )); then
          ui_stage 'Phục hồi đăng nhập Zalo an toàn'
          if (( DRY_RUN )); then
            log '+ bash vendor/zalo/zalo-login-recover.sh --dry-run'
          elif [[ -f "$ROOT_DIR/vendor/zalo/zalo-login-recover.sh" ]] && bash -n "$ROOT_DIR/vendor/zalo/zalo-login-recover.sh"; then
            bash "$ROOT_DIR/vendor/zalo/zalo-login-recover.sh" || fail 'Không thể sao lưu dữ liệu cũ để sửa lỗi QR (đảm bảo Zalo đã đóng)'
          else
            fail 'Thiếu script phục hồi đăng nhập Zalo trong Office Kit'
          fi
        fi
      else
        fail 'Sửa/cập nhật Zalo thất bại; không thay đổi dữ liệu đăng nhập'
      fi
    fi
    # A Zalo download/proxy failure must not roll back working Unikey/Flameshot
    # settings. Keep the full snapshot for a targeted rollback if ever needed.
    if ((${#FAILURES[@]})); then
      log "Partial repair: keep successful components; desktop backup at $BACKUP_DIR"
    fi
    ui_stage 'Tổng kết và ghi báo cáo'
    write_report
    ui_finish
    ((${#FAILURES[@]} == 0))
    return
  fi
  if (( ! ASSUME_YES && ! DRY_RUN )); then
    read -r -p "Tiếp tục setup profile '$PROFILE' trên máy này? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { log 'Cancelled by user'; write_report; return 0; }
  fi
  UI_TOTAL=5
  if [[ "$PROFILE" == office || "$PROFILE" == desktop || "$PROFILE" == full ]]; then ((UI_TOTAL += 5)); fi
  if [[ "$PROFILE" == desktop || "$PROFILE" == full ]]; then ((UI_TOTAL += 2)); fi
  if [[ "$PROFILE" == full ]]; then ((UI_TOTAL += 4)); fi
  ui_stage 'Kiểm tra và sửa trạng thái APT/dpkg'
  repair_package_state || true
  ui_stage 'Sao lưu cấu hình desktop'
  backup_desktop_settings || { fail 'Không sao lưu được cấu hình desktop'; write_report; return 1; }
  ui_stage 'Thư viện nền tảng và mạng'
  module_base
  if [[ "$PROFILE" == office || "$PROFILE" == desktop || "$PROFILE" == full ]]; then
    # Establish the three user-critical apps before optional Office/media installs.
    ui_stage 'UniKey · bộ gõ tiếng Việt và tự phục hồi phiên'
    module_vietnamese_input || fail 'UniKey chưa được cấu hình; tiếp tục cài các ứng dụng còn lại'
    ui_stage 'Flameshot · chụp màn hình Ctrl+Alt+S'
    module_flameshot || fail 'Flameshot chưa hoàn tất; tiếp tục cài các ứng dụng còn lại'
    if [[ "$PROFILE" == desktop || "$PROFILE" == full ]]; then
      ui_stage 'Zalo Linux · ứng dụng chat'
      module_zalo || fail 'Zalo chưa hoàn tất; tiếp tục cài các ứng dụng còn lại'
    fi
    ui_stage 'Office, font tiếng Việt và máy in'
    module_office
    ui_stage 'Video, âm thanh và PDF'
    module_media
    ui_stage 'GenOffice'
    if [[ "$OFFICE_SECONDARY" == genoffice ]] && (( $(office_suite_count) < 2 )); then
      module_genoffice
    else
      log 'GenOffice: không cài thêm mặc định để giữ tối đa 2 bộ Office.'
    fi
  fi
  if [[ "$PROFILE" == desktop || "$PROFILE" == full ]]; then
    ui_stage 'Tiện ích Windows → Ubuntu · sao lưu, ổ đĩa, chia sẻ'
    module_everyday
  fi
  if [[ "$PROFILE" == full ]]; then
    ui_stage 'Công cụ lập trình'
    module_dev
    ui_stage 'Kết nối và điều khiển từ xa'
    module_remote
    ui_stage 'Flatpak'
    module_flatpak
    ui_stage 'Ứng dụng bên thứ ba'
    module_third_party
  fi
  ui_stage 'Kiểm tra sau cài đặt'
  verify
  ui_stage 'Xuất báo cáo'
  write_report
  ui_finish
  if ((${#FAILURES[@]})); then log 'Completed with failures'; return 1; fi
  log 'Completed with PASS/WARN status'
  (( NO_REBOOT || DRY_RUN )) || log 'Reboot recommended after reviewing the report'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
