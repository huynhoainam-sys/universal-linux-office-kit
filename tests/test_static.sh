#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
fail() { echo "FAIL: $*" >&2; exit 1; }
grep -q 'set -Eeuo pipefail' "$ROOT/setup.sh" || fail 'strict mode missing'
grep -q -- '--dry-run' "$ROOT/setup.sh" || fail 'dry-run missing'
grep -q -- '--profile' "$ROOT/setup.sh" || fail 'profile missing'
grep -q 'dpkg --configure -a' "$ROOT/setup.sh" || fail 'dpkg repair missing'
grep -q 'apt-get -f install' "$ROOT/setup.sh" || fail 'apt repair missing'
grep -q 'linuxmint' "$ROOT/setup.sh" || fail 'Mint detection missing'
grep -q 'libreoffice' "$ROOT/setup.sh" || fail 'office module missing'
grep -q 'PROFILE.*office.*full' "$ROOT/setup.sh" || fail 'profile gating missing'
grep -q 'google-chrome-stable_current_amd64.deb' "$ROOT/setup.sh" || fail 'Chrome installer missing'
grep -q 'microsoft-edge.sources' "$ROOT/setup.sh" || fail 'Edge repository missing'
grep -q 'docker-ce' "$ROOT/setup.sh" || fail 'Docker installer missing'
grep -q 'zoom.us/client/latest' "$ROOT/setup.sh" || fail 'Zoom installer missing'
grep -q 'wps-office_11.1.0.11723.XA_amd64.deb' "$ROOT/setup.sh" || fail 'WPS installer missing'
grep -q 'module_genoffice' "$ROOT/setup.sh" || fail 'GenOffice module missing'
grep -q 'api.github.com/repos/genspark-ai/genoffice/releases/latest' "$ROOT/setup.sh" || fail 'GenOffice official release missing'
grep -q 'fallback_sha256=' "$ROOT/setup.sh" || fail 'GenOffice SHA-256 fallback missing'
grep -q 'mktemp -d.*ulok-' "$ROOT/setup.sh" || fail 'Deb download must use a private temporary directory'
if grep -q 'raw.githubusercontent.com' "$ROOT/setup.sh"; then fail 'Raw GitHub dependency remains'; fi
grep -q 'vendor/zalo/install-zalo-linux.sh' "$ROOT/setup.sh" || fail 'Bundled Zalo installer missing'
grep -q 'ZALO_VARIANT=' "$ROOT/setup.sh" || fail 'Zalo variant selector missing'
grep -q -- '--repair-desktop' "$ROOT/setup.sh" || fail 'One-shot desktop repair missing'
grep -q -- '-bg.*#061021' "$ROOT/.github/scripts/capture-ubuntu.sh" || fail 'Ubuntu terminal capture must use the NAMHH navy background'
grep -q -- '--fix-zalo' "$ROOT/setup.sh" || fail 'Zalo repair missing'
grep -q -- '--fix-zalo-login' "$ROOT/setup.sh" || fail 'Zalo QR login recovery missing'
if grep -q 'git clone --quiet --depth 1' "$ROOT/setup.sh"; then fail 'Second Zalo clone still required'; fi
for helper in install-zalo-linux.sh zalo-download.sh zalo-launcher.sh zalo-repair.sh backup-zalo-linux.sh zalo-doctor.sh zalo-login-recover.sh; do
  [[ -s "$ROOT/vendor/zalo/$helper" ]] || fail "Missing Zalo helper: $helper"
  bash -n "$ROOT/vendor/zalo/$helper" || fail "Broken Zalo helper syntax: $helper"
done
grep -q '\.ulok-full-installed' "$ROOT/setup.sh" || fail 'Zalo dedup marker missing'
grep -q 'install_apt flameshot' "$ROOT/setup.sh" || fail 'Flameshot installer missing'
grep -q '<Primary><Shift>s' "$ROOT/setup.sh" || fail 'Flameshot shortcut missing'
grep -q "script --quiet --return --command 'flameshot gui'" "$ROOT/setup.sh" || fail 'Flameshot GNOME Wayland PTY workaround missing'
grep -q 'ibus-unikey' "$ROOT/setup.sh" || fail 'Vietnamese IBus input missing'
grep -q 'fcitx5-unikey' "$ROOT/setup.sh" || fail 'Vietnamese Fcitx input missing'
grep -q -- '--fix-unikey' "$ROOT/setup.sh" || fail 'Unikey repair option missing'
grep -q -- '--fix-flameshot' "$ROOT/setup.sh" || fail 'Flameshot repair option missing'
grep -q -- '--canon-ufrii-archive' "$ROOT/setup.sh" || fail 'Canon archive option missing'
bash "$ROOT/tests/test_canon_repair.sh"
bash "$ROOT/tests/test_canon_integration.sh"
grep -q 'fonts-crosextra-carlito' "$ROOT/setup.sh" || fail 'Office fonts missing'
grep -q 'cifs-utils smbclient' "$ROOT/setup.sh" || fail 'SMB tools missing'
if command -v bash >/dev/null; then bash -n "$ROOT/setup.sh"; fi
bash -n "$ROOT/doctor.sh"
bash "$ROOT/tests/test_input_method.sh"
bash "$ROOT/tests/test_ibus_priority.sh"
bash "$ROOT/tests/test_flameshot.sh"
bash "$ROOT/tests/test_secure_download.sh"
bash "$ROOT/tests/test_genoffice.sh"
bash "$ROOT/tests/test_office_suites.sh"
python3 "$ROOT/tests/test_report_html.py"
bash "$ROOT/tests/test_report_open.sh"
bash "$ROOT/tests/test_repair_flow.sh"
bash "$ROOT/tests/test_apt_skip.sh"
bash "$ROOT/tests/test_apt_isolation.sh"
bash "$ROOT/tests/test_outlook.sh"
bash "$ROOT/tests/test_windows_like.sh"
bash "$ROOT/tests/test_zalo_bundle.sh"
bash "$ROOT/tests/test_terminal_ui.sh"
bash "$ROOT/tests/test_desktop_profile.sh"
bash "$ROOT/tests/test_unikey_guard.sh"
bash "$ROOT/tests/test_core_resilience.sh"
bash "$ROOT/tests/test_profiles_matrix.sh"
echo 'PASS: static checks'
