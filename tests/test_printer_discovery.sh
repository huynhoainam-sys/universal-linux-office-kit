#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$(mktemp -d)"
trap 'rm -rf "$D"' EXIT
mkdir -p "$D/bin"
cat > "$D/bin/lpstat" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cat > "$D/bin/lpinfo" <<'EOF'
#!/usr/bin/env bash
echo "direct usb://Canon/LBP6230%2F6240?serial=123"
EOF
chmod +x "$D/bin/"*
PATH="$D/bin:$PATH" bash "$ROOT/scripts/printer-discovery.sh" | grep -q "usb://Canon"
cat > "$D/bin/lpinfo" <<'EOF'
#!/usr/bin/env bash
echo "network dnssd://Canon%20LBP6240._ipp._tcp.local/"
EOF
chmod +x "$D/bin/lpinfo"
PATH="$D/bin:$PATH" bash "$ROOT/scripts/printer-discovery.sh" | grep -q "dnssd://"
cat > "$D/bin/lpinfo" <<'EOF'
#!/usr/bin/env bash
echo "direct usb://Canon/LBP2900?serial=123"
EOF
chmod +x "$D/bin/lpinfo"
if PATH="$D/bin:$PATH" bash "$ROOT/scripts/printer-discovery.sh" >/dev/null; then echo "FAIL: false match" >&2; exit 1; fi
echo "PASS: Canon USB/mDNS discovery; non-matching Canon ignored"
