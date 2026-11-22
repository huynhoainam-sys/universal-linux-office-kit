#!/usr/bin/env bash
# NAMHH: restore a missing GNOME IBus Unikey input source after login.
# Never change the user's selected layout, current source or other frameworks.
set -Eeuo pipefail

desktop="${XDG_CURRENT_DESKTOP:-}"
[[ "${desktop,,}" == *gnome* ]] || exit 0
command -v gsettings >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0
[[ "$(dpkg-query -W -f='${Status}' ibus-unikey 2>/dev/null || true)" == 'install ok installed' ]] || exit 0
component="${IBUS_UNIKEY_COMPONENT:-/usr/share/ibus/component/unikey.xml}"
[[ -r "$component" ]] || exit 0

engine="$(python3 - "$component" <<'PY'
import sys
import xml.etree.ElementTree as ET
try:
    print(ET.parse(sys.argv[1]).findtext('./engines/engine/name') or '')
except (OSError, ET.ParseError):
    pass
PY
)"
[[ -n "$engine" ]] || exit 0

schema='org.gnome.desktop.input-sources'
for attempt in 1 2 3; do
  if [[ "$(gsettings writable "$schema" sources 2>/dev/null || true)" == true ]]; then
    # Apply the requested Windows-style VNI/Unicode once on first graphical
    # login. On later logins respect changes the user made in Unikey settings.
    marker="${XDG_CONFIG_HOME:-$HOME/.config}/namhh/unikey-vni-initialized"
    if [[ ! -e "$marker" ]] && \
        gsettings list-schemas 2>/dev/null | grep -qx 'org.freedesktop.ibus.engine.unikey'; then
      if gsettings set org.freedesktop.ibus.engine.unikey input-method vni && \
          gsettings set org.freedesktop.ibus.engine.unikey output-charset unicode; then
        mkdir -p -- "$(dirname -- "$marker")"
        printf '%s\n' 'vni/unicode configured on first login by NAMHH' > "$marker"
      fi
    fi
    raw="$(gsettings get "$schema" sources 2>/dev/null || true)"
    updated="$(python3 - "$raw" "$engine" <<'PY'
import ast
import sys
value = sys.argv[1].strip()
if value.startswith('@a(ss) '):
    value = value[len('@a(ss) '):]
try:
    sources = ast.literal_eval(value)
    assert isinstance(sources, list)
    assert all(isinstance(item, tuple) and len(item) == 2 and all(isinstance(field, str) for field in item) for item in sources)
except (SyntaxError, ValueError, AssertionError):
    sys.exit(0)
item = ('ibus', sys.argv[2])
if item not in sources:
    sources.append(item)
    print(repr(sources))
PY
)"
    # Empty means the correct input source already exists OR GSettings was unreadable.
    if [[ -n "$updated" ]]; then
      if gsettings set "$schema" sources "$updated"; then
        if [[ "$(gsettings writable "$schema" current 2>/dev/null || true)" == true ]]; then
          unikey_index="$(python3 - "$updated" "$engine" <<'PY'
import ast
import sys
print(ast.literal_eval(sys.argv[1]).index(('ibus', sys.argv[2])))
PY
)"
          gsettings set "$schema" current "$unikey_index" || true
        fi
        printf '%s\n' 'NAMHH: restored missing Unikey input source'
      fi
    fi
    exit 0
  fi
  sleep 2
done
exit 0
