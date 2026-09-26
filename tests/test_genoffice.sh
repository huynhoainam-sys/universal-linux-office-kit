#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../setup.sh
source "$ROOT/setup.sh"
DRY_RUN=0
SKIP_THIRD_PARTY=0
LOG_PATH="$(mktemp)"
trap 'rm -f -- "$LOG_PATH"' EXIT
INSTALLS=0
CURLS=0
ALREADY=0
ASSET_URL='https://github.com/genspark-ai/genoffice/releases/download/v1/genoffice_1_amd64.deb'

package_installed() { (( ALREADY )); }
dpkg() {
  if [[ "$1" == --print-architecture ]]; then printf 'amd64\n';
  else command dpkg "$@"; fi
}
getconf() { printf 'glibc 2.39\n'; }
dpkg-deb() {
  case "$3" in
    Package) printf 'genoffice\n' ;;
    Architecture) printf 'amd64\n' ;;
    *) return 1 ;;
  esac
}
curl() {
  CURLS=$((CURLS + 1))
  local url='' target='' previous=''
  for arg in "$@"; do
    [[ "$previous" == -o ]] && target="$arg"
    [[ "$arg" == https://* ]] && url="$arg"
    previous="$arg"
  done
  if [[ "$url" == *'/releases/latest' ]]; then
    printf '{"assets":[{"name":"genoffice_1_amd64.deb","browser_download_url":"%s"}]}\n' "$ASSET_URL" > "$target"
  else
    printf 'fake deb\n' > "$target"
  fi
}
sudo() {
  [[ "$1 $2 $3" == 'apt-get install -y' ]] || return 1
  INSTALLS=$((INSTALLS + 1))
}

module_genoffice
[[ "$INSTALLS" == 1 && "$CURLS" == 2 ]] || { echo 'FAIL: official GenOffice asset was not installed once' >&2; exit 1; }
ALREADY=1
module_genoffice
[[ "$INSTALLS" == 1 && "$CURLS" == 2 ]] || { echo 'FAIL: installed GenOffice was downloaded again' >&2; exit 1; }
ALREADY=0
ASSET_URL='https://example.invalid/genoffice_1_amd64.deb'
module_genoffice
[[ "$INSTALLS" == 1 && "$CURLS" == 3 ]] || { echo 'FAIL: untrusted asset URL was accepted' >&2; exit 1; }
echo 'PASS: GenOffice release selection, source and deduplication'
