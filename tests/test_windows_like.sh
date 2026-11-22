#!/usr/bin/env bash
# Windows-like controls are opt-in and never overwrite an already complete layout.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
mkdir -p -- "$TEMP/bin"
export XDG_CURRENT_DESKTOP='ubuntu:GNOME' WINLIKE_TEST_STATE="$TEMP"
printf "'appmenu:close'\n" > "$TEMP/layout"
cat > "$TEMP/bin/gsettings" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  writable) printf 'true\n' ;;
  get) cat "$WINLIKE_TEST_STATE/layout" ;;
  set)
    printf '%s\n' "$*" >> "$WINLIKE_TEST_STATE/changes"
    printf "'%s'\n" "$4" > "$WINLIKE_TEST_STATE/layout" ;;
esac
EOF
chmod +x "$TEMP/bin/gsettings"
export PATH="$TEMP/bin:$PATH"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
module_windows_like
grep -q '^.*minimize,maximize,close' "$TEMP/layout"
count="$(wc -l < "$TEMP/changes")"
module_windows_like
[[ "$(wc -l < "$TEMP/changes")" == "$count" ]]
export XDG_CURRENT_DESKTOP='X-Cinnamon'
module_windows_like
[[ "$(wc -l < "$TEMP/changes")" == "$count" ]]
echo 'PASS: optional GNOME Windows-style controls, idempotent and Mint-safe'
