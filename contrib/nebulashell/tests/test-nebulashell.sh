#!/usr/bin/env bash
# NebulaShell — regression tests
# Runs without a live Kilo installation or Ollama server.
# Usage: bash contrib/nebulashell/tests/test-nebulashell.sh
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/nebulashell.sh"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin"

pass=0; fail=0

_check() {
  local desc="$1" got="$2" want="$3"
  if [[ "$got" == $want ]]; then
    printf '  PASS: %s\n' "$desc"; (( pass++ )) || true
  else
    printf '  FAIL: %s\n' "$desc"
    printf '        want: %s\n' "$want"
    printf '        got:  %s\n' "$got"
    (( fail++ )) || true
  fi
}

# ────────────────────────────────────────────────────────────
# Fake kilo-desktop that echoes telemetry env and args
cat > "$tmp/bin/kilo-desktop" <<'FAKE'
#!/bin/bash
printf 'telemetry=%s args=%s\n' "${KILO_DISABLE_TELEMETRY:-unset}" "$*"
FAKE
chmod +x "$tmp/bin/kilo-desktop"

# ── Test 1: inside container — telemetry and args ────────────
printf 'Test 1 — inside container (kilo-desktop in PATH)\n'

out="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" run)"
_check "run sets KILO_DISABLE_TELEMETRY=1" "$out" "telemetry=1 args="

out="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" software-render)"
_check "software-render passes --disable-gpu" "$out" "telemetry=1 args=--disable-gpu"

out="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" run --extra-flag)"
_check "extra flags forwarded" "$out" "telemetry=1 args=--extra-flag"

# ── Test 2: doctor output ────────────────────────────────────
printf 'Test 2 — doctor output\n'

out="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" doctor 2>&1)"
_check "doctor shows D-Bus section"    "$out" *"D-Bus"*
_check "doctor shows Ollama section"   "$out" *"Ollama"*
_check "doctor shows GPU section"      "$out" *"GPU"*
_check "doctor shows no-changes note"  "$out" *"no changes made"*

# ── Test 3: Fedora host delegation ──────────────────────────
printf 'Test 3 — Fedora host delegation (no kilo-desktop, has distrobox)\n'

mkdir -p "$tmp/host-bin"
cat > "$tmp/host-bin/distrobox" <<'FAKE'
#!/bin/bash
printf 'distrobox: %s\n' "$*"
FAKE
chmod +x "$tmp/host-bin/distrobox"
ln -sf "$(command -v bash)" "$tmp/host-bin/bash"
ln -sf "$(command -v curl 2>/dev/null || true)" "$tmp/host-bin/curl" 2>/dev/null || true

out="$(PATH="$tmp/host-bin" bash "$SCRIPT" run)"
_check "host run delegates to distrobox"          "$out" *"enter kilo-debian -- env KILO_DISABLE_TELEMETRY=1 kilo-desktop"*

out="$(PATH="$tmp/host-bin" bash "$SCRIPT" software-render)"
_check "host software-render passes --disable-gpu" "$out" *"kilo-desktop --disable-gpu"*

# ── Test 4: unknown command exits non-zero ───────────────────
printf 'Test 4 — unknown command exits non-zero\n'

if PATH="$tmp/bin:$PATH" bash "$SCRIPT" badcommand >/dev/null 2>&1; then
  _check "unknown command exits non-zero" "exit-0" "exit-nonzero"
else
  _check "unknown command exits non-zero" "exit-nonzero" "exit-nonzero"
fi

# ── Test 5: ollama-check with no server ─────────────────────
printf 'Test 5 — ollama-check handles no server\n'

cat > "$tmp/bin/curl" <<'FAKE'
#!/bin/bash
exit 1
FAKE
chmod +x "$tmp/bin/curl"

out="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" ollama-check 2>&1 || true)"
_check "ollama-check reports no response" "$out" *"no response from"*

# ── Test 6: version command ──────────────────────────────────
printf 'Test 6 — version command\n'

out="$(PATH="$tmp/bin:$PATH" bash "$SCRIPT" version 2>&1)"
_check "version contains NebulaShell" "$out" *"NebulaShell"*

# ── Summary ──────────────────────────────────────────────────
printf '\n'
total=$(( pass + fail ))
if (( fail == 0 )); then
  printf 'PASS: %d/%d tests passed\n' "$pass" "$total"
else
  printf 'FAIL: %d/%d tests failed\n' "$fail" "$total"
  exit 1
fi
