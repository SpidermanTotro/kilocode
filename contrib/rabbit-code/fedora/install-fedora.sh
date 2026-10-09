#!/usr/bin/env bash
# User-level install of Rabbit Code Native; no sudo, Distrobox or .deb package.
set -euo pipefail
if [[ ${EUID:-1} -eq 0 ]]; then
  echo 'Please run as your regular Fedora user, not root.' >&2
  exit 2
fi
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SRC_ROOT="$(cd "$SELF_DIR/.." && pwd -P)"
APP_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/rabbit-code-native"
BIN_ROOT="${XDG_BIN_HOME:-$HOME/.local/bin}"
MENU_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APP_ROOT/fedora" "$BIN_ROOT" "$MENU_ROOT"
install -m 0644 "$SRC_ROOT/rabbit_local.py" "$APP_ROOT/rabbit_local.py"
install -m 0644 "$SELF_DIR/native_app.py" "$APP_ROOT/fedora/native_app.py"
{
  printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail'
  printf 'exec python3 %q "$@"\n' "$APP_ROOT/fedora/native_app.py"
} > "$BIN_ROOT/rabbit-code-native"
chmod 0755 "$BIN_ROOT/rabbit-code-native"
{
  printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Rabbit Code Native'
  printf '%s\n' 'Comment=Local Ollama coding assistant running on Fedora'
  printf 'Exec="%s"\n' "$BIN_ROOT/rabbit-code-native"
  printf '%s\n' 'Icon=utilities-terminal' 'Terminal=false' 'Categories=Development;IDE;'
} > "$MENU_ROOT/rabbit-code-native.desktop"
chmod 0644 "$MENU_ROOT/rabbit-code-native.desktop"
printf 'Rabbit Code Native installed for this user (Fedora host, no Debian/Distrobox).\n'
printf 'Run: %s\n' "$BIN_ROOT/rabbit-code-native"
printf 'Menu: Rabbit Code Native\nTo uninstall: remove the files in %s and the generated launcher/menu entries.\n' "$APP_ROOT"
