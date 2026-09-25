#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="full"
DRY_RUN=0
ASSUME_YES=0
NO_REBOOT=0
SKIP_FLATPAK=0
SKIP_THIRD_PARTY=0
REPORT_PATH="${ROOT_DIR}/setup-report.txt"
LOG_PATH="${ROOT_DIR}/setup.log"
declare -a WARNINGS=()
declare -a FAILURES=()

usage() {
  cat <<'EOF'
Universal Linux Office Kit
Usage: ./setup.sh [options]
  --profile minimal|office|full  What to install (default: full)
  --dry-run                      Print actions without changing the system
  --yes                          Skip confirmation
  --no-reboot                    Never offer reboot
  --skip-flatpak                 Do not install Flatpak packages
  --skip-third-party             Do not install official Chrome/Edge/VS Code/Docker/Zoom
  --report PATH                  Write report to PATH
  -h, --help                     Show help
EOF
}

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a "$LOG_PATH"; }
warn() { WARNINGS+=("$*"); log "WARN: $*"; }
fail() { FAILURES+=("$*"); log "FAIL: $*"; }

run() {
  log "+ $*"
  if (( DRY_RUN )); then return 0; fi
  "$@"
}

apt_run() { run sudo apt-get "$@"; }

require_platform() {
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
  apt_run update || { fail 'apt update thất bại'; return 1; }
}

install_apt() {
  local -a packages=("$@")
  apt_run install -y --no-install-recommends "${packages[@]}" || { fail "Không cài được: ${packages[*]}"; return 1; }
}

install_deb_url() {
  local name="$1" url="$2" target="${TMPDIR:-/tmp}/${name}.deb"
  log "Downloading official package: $name"
  if (( DRY_RUN )); then
    log "+ curl -fL --retry 3 -o $target $url"
    log "+ sudo apt-get install -y $target"
    return 0
  fi
  curl -fL --retry 3 --retry-delay 2 -o "$target" "$url" || { fail "Download failed: $name"; return 1; }
  sudo apt-get install -y "$target" || { fail "Install failed: $name"; return 1; }
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
  run sudo ufw --force enable || warn 'Không bật được UFW; kiểm tra thủ công'
}

module_office() {
  log 'Module: office'
  install_apt libreoffice libreoffice-l10n-vi libreoffice-help-vi \
    hunspell-vi hyphen-vi mythes-vi evince poppler-utils \
    simple-scan cups system-config-printer || true
}

module_media() {
  log 'Module: media'
  install_apt vlc ffmpeg imagemagick gimp file libavcodec-extra fonts-noto-core \
    fonts-noto-cjk fonts-liberation || true
}

module_dev() {
  log 'Module: dev'
  install_apt build-essential pkg-config python3 python3-pip python3-venv \
    python3-dev shellcheck make tmux vim || true
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
  else
    warn "Chrome/Zoom direct .deb skipped on architecture: $arch"
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
        curl -fsSL --retry 3 https://download.docker.com/linux/ubuntu/gpg | sudo tee /etc/apt/keyrings/docker.asc >/dev/null || fail 'Docker signing key download failed'
        sudo chmod a+r /etc/apt/keyrings/docker.asc
        sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $codename
Components: stable
Architectures: $arch
Signed-By: /etc/apt/keyrings/docker.asc
EOF
        apt_run update || fail 'Docker repository update failed'
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

verify() {
  log 'Verification'
  local item
  for item in curl git libreoffice ffmpeg ufw; do
    if command -v "$item" >/dev/null 2>&1; then log "PASS: $item"; else warn "Thiếu hoặc chưa có lệnh: $item"; fi
  done
  for item in google-chrome microsoft-edge code docker zoom; do
    command -v "$item" >/dev/null 2>&1 && log "PASS: $item" || warn "Optional app not found: $item"
  done
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
    printf ' - %s\n' "${WARNINGS[@]}"
    echo "Failures: ${#FAILURES[@]}"
    printf ' - %s\n' "${FAILURES[@]}"
    echo
    echo "Log: ${LOG_PATH}"
  } >"$REPORT_PATH"
  log "Report: $REPORT_PATH"
}

main() {
  : >"$LOG_PATH"
  while (($#)); do
    case "$1" in
      --profile) PROFILE="${2:?Missing profile}"; shift 2 ;;
      --dry-run) DRY_RUN=1; shift ;;
      --yes) ASSUME_YES=1; shift ;;
      --no-reboot) NO_REBOOT=1; shift ;;
      --skip-flatpak) SKIP_FLATPAK=1; shift ;;
      --skip-third-party) SKIP_THIRD_PARTY=1; shift ;;
      --report) REPORT_PATH="${2:?Missing report path}"; shift 2 ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; return 2 ;;
    esac
  done
  case "$PROFILE" in minimal|office|full) ;; *) fail "Profile không hợp lệ: $PROFILE"; return 2 ;; esac
  require_platform || { write_report; return 1; }
  if (( ! ASSUME_YES && ! DRY_RUN )); then
    read -r -p "Tiếp tục setup profile '$PROFILE' trên máy này? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { log 'Cancelled by user'; write_report; return 0; }
  fi
  repair_package_state || true
  module_base
  if [[ "$PROFILE" == office || "$PROFILE" == full ]]; then
    module_office
    module_media
  fi
  if [[ "$PROFILE" == full ]]; then
    module_dev
    module_remote
    module_flatpak
    module_third_party
  fi
  verify
  write_report
  if ((${#FAILURES[@]})); then log 'Completed with failures'; return 1; fi
  log 'Completed with PASS/WARN status'
  (( NO_REBOOT || DRY_RUN )) || log 'Reboot recommended after reviewing the report'
}

main "$@"
