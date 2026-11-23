#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
mkdir -p "$TEMP/bin" "$TEMP/ppd"

printf '%s\n' '*NickName: "HP Designjet T920 PostScript"' > "$TEMP/ppd/LBP6230-6240.ppd"
printf '%s\n' '*NickName: "HP Designjet T920 PostScript"' > "$TEMP/ppd/LBP6230-6240-2.ppd"
cat > "$TEMP/bin/lpstat" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  -v)
    if (($# > 1)); then
      [[ "$2" == LBP6230-6240 || "$2" == LBP6230-6240-2 || "$2" == TOSHIBA_e_STUDIO ]] || exit 1
    fi
    printf '%s\n' \
      'device for LBP6230-6240: usb://Canon/LBP6230%2F6240' \
      'device for LBP6230-6240-2: ipp://192.0.2.20/ipp/print' \
      'device for TOSHIBA_e_STUDIO: ipp://192.0.2.21/ipp/print'
    ;;
  *) exit 1 ;;
esac
EOF
cat > "$TEMP/bin/lpinfo" <<'EOF'
#!/usr/bin/env bash
[[ "$1" == -m ]] || exit 1
printf '%s\n' 'Canon/CNRCUPSLBP6230ZNK.ppd Canon LBP6230/6240'
EOF
cat > "$TEMP/bin/sudo" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$CANON_TEST_CALLS"
if [[ "$1" == cp ]]; then
  shift
  cp "$@"
elif [[ "$1" != lpadmin ]]; then
  exit 1
fi
EOF
chmod +x "$TEMP/bin/"*
export PATH="$TEMP/bin:$PATH" CANON_PPD_DIR="$TEMP/ppd" CANON_TEST_CALLS="$TEMP/calls"
SCRIPT="$ROOT/scripts/fix-canon-lbp6230.sh"

# Read-only check catches the wrong HP PPD, lists all three queues, but no writes.
bash "$SCRIPT" > "$TEMP/diagnosis"
grep -q '\[SAI DRIVER\]' "$TEMP/diagnosis"
grep -q 'LBP6230-6240-2' "$TEMP/diagnosis"
! grep -q '^TOSHIBA_e_STUDIO$' "$TEMP/diagnosis"
[[ ! -e "$TEMP/calls" ]]

bash "$SCRIPT" --queue LBP6230-6240 --dry-run > "$TEMP/dry-run"
grep -q '\[DRY-RUN\]' "$TEMP/dry-run"
[[ ! -e "$TEMP/calls" ]]

if bash "$SCRIPT" --queue TOSHIBA_e_STUDIO --apply >"$TEMP/reject" 2>&1; then
  printf 'FAIL: modified an unrelated Toshiba printer\n' >&2
  exit 1
fi
[[ ! -e "$TEMP/calls" ]]

# Correct one specifically named queue; PPD backup must happen before lpadmin.
bash "$SCRIPT" --queue LBP6230-6240 --apply > "$TEMP/applied"
grep -q '^cp -p -- ' "$TEMP/calls"
grep -q '^lpadmin -p LBP6230-6240 -m Canon/CNRCUPSLBP6230ZNK.ppd$' "$TEMP/calls"
! grep -q 'TOSHIBA' "$TEMP/calls"
[[ $(find "$TEMP/ppd" -name '*.bak' | wc -l) -eq 1 ]]

# --full repairs the two wrong Canon queues in one invocation; never Toshiba.
: > "$TEMP/calls"
bash "$SCRIPT" --full --apply --accept-canon-license > "$TEMP/full"
grep -q 'Canon: đã sửa 2 hàng đợi nhầm HP; lỗi 0' "$TEMP/full"
grep -q '^lpadmin -p LBP6230-6240 -m Canon/CNRCUPSLBP6230ZNK.ppd$' "$TEMP/calls"
grep -q '^lpadmin -p LBP6230-6240-2 -m Canon/CNRCUPSLBP6230ZNK.ppd$' "$TEMP/calls"
! grep -q 'TOSHIBA' "$TEMP/calls"

if bash "$SCRIPT" --full --apply > "$TEMP/license-reject" 2>&1; then
  printf 'FAIL: --full applied without Canon license acknowledgement\n' >&2
  exit 1
fi

# Already-correct Canon queues are idempotent; no extra CUPS changes.
printf '%s\n' '*NickName: "Canon LBP6230/6240"' > "$TEMP/ppd/LBP6230-6240.ppd"
printf '%s\n' '*NickName: "Canon LBP6230/6240"' > "$TEMP/ppd/LBP6230-6240-2.ppd"
: > "$TEMP/calls"
bash "$SCRIPT" --full --apply --accept-canon-license > "$TEMP/idempotent"
grep -q 'Canon: đã sửa 0 hàng đợi nhầm HP; lỗi 0' "$TEMP/idempotent"
[[ ! -s "$TEMP/calls" ]]

# A blocked curl call falls back to wget; a checksum mismatch is rejected.
(
  source "$SCRIPT"
  printf 'canon-test-archive\n' > "$TEMP/download-fixture"
  CANON_OFFICIAL_SHA256="$(sha256sum "$TEMP/download-fixture" | cut -d' ' -f1)"
  CANON_OFFICIAL_URL='https://canon.example.invalid/driver.tar.gz'
  CANON_OFFICIAL_REDIRECT='https://canon.example.invalid/fallback.tar.gz'
  APPLY=1
  DRY_RUN=0
  HOME="$TEMP/user"
  mkdir -p "$HOME/Downloads"
  curl() { return 22; }
  wget() {
    local arg out=''
    for arg in "$@"; do
      case "$arg" in --output-document=*) out="${arg#*=}" ;; esac
    done
    cp -- "$TEMP/download-fixture" "$out"
  }
  download_official_driver > "$TEMP/download-output"
  grep -q 'Tải Canon chính thức qua wget' "$TEMP/download-output"
  verify_official_archive "$CANON_ARCHIVE"
  printf 'corrupted\n' > "$CANON_ARCHIVE"
  if verify_official_archive "$CANON_ARCHIVE"; then
    printf 'FAIL: accepted corrupted official Canon archive\n' >&2
    exit 1
  fi
  rm -r -- "$TEMP_DOWNLOAD_DIR"
)

# Reject a generic UFR II archive; this Canon model needs UFRII LT.
touch "$TEMP/linux-UFRII-drv-v640-us-01.tar.gz"
if bash "$SCRIPT" --archive "$TEMP/linux-UFRII-drv-v640-us-01.tar.gz" --dry-run > "$TEMP/reject-archive" 2>&1; then
  printf 'FAIL: accepted the generic UFR II release for LBP6230/6240\n' >&2
  exit 1
fi

# The Office Kit installer must not skip UFRII LT just because generic UFR II
# happens to exist. It should skip only when the matching archive package exists.
mkdir -p "$TEMP/driver"
touch "$TEMP/driver/cnrdrvcups-ufr2lt-uk_5.10_amd64.deb"
tar -czf "$TEMP/linux-UFRIILT-drv-v510-m17n.tar.gz" -C "$TEMP/driver" .
# shellcheck source=../setup.sh
source "$ROOT/setup.sh"
CANON_UFRII_ARCHIVE="$TEMP/linux-UFRIILT-drv-v510-m17n.tar.gz"
LOG_PATH="$TEMP/setup.log"
DRY_RUN=0
dpkg() { [[ "$1" == --print-architecture ]] && printf 'amd64\n'; }
dpkg-deb() {
  if [[ "$3" == Architecture ]]; then printf 'amd64\n'
  elif [[ "$3" == Package ]]; then printf 'cnrdrvcups-ufr2lt-uk\n'; fi
}
package_installed() { [[ "$1" == cnrdrvcups-ufr2-us ]]; }
apt_run() { printf '%s\n' "$*" >> "$TEMP/apt-calls"; }
module_canon_ufrii > /dev/null
grep -q 'cnrdrvcups-ufr2lt-uk_5.10_amd64.deb' "$TEMP/apt-calls"
package_installed() { [[ "$1" == cnrdrvcups-ufr2lt-uk ]]; }
: > "$TEMP/apt-calls"
module_canon_ufrii > /dev/null
[[ ! -s "$TEMP/apt-calls" ]]

echo 'PASS: Canon --full repairs wrong queues, verifies checksum, falls back to wget and preserves Toshiba'
