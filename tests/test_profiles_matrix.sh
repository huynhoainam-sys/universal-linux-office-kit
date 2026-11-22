#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
trap 'rm -r -- "$TEMP"' EXIT
for testcase in minimal:5 office:10 desktop:12 full:16; do
  profile="${testcase%:*}"
  count="${testcase#*:}"
  (
    source "$ROOT/setup.sh"
    LOG_PATH="$TEMP/$profile.log"
    export FORCE_COLOR=1 TERM=xterm-256color NO_COLOR=1
    require_platform() { ID=ubuntu; VERSION_ID=24.04; return 0; }
    main --profile "$profile" --dry-run --yes --no-open-report \
      --report "$TEMP/$profile.txt"
  ) >"$TEMP/$profile.terminal"
  grep -q "${count}/${count} bước" "$TEMP/$profile.terminal"
  grep -q '^Dry-run: 1$' "$TEMP/$profile.txt"
  grep -q '^Failures: 0$' "$TEMP/$profile.txt"
done
echo 'PASS: minimal/office/desktop/full have accurate progress totals on safe dry-run'
