#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
D="$(mktemp -d)"
trap 'rm -rf -- "$D"' EXIT
source "$ROOT/setup.sh"
LOG_PATH="$D/setup.log"
DRY_RUN=1
SKIP_THIRD_PARTY=0
dpkg() {
  if [[ "$1" == --print-architecture ]]; then printf '%s\n' "$FAKE_ARCH"; return 0; fi
  return 1
}
install_deb_url() { printf '%s\n' "$*" >> "$D/urls"; return "${FAKE_DOWNLOAD_FAIL:-0}"; }
FAKE_ARCH=amd64
module_rustdesk
grep -q 'rustdesk-1.5.3-x86_64.deb 81096d2f65fd43352540c351bca15bb0712a2a6f9efa4c95e9fff25cb97b3b81' "$D/urls"
FAKE_ARCH=arm64
module_rustdesk
grep -q 'rustdesk-1.5.3-aarch64.deb fa85e8d3ccd45e2e303c2d1359af5dc51aa93d880e39ba47c9b04bfabd82ae19' "$D/urls"
FAKE_ARCH=i386
if module_rustdesk; then echo 'FAIL: unsupported architecture was accepted' >&2; exit 1; fi
FAKE_ARCH=amd64
SKIP_THIRD_PARTY=1
: > "$D/urls"
module_rustdesk
[[ ! -s "$D/urls" ]] || { echo 'FAIL: skip-third-party downloaded RustDesk' >&2; exit 1; }
SKIP_THIRD_PARTY=0
FAKE_DOWNLOAD_FAIL=1
if module_rustdesk; then echo 'FAIL: download error was accepted' >&2; exit 1; fi
FAKE_DOWNLOAD_FAIL=0
# A separate --install-rustdesk must never call other office/remote modules.
main_calls="$D/only-rustdesk"
require_platform() { return 0; }
backup_desktop_settings() { BACKUP_DIR="$D/backup"; mkdir -p -- "$BACKUP_DIR"; }
module_rustdesk() { printf 'rustdesk\n' >> "$main_calls"; }
module_office_suites() { echo 'FAIL: office was invoked' >&2; return 9; }
module_vietnamese_input() { echo 'FAIL: Unikey was invoked' >&2; return 9; }
module_flameshot() { echo 'FAIL: Flameshot was invoked' >&2; return 9; }
module_zalo() { echo 'FAIL: Zalo was invoked' >&2; return 9; }
module_canon_auto() { echo 'FAIL: Canon was invoked' >&2; return 9; }
INSTALL_RUSTDESK=0 DRY_RUN=1
WARNINGS=()
FAILURES=()
main --install-rustdesk --yes --dry-run --no-open-report --report "$D/standalone-report.txt" > "$D/standalone-terminal"
[[ "$(cat "$main_calls")" == rustdesk ]]
grep -q '^Failures: 0$' "$D/standalone-report.txt"
grep -q '^Dry-run: 1$' "$D/standalone-report.txt"
grep -q 'Module: RustDesk' "$ROOT/setup.sh"
echo 'PASS: RustDesk pin amd64/arm64, skip/failure cases and standalone isolation'
