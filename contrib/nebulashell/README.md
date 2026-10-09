# NebulaShell

> **Fedora AI Launcher — Kilo Desktop · Distrobox · Ollama**

![NebulaShell Logo](nebulashell-logo.svg)

NebulaShell is a Fedora-native launcher for [Kilo Desktop](https://kilocode.ai) running inside a Debian Distrobox container, with built-in Ollama local-model integration.

---

## What's included

| File | Purpose |
|---|---|
| `nebulashell.sh` | Main launcher: `doctor`, `run`, `software-render`, `ollama-check`, `ollama-setup` |
| `setup-nebula.sh` | First-time setup: creates container, installs Kilo, installs launcher |
| `nebulashell.desktop` | Fedora GNOME/KDE app-menu entry |
| `nebulashell.spec` | RPM spec for `dnf install`-style packaging |
| `nebulashell-logo.svg` | NebulaShell logo — dark space theme, purple/indigo |
| `tests/test-nebulashell.sh` | Regression tests (no live Kilo or Ollama needed) |

---

## Quick start

### 1. Clone the branch

```bash
git clone --depth 1 --filter=blob:none --sparse \
  --branch feat/nebulashell \
  https://github.com/SpidermanTotro/kilocode.git \
  nebulashell-test

cd nebulashell-test
git sparse-checkout set contrib/nebulashell
```

### 2. First-time setup (Fedora host)

```bash
bash contrib/nebulashell/setup-nebula.sh
```

This creates the `kilo-debian` Distrobox container, installs Kilo Desktop inside it, and drops `nebulashell` into `~/.local/bin`.

Preview without making changes:

```bash
bash contrib/nebulashell/setup-nebula.sh --dry-run
```

### 3. Run diagnostics

```bash
nebulashell doctor
```

### 4. Connect Ollama (local AI models)

```bash
# Check what models you have:
nebulashell ollama-check

# Configure Kilo to use a specific model (close Kilo first):
NEBULA_OLLAMA_MODEL=qwen2.5-coder:7b nebulashell ollama-setup

# Then launch:
nebulashell run
```

### 5. Launch Kilo Desktop

```bash
nebulashell run
```

If the window is blank or black:

```bash
nebulashell software-render
```

---

## All commands

```
nebulashell doctor          Read-only diagnostics
nebulashell run             Launch Kilo Desktop
nebulashell software-render Launch with --disable-gpu
nebulashell ollama-check    Verify Ollama + list models
nebulashell ollama-setup    Configure Kilo to use Ollama
nebulashell version         Print NebulaShell version
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `NEBULA_CONTAINER` | `kilo-debian` | Distrobox container name |
| `NEBULA_OLLAMA_HOST` | `http://127.0.0.1:11434` | Ollama API base URL |
| `NEBULA_OLLAMA_MODEL` | _(none)_ | Preferred model to verify/configure |

---

## Install as RPM (optional)

```bash
sudo dnf install rpm-build
mkdir -p ~/rpmbuild/SOURCES
cp contrib/nebulashell/nebulashell.sh         ~/rpmbuild/SOURCES/
cp contrib/nebulashell/nebulashell.desktop     ~/rpmbuild/SOURCES/
cp contrib/nebulashell/nebulashell-logo.svg    ~/rpmbuild/SOURCES/
rpmbuild -ba contrib/nebulashell/nebulashell.spec
sudo dnf install ~/rpmbuild/RPMS/noarch/nebulashell-*.rpm
```

---

## Run the tests

```bash
bash contrib/nebulashell/tests/test-nebulashell.sh
```

All tests run without a live Kilo installation or Ollama server.  
Expected output: `PASS: N/N tests passed`

---

## Ollama models tested

| Model | Use case |
|---|---|
| `qwen2.5-coder:7b` | Code generation, editing, agents |
| `qwen3:8b` | General reasoning, planning |
| `qwen2.5:1.5b-instruct` | Fast completions, low RAM |

Pull models with: `ollama pull <model>`

---

## Known issues

| Issue | Severity | Notes |
|---|---|---|
| `Failed to connect to /run/dbus/system_bus_socket` | Non-fatal | Normal in Distrobox |
| `WebGL2 blocklisted` | Minor | Use `software-render` if window is blank |
| `fs.Stats constructor deprecated` | Non-fatal | Upstream Node.js in Kilo |
| `Invalid environment value 'stable'` | Non-fatal | Upstream Anaconda bridge |
| Kilo Desktop telemetry shows `set to on` | Known | Control via in-app Settings → Privacy |

---

## Links

- Kilo Code (upstream): <https://github.com/Kilo-Org/kilocode>
- Kilo website: <https://kilocode.ai>
- This fork: <https://github.com/SpidermanTotro/kilocode>
- Ollama: <https://ollama.com>
