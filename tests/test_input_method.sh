#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_CONFIG_HOME="$TEMP/home/.config"
mkdir -p "$XDG_CONFIG_HOME/fcitx5" "$TEMP/bin"
printf '#!/bin/sh\nexit 0\n' > "$TEMP/bin/im-config"
printf '#!/bin/sh\nexit 0\n' > "$TEMP/bin/fcitx5-remote"
chmod +x "$TEMP/bin/"*
export PATH="$TEMP/bin:$PATH"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
package_installed() { [[ "$1" == fcitx5-unikey ]]; }
cat > "$XDG_CONFIG_HOME/fcitx5/profile" <<'EOF'
[Groups/0]
Name=Work
Default Layout=us
DefaultIM=keyboard-us
[Groups/0/Items/0]
Name=keyboard-us
Layout=
[GroupOrder]
0=Work
EOF
configure_fcitx5_unikey
grep -q 'Name=Work' "$XDG_CONFIG_HOME/fcitx5/profile"
grep -q 'Name=unikey' "$XDG_CONFIG_HOME/fcitx5/profile"
grep -q '^DefaultIM=unikey$' "$XDG_CONFIG_HOME/fcitx5/profile"
[[ "$(grep -c '^Name=unikey$' "$XDG_CONFIG_HOME/fcitx5/profile")" == 1 ]]
configure_fcitx5_unikey
[[ "$(grep -c '^Name=unikey$' "$XDG_CONFIG_HOME/fcitx5/profile")" == 1 ]]

# GNOME must pick IBus even if an older install left Fcitx5 on the machine.
export XDG_CURRENT_DESKTOP='ubuntu:GNOME'
package_installed() { [[ "$1" == fcitx5-unikey ]]; }
install_apt() { [[ " $* " == *' ibus-unikey '* ]]; }
configure_ibus_unikey() { echo ibus > "$TEMP/selected"; }
module_vietnamese_input
[[ "$(<"$TEMP/selected")" == ibus ]]
echo 'PASS: Fcitx5 profile and GNOME IBus selection'
