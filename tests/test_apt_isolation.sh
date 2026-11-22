#!/usr/bin/env bash
# One unavailable APT package must not suppress other packages in the batch.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
package_installed() { [[ -e "$TEMP/installed-$1" ]]; }
apt_run() {
  printf '%s\n' "$*" >> "$TEMP/attempts"
  [[ " $* " != *' blocked '* ]] || return 100
  local pkg=''
  for pkg in good-a good-b; do
    [[ " $* " != *" $pkg "* ]] || touch "$TEMP/installed-$pkg"
  done
}

# Batch fails because 'blocked' is unavailable, but both independent apps work.
if install_apt good-a blocked good-b; then
  echo 'FAIL: missing package reported as success' >&2
  exit 1
fi
[[ -e "$TEMP/installed-good-a" && -e "$TEMP/installed-good-b" ]]
grep -q 'install -y --no-install-recommends blocked' "$TEMP/attempts"
[[ ${#WARNINGS[@]} -ge 2 ]]

# When the proxy is offline, fallback attempts must only use cached packages.
APT_OFFLINE=1
: > "$TEMP/attempts"
if install_apt blocked; then
  echo 'FAIL: blocked offline package reported as success' >&2
  exit 1
fi
grep -q 'install -y --no-download --no-install-recommends blocked' "$TEMP/attempts"
echo 'PASS: one blocked APT package leaves independent apps installable'
