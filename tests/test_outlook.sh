#!/usr/bin/env bash
# Outlook Web is a safe launcher, not an unofficial Microsoft Outlook binary.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
export HOME="$TEMP/home" XDG_BIN_HOME="$TEMP/home/.local/bin" XDG_DATA_HOME="$TEMP/home/.local/share"
mkdir -p -- "$TEMP/bin" "$HOME"
cat > "$TEMP/bin/microsoft-edge-stable" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" > "$OUTLOOK_TEST_ARGS"
EOF
chmod +x "$TEMP/bin/microsoft-edge-stable"
export PATH="$TEMP/bin:$PATH" OUTLOOK_TEST_ARGS="$TEMP/browser-args"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
module_outlook_web
[[ -x "$XDG_BIN_HOME/ulok-outlook-web" ]]
grep -q 'Name=Microsoft Outlook (Web)' "$XDG_DATA_HOME/applications/namhh-outlook-web.desktop"
"$XDG_BIN_HOME/ulok-outlook-web"
[[ "$(<"$OUTLOOK_TEST_ARGS")" == '--app=https://outlook.office.com/mail/' ]]

# Idempotent and protective of user-provided launchers.
module_outlook_web
printf '# Personal script\n' > "$XDG_BIN_HOME/ulok-outlook-web"
if module_outlook_web; then
  echo 'FAIL: user-owned Outlook launcher overwritten' >&2
  exit 1
fi
[[ "$(<"$XDG_BIN_HOME/ulok-outlook-web")" == '# Personal script' ]]
echo 'PASS: Outlook Web launcher, browser selection and user settings protection'
