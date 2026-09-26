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
[[ "$(grep -c '^Name=unikey$' "$XDG_CONFIG_HOME/fcitx5/profile")" == 1 ]]
configure_fcitx5_unikey
[[ "$(grep -c '^Name=unikey$' "$XDG_CONFIG_HOME/fcitx5/profile")" == 1 ]]
echo 'PASS: Fcitx5 profile preserved and Unikey added once'
