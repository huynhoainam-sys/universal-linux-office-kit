#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_DATA_HOME="$TEMP/home/.local/share" XDG_BIN_HOME="$TEMP/home/.local/bin"
mkdir -p "$XDG_DATA_HOME/zalo-linux" "$XDG_DATA_HOME/applications" "$XDG_BIN_HOME" "$TEMP/bin"
cp "$ROOT/vendor/zalo/zalo-launcher.sh" "$XDG_BIN_HOME/zalo-linux"
chmod +x "$XDG_BIN_HOME/zalo-linux"
printf 'chat\n' > "$XDG_DATA_HOME/zalo-linux/.ulok-full-installed"
printf '#!/usr/bin/env bash\nexit 0\n' > "$XDG_DATA_HOME/zalo-linux/Zalo-x86_64.AppImage"
chmod +x "$XDG_DATA_HOME/zalo-linux/Zalo-x86_64.AppImage"
printf '[Desktop Entry]\nName=Zalo Linux\n' > "$XDG_DATA_HOME/applications/zalo-linux.desktop"
for app in xclip wl-paste; do printf '#!/usr/bin/env bash\nexit 0\n' > "$TEMP/bin/$app"; chmod +x "$TEMP/bin/$app"; done
export PATH="$TEMP/bin:$PATH"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
FIX_ZALO=1
package_installed() { [[ "$1" == libopus0 || "$1" == pulseaudio-utils ]]; }
module_zalo
grep -q 'bỏ qua' "$LOG_PATH"
echo 'PASS: Zalo bundle skips already compatible AppImage, launcher and dependencies'
