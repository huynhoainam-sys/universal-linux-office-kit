#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "$0")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_CONFIG_HOME="$TEMP/home/.config" XDG_BIN_HOME="$TEMP/home/.local/bin"
export XDG_CURRENT_DESKTOP='ubuntu:GNOME' XDG_SESSION_TYPE='wayland'
mkdir -p "$TEMP/bin" "$HOME"
cat > "$TEMP/bin/flameshot" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$TEMP/bin/python3" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$HOTKEY_TEST_CALLS"
EOF
chmod +x "$TEMP/bin/"*
export PATH="$TEMP/bin:$PATH" HOTKEY_TEST_CALLS="$TEMP/hotkey-calls"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
configure_flameshot_shortcut
configure_flameshot_shortcut
[[ -x "$XDG_BIN_HOME/ulok-flameshot" ]]
grep -q 'QT_QPA_PLATFORM=wayland' "$XDG_BIN_HOME/ulok-flameshot"
grep -q 'X-ULOK-Managed=true' "$XDG_CONFIG_HOME/autostart/ulok-flameshot.desktop"
grep -q -- 'flameshot-hotkey.py --launcher' "$HOTKEY_TEST_CALLS"
package_installed() { return 1; }
install_apt() { return 1; }
if module_flameshot; then
  echo 'FAIL: missing APT package incorrectly accepted' >&2
  exit 1
fi
echo 'PASS: Flameshot launcher and shortcut repair delegation'
