#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
package_installed() { [[ "$1" == ibus || "$1" == libopus0 ]]; }
apt_run() { printf '%s\n' "$*" >> "$TEMP/apt-called"; }
install_apt ibus libopus0
[[ ! -e "$TEMP/apt-called" ]]
install_apt ibus ibus-unikey libopus0 pulseaudio-utils
[[ "$(<"$TEMP/apt-called")" == 'install -y --no-install-recommends ibus-unikey pulseaudio-utils' ]]
echo 'PASS: installed dependencies skipped; only missing packages requested'
