#!/usr/bin/env bash
# First-time setup: create the kilo-debian Distrobox and install Kilo Desktop.
# Run this ONCE on your Fedora host. Requires distrobox and internet access.
#
# Usage:
#   bash contrib/linux-distrobox/setup-container.sh [--dry-run]
#
# What it does:
#   1. Creates a Debian Trixie Distrobox container named kilo-debian
#   2. Installs Kilo Desktop 0.1.11 inside the container
#   3. Verifies the installation
#   4. Installs kilo-fedora.sh to ~/.local/bin/kilo-fedora on the Fedora host
#
# What it does NOT do:
#   - Modify any system files outside the container
#   - Install GPU drivers or Ollama (separate steps)
#   - Override any existing container with the same name (safe to re-run check)
set -euo pipefail

CONTAINER="${KILO_DISTROBOX_CONTAINER:-kilo-debian}"
CONTAINER_IMAGE="${KILO_CONTAINER_IMAGE:-docker.io/library/debian:trixie}"
DRY_RUN=false
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    -h|--help)
      printf 'Usage: bash setup-container.sh [--dry-run]\n'
      printf '  --dry-run  Print what would happen without making any changes.\n'
      exit 0
      ;;
  esac
done

step() { printf '\n==> %s\n' "$*"; }
info() { printf '    %s\n' "$*"; }
run()  {
  if [[ "$DRY_RUN" == true ]]; then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# ---------------------------------------------------------------------------
step "Checking prerequisites"

if ! command -v distrobox >/dev/null 2>&1; then
  printf 'ERROR: distrobox not found. Install it first:\n' >&2
  printf '  sudo dnf install distrobox\n' >&2
  exit 1
fi
info "distrobox: $(distrobox --version 2>/dev/null | head -1)"

if ! command -v curl >/dev/null 2>&1; then
  printf 'ERROR: curl is required.\n' >&2
  exit 1
fi

# ---------------------------------------------------------------------------
step "Checking for existing container: $CONTAINER"

if distrobox list 2>/dev/null | grep -q "^[^|]*|[[:space:]]*${CONTAINER}[[:space:]]*|"; then
  info "Container '$CONTAINER' already exists — skipping creation."
  CREATE_CONTAINER=false
else
  info "Container '$CONTAINER' not found — will create it."
  CREATE_CONTAINER=true
fi

# ---------------------------------------------------------------------------
if [[ "$CREATE_CONTAINER" == true ]]; then
  step "Creating Distrobox container: $CONTAINER (image: $CONTAINER_IMAGE)"
  run distrobox create \
    --name "$CONTAINER" \
    --image "$CONTAINER_IMAGE" \
    --yes
fi

# ---------------------------------------------------------------------------
step "Installing Kilo Desktop inside $CONTAINER"

# Kilo Desktop provides a Linux install script.
# We run it non-interactively inside the container.
INSTALL_CMD='set -euo pipefail
if command -v kilo-desktop >/dev/null 2>&1; then
  echo "kilo-desktop already installed: $(dpkg-query -W -f='"'"'${Version}'"'"' kilo-desktop 2>/dev/null || echo unknown)"
  exit 0
fi
echo "Updating apt..."
apt-get update -qq
echo "Installing curl and dependencies..."
apt-get install -y -qq curl libgtk-3-0 libnss3 libasound2 libxss1 libgbm1
echo "Downloading Kilo Desktop installer..."
curl -fsSL https://kilocode.ai/install/linux -o /tmp/kilo-install.sh
bash /tmp/kilo-install.sh --yes
rm -f /tmp/kilo-install.sh
echo "kilo-desktop installed: $(dpkg-query -W -f='"'"'${Package} ${Version}'"'"' kilo-desktop 2>/dev/null)"'

run distrobox enter "$CONTAINER" -- bash -c "$INSTALL_CMD"

# ---------------------------------------------------------------------------
step "Verifying installation"

VERIFY_CMD='command -v kilo-desktop && kilo-desktop --version 2>&1 | head -3 || echo "VERIFY FAILED"'
run distrobox enter "$CONTAINER" -- bash -c "$VERIFY_CMD"

# ---------------------------------------------------------------------------
step "Installing kilo-fedora launcher to ~/.local/bin"

LOCAL_BIN="$HOME/.local/bin"
run mkdir -p "$LOCAL_BIN"
run cp "$SCRIPT_DIR/kilo-fedora.sh" "$LOCAL_BIN/kilo-fedora"
run chmod +x "$LOCAL_BIN/kilo-fedora"
info "Installed: $LOCAL_BIN/kilo-fedora"

# Remind user to add ~/.local/bin to PATH if needed.
if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
  info "Note: Add ~/.local/bin to your PATH:"
  info "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
fi

# ---------------------------------------------------------------------------
step "Installing .desktop entry"

DESKTOP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
run mkdir -p "$DESKTOP_DIR"
run cp "$SCRIPT_DIR/kilo-desktop-distrobox.desktop" "$DESKTOP_DIR/"
run sed -i "s|Exec=kilo-fedora|Exec=$LOCAL_BIN/kilo-fedora|g" \
  "$DESKTOP_DIR/kilo-desktop-distrobox.desktop" 2>/dev/null || true
info "Desktop entry: $DESKTOP_DIR/kilo-desktop-distrobox.desktop"

if command -v update-desktop-database >/dev/null 2>&1; then
  run update-desktop-database "$DESKTOP_DIR" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
printf '\n'
if [[ "$DRY_RUN" == true ]]; then
  printf 'Dry-run complete. No changes were made.\n'
else
  printf 'Setup complete!\n\n'
  printf 'Next steps:\n'
  printf '  1. Run diagnostics:     kilo-fedora doctor\n'
  printf '  2. Connect to Ollama:   kilo-fedora ollama-setup\n'
  printf '  3. Launch Kilo:         kilo-fedora run\n'
  printf '  4. Or use app menu:     search for "Kilo Desktop"\n'
fi
