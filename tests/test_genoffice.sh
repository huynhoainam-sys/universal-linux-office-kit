#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$ROOT/setup.sh"
DRY_RUN=0
SKIP_THIRD_PARTY=0
LOG_PATH="$(mktemp)"
trap 'rm -f -- "$LOG_PATH"' EXIT
INSTALLS=0
CURLS=0
ALREADY=0
API_BLOCKED=0
ASSET_URL='https://github.com/genspark-ai/genoffice/releases/download/v1/genoffice_1_amd64.deb'
PINNED_URL='https://github.com/genspark-ai/genoffice/releases/download/v0.11.727/genoffice_0.11.727_amd64.deb'
PINNED_DIGEST='2e8b7c5c737d603742c6c5a60d626944cb36c9caed07e9d7cef60998122de26b'
CHECKSUM_MATCH=1
LAST_DOWNLOAD=''
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
  [[ "$url" == *'/releases/latest' && "$API_BLOCKED" == 1 ]] && return 22
  if [[ "$url" == *'/releases/latest' ]]; then
    printf '{"assets":[{"name":"genoffice_1_amd64.deb","browser_download_url":"%s","digest":"sha256:%064d"}]}\n' "$ASSET_URL" 0 > "$target"
  else
    LAST_DOWNLOAD="$url"
    printf 'fake deb\n' > "$target"
  fi
}
sha256sum() {
  if [[ "$LAST_DOWNLOAD" == "$PINNED_URL" ]]; then
    if (( CHECKSUM_MATCH )); then printf '%s  %s\n' "$PINNED_DIGEST" "$1"
    else printf '%064d  %s\n' 0 "$1"; fi
  else
    printf '%064d  %s\n' 0 "$1"
  fi
}
sudo() {
  [[ "$1 $2 $3" == 'apt-get install -y' ]] || return 1
  INSTALLS=$((INSTALLS + 1))
}
module_genoffice
[[ "$INSTALLS" == 1 && "$CURLS" == 2 ]] || { echo 'FAIL: official release with checksum not installed' >&2; exit 1; }
ALREADY=1
module_genoffice
[[ "$INSTALLS" == 1 && "$CURLS" == 2 ]] || { echo 'FAIL: installed GenOffice downloaded again' >&2; exit 1; }
ALREADY=0
ASSET_URL='https://example.invalid/genoffice_1_amd64.deb'
module_genoffice
[[ "$INSTALLS" == 1 && "$CURLS" == 3 ]] || { echo 'FAIL: untrusted asset URL was accepted' >&2; exit 1; }
API_BLOCKED=1
module_genoffice
[[ "$INSTALLS" == 2 && "$LAST_DOWNLOAD" == "$PINNED_URL" ]] || { echo 'FAIL: GitHub API 403 fallback did not install verified release' >&2; exit 1; }
CHECKSUM_MATCH=0
module_genoffice
[[ "$INSTALLS" == 2 ]] || { echo 'FAIL: mismatched fallback checksum was installed' >&2; exit 1; }
echo 'PASS: GenOffice source, dedup, API 403 fallback, checksum enforcement'
