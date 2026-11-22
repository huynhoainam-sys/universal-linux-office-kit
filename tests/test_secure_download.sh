#!/usr/bin/env bash
# Third-party packages must never be written to predictable shared /tmp paths.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
mkdir -p -- "$TEMP/bin" "$TEMP/downloads"
export TMPDIR="$TEMP/downloads" TEST_DOWNLOAD_ROOT="$TEMP"
cat > "$TEMP/bin/curl" <<'EOF'
#!/usr/bin/env bash
target=''
url=''
while (($#)); do
  if [[ "$1" == -o ]]; then target="$2"; shift 2
  else [[ "$1" != https://* ]] || url="$1"; shift; fi
done
[[ -n "$target" && "$target" == "$TMPDIR"/ulok-*/wps-office.deb ]] || exit 18
[[ "${ULOK_TEST_CURL_BLOCKED:-0}" != 1 ]] || exit 22
[[ "${ULOK_TEST_PRIMARY_BLOCKED:-0}" != 1 || "$url" != */blocked.deb ]] || exit 22
printf 'mock verified package\n' > "$target"
EOF
cat > "$TEMP/bin/wget" <<'EOF'
#!/usr/bin/env bash
target=''
url=''
for arg in "$@"; do
  [[ "$arg" != --output-document=* ]] || target="${arg#--output-document=}"
  [[ "$arg" != https://* ]] || url="$arg"
done
[[ -n "$target" && "$target" == "$TMPDIR"/ulok-*/wps-office.deb ]] || exit 18
[[ "${ULOK_TEST_PRIMARY_BLOCKED:-0}" != 1 || "$url" != */blocked.deb ]] || exit 22
printf 'mock verified package\n' > "$target"
EOF
chmod +x "$TEMP/bin/curl" "$TEMP/bin/wget"
export PATH="$TEMP/bin:$PATH"
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
package_installed() { return 1; }
apt_run() { printf '%s\n' "$*" >> "$TEMP/apt-calls"; }
expected="$(printf 'mock verified package\n' | sha256sum | cut -d' ' -f1)"

install_deb_url wps-office 'https://example.invalid/verified.deb' "$expected"
[[ "$(wc -l < "$TEMP/apt-calls")" == 1 ]]
[[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]]

# Proxy / HTTP 403 on channel one: fall back to wget, still verify the hash.
export ULOK_TEST_CURL_BLOCKED=1
install_deb_url wps-office 'https://example.invalid/blocked.deb' "$expected"
[[ "$(wc -l < "$TEMP/apt-calls")" == 2 ]]
unset ULOK_TEST_CURL_BLOCKED

# Both transports blocked for a source: use only an HTTPS mirror with the same pin.
export ULOK_TEST_PRIMARY_BLOCKED=1
install_deb_url wps-office 'https://primary.invalid/blocked.deb' "$expected" 'https://mirror.invalid/verified.deb'
[[ "$(wc -l < "$TEMP/apt-calls")" == 3 ]]
unset ULOK_TEST_PRIMARY_BLOCKED

# A wrong digest must never reach the package installer; temporary files vanish.
if install_deb_url wps-office 'https://example.invalid/bad.deb' "$(printf '0%.0s' {1..64})"; then
  echo 'FAIL: invalid checksum was accepted' >&2
  exit 1
fi
[[ "$(wc -l < "$TEMP/apt-calls")" == 3 ]]
[[ -z "$(find "$TMPDIR" -mindepth 1 -print -quit)" ]]
echo 'PASS: isolated downloads, checksum enforced, temporary files cleaned'
