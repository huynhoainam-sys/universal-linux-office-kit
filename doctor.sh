#!/usr/bin/env bash
set -Eeuo pipefail

# Read-only health check. Run after setup, or any time to inspect this machine.
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPORT="${1:-$ROOT_DIR/doctor-report.txt}"
mkdir -p -- "$(dirname -- "$REPORT")"

status() {
  local label="$1" state="$2" detail="${3:-}"
  printf '%-24s %-10s %s\n' "$label" "$state" "$detail"
}
has_package() {
  [[ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" == 'install ok installed' ]]
}
has_command() { command -v "$1" >/dev/null 2>&1; }

{
  printf 'Universal Linux Office Kit — System Doctor\nDate: %s\n' "$(date -Is)"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    status 'OS' INFO "${PRETTY_NAME:-unknown}"
  fi
  status 'Desktop' INFO "${XDG_CURRENT_DESKTOP:-unknown} (${XDG_SESSION_TYPE:-unknown})"
  status 'Disk free' INFO "$(df -h / | awk 'NR==2 {print $4}')"
  if [[ -z "$(dpkg --audit 2>/dev/null || true)" ]]; then
    status 'Package state' PASS 'dpkg audit clean'
  else
    status 'Package state' WARN 'run sudo dpkg --configure -a'
  fi
  for app in libreoffice wps flameshot thunderbird pdfarranger ffmpeg; do
    if has_command "$app"; then status "$app" PASS "$(command -v "$app")";
    else status "$app" WARN 'not found'; fi
  done
  if has_package genoffice || has_command genoffice; then
    status 'GenOffice' PASS 'installed'
  else
    status 'GenOffice' OPTIONAL 'office/full profile; amd64 and glibc 2.34+'
  fi
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    if has_package ibus-unikey; then
      status 'Vietnamese input' PASS 'IBus Unikey installed (GNOME)'
      if has_command gsettings && gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -qi 'unikey'; then
        status 'Unikey source' PASS 'GNOME Input Sources configured'
      else
        status 'Unikey source' WARN 'run ./setup.sh --fix-unikey'
      fi
    else
      status 'Vietnamese input' WARN 'GNOME needs ibus-unikey; run ./setup.sh --fix-unikey'
    fi
  elif has_package fcitx5-unikey; then
    status 'Vietnamese input' PASS 'Fcitx5 Unikey installed'
    if grep -qx 'Name=unikey' "${XDG_CONFIG_HOME:-$HOME/.config}/fcitx5/profile" 2>/dev/null; then
      status 'Unikey profile' PASS 'Fcitx5 engine configured'
    else
      status 'Unikey profile' WARN 'run ./setup.sh --fix-unikey'
    fi
  elif has_package ibus-unikey; then
    status 'Vietnamese input' PASS 'IBus Unikey installed'
    if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && has_command gsettings; then
      if gsettings get org.gnome.desktop.input-sources sources 2>/dev/null | grep -qi 'unikey'; then
        status 'Unikey source' PASS 'GNOME Input Sources configured'
      else
        status 'Unikey source' WARN 'run ./setup.sh --fix-unikey'
      fi
    fi
  else
    status 'Vietnamese input' WARN 'Unikey package not installed'
  fi
  if has_command flameshot; then
    if [[ -x "${XDG_BIN_HOME:-$HOME/.local/bin}/ulok-flameshot" ]]; then
      status 'Flameshot launcher' PASS 'user shortcut helper installed'
    else
      status 'Flameshot launcher' WARN 'run ./setup.sh --fix-flameshot'
    fi
    if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
      if has_package xdg-desktop-portal-gnome || has_package xdg-desktop-portal-kde; then
        status 'Screenshot portal' PASS 'Wayland portal backend installed'
      else
        status 'Screenshot portal' WARN 'missing Wayland portal backend'
      fi
      status 'Flameshot Wayland' INFO 'the desktop may prompt for screenshot permission'
    fi
    desktop="${XDG_CURRENT_DESKTOP:-}"
    if [[ "${desktop,,}" == *gnome* ]] && has_command gsettings; then
      shortcut_ok=0
      for shortcut_path in \
        '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/namhh-flameshot/' \
        '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/'; do
        shortcut_schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$shortcut_path"
        if [[ "$(gsettings get "$shortcut_schema" binding 2>/dev/null)" == "'<Primary><Alt>s'" ]] && \
          [[ "$(gsettings get "$shortcut_schema" command 2>/dev/null)" == *ulok-flameshot* ]]; then
          shortcut_ok=1
          break
        fi
      done
      if (( shortcut_ok )); then
        status 'Ctrl+Alt+S' PASS 'Flameshot custom shortcut configured'
      else
        status 'Ctrl+Alt+S' WARN 'run ./setup.sh --fix-flameshot'
      fi
    fi
    if has_command pgrep && pgrep -u "$(id -u)" -x flameshot >/dev/null 2>&1; then
      status 'Flameshot process' PASS 'running'
    else
      status 'Flameshot process' INFO 'not running (start from app menu or shortcut)'
    fi
  fi
  for pkg in cups cifs-utils openvpn; do
    if has_package "$pkg"; then status "$pkg" PASS 'installed';
    else status "$pkg" WARN 'not installed'; fi
  done
  if has_package rustdesk && has_command rustdesk; then
    status 'RustDesk' PASS 'installed via .deb (test interactive remote session)'
  elif has_command rustdesk; then
    status 'RustDesk' WARN 'binary available but .deb package not detected'
  else
    status 'RustDesk' OPTIONAL 'run ./setup.sh --install-rustdesk --yes'
  fi
  if [[ -x "${XDG_BIN_HOME:-$HOME/.local/bin}/zalo-linux" ]]; then
    if [[ -x "${XDG_DATA_HOME:-$HOME/.local/share}/zalo-linux/Zalo-x86_64.AppImage" ]]; then
      status 'Zalo Linux' PASS 'launcher and AppImage exist; open GUI to test'
    else
      status 'Zalo Linux' WARN 'launcher exists but AppImage is missing; run --fix-zalo'
    fi
  else
    status 'Zalo Linux' OPTIONAL 'full profile / third-party app'
  fi
  if [[ -x "${XDG_BIN_HOME:-$HOME/.local/bin}/ulok-outlook-web" ]] && \
    [[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/applications/namhh-outlook-web.desktop" ]]; then
    status 'Outlook Web' PASS 'launcher ready; login in your browser'
  else
    status 'Outlook Web' OPTIONAL 'run ./setup.sh --fix-outlook'
  fi
  if has_package cnrdrvcups-ufr2lt-uk || has_package cnrdrvcups-ufr2lt-us; then
    status 'Canon UFRII LT' PASS 'driver for LBP6230/6240 available; verify CUPS queue model'
  elif has_package cnrdrvcups-ufr2 || has_package cnrdrvcups-ufr2-uk || has_package cnrdrvcups-ufr2-us; then
    status 'Canon UFR II' PASS 'generic UFR II installed; LBP6230/6240 needs UFRII LT'
  else
    status 'Canon UFRII LT' OPTIONAL 'LBP6230/6240: download official v5.10 archive'
  fi
  if has_command lpstat; then
    lpstat -p -d 2>/dev/null || status 'Printer queue' INFO 'not configured'
    while IFS= read -r printer_line; do
      [[ "$printer_line" == 'device for '*': '* ]] || continue
      printer_name="${printer_line#device for }"
      printer_name="${printer_name%%:*}"
      [[ "$printer_name" =~ ^LBP6230[-_]6240([-_][0-9]+)?$ ]] || continue
      printer_ppd="/etc/cups/ppd/${printer_name}.ppd"
      if [[ -r "$printer_ppd" ]] && grep -Eqi '^\*NickName:.*HP Designjet' "$printer_ppd"; then
        status 'Canon LBP6230/6240' WARN "$printer_name uses HP Designjet; bash scripts/fix-canon-lbp6230.sh"
      fi
    done < <(lpstat -v 2>/dev/null || true)
  fi
} | tee "$REPORT"

printf 'Report: %s\n' "$REPORT"
