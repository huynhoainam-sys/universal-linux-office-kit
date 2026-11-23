#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
# shellcheck source=../setup.sh
source "$ROOT/setup.sh"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0

lpstat() {
  [[ "$1" == -v ]] || return 1
  if [[ "${CANON_TEST_PRESENT:-1}" == 1 ]]; then
    printf '%s\n' \
      'device for LBP6230-6240: usb://Canon/LBP6230%2F6240' \
      'device for TOSHIBA_e_STUDIO: ipp://192.0.2.21/ipp/print'
  fi
}

run_canon_helper() { printf 'repair\n' >> "$TEMP/helper-calls"; return "${CANON_TEST_HELPER_EXIT:-0}"; }

# A user without this Canon never downloads the driver, even with opt-in.
CANON_LICENSE_ACCEPTED=1 CANON_TEST_PRESENT=0
module_canon_auto
[[ ! -e "$TEMP/helper-calls" ]]

# A printer found without Canon's license acceptance produces a warning only.
CANON_LICENSE_ACCEPTED=0 CANON_TEST_PRESENT=1
module_canon_auto
[[ ! -e "$TEMP/helper-calls" ]]
grep -q -- '--accept-canon-license' "$LOG_PATH"

# Opt-in within the standard installer performs the repair once.
CANON_LICENSE_ACCEPTED=1
module_canon_auto
[[ $(wc -l < "$TEMP/helper-calls") -eq 1 ]]

# Driver failure does not stop office apps; it stays a warning.
CANON_TEST_HELPER_EXIT=1
if module_canon_auto; then
  printf 'FAIL: Canon helper failure unexpectedly reported success\n' >&2
  exit 1
fi
[[ $(wc -l < "$TEMP/helper-calls") -eq 2 ]]

# Full dry-run only logs what it would do; never calls the helper.
DRY_RUN=1
module_canon_auto
[[ $(wc -l < "$TEMP/helper-calls") -eq 2 ]]

# Canon is part of the same office module, after other essential packages.
DRY_RUN=0 CANON_TEST_HELPER_EXIT=0
module_office_suites() { printf 'office-suites\n' >> "$TEMP/modules"; }
install_apt() { printf 'apt\n' >> "$TEMP/modules"; }
configure_office_fonts() { printf 'fonts\n' >> "$TEMP/modules"; }
module_canon_ufrii() { printf 'canon-archive\n' >> "$TEMP/modules"; }
module_canon_auto() { printf 'canon-auto\n' >> "$TEMP/modules"; }
module_office
[[ "$(tail -2 "$TEMP/modules" | tr '\n' ' ')" == 'canon-archive canon-auto ' ]]

echo 'PASS: integrated Canon auto-detection, license gating, isolated errors and office profile order'
