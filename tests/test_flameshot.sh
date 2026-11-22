#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_CONFIG_HOME="$TEMP/home/.config" XDG_BIN_HOME="$TEMP/home/.local/bin"
export XDG_CURRENT_DESKTOP='ubuntu:GNOME' XDG_SESSION_TYPE='wayland'
export GS_STATE="$TEMP/gsettings-value" GS_LOG="$TEMP/gsettings-log"
mkdir -p "$TEMP/bin" "$HOME"
printf '%s\n' "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/existing/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/']" > "$GS_STATE"
export GS_OLD_COMMAND="'another-screenshot-tool'"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEMP/bin/flameshot"
cat > "$TEMP/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  get)
    if [[ "$3" == custom-keybindings ]]; then cat "$GS_STATE"
    elif [[ "$3" == command ]]; then
      if [[ "$2" == */flameshot/ ]]; then printf '%s\n' "$GS_OLD_COMMAND"
      else printf '%s\n' "'${XDG_BIN_HOME}/ulok-flameshot'"; fi
    fi ;;
  set)
    printf '%s\n' "$*" >> "$GS_LOG"
    if [[ "$2" == org.gnome.settings-daemon.plugins.media-keys && "$3" == custom-keybindings ]]; then
      printf '%s\n' "$4" > "$GS_STATE"
    fi
    ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$TEMP/bin/"*
export PATH="$TEMP/bin:$PATH"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
configure_flameshot_shortcut
configure_flameshot_shortcut
[[ -x "$XDG_BIN_HOME/ulok-flameshot" ]]
grep -q 'QT_QPA_PLATFORM=wayland' "$XDG_BIN_HOME/ulok-flameshot"
grep -q 'X-ULOK-Managed=true' "$XDG_CONFIG_HOME/autostart/ulok-flameshot.desktop"
grep -q 'existing/' "$GS_STATE"
[[ "$(grep -o 'custom-keybindings/flameshot/' "$GS_STATE" | wc -l)" == 1 ]]
[[ "$(grep -o 'custom-keybindings/namhh-flameshot/' "$GS_STATE" | wc -l)" == 1 ]]
! grep -q 'custom-keybindings/flameshot/ name ' "$GS_LOG"
grep -q 'ulok-flameshot' "$GS_LOG"
grep -q '<Primary><Shift>s' "$GS_LOG"

# Existing Office Kit installations keep using their original managed path.
export GS_OLD_COMMAND="'${XDG_BIN_HOME}/ulok-flameshot'"
printf '%s\n' "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/flameshot/']" > "$GS_STATE"
: > "$GS_LOG"
configure_flameshot_shortcut
! grep -q 'custom-keybindings/namhh-flameshot/' "$GS_STATE"
grep -q 'custom-keybindings/flameshot/ binding <Primary><Shift>s' "$GS_LOG"

package_installed() { return 1; }
install_apt() { return 1; }
if module_flameshot; then
  echo 'FAIL: missing APT package incorrectly accepted' >&2
  exit 1
fi
echo 'PASS: Flameshot Wayland launcher, autostart and non-destructive shortcut'
