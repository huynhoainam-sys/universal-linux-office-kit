#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
OUT="${1:-$HOME/zalo-linux-backups}"
STAMP="$(date +%Y%m%d-%H%M%S)"
mkdir -p -- "$OUT"
paths=()
for p in "$CONFIG_HOME/ZaloData" "$CONFIG_HOME/ZaloApp" "$CONFIG_HOME/Zalo" "$DATA_HOME/ZaloData" "$DATA_HOME/Zalo"; do
  [[ -e "$p" ]] && paths+=("$p")
done
(( ${#paths[@]} )) || { echo "Không tìm thấy dữ liệu Zalo local; chưa cần backup."; exit 0; }
ARCHIVE="$(mktemp --suffix=.tar.gz "$OUT/zalo-data-$STAMP.XXXXXX")"
trap 'rm -f -- "$ARCHIVE" "$ARCHIVE.sha256"' ERR
tar -czf "$ARCHIVE" "${paths[@]}"
sha256sum "$ARCHIVE" > "$ARCHIVE.sha256"
trap - ERR
echo "Đã backup: $ARCHIVE"
