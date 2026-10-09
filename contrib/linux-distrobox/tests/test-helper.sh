#!/usr/bin/env bash
set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/kilo-fedora.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"
cat > "$tmp/bin/kilo-desktop" <<'EOF'
#!/bin/bash
printf 'telemetry=%s args=%s\n' "${KILO_TELEMETRY_LEVEL:-unset}" "$*"
EOF
chmod +x "$tmp/bin/kilo-desktop"
# Fake a Debian-container environment, verify launch flags and telemetry variable.
output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" run)"
[[ "$output" == 'telemetry=off args=' ]]
output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" software-render)"
[[ "$output" == 'telemetry=off args=--disable-gpu' ]]
output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" doctor)"
[[ "$output" == *'system D-Bus socket:'* ]]
[[ "$output" == *'Diagnostics only: no changes made.'* ]]
# Fake host without Kilo and with distrobox to verify host delegation.
mv "$tmp/bin/kilo-desktop" "$tmp/bin/kilo-desktop.old"
cat > "$tmp/bin/distrobox" <<'EOF'
#!/bin/bash
printf 'host-delegate args=%s\n' "$*"
EOF
chmod +x "$tmp/bin/distrobox"
output="$(PATH="$tmp/bin:/usr/bin:/bin" bash "$SCRIPT" run)"
[[ "$output" == *'enter kilo-debian -- env KILO_TELEMETRY_LEVEL=off kilo-desktop' ]]
output="$(PATH="$tmp/bin:/usr/bin:/bin" bash "$SCRIPT" software-render)"
[[ "$output" == *'kilo-desktop --disable-gpu' ]]
printf '%s\n' 'PASS: syntax + container launch + software fallback + read-only doctor + Fedora delegation'