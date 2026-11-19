#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -rf -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_CONFIG_HOME="$TEMP/home/.config" XDG_BIN_HOME="$TEMP/home/.local/bin"
export XDG_CURRENT_DESKTOP='ubuntu:GNOME' XDG_SESSION_TYPE='wayland'
export GS_STATE="$TEMP/gsettings-value" GS_LOG="$TEMP/gsettings-log"
mkdir -p "$TEMP/bin" "$HOME"
printf '%s\n' "['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/existing/']" > "$GS_STATE"
printf '#!/usr/bin/env bash\nexit 0\n' > "$TEMP/bin/flameshot"
cat > "$TEMP/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  get) cat "$GS_STATE" ;;
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
grep -q 'ulok-flameshot' "$GS_LOG"
echo 'PASS: Flameshot Wayland launcher, autostart and non-destructive shortcut'
