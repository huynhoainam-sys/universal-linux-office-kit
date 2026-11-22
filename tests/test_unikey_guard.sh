#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
mkdir -p -- "$TEMP/bin" "$TEMP/config"
export XDG_CONFIG_HOME="$TEMP/config" XDG_CURRENT_DESKTOP='ubuntu:GNOME'
export IBUS_UNIKEY_COMPONENT="$TEMP/unikey.xml" NAMHH_TEST_STATE="$TEMP"
export PATH="$TEMP/bin:$PATH"
printf '%s\n' '[('\''xkb'\'', '\''us'\'')]' > "$TEMP/sources"
printf '%s\n' '[('\''xkb'\'', '\''us'\'')]' > "$TEMP/mru-sources"
printf '%s\n' '<?xml version="1.0"?><component><engines><engine><name>Unikey</name></engine></engines></component>' > "$TEMP/unikey.xml"
cat > "$TEMP/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
printf '%s' 'install ok installed'
EOF
cat > "$TEMP/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  writable) printf '%s\n' true ;;
  list-schemas) printf '%s\n' org.freedesktop.ibus.engine.unikey ;;
  get)
    if [[ "$3" == sources || "$3" == mru-sources ]]; then
      if [[ -f "$NAMHH_TEST_STATE/get-fail-once" ]]; then
        rm -f "$NAMHH_TEST_STATE/get-fail-once"
        exit 1
      fi
      if [[ -f "$NAMHH_TEST_STATE/invalid" ]]; then printf '%s\n' 'broken GVariant'
      else command cat "$NAMHH_TEST_STATE/$3"; fi
    fi ;;
  set)
    printf '%s %s %s\n' "$2" "$3" "$4" >> "$NAMHH_TEST_STATE/settings"
    if [[ "$3" == sources || "$3" == mru-sources ]]; then printf '%s\n' "$4" > "$NAMHH_TEST_STATE/$3"; fi ;;
esac
EOF
chmod +x "$TEMP/bin/dpkg-query" "$TEMP/bin/gsettings"

bash "$ROOT/scripts/unikey-session-guard.sh"
[[ "$(<"$TEMP/sources")" == "[('ibus', 'Unikey'), ('xkb', 'us')]" ]]
[[ "$(<"$TEMP/mru-sources")" == "[('ibus', 'Unikey'), ('xkb', 'us')]" ]]
! grep -Eq ' input-method | output-charset | current ' "$TEMP/settings"

# Subsequent logins retain users' selection and never duplicate Unikey.
before="$(wc -l < "$TEMP/settings")"
printf '%s\n' "[('xkb', 'us'), ('ibus', 'Unikey')]" > "$TEMP/mru-sources"
bash "$ROOT/scripts/unikey-session-guard.sh"
[[ "$(wc -l < "$TEMP/settings")" == "$before" ]]
[[ "$(<"$TEMP/mru-sources")" == "[('xkb', 'us'), ('ibus', 'Unikey')]" ]]

# Autostart can beat the DBus settings service; retry a temporary read failure.
printf '%s\n' "[('xkb', 'us')]" > "$TEMP/sources"
touch "$TEMP/get-fail-once"
bash "$ROOT/scripts/unikey-session-guard.sh"
[[ "$(<"$TEMP/sources")" == "[('ibus', 'Unikey'), ('xkb', 'us')]" ]]
before="$(wc -l < "$TEMP/settings")"

# A broken/empty GNOME Input Sources value must not be overwritten.
printf '%s\n' "[('xkb', 'us')]" > "$TEMP/sources"
touch "$TEMP/invalid"
bash "$ROOT/scripts/unikey-session-guard.sh"
[[ "$(<"$TEMP/sources")" == "[('xkb', 'us')]" ]]
[[ "$(wc -l < "$TEMP/settings")" == "$before" ]]

# Cinnamon/Mint must not get GNOME-only settings from the guard.
rm -f "$TEMP/invalid"
export XDG_CURRENT_DESKTOP='X-Cinnamon'
bash "$ROOT/scripts/unikey-session-guard.sh"
[[ "$(wc -l < "$TEMP/settings")" == "$before" ]]
echo 'PASS: Unikey guard restores priority only when missing, preserves typing method and user choices'
