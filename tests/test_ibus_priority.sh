#!/usr/bin/env bash
# GNOME 22.04/24.04: prioritize Unikey without writing the deprecated current
# key, deleting other sources, or resetting the user's typing preference.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
mkdir -p -- "$TEMP/bin" "$TEMP/home"
export HOME="$TEMP/home" XDG_CONFIG_HOME="$TEMP/home/.config"
export XDG_CURRENT_DESKTOP='ubuntu:GNOME'
export IBUS_UNIKEY_COMPONENT="$TEMP/unikey.xml" NAMHH_TEST_STATE="$TEMP"
printf '%s\n' '<?xml version="1.0"?><component><engines><engine><name>Unikey</name></engine></engines></component>' > "$IBUS_UNIKEY_COMPONENT"
printf '%s\n' "[('xkb', 'us'), ('ibus', 'Unikey'), ('xkb', 'gb')]" > "$TEMP/sources"
printf '%s\n' "[('xkb', 'us'), ('xkb', 'gb')]" > "$TEMP/mru-sources"
cat > "$TEMP/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  writable) printf 'true\n' ;;
  get) command cat "$NAMHH_TEST_STATE/$3" ;;
  set)
    printf '%s %s %s\n' "$2" "$3" "$4" >> "$NAMHH_TEST_STATE/settings"
    case "$3" in sources|mru-sources) printf '%s\n' "$4" > "$NAMHH_TEST_STATE/$3" ;; esac ;;
esac
EOF
printf '#!/bin/sh\nexit 0\n' > "$TEMP/bin/im-config"
chmod +x "$TEMP/bin/gsettings" "$TEMP/bin/im-config"
export PATH="$TEMP/bin:$PATH"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
package_installed() { [[ "$1" == ibus-unikey ]]; }
desktop_is_gnome() { return 0; }
install_unikey_session_guard() { :; }

configure_ibus_unikey
[[ "$(<"$TEMP/sources")" == "[('ibus', 'Unikey'), ('xkb', 'us'), ('xkb', 'gb')]" ]]
[[ "$(<"$TEMP/mru-sources")" == "[('ibus', 'Unikey'), ('xkb', 'us'), ('xkb', 'gb')]" ]]
! grep -Eq ' current | input-method | output-charset ' "$TEMP/settings"

# Second run is idempotent: neither source order nor typing config changes.
before="$(wc -l < "$TEMP/settings")"
configure_ibus_unikey
[[ "$(wc -l < "$TEMP/settings")" == "$before" ]]

# Malformed GVariant is left untouched to avoid destroying the source list.
printf '%s\n' 'broken GVariant' > "$TEMP/sources"
configure_ibus_unikey
[[ "$(<"$TEMP/sources")" == 'broken GVariant' ]]
[[ "$(wc -l < "$TEMP/settings")" == "$before" ]]
echo 'PASS: GNOME prioritizes Unikey, preserves other sources and typing preferences'
