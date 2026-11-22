#!/usr/bin/env bash
# NAMHH: restore a missing GNOME IBus Unikey input source after login.
# Restore the initial Unikey preference only if GNOME lost the source.
# Never change Telex/VNI settings, other layouts or a working selection.
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
    print(repr([item] + sources))
PY
)"
    # Empty means the correct input source already exists OR GSettings was unreadable.
    if [[ -n "$updated" ]]; then
      if gsettings set "$schema" sources "$updated"; then
        if [[ "$(gsettings writable "$schema" mru-sources 2>/dev/null || true)" == true ]]; then
          recent="$(gsettings get "$schema" mru-sources 2>/dev/null || true)"
          preferred="$(python3 - "$recent" "$engine" <<'PY'
import ast, sys
raw = sys.argv[1].strip()
if raw.startswith('@a(ss) '):
    raw = raw[len('@a(ss) '):]
try:
    sources = ast.literal_eval(raw)
    assert isinstance(sources, list)
    assert all(isinstance(x, tuple) and len(x) == 2 and all(isinstance(v, str) for v in x) for x in sources)
except (ValueError, SyntaxError, AssertionError):
    sys.exit(0)
item = ('ibus', sys.argv[2])
print(repr([item] + [source for source in sources if source != item]))
PY
)"
          [[ -z "$preferred" ]] || gsettings set "$schema" mru-sources "$preferred" || true
        fi
        printf '%s\n' 'NAMHH: restored missing Unikey input source (priority first)'
      fi
    fi
    exit 0
  fi
  sleep 2
done
exit 0
