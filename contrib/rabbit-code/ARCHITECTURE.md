# Rabbit Code teardown and independence plan

- Original: SpidermanTotro/kilocode fork of Kilo-Org/kilocode, licensed MIT. Preserve notices.
- The public packages/opencode CLI/backend is available for inspection and incremental replacement.
- The public packages/kilo-vscode extension is optional, not part of the independent native UI.
- Kilo Desktop Electron sources are not present; do not claim that app can be rebuilt from this fork.
- Existing feat/nebulashell branch remains an optional Debian/Distrobox launcher, not Rabbit Code core.
- Existing rabbit-foundry engine and SwitchStudio Next are separate; do not modify them.

## Phases

v0.1 (this branch): Fedora host native Python service/browser UI, Ollama local-only chats; separate project-scoped Kilo CLI adapter.
v0.2: read-only project browser with explicit directory boundaries.
v0.3: structured patch preview and user-approved apply/undo.
v0.4: sandboxed local agent tools, permissions, audit logs, and network-isolated tests.
v0.5: independent Fedora RPM/Flatpak and native app window.
v1.0: independent features supported by measured tests; no Kilo Desktop dependency.

## Security

Loopback-only bind; reject cross-site Host, Origin, and token; no CORS; refuse uninstalled model IDs; no proxies or redirects to remote inference; no file-serving, shell-execution or cloud-provider paths.
Mocked unit tests cannot prove the native GUI or Ollama inference on real Fedora. Keep a tested rollback path and don't delete kilo-debian until the replacement is operational.
