# Kilo Desktop — Fedora / Distrobox launcher

Run Kilo Desktop 0.1.11+ on Fedora via a Debian Distrobox container.

## What this provides

| File | Purpose |
|---|---|
| `kilo-fedora.sh` | Host launcher: `run`, `doctor`, `software-render`, `ollama-check` |
| `kilo-desktop-distrobox.desktop` | Fedora application menu entry |
| `kilo-desktop.spec` | RPM spec for packaging the launcher as a Fedora package |
| `tests/test-helper.sh` | Regression tests (no live Kilo or Ollama required) |

## Prerequisites

1. **Fedora host** with `distrobox` installed (`sudo dnf install distrobox`)
2. A **kilo-debian** Distrobox container with Kilo Desktop installed inside it
3. Wayland or X11 session (Wayland recommended on Fedora 40+)

If you don't have the container yet:
```bash
distrobox create --name kilo-debian --image debian:12
distrobox enter kilo-debian -- bash -c "
  curl -fsSL https://kilocode.ai/install/linux | bash
"
```

## Quick start

Clone the Fedora branch from the fork:

```bash
git clone --depth 1 --filter=blob:none --sparse \
  --branch fix/fedora-distrobox-desktop \
  https://github.com/SpidermanTotro/kilocode.git \
  kilocode-fedora-test

cd kilocode-fedora-test
git sparse-checkout set contrib/linux-distrobox
```

Run diagnostics first:

```bash
bash contrib/linux-distrobox/kilo-fedora.sh doctor
```

Then launch:

```bash
bash contrib/linux-distrobox/kilo-fedora.sh run
```

If the window is blank or black (WebGL2 blocklisted):

```bash
bash contrib/linux-distrobox/kilo-fedora.sh software-render
```

## Ollama (local AI models)

Check if Ollama is reachable and list available models:

```bash
bash contrib/linux-distrobox/kilo-fedora.sh ollama-check
```

To specify a preferred model:

```bash
KILO_OLLAMA_MODEL=llama3 bash contrib/linux-distrobox/kilo-fedora.sh ollama-check
```

To point at a remote Ollama server:

```bash
KILO_OLLAMA_HOST=http://192.168.1.10:11434 bash contrib/linux-distrobox/kilo-fedora.sh ollama-check
```

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `KILO_DISTROBOX_CONTAINER` | `kilo-debian` | Distrobox container name |
| `KILO_OLLAMA_HOST` | `http://127.0.0.1:11434` | Ollama API base URL |
| `KILO_OLLAMA_MODEL` | _(none)_ | Model name to verify on startup |

## Telemetry note

`KILO_DISABLE_TELEMETRY=1` is passed to suppress Kilo CLI telemetry.
Kilo Desktop, LaunchDarkly, and Anaconda may still make outbound connections
independently. Review Kilo's privacy settings inside the application to control
Desktop-level telemetry.

## Running the tests

```bash
bash contrib/linux-distrobox/tests/test-helper.sh
```

All tests run without a live Kilo installation or Ollama server.
Expected output: `PASS: N/N tests passed`

## Installing as an RPM (optional)

```bash
sudo dnf install rpm-build
cp contrib/linux-distrobox/kilo-fedora.sh ~/rpmbuild/SOURCES/
cp contrib/linux-distrobox/kilo-desktop-distrobox.desktop ~/rpmbuild/SOURCES/
rpmbuild -ba contrib/linux-distrobox/kilo-desktop.spec
sudo dnf install ~/rpmbuild/RPMS/noarch/kilo-desktop-fedora-*.rpm
```

After installing the RPM, use `kilo-fedora` directly:

```bash
kilo-fedora doctor
kilo-fedora run
kilo-fedora ollama-check
```

## Known issues

| Issue | Severity | Notes |
|---|---|---|
| `Failed to connect to /run/dbus/system_bus_socket` | Non-fatal | Normal in Distrobox; session D-Bus still works |
| `WebGL2 blocklisted` | Minor | Use `software-render` command if window is blank |
| `fs.Stats constructor is deprecated` | Non-fatal | Upstream Node.js issue in Kilo Desktop |
| `Invalid environment value 'stable'` | Non-fatal | Upstream Anaconda bridge config issue |
| Kilo CLI telemetry shows `set to on` in log | Known | Desktop overrides env var; control via in-app settings |

## Links

- Upstream Kilo Code: <https://github.com/Kilo-Org/kilocode>
- Kilo website: <https://kilocode.ai>
- This fork: <https://github.com/SpidermanTotro/kilocode>
- Linux packaging issue: <https://github.com/Kilo-Org/kilocode/issues/14851>
