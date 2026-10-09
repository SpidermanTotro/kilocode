#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════╗
# ║              NebulaShell — Fedora AI Launcher            ║
# ║   Kilo Desktop · Distrobox · Ollama · Local Inference    ║
# ╚══════════════════════════════════════════════════════════╝
#
# Launches Kilo Desktop from a Fedora host via a Debian Distrobox
# container, with Ollama local-model integration.
#
# Usage:
#   bash nebulashell.sh [COMMAND] [OPTIONS]
#
# Environment:
#   NEBULA_CONTAINER      Distrobox container name   (default: kilo-debian)
#   NEBULA_OLLAMA_HOST    Ollama base URL             (default: http://127.0.0.1:11434)
#   NEBULA_OLLAMA_MODEL   Preferred model to verify   (default: none)

set -euo pipefail

# ── Identity ────────────────────────────────────────────────
NEBULA_VERSION="1.0.0"
NEBULA_BANNER="NebulaShell v${NEBULA_VERSION}"

# ── Configuration ───────────────────────────────────────────
CONTAINER="${NEBULA_CONTAINER:-kilo-debian}"
OLLAMA_HOST="${NEBULA_OLLAMA_HOST:-http://127.0.0.1:11434}"
OLLAMA_MODEL="${NEBULA_OLLAMA_MODEL:-}"
COMMAND="${1:-doctor}"
shift || true

# ── Helpers ─────────────────────────────────────────────────
_banner() {
  printf '\n  ◈ %s\n\n' "$NEBULA_BANNER" >&2
}

_info()  { printf '  › %s\n'        "$*" >&2; }
_ok()    { printf '  ✓ %s\n'        "$*" >&2; }
_warn()  { printf '  ⚠ %s\n'        "$*" >&2; }
_err()   { printf '  ✗ %s\n'        "$*" >&2; }
_sep()   { printf '  %s\n' "────────────────────────────────────────" >&2; }

# ── Usage ───────────────────────────────────────────────────
usage() {
  cat >&2 <<'EOF'

  NebulaShell — Fedora AI Launcher

  COMMANDS
    doctor          Read-only diagnostics: container, display, GPU, Ollama
    run             Launch Kilo Desktop via Distrobox
    software-render Launch with --disable-gpu (blank window workaround)
    ollama-check    Verify Ollama is running and list available models
    ollama-setup    Configure Kilo Desktop to use your local Ollama models
    version         Print NebulaShell version

  ENVIRONMENT VARIABLES
    NEBULA_CONTAINER      Distrobox container name   (default: kilo-debian)
    NEBULA_OLLAMA_HOST    Ollama API base URL         (default: http://127.0.0.1:11434)
    NEBULA_OLLAMA_MODEL   Preferred Ollama model      (e.g. qwen2.5-coder:7b)

  EXAMPLES
    bash nebulashell.sh doctor
    bash nebulashell.sh run
    NEBULA_OLLAMA_MODEL=qwen2.5-coder:7b bash nebulashell.sh ollama-setup
    bash nebulashell.sh ollama-check

  TELEMETRY NOTE
    KILO_DISABLE_TELEMETRY=1 is passed on every launch to suppress Kilo CLI
    telemetry. Kilo Desktop, LaunchDarkly and Anaconda may still phone home
    independently — control this via Kilo's in-app privacy settings.

EOF
}

# ── Container detection ─────────────────────────────────────
_in_container() {
  # Returns 0 if kilo-desktop is reachable (we're inside the container)
  command -v kilo-desktop >/dev/null 2>&1
}

_require_distrobox() {
  if ! command -v distrobox >/dev/null 2>&1; then
    _err "distrobox not found in PATH."
    _err "Install it on Fedora:  sudo dnf install distrobox"
    _err "Or run this script from inside the ${CONTAINER} container."
    exit 2
  fi
}

# ── Launch helpers ──────────────────────────────────────────
_launch_inside() {
  local -a extra=("$@")
  _info "Launching Kilo Desktop inside container…"
  _warn "KILO_DISABLE_TELEMETRY=1 set — Desktop/network telemetry not guaranteed off."
  exec env KILO_DISABLE_TELEMETRY=1 kilo-desktop "${extra[@]}"
}

_launch_from_host() {
  _require_distrobox
  _info "Entering Distrobox: ${CONTAINER}"
  _warn "KILO_DISABLE_TELEMETRY=1 set — Desktop/network telemetry not guaranteed off."
  exec distrobox enter "$CONTAINER" -- env KILO_DISABLE_TELEMETRY=1 kilo-desktop "$@"
}

# ── Ollama helpers ──────────────────────────────────────────
_ollama_tags() {
  command -v curl >/dev/null 2>&1 || { printf ''; return; }
  curl -fs --max-time 3 "${OLLAMA_HOST}/api/tags" 2>/dev/null || printf ''
}

_check_ollama() {
  local tags
  tags="$(_ollama_tags)"
  if [[ -z "$tags" ]]; then
    _warn "Ollama: no response from ${OLLAMA_HOST}"
    return 1
  fi
  _ok "Ollama endpoint reachable: ${OLLAMA_HOST}"

  if command -v jq >/dev/null 2>&1; then
    local models
    models="$(printf '%s' "$tags" | jq -r '.models[].name' 2>/dev/null | tr '\n' '  ')"
    if [[ -n "$models" ]]; then
      _ok "Models available: ${models}"
    else
      _warn "No models pulled yet. Try: ollama pull qwen2.5-coder:7b"
    fi
    if [[ -n "$OLLAMA_MODEL" ]]; then
      if printf '%s' "$tags" | jq -e --arg m "$OLLAMA_MODEL" \
          '.models[] | select(.name==$m)' >/dev/null 2>&1; then
        _ok "Preferred model '${OLLAMA_MODEL}': found"
      else
        _warn "Preferred model '${OLLAMA_MODEL}': NOT found — run: ollama pull ${OLLAMA_MODEL}"
      fi
    fi
  else
    _warn "Install jq for model listing: sudo dnf install jq"
  fi
  return 0
}

# ── Commands ─────────────────────────────────────────────────

cmd_doctor() {
  _banner
  _sep
  _info "Container: ${CONTAINER}"

  # Executable
  if command -v kilo-desktop >/dev/null 2>&1; then
    _ok "kilo-desktop: $(command -v kilo-desktop)"
  else
    _warn "kilo-desktop: not in PATH (run from Fedora host, not inside container)"
  fi

  # Package version (Debian container)
  if command -v dpkg-query >/dev/null 2>&1; then
    local pkg
    pkg="$(dpkg-query -W -f='${Package} ${Version}' kilo-desktop 2>/dev/null || true)"
    [[ -n "$pkg" ]] && _ok "Installed: ${pkg}"
  fi

  _sep
  _info "Display"
  _info "  XDG_SESSION_TYPE : ${XDG_SESSION_TYPE:-unset}"
  _info "  DISPLAY          : ${DISPLAY:-unset}"
  _info "  WAYLAND_DISPLAY  : ${WAYLAND_DISPLAY:-unset}"

  _sep
  _info "D-Bus"
  if [[ -S /run/dbus/system_bus_socket ]]; then
    _ok  "System D-Bus socket: present"
  else
    _warn "System D-Bus socket: unavailable (non-fatal in Distrobox)"
  fi
  if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
    _ok  "Session D-Bus: configured"
  else
    _warn "Session D-Bus: address unset"
  fi

  _sep
  _info "GPU"
  if [[ -e /dev/dri/renderD128 || -e /dev/dri/card0 ]]; then
    _ok "DRM device visible (GPU acceleration available)"
  else
    _warn "DRM device not visible — use 'software-render' if window is blank"
  fi

  _sep
  _info "Ollama (host: ${OLLAMA_HOST})"
  _check_ollama || true

  _sep
  printf '  Diagnostics complete — no changes made.\n\n' >&2
}

cmd_run() {
  if _in_container; then
    _launch_inside "$@"
  else
    _launch_from_host "$@"
  fi
}

cmd_software_render() {
  _warn "Software rendering mode: reduced performance, fixes blank/black windows."
  if _in_container; then
    _launch_inside --disable-gpu "$@"
  else
    _launch_from_host --disable-gpu "$@"
  fi
}

cmd_ollama_check() {
  _banner
  _sep
  _info "Ollama check"
  _info "  Host  : ${OLLAMA_HOST}"
  [[ -n "$OLLAMA_MODEL" ]] && _info "  Model : ${OLLAMA_MODEL}"
  _sep
  _check_ollama || true
  printf '\n' >&2
}

cmd_ollama_setup() {
  _banner
  _sep
  _info "Configuring Kilo Desktop to use Ollama"
  _warn "Close Kilo Desktop before running this command."
  _sep

  local tags
  tags="$(_ollama_tags)"
  if [[ -z "$tags" ]]; then
    _err "Ollama not reachable at ${OLLAMA_HOST}."
    _err "Start Ollama first:  ollama serve"
    exit 1
  fi
  _ok "Ollama reachable"

  # Pick model
  local model="$OLLAMA_MODEL"
  if [[ -z "$model" ]] && command -v jq >/dev/null 2>&1; then
    model="$(printf '%s' "$tags" | jq -r '.models[0].name // empty' 2>/dev/null || true)"
  fi
  if [[ -z "$model" ]]; then
    _err "No Ollama models found. Pull one first:"
    _err "  ollama pull qwen2.5-coder:7b"
    exit 1
  fi
  _ok "Using model: ${model}"

  # Write Kilo Desktop model-preferences.json
  local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Kilo Desktop/plugins/kilo-ui"
  local prefs_file="${config_dir}/model-preferences.json"

  if [[ -f "$prefs_file" ]]; then
    cp "$prefs_file" "${prefs_file}.nebula.bak"
    _info "Backed up: ${prefs_file}.nebula.bak"
  fi

  mkdir -p "$config_dir"
  cat > "$prefs_file" <<EOF
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

  _ok "Written: ${prefs_file}"
  _sep
  _info "Next: launch Kilo and select  Ollama › ${model}  in the model picker."
  _info "If Ollama doesn't appear: Kilo Settings → Models → Add → Ollama"
  _info "  Base URL: ${OLLAMA_HOST}"
  printf '\n' >&2
}

cmd_version() {
  printf '%s\n' "$NEBULA_BANNER"
}

# ── Dispatch ─────────────────────────────────────────────────
case "$COMMAND" in
  -h|--help|help) usage ;;
  doctor)         cmd_doctor ;;
  run)            cmd_run "$@" ;;
  software-render) cmd_software_render "$@" ;;
  ollama-check)   cmd_ollama_check ;;
  ollama-setup)   cmd_ollama_setup ;;
  version)        cmd_version ;;
  *)
    _err "Unknown command: ${COMMAND}"
    usage
    exit 2
    ;;
esac
