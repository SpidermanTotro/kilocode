#!/usr/bin/env bash
# Kilo Desktop on Fedora via an existing Debian Distrobox.
# This script does not modify system files, container configuration, or GitHub.
set -euo pipefail

BOX="${KILO_DISTROBOX_CONTAINER:-kilo-debian}"
MODE="${1:-doctor}"
shift || true

usage() {
  cat <<'EOF'
Usage: bash kilo-fedora.sh [doctor|run|software-render] [additional Electron flags]

  doctor           Check the existing installation and desktop environment.
  run              Launch Kilo in the existing Debian Distrobox.
  software-render  Retry with --disable-gpu if the graphical window is blank.

Environment: KILO_DISTROBOX_CONTAINER sets the container name (default kilo-debian).
The launcher sets KILO_TELEMETRY_LEVEL=off for Kilo CLI telemetry only.
It does NOT guarantee that Kilo Desktop, LaunchDarkly, or Anaconda are offline.
EOF
}

inside_box() {
  # A distrobox provides the kilo-desktop command; its host may not.
  command -v kilo-desktop >/dev/null 2>&1
}

launch_inside() {
  local -a args=("$@")
  printf 'Launching Kilo Desktop in the existing container.\n' >&2
  printf 'Note: CLI telemetry requested off; Desktop/network telemetry is not guaranteed off.\n' >&2
  exec env KILO_TELEMETRY_LEVEL=off kilo-desktop "${args[@]}"
}

launch_from_host() {
  if ! command -v distrobox >/dev/null 2>&1; then
    printf 'ERROR: Neither kilo-desktop nor distrobox is available in PATH.\n' >&2
    exit 2
  fi
  printf 'Entering existing Distrobox: %s\n' "$BOX" >&2
  printf 'Note: CLI telemetry requested off; Desktop/network telemetry is not guaranteed off.\n' >&2
  exec distrobox enter "$BOX" -- env KILO_TELEMETRY_LEVEL=off kilo-desktop "$@"
}

doctor_inside() {
  printf 'Kilo Desktop in Distrobox — read-only checks\n'
  printf '  executable: %s\n' "$(command -v kilo-desktop)"
  if command -v dpkg-query >/dev/null 2>&1; then
    dpkg-query -W -f='  installed package: ${Package} ${Version} (${Status})\n' kilo-desktop 2>/dev/null || true
  fi
  printf '  XDG_SESSION_TYPE: %s\n' "${XDG_SESSION_TYPE:-unset}"
  printf '  DISPLAY: %s\n' "${DISPLAY:-unset}"
  printf '  WAYLAND_DISPLAY: %s\n' "${WAYLAND_DISPLAY:-unset}"
  if [[ -S /run/dbus/system_bus_socket ]]; then
    printf '  system D-Bus socket: present\n'
  else
    printf '  system D-Bus socket: unavailable (often non-fatal in Distrobox)\n'
  fi
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    printf '  session D-Bus address: configured\n'
  else
    printf '  session D-Bus address: unset\n'
  fi
  if [[ -e /dev/dri/renderD128 || -e /dev/dri/card0 ]]; then
    printf '  DRM graphics device: visible\n'
  else
    printf '  DRM graphics device: not visible (may affect GPU acceleration)\n'
  fi
  if command -v curl >/dev/null 2>&1; then
    if curl -fs --max-time 2 -o /dev/null http://127.0.0.1:11434/api/tags; then
      printf '  Ollama: HTTP endpoint reachable on localhost:11434\n'
    else
      printf '  Ollama: no HTTP response from localhost:11434 (not necessarily broken)\n'
    fi
  fi
  printf '\nDiagnostics only: no changes made.\n'
}

case "$MODE" in
  -h|--help|help) usage ;;
  doctor)
    if inside_box; then
      doctor_inside
    elif command -v distrobox >/dev/null 2>&1; then
      printf 'Checking existing Distrobox %s...\n' "$BOX"
      exec distrobox enter "$BOX" -- bash "$0" doctor
    else
      printf 'ERROR: Run this on Fedora (with distrobox) or inside the kilo-debian container.\n' >&2
      exit 2
    fi
    ;;
  run)
    if inside_box; then launch_inside "$@"; else launch_from_host "$@"; fi
    ;;
  software-render)
    # Emergency workaround for black/blank windows only; reduced performance.
    if inside_box; then launch_inside --disable-gpu "$@"; else launch_from_host --disable-gpu "$@"; fi
    ;;
  *)
    printf 'Unknown mode: %s\n' "$MODE" >&2
    usage >&2
    exit 2
    ;;
esac