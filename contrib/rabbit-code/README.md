# Rabbit Code Native v0.1 — Fedora host, local-first

Rabbit Code Native is an independent Python-standard-library prototype. It does not need Debian, Distrobox, Electron, Kilo Desktop, a Kilo login, or remote inference.
Native UI runs on 127.0.0.1:8766; it requests models only from the existing host Ollama daemon at 127.0.0.1:11434.

## Launch on Fedora

From the feat/rabbit-code-fedora-native branch of this repo, on the FEDORA HOST:

```bash
ollama list
python3 contrib/rabbit-code/fedora/native_app.py
```

Open http://127.0.0.1:8766/ in the Fedora browser if one does not appear. Ctrl+C stops the local service.

Optional **per-user GNOME application menu** (no sudo):

```bash
bash contrib/rabbit-code/fedora/install-fedora.sh
"$HOME/.local/bin/rabbit-code-native"
```

This installer writes only under your own XDG data/bin folders. It does not remove or touch your Debian Distrobox or original Kilo Desktop; keep those installed until the native app passes real Fedora tests.

## Capabilities and boundaries

- Local model picker, coding chat, and reset. Only installed Ollama model IDs are allowed.
- Loopback HTTP server with random POST token, Host/Origin checks, and request size limits.
- Local Ollama only: no HTTP proxies, no redirects, no cloud model fallback, no CDN.
- No repo access, file writes, shell commands, Git mutations, tool execution, account requirement, or automatic downloads.
- Conversation history lives in the browser tab only; Ollama and the browser may still keep their own logs.

**Not a complete coding agent or GTK desktop app yet.** Its UI runs in the Fedora web browser, served by a native Fedora Python process. A later step can package a GTK/Qt wrapper or RPM after tests.

The optional rabbit_local.py compatibility adapter still relies on the Kilo CLI for its 'run' command. This native GUI uses the same Ollama discovery code but **does not use Kilo CLI**.

## Tests

```bash
python3 -m py_compile contrib/rabbit-code/rabbit_local.py contrib/rabbit-code/fedora/native_app.py
bash -n contrib/rabbit-code/fedora/install-fedora.sh
python3 -m unittest discover -s contrib/rabbit-code/tests -v
```

Unit tests mock Ollama. Real model inference, live Fedora GUI and network behavior still require hardware smoke tests. Don't merge before these pass.

## Licenses and independent development

Original Kilo/opencode code is MIT-licensed. Keep LICENSE and upstream notices in derivative distributions. Kilo Desktop's private Electron sources are absent from this fork; Rabbit Code Native is independently implemented.

## Next

Real Fedora + Ollama validation, scoped read-only repo awareness, explicit patch previews, sandboxed execution approval, and finally independent native packaging.
