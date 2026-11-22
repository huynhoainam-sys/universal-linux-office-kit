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
    if [[ "$3" == sources ]]; then
      if [[ -f "$NAMHH_TEST_STATE/invalid" ]]; then printf '%s\n' 'broken GVariant'
      else command cat "$NAMHH_TEST_STATE/sources"; fi
    fi ;;
  set)
    printf '%s %s %s\n' "$2" "$3" "$4" >> "$NAMHH_TEST_STATE/settings"
    if [[ "$3" == sources ]]; then printf '%s\n' "$4" > "$NAMHH_TEST_STATE/sources"; fi ;;
esac
EOF
chmod +x "$TEMP/bin/dpkg-query" "$TEMP/bin/gsettings"

bash "$ROOT/scripts/unikey-session-guard.sh"
grep -q "('ibus', 'Unikey')" "$TEMP/sources"
grep -q 'input-method vni' "$TEMP/settings"
grep -q 'output-charset unicode' "$TEMP/settings"
grep -q 'current 1' "$TEMP/settings"
[[ -s "$XDG_CONFIG_HOME/namhh/unikey-vni-initialized" ]]

# Subsequent logins retain users' changes and never duplicate Unikey.
before="$(wc -l < "$TEMP/settings")"
bash "$ROOT/scripts/unikey-session-guard.sh"
[[ "$(wc -l < "$TEMP/settings")" == "$before" ]]

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
echo 'PASS: Unikey session guard recovers lost source, selects VNI/Unicode once and preserves user settings'
