#!/usr/bin/env bash
set -Eeuo pipefail
# Check CUPS queues and exact-model USB / DNS-SD records (no network scans).
if command -v lpstat >/dev/null 2>&1; then
  lpstat -v 2>/dev/null | grep -E "^device for LBP6230[-_]6240([-_][0-9]+)?: " && exit 0
fi
if command -v lpinfo >/dev/null 2>&1; then
  lpinfo -v 2>/dev/null | grep -Ei "canon.*(lbp6230|lbp6240)(%2f|/|%20|[[:space:]]|$)" && exit 0
fi
if command -v ippfind >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
  timeout 8 ippfind --ls 2>/dev/null | grep -Ei "canon.*(lbp6230|lbp6240)" && exit 0
fi
exit 1
