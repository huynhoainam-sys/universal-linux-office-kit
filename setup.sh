#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROFILE="full"
DRY_RUN=0
ASSUME_YES=0
NO_REBOOT=0
SKIP_FLATPAK=0
SKIP_THIRD_PARTY=0
CANON_UFRII_ARCHIVE=''
FIX_UNIKEY=0
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
  --skip-third-party             Do not install GenOffice/Chrome/Edge/VS Code/Docker/Zoom/Zalo
  --canon-ufrii-archive PATH     Install Canon UFR II from official downloaded .tar.gz
  --fix-unikey                  Repair only the Vietnamese input method for this user
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
  apt_run update || { fail 'apt update thất bại'; return 1; }
}

install_apt() {
  local -a packages=("$@")
  apt_run install -y --no-install-recommends "${packages[@]}" || { fail "Không cài được: ${packages[*]}"; return 1; }
}

package_installed() {
  [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" == 'install ok installed' ]]
}

install_deb_url() {
  local name="$1" url="$2" target="${TMPDIR:-/tmp}/${name}.deb"
  if (( ! DRY_RUN )) && package_installed "$name"; then
    log "Already installed: $name; skipping download"
    return 0
  fi
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
  install_apt xdg-utils cifs-utils smbclient gvfs-backends \
    openvpn network-manager-openvpn network-manager-openvpn-gnome || true
}

module_office() {
  log 'Module: office'
  install_apt libreoffice libreoffice-l10n-vi libreoffice-help-vi \
    hunspell-vi hyphen-vi mythes-vi evince poppler-utils \
    simple-scan cups system-config-printer || true
  install_apt libreoffice-gtk3 thunderbird pdfarranger || true
  install_apt fonts-crosextra-carlito fonts-crosextra-caladea \
    fonts-liberation2 fonts-noto-color-emoji || true
  configure_office_fonts
  module_vietnamese_input
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
  arch="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
  [[ "$arch" == amd64 ]] || { warn "GenOffice requires amd64; skipped on $arch"; return 0; }
  glibc_version="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}')"
  if [[ -z "$glibc_version" ]] || ! dpkg --compare-versions "$glibc_version" ge 2.34; then
    warn "GenOffice requires glibc 2.34 or newer; found ${glibc_version:-unknown}"
    return 0
  fi
  release_url='https://api.github.com/repos/genspark-ai/genoffice/releases/latest'
  if (( DRY_RUN )); then
    log "+ get latest GenOffice release from $release_url; verify amd64 .deb; sudo apt-get install -y ./genoffice_<version>_amd64.deb"
    return 0
  fi
  command -v jq >/dev/null || { warn 'GenOffice requires jq to inspect release metadata'; return 0; }
  dir="$(mktemp -d)" || { warn 'Could not create GenOffice temporary directory'; return 0; }
  metadata="$dir/release.json"
  deb="$dir/genoffice_amd64.deb"
  if ! curl -fsSL --retry 3 "$release_url" -o "$metadata"; then
    rm -rf -- "$dir"
    warn 'Could not read GenOffice release metadata'
    return 0
  fi
  asset_url="$(jq -er '[.assets[] | select(.name | test("^genoffice_[^/]+_amd64[.]deb$"))] | if length == 1 then .[0].browser_download_url else empty end' "$metadata" 2>/dev/null)" || {
    rm -rf -- "$dir"
    warn 'Latest GenOffice release does not have exactly one amd64 .deb asset'
    return 0
  }
  [[ "$asset_url" == https://github.com/genspark-ai/genoffice/releases/download/* ]] || {
    rm -rf -- "$dir"
    warn 'GenOffice asset URL is not from the official GitHub repository'
    return 0
  }
  digest="$(jq -r --arg url "$asset_url" '.assets[] | select(.browser_download_url == $url) | .digest // empty' "$metadata")"
  if ! curl -fL --retry 3 --retry-delay 2 "$asset_url" -o "$deb"; then
    rm -rf -- "$dir"
    warn 'GenOffice download failed'
    return 0
  fi
  if [[ "$digest" == sha256:* ]] && [[ "${digest#sha256:}" != "$(sha256sum "$deb" | awk '{print $1}')" ]]; then
    rm -rf -- "$dir"
    warn 'GenOffice SHA-256 does not match release metadata'
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
  if (( ! DRY_RUN )); then
    if package_installed fcitx5-unikey; then
      log 'Fcitx5 Unikey already installed; keeping the existing input method'
      configure_fcitx5_unikey
      return 0
    fi
    if package_installed ibus-unikey; then
      log 'IBus Unikey already installed; keeping the existing input method'
      configure_ibus_unikey
      return 0
    fi
  fi
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *Cinnamon* || "${ID:-}" == linuxmint && "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
    install_apt fcitx5 fcitx5-unikey fcitx5-config-qt im-config || true
    configure_fcitx5_unikey
  else
    install_apt ibus ibus-unikey im-config || true
    configure_ibus_unikey
  fi
}

configure_fcitx5_unikey() {
  if (( DRY_RUN )); then log '+ select Fcitx5 and add Unikey to user profile'; return 0; fi
  package_installed fcitx5-unikey || { warn 'Fcitx5 Unikey chưa cài được'; return 0; }
  if command -v im-config >/dev/null; then
    im-config -n fcitx5 >/dev/null 2>&1 || warn 'Không chọn được Fcitx5 qua im-config'
  fi
  local profile="${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile" index
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
  elif ! grep -qx 'Name=unikey' "$profile"; then
    if ! grep -q '^\[Groups/0\]' "$profile"; then
      warn "Profile Fcitx5 có cấu trúc khác; hãy thêm Unikey bằng fcitx5-configtool: $profile"
      return 0
    fi
    cp -p -- "$profile" "${profile}.bak-ulok-$(date +%Y%m%d-%H%M%S)"
    index="$(sed -n 's/^\[Groups\/0\/Items\/\([0-9][0-9]*\)\]$/\1/p' "$profile" | sort -n | tail -1)"
    index="$((${index:-0} + 1))"
    printf '\n[Groups/0/Items/%s]\nName=unikey\nLayout=\n' "$index" >> "$profile"
  fi
  command -v fcitx5-remote >/dev/null && fcitx5-remote -r >/dev/null 2>&1 || true
  log 'Fcitx5 Unikey configured; log out and back in to apply session environment'
}

configure_ibus_unikey() {
  if (( DRY_RUN )); then log '+ check IBus Unikey engine'; return 0; fi
  package_installed ibus-unikey || { warn 'IBus Unikey chưa cài được'; return 0; }
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
    return 0
  fi
  log "IBus Unikey engine available: $engine"
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && command -v gsettings >/dev/null; then
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
      else
        warn 'Không đọc được Input Sources; thêm Unikey trong Settings > Keyboard'
      fi
    fi
  fi
  log 'Chọn Unikey trong Input Sources; có thể cần đăng xuất/đăng nhập một lần'
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
  install_apt vlc ffmpeg imagemagick gimp file libavcodec-extra fonts-noto-core \
    fonts-noto-cjk fonts-liberation || true
  install_apt flameshot || true
  configure_flameshot_shortcut
}

configure_flameshot_shortcut() {
  log 'Configuring Flameshot shortcut: Ctrl+Shift+S'
  if (( DRY_RUN )); then
    log '+ set GNOME custom keybinding Ctrl+Shift+S to flameshot gui'
    return 0
  fi
  command -v flameshot >/dev/null || { warn 'Flameshot chưa cài; bỏ qua phím tắt'; return 0; }
  command -v gsettings >/dev/null || { warn 'Không có gsettings; hãy tạo phím tắt Flameshot thủ công'; return 0; }
  if [[ "${XDG_CURRENT_DESKTOP:-}" != *GNOME* ]]; then
    warn 'Phím tắt tự động hiện hỗ trợ GNOME; hãy tạo Ctrl+Shift+S → flameshot gui trong Keyboard Shortcuts'
    return 0
  fi
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
    gsettings set "$key_schema:$path" command 'flameshot gui' && \
    gsettings set "$key_schema:$path" binding '<Primary><Shift>s' || warn 'Không gán được Ctrl+Shift+S cho Flameshot'
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
    # Current official WPS Linux Deb URL, discovered from the vendor's Linux page.
    # Update this single value when WPS publishes a new build.
    install_deb_url wps-office https://wdl1.pcfg.cache.wpscdn.com/wpsdl/wpsoffice/download/linux/11723/wps-office_11.1.0.11723.XA_amd64.deb || true
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
  log 'Module: Zalo Linux (full variant)'
  local marker="${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux/.ulok-full-installed"
  if (( ! DRY_RUN )) && [[ -f "$marker" && -x "${XDG_BIN_HOME:-$HOME/.local/bin}/zalo-linux" ]]; then
    log 'Zalo Linux full already installed by this kit; skipping duplicate installer'
    return 0
  fi
  local url='https://raw.githubusercontent.com/huynhoainam-sys/zalo-linux-chat-kit/main/install-zalo-linux.sh'
  local script
  if (( DRY_RUN )); then
    log "+ curl -fsSL $url (fallback: wget -qO-) to a temporary file; ZALO_VARIANT=full bash"
    return 0
  fi
  script="$(mktemp)" || { fail 'Không tạo được file tạm cho Zalo'; return 1; }
  if ! { command -v curl >/dev/null && curl -fsSL "$url" -o "$script"; } && \
     ! { command -v wget >/dev/null && wget -qO "$script" "$url"; }; then
    rm -f -- "$script"
    fail 'Không tải được installer Zalo bằng curl hoặc wget'
    return 1
  fi
  [[ -s "$script" ]] || { rm -f -- "$script"; fail 'Installer Zalo tải về rỗng'; return 1; }
  # Installer writes to the invoking user's home directory; never run it with sudo.
  if ! ZALO_VARIANT=full bash "$script"; then
    rm -f -- "$script"
    fail 'Cài Zalo Linux thất bại'
    return 1
  fi
  rm -f -- "$script"
  printf 'full\n' > "$marker"
  log 'PASS: Zalo Linux installer completed'
}

verify() {
  log 'Verification'
  if (( DRY_RUN )); then log 'Dry-run: package verification skipped'; return 0; fi
  local item
  for item in curl git ufw; do
    if command -v "$item" >/dev/null 2>&1; then log "PASS: $item"; else warn "Thiếu hoặc chưa có lệnh: $item"; fi
  done
  if [[ "$PROFILE" == office || "$PROFILE" == full ]]; then
    for item in flameshot thunderbird pdfarranger libreoffice ffmpeg; do
      command -v "$item" >/dev/null 2>&1 && log "PASS: $item" || warn "Office app not found: $item"
    done
    if (( ! SKIP_THIRD_PARTY )); then
      package_installed genoffice && log 'PASS: GenOffice' || warn 'Optional app not found: GenOffice'
    fi
    if dpkg-query -W -f='${Status}' ibus-unikey fcitx5-unikey 2>/dev/null | grep -q 'install ok installed'; then
      log 'PASS: Vietnamese input package installed'
    else
      warn 'Chưa xác nhận được bộ gõ tiếng Việt'
    fi
  fi
  if [[ "$PROFILE" == full && "$SKIP_THIRD_PARTY" == 0 ]]; then
    for item in google-chrome microsoft-edge code docker zoom wps; do
      command -v "$item" >/dev/null 2>&1 && log "PASS: $item" || warn "Optional app not found: $item"
    done
    [[ -x "${XDG_BIN_HOME:-$HOME/.local/bin}/zalo-linux" ]] && log 'PASS: Zalo Linux launcher' || warn 'Zalo Linux launcher not found'
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
      --canon-ufrii-archive) CANON_UFRII_ARCHIVE="${2:?Missing Canon archive path}"; shift 2 ;;
      --fix-unikey) FIX_UNIKEY=1; shift ;;
      --report) REPORT_PATH="${2:?Missing report path}"; shift 2 ;;
      -h|--help) usage; return 0 ;;
      *) usage >&2; return 2 ;;
    esac
  done
  case "$PROFILE" in minimal|office|full) ;; *) fail "Profile không hợp lệ: $PROFILE"; return 2 ;; esac
  if [[ "$PROFILE" == minimal && -n "$CANON_UFRII_ARCHIVE" ]]; then
    fail 'Canon UFR II cần profile office hoặc full'
    return 2
  fi
  require_platform || { write_report; return 1; }
  if (( FIX_UNIKEY )); then
    module_vietnamese_input
    write_report
    ((${#FAILURES[@]} == 0))
    return
  fi
  if (( ! ASSUME_YES && ! DRY_RUN )); then
    read -r -p "Tiếp tục setup profile '$PROFILE' trên máy này? [y/N] " answer
    [[ "$answer" =~ ^[Yy]$ ]] || { log 'Cancelled by user'; write_report; return 0; }
  fi
  repair_package_state || true
  module_base
  if [[ "$PROFILE" == office || "$PROFILE" == full ]]; then
    module_office
    module_media
    module_genoffice
  fi
  if [[ "$PROFILE" == full ]]; then
    module_dev
    module_remote
    module_flatpak
    module_third_party
    module_zalo || true
  fi
  verify
  write_report
  if ((${#FAILURES[@]})); then log 'Completed with failures'; return 1; fi
  log 'Completed with PASS/WARN status'
  (( NO_REBOOT || DRY_RUN )) || log 'Reboot recommended after reviewing the report'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  main "$@"
fi
