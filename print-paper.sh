#!/usr/bin/env bash
set -Eeuo pipefail

usage() {
  cat <<'EOF'
In PDF theo khổ trang A4/A5, không đổi mặc định của máy in.
  bash print-paper.sh TEN_MAY_IN file.pdf [--dry-run]
Xem tên máy in: lpstat -e
EOF
}

if (( $# < 2 || $# > 3 )); then usage >&2; exit 2; fi
printer=$1
file=$2
dry_run=0
if (( $# == 3 )); then
  [[ $3 == --dry-run ]] || { usage >&2; exit 2; }
  dry_run=1
fi
[[ -f $file ]] || { echo "Không tìm thấy file: $file" >&2; exit 1; }
for cmd in pdfinfo lpstat lp; do
  command -v "$cmd" >/dev/null || { echo "Thiếu lệnh $cmd" >&2; exit 1; }
done
lpstat -e | grep -Fxq -- "$printer" || { echo "Không tìm thấy máy in: $printer" >&2; exit 1; }

info=$(pdfinfo -f 1 -l 100000 -- "$file") || { echo 'Không đọc được PDF' >&2; exit 1; }
pages=$(awk '/^Pages:/ {print $2; exit}' <<<"$info")
[[ $pages =~ ^[1-9][0-9]*$ ]] || { echo 'Không xác định được số trang PDF' >&2; exit 1; }

sizes=$(awk '
  $1 == "Page" && $3 == "size:" {
    w=$4+0; h=$6+0;
    if (w>h) {t=w; w=h; h=t}
    if (w>=590 && w<=600 && h>=837 && h<=847) print "A4";
    else if (w>=415 && w<=425 && h>=590 && h<=600) print "A5";
    else print "OTHER";
  }
' <<<"$info")
count=$(wc -l <<<"$sizes")
(( count == pages )) || { echo 'Không đọc đủ khổ giấy của từng trang' >&2; exit 1; }
media=$(sort -u <<<"$sizes")
case "$media" in
  A4|A5) ;;
  *$'\n'*) echo 'PDF có nhiều khổ giấy: hãy tách file A4 và A5 rồi in riêng.' >&2; exit 1 ;;
  *) echo 'PDF không phải A4/A5; kiểm tra khổ trang trước khi in.' >&2; exit 1 ;;
esac

echo "Máy in: $printer | PDF: $pages trang | Khổ: $media"
if (( dry_run )); then
  printf 'Sẽ chạy: lp -d %q -o media=%q %q\n' "$printer" "$media" "$file"
else
  lp -d "$printer" -o "media=$media" -- "$file"
fi
