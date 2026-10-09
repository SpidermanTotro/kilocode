#!/usr/bin/env bash
# Regression tests for kilo-fedora.sh
# Run from any directory: bash contrib/linux-distrobox/tests/test-helper.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/kilo-fedora.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

# ---------------------------------------------------------------------------
pass=0
fail=0

check() {
  local desc="$1" result="$2" expected="$3"
  if [[ "$result" == $expected ]]; then
    printf '  PASS: %s\n' "$desc"
    (( pass++ )) || true
  else
    printf '  FAIL: %s\n' "$desc"
    printf '        expected: %s\n' "$expected"
    printf '        got:      %s\n' "$result"
    (( fail++ )) || true
  fi
}

# ---------------------------------------------------------------------------
# Fake kilo-desktop that echoes the telemetry env var and any args passed.
cat > "$tmp/bin/kilo-desktop" <<'EOF'
#!/bin/bash
printf 'telemetry=%s args=%s\n' "${KILO_DISABLE_TELEMETRY:-unset}" "$*"
EOF
chmod +x "$tmp/bin/kilo-desktop"

printf 'Test 1 — inside container (kilo-desktop in PATH)\n'

output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" run)"
check "run sets KILO_DISABLE_TELEMETRY=1" "$output" "telemetry=1 args="

output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" software-render)"
check "software-render passes --disable-gpu" "$output" "telemetry=1 args=--disable-gpu"

output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" run --extra-flag)"
check "extra flags forwarded" "$output" "telemetry=1 args=--extra-flag"

# ---------------------------------------------------------------------------
printf 'Test 2 — doctor output inside container\n'

output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" doctor)"
check "doctor shows D-Bus line"       "$output" *"system D-Bus:"*
check "doctor shows no-changes note"  "$output" *"Diagnostics only: no changes made."*
check "doctor shows executable line"  "$output" *"executable:"*

# ---------------------------------------------------------------------------
printf 'Test 3 — Fedora host delegation (no kilo-desktop, has distrobox)\n'

# Create an isolated bin dir with ONLY distrobox (no kilo-desktop).
mkdir -p "$tmp/host-bin"
cat > "$tmp/host-bin/distrobox" <<'EOF'
#!/bin/bash
printf 'distrobox-args: %s\n' "$*"
EOF
chmod +x "$tmp/host-bin/distrobox"
# Provide bash itself so the script can run, but no kilo-desktop.
ln -sf "$(command -v bash)"  "$tmp/host-bin/bash"
ln -sf "$(command -v curl)"  "$tmp/host-bin/curl" 2>/dev/null || true

output="$(PATH="$tmp/host-bin" bash "$SCRIPT" run)"
check "host run delegates to distrobox"           "$output" *"enter kilo-debian -- env KILO_DISABLE_TELEMETRY=1 kilo-desktop"*

output="$(PATH="$tmp/host-bin" bash "$SCRIPT" software-render)"
check "host software-render passes --disable-gpu" "$output" *"kilo-desktop --disable-gpu"*

# ---------------------------------------------------------------------------
printf 'Test 4 — unknown command exits non-zero\n'

if PATH="$tmp/bin:$PATH" bash "$SCRIPT" badcmd 2>/dev/null; then
  check "unknown command exits non-zero" "exit-0" "exit-nonzero"
else
  check "unknown command exits non-zero" "exit-nonzero" "exit-nonzero"
fi

# ---------------------------------------------------------------------------
printf 'Test 5 — ollama-check runs without crashing (no live server)\n'

# Provide a fake curl that always fails (simulates no Ollama server).
cat > "$tmp/bin/curl" <<'EOF'
#!/bin/bash
exit 1
EOF
chmod +x "$tmp/bin/curl"

output="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" ollama-check 2>&1 || true)"
check "ollama-check handles no server" "$output" *"no response from"*

# ---------------------------------------------------------------------------
printf '\n'
if (( fail == 0 )); then
  printf 'PASS: %d/%d tests passed\n' "$pass" "$(( pass + fail ))"
else
  printf 'FAIL: %d test(s) failed out of %d\n' "$fail" "$(( pass + fail ))"
  exit 1
fi
