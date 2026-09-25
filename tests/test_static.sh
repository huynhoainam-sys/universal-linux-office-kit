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
if command -v bash >/dev/null; then bash -n "$ROOT/setup.sh"; fi
echo 'PASS: static checks'
