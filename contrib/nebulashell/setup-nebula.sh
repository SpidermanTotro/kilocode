#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║         NebulaShell — First-Time Container Setup         ║
# ╚══════════════════════════════════════════════════════════╝
#
# Run ONCE on your Fedora host to:
#   1. Create a Debian Distrobox container (kilo-debian)
#   2. Install Kilo Desktop inside it
#   3. Install nebulashell to ~/.local/bin/nebulashell
#   4. Add a Fedora app-menu .desktop entry
#
# Usage:
#   bash setup-nebula.sh [--dry-run] [--container NAME]
#
# Does NOT modify system files or install GPU drivers.
set -euo pipefail

NEBULA_VERSION="1.0.0"
CONTAINER="${NEBULA_CONTAINER:-kilo-debian}"
CONTAINER_IMAGE="${NEBULA_CONTAINER_IMAGE:-docker.io/library/debian:trixie}"
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── Arg parsing ──────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)          DRY_RUN=true ;;
    --container)        CONTAINER="$2"; shift ;;
    --container=*)      CONTAINER="${1#*=}" ;;
    -h|--help)
      printf 'NebulaShell v%s — setup\n\n' "$NEBULA_VERSION"
      printf 'Usage: bash setup-nebula.sh [--dry-run] [--container NAME]\n\n'
      printf '  --dry-run          Show what would happen without making changes\n'
      printf '  --container NAME   Use a different Distrobox container name\n'
      exit 0
      ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
  shift
done

# ── Helpers ──────────────────────────────────────────────────
_step() { printf '\n  ◈ %s\n' "$*"; }
_ok()   { printf '    ✓ %s\n' "$*"; }
_info() { printf '    › %s\n' "$*"; }
_warn() { printf '    ⚠ %s\n' "$*"; }
_err()  { printf '    ✗ %s\n' "$*" >&2; }

_run() {
  if [[ "$DRY_RUN" == true ]]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# ── Header ───────────────────────────────────────────────────
printf '\n'
printf '  ╔══════════════════════════════════════════╗\n'
printf '  ║     NebulaShell v%-6s — Setup          ║\n' "$NEBULA_VERSION"
printf '  ╚══════════════════════════════════════════╝\n'
[[ "$DRY_RUN" == true ]] && printf '\n  [ DRY-RUN MODE — no changes will be made ]\n'

# ── Prerequisites ────────────────────────────────────────────
_step "Checking prerequisites"

if ! command -v distrobox >/dev/null 2>&1; then
  _err "distrobox not found."
  _err "Install it: sudo dnf install distrobox"
  exit 1
fi
_ok "distrobox: $(distrobox --version 2>/dev/null | head -1)"

if ! command -v curl >/dev/null 2>&1; then
  _err "curl is required."
  exit 1
fi
_ok "curl: present"

# ── Container ────────────────────────────────────────────────
_step "Distrobox container: ${CONTAINER}"

if distrobox list 2>/dev/null | grep -qE "[[:space:]]${CONTAINER}[[:space:]]"; then
  _ok "Container '${CONTAINER}' already exists — skipping creation"
  CREATE=false
else
  _info "Container '${CONTAINER}' not found — will create from ${CONTAINER_IMAGE}"
  CREATE=true
fi

if [[ "$CREATE" == true ]]; then
  _run distrobox create --name "$CONTAINER" --image "$CONTAINER_IMAGE" --yes
  _ok "Container created"
fi

# ── Install Kilo Desktop ─────────────────────────────────────
_step "Installing Kilo Desktop inside ${CONTAINER}"

INSTALL_CMD='set -euo pipefail
if command -v kilo-desktop >/dev/null 2>&1; then
  VER=$(dpkg-query -W -f="${Version}" kilo-desktop 2>/dev/null || echo "?")
  echo "Already installed: kilo-desktop ${VER}"
  exit 0
fi
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq curl libgtk-3-0 libnss3 libasound2 libxss1 libgbm1 jq
curl -fsSL https://kilocode.ai/install/linux -o /tmp/kilo-install.sh
bash /tmp/kilo-install.sh --yes
rm -f /tmp/kilo-install.sh
dpkg-query -W -f="Installed: ${Package} ${Version}\n" kilo-desktop'

_run distrobox enter "$CONTAINER" -- bash -c "$INSTALL_CMD"

# ── Verify ───────────────────────────────────────────────────
_step "Verifying installation"
_run distrobox enter "$CONTAINER" -- bash -c \
  'command -v kilo-desktop && kilo-desktop --version 2>&1 | head -2 || echo "VERIFY FAILED"'

# ── Install nebulashell launcher ─────────────────────────────
_step "Installing nebulashell launcher"

LOCAL_BIN="$HOME/.local/bin"
_run mkdir -p "$LOCAL_BIN"
_run cp "${SCRIPT_DIR}/nebulashell.sh" "${LOCAL_BIN}/nebulashell"
_run chmod +x "${LOCAL_BIN}/nebulashell"
_ok "Installed: ${LOCAL_BIN}/nebulashell"

if [[ ":$PATH:" != *":${LOCAL_BIN}:"* ]]; then
  _warn "~/.local/bin is not in your PATH. Add it:"
  _warn "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc && source ~/.bashrc"
fi

# ── Desktop entry ────────────────────────────────────────────
_step "Installing app-menu entry"

DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
_run mkdir -p "$DESKTOP_DIR"
_run cp "${SCRIPT_DIR}/nebulashell.desktop" "$DESKTOP_DIR/"
_ok "Entry: ${DESKTOP_DIR}/nebulashell.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  _run update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# ── Done ─────────────────────────────────────────────────────
printf '\n'
if [[ "$DRY_RUN" == true ]]; then
  printf '  Dry-run complete — nothing was changed.\n\n'
else
  printf '  ✓ NebulaShell setup complete!\n\n'
  printf '  Next steps:\n'
  printf '    nebulashell doctor         — run diagnostics\n'
  printf '    nebulashell ollama-setup   — connect Kilo to Ollama\n'
  printf '    nebulashell run            — launch Kilo Desktop\n'
  printf '\n'
fi
