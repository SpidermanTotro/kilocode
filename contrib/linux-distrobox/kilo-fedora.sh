#!/usr/bin/env bash
# Kilo Desktop on Fedora via an existing Debian Distrobox.
# This script does not modify system files, container configuration, or GitHub.
#
# Usage:
#   bash kilo-fedora.sh [doctor|run|software-render|ollama-check] [extra Electron flags]
#
# Environment overrides (all optional):
#   KILO_DISTROBOX_CONTAINER  Container name (default: kilo-debian)
#   KILO_OLLAMA_HOST          Ollama base URL (default: http://127.0.0.1:11434)
#   KILO_OLLAMA_MODEL         Preferred model to verify on startup (default: none checked)
set -euo pipefail

BOX="${KILO_DISTROBOX_CONTAINER:-kilo-debian}"
OLLAMA_HOST="${KILO_OLLAMA_HOST:-http://127.0.0.1:11434}"
OLLAMA_MODEL="${KILO_OLLAMA_MODEL:-}"
MODE="${1:-doctor}"
shift || true

# ---------------------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: bash kilo-fedora.sh [doctor|run|software-render|ollama-check|ollama-setup] [extra flags]

  doctor          Read-only check of the existing installation and environment.
  run             Launch Kilo Desktop inside the existing Debian Distrobox.
  software-render Launch with --disable-gpu (workaround for blank/black windows).
  ollama-check    Test connectivity to the local Ollama server and list models.
  ollama-setup    Write Kilo Desktop config to use your local Ollama models.
                  Run this once before starting Kilo, with Kilo Desktop closed.

Environment variables:
  KILO_DISTROBOX_CONTAINER  Container name (default: kilo-debian)
  KILO_OLLAMA_HOST          Ollama API base URL (default: http://127.0.0.1:11434)
  KILO_OLLAMA_MODEL         Model name to verify is available (optional)

Telemetry note:
  KILO_DISABLE_TELEMETRY=1 is passed to suppress Kilo CLI telemetry.
  Kilo Desktop, LaunchDarkly, and Anaconda may still phone home independently.
EOF
}

# ---------------------------------------------------------------------------
# Returns 0 if we are already inside the Distrobox (kilo-desktop is in PATH).
inside_box() {
  command -v kilo-desktop >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# Launch kilo-desktop with the correct telemetry suppression env var.
launch_inside() {
  local -a args=("$@")
  printf 'Launching Kilo Desktop inside container.\n' >&2
  printf 'Note: KILO_DISABLE_TELEMETRY=1 set; Desktop/network telemetry not guaranteed off.\n' >&2
  exec env KILO_DISABLE_TELEMETRY=1 kilo-desktop "${args[@]}"
}

# ---------------------------------------------------------------------------
# Delegate to Distrobox from the Fedora host.
launch_from_host() {
  if ! command -v distrobox >/dev/null 2>&1; then
    printf 'ERROR: Neither kilo-desktop nor distrobox found in PATH.\n' >&2
    printf 'Run this script on your Fedora host or inside the kilo-debian container.\n' >&2
    exit 2
  fi
  printf 'Entering existing Distrobox: %s\n' "$BOX" >&2
  printf 'Note: KILO_DISABLE_TELEMETRY=1 set; Desktop/network telemetry not guaranteed off.\n' >&2
  exec distrobox enter "$BOX" -- env KILO_DISABLE_TELEMETRY=1 kilo-desktop "$@"
}

# ---------------------------------------------------------------------------
# Read-only environment diagnostics.
doctor_inside() {
  printf 'Kilo Desktop — Fedora/Distrobox diagnostics (read-only)\n'
  printf '==========================================================\n'

  # Executable
  if command -v kilo-desktop >/dev/null 2>&1; then
    printf '  executable:        %s\n' "$(command -v kilo-desktop)"
  else
    printf '  executable:        NOT FOUND\n'
  fi

  # Installed package (Debian container)
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='  installed package: ${Package} ${Version} (${Status})\n' \
      kilo-desktop 2>/dev/null || printf '  installed package: not found via dpkg\n'
  fi

  # Display / Wayland
  printf '  XDG_SESSION_TYPE:  %s\n' "${XDG_SESSION_TYPE:-unset}"
  printf '  DISPLAY:           %s\n' "${DISPLAY:-unset}"
  printf '  WAYLAND_DISPLAY:   %s\n' "${WAYLAND_DISPLAY:-unset}"

  # D-Bus
  if [[ -S /run/dbus/system_bus_socket ]]; then
    printf '  system D-Bus:      socket present\n'
  else
    printf '  system D-Bus:      socket unavailable (often non-fatal in Distrobox)\n'
  fi
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    printf '  session D-Bus:     configured (%s)\n' "${DBUS_SESSION_BUS_ADDRESS%%,*}"
  else
    printf '  session D-Bus:     address unset\n'
  fi

  # GPU
  if [[ -e /dev/dri/renderD128 || -e /dev/dri/card0 ]]; then
    printf '  DRM GPU device:    visible\n'
  else
    printf '  DRM GPU device:    not visible (GPU acceleration may be unavailable)\n'
  fi

  # Ollama
  _check_ollama

  printf '\nDiagnostics only: no changes made.\n'
}

# ---------------------------------------------------------------------------
# Ollama connectivity check (used by both doctor and ollama-check).
_check_ollama() {
  if ! command -v curl >/dev/null 2>&1; then
    printf '  Ollama:            curl not available, skipping check\n'
    return
  fi

  local tags
  tags="$(curl -fs --max-time 3 "${OLLAMA_HOST}/api/tags" 2>/dev/null || true)"
  if [[ -z "$tags" ]]; then
    printf '  Ollama:            no response from %s\n' "$OLLAMA_HOST"
    return
  fi

  printf '  Ollama endpoint:   reachable (%s)\n' "$OLLAMA_HOST"

  # List model names if jq is available
  if command -v jq >/dev/null 2>&1; then
    local models
    models="$(printf '%s' "$tags" | jq -r '.models[].name' 2>/dev/null | tr '\n' '  ' || true)"
    if [[ -n "$models" ]]; then
      printf '  Ollama models:     %s\n' "$models"
    else
      printf '  Ollama models:     (none pulled yet)\n'
    fi

    # Verify preferred model if set
    if [[ -n "$OLLAMA_MODEL" ]]; then
      if printf '%s' "$tags" | jq -e --arg m "$OLLAMA_MODEL" \
          '.models[] | select(.name==$m)' >/dev/null 2>&1; then
        printf '  Preferred model:   %s — FOUND\n' "$OLLAMA_MODEL"
      else
        printf '  Preferred model:   %s — NOT FOUND (run: ollama pull %s)\n' \
          "$OLLAMA_MODEL" "$OLLAMA_MODEL"
      fi
    fi
  else
    printf '  Ollama models:     install jq for model listing\n'
  fi
}

# ---------------------------------------------------------------------------
# Stand-alone ollama-check command.
ollama_check() {
  printf 'Ollama connectivity check\n'
  printf '  host: %s\n' "$OLLAMA_HOST"
  [[ -n "$OLLAMA_MODEL" ]] && printf '  preferred model: %s\n' "$OLLAMA_MODEL"
  _check_ollama
}

# ---------------------------------------------------------------------------
# ollama-setup: write Kilo Desktop model-preferences.json to use Ollama.
# Kilo Desktop must NOT be running when this is called.
ollama_setup() {
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Kilo Desktop/plugins/kilo-ui"
  local prefs="$config_dir/model-preferences.json"

  # Require Ollama to be reachable first.
  if ! command -v curl >/dev/null 2>&1; then
    printf 'ERROR: curl is required for ollama-setup.\n' >&2
    exit 1
  fi
  local tags
  tags="$(curl -fs --max-time 3 "${OLLAMA_HOST}/api/tags" 2>/dev/null || true)"
  if [[ -z "$tags" ]]; then
    printf 'ERROR: Ollama not reachable at %s.\n' "$OLLAMA_HOST" >&2
    printf 'Start Ollama first: ollama serve\n' >&2
    exit 1
  fi

  # Pick the model to register: prefer KILO_OLLAMA_MODEL, else first available.
  local model=""
  if [[ -n "$OLLAMA_MODEL" ]]; then
    model="$OLLAMA_MODEL"
  elif command -v jq >/dev/null 2>&1; then
    model="$(printf '%s' "$tags" | jq -r '.models[0].name // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$model" ]]; then
    printf 'ERROR: No Ollama models found. Run: ollama pull qwen2.5-coder:7b\n' >&2
    exit 1
  fi

  printf 'Setting up Kilo Desktop to use Ollama model: %s\n' "$model"
  printf '  Config: %s\n' "$prefs"

  # Back up existing config.
  if [[ -f "$prefs" ]]; then
    cp "$prefs" "${prefs}.bak"
    printf '  Backed up existing config to %s.bak\n' "$prefs"
  fi

  mkdir -p "$config_dir"

  # Write the model-preferences.json.
  # providerID "ollama" is the built-in Kilo Desktop Ollama provider.
  cat > "$prefs" <<EOF
{
	"modelSelections": {},
	"variantSelections": {},
	"recentModels": [
		{
			"providerID": "ollama",
			"modelID": "${model}"
		}
	],
	"autoFreeModelsEnabled": true
}
EOF

  printf '  Done. Start Kilo Desktop and select Ollama / %s from the model picker.\n' "$model"
  printf '  If Ollama does not appear, open Kilo settings → Models → Add provider → Ollama\n'
  printf '  and set the base URL to: %s\n' "$OLLAMA_HOST"
}

# ---------------------------------------------------------------------------
case "$MODE" in
  -h|--help|help)
    usage
    ;;

  doctor)
    if inside_box; then
      doctor_inside
    elif command -v distrobox >/dev/null 2>&1; then
      printf 'Checking existing Distrobox %s...\n' "$BOX"
      exec distrobox enter "$BOX" -- bash "$0" doctor
    else
      printf 'ERROR: Run on Fedora (with distrobox) or inside the kilo-debian container.\n' >&2
      exit 2
    fi
    ;;

  run)
    if inside_box; then
      launch_inside "$@"
    else
      launch_from_host "$@"
    fi
    ;;

  software-render)
    # Workaround for blank/black Electron window on some GPU drivers.
    if inside_box; then
      launch_inside --disable-gpu "$@"
    else
      launch_from_host --disable-gpu "$@"
    fi
    ;;

  ollama-check)
    ollama_check
    ;;

  ollama-setup)
    ollama_setup
    ;;

  *)
    printf 'Unknown command: %s\n' "$MODE" >&2
    usage >&2
    exit 2
    ;;
esac
