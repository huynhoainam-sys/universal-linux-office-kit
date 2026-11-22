#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
REPORT_PATH="$TEMP/report.txt"

declare -A installed=()
declare -a calls=()
office_suite_installed() { [[ "${installed[$1]:-0}" == 1 ]]; }
install_deb_url() {
  [[ "$1" == wps-office ]] || { echo "Unexpected deb: $1" >&2; return 1; }
  installed[wps]=1
  calls+=(wps)
}
install_apt() {
  [[ "$1" == libreoffice ]] || { echo "Unexpected apt: $1" >&2; return 1; }
  installed[libreoffice]=1
  calls+=(libreoffice)
}
dpkg() { [[ "$1" == --print-architecture ]] && printf 'amd64\n'; }
reset_suites() {
  installed=()
  calls=()
  WARNINGS=()
  OFFICE_SECONDARY=auto
  SKIP_THIRD_PARTY=0
}
assert_calls() {
  local actual="${calls[*]:-}"
  [[ "$actual" == "$1" ]] || { echo "FAIL: expected '$1', received '$actual'" >&2; exit 1; }
  (( $(office_suite_count) <= 2 )) || { echo 'FAIL: installed more than two office suites' >&2; exit 1; }
}

reset_suites
module_office_suites
assert_calls 'wps libreoffice'

reset_suites
installed[genoffice]=1
module_office_suites
assert_calls 'wps'

reset_suites
installed[wps]=1
module_office_suites
assert_calls 'libreoffice'

reset_suites
installed[wps]=1 installed[genoffice]=1
module_office_suites
assert_calls ''

reset_suites
installed[libreoffice]=1 installed[genoffice]=1
module_office_suites
assert_calls ''
[[ "${#WARNINGS[@]}" == 1 ]] || { echo 'FAIL: missing non-destructive WPS warning' >&2; exit 1; }

reset_suites
installed[wps]=1 installed[libreoffice]=1 installed[genoffice]=1
module_office_suites
[[ "${#calls[@]}" == 0 && "${#WARNINGS[@]}" == 1 ]] || { echo 'FAIL: third suite was not preserved safely' >&2; exit 1; }

reset_suites
OFFICE_SECONDARY=genoffice
module_office_suites
assert_calls 'wps'
[[ "${installed[libreoffice]:-0}" == 0 ]] || { echo 'FAIL: LibreOffice installed despite GenOffice selection' >&2; exit 1; }

echo 'PASS: WPS first, two-suite cap, installed-suite detection, no automatic removal'
