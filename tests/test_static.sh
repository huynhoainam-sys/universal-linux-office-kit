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
grep -q 'zalo-linux-chat-kit/main/install-zalo-linux.sh' "$ROOT/setup.sh" || fail 'Zalo installer missing'
grep -q 'ZALO_VARIANT=full bash' "$ROOT/setup.sh" || fail 'Zalo full variant missing'
grep -q 'wget -qO' "$ROOT/setup.sh" || fail 'Zalo wget fallback missing'
grep -q '\.ulok-full-installed' "$ROOT/setup.sh" || fail 'Zalo dedup marker missing'
grep -q 'install_apt flameshot' "$ROOT/setup.sh" || fail 'Flameshot installer missing'
grep -q '<Primary><Shift>s' "$ROOT/setup.sh" || fail 'Flameshot shortcut missing'
grep -q 'ibus-unikey' "$ROOT/setup.sh" || fail 'Vietnamese IBus input missing'
grep -q 'fcitx5-unikey' "$ROOT/setup.sh" || fail 'Vietnamese Fcitx input missing'
grep -q -- '--fix-unikey' "$ROOT/setup.sh" || fail 'Unikey repair option missing'
grep -q -- '--canon-ufrii-archive' "$ROOT/setup.sh" || fail 'Canon archive option missing'
grep -q 'fonts-crosextra-carlito' "$ROOT/setup.sh" || fail 'Office fonts missing'
grep -q 'cifs-utils smbclient' "$ROOT/setup.sh" || fail 'SMB tools missing'
if command -v bash >/dev/null; then bash -n "$ROOT/setup.sh"; fi
bash -n "$ROOT/doctor.sh"
bash "$ROOT/tests/test_input_method.sh"
bash "$ROOT/tests/test_genoffice.sh"
echo 'PASS: static checks'
