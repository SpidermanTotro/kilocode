# Running Kilo Desktop on Fedora through Distrobox

The downloadable Kilo Desktop Linux package is a `.deb` for Debian-based distributions. This helper is for users who **already installed** the package inside an existing Debian Distrobox (for example `kilo-debian`). It does not install packages or change system configuration.

Run from a Fedora terminal, at the repository root:

```bash
bash contrib/linux-distrobox/kilo-fedora.sh doctor
bash contrib/linux-distrobox/kilo-fedora.sh run
```

If the graphical window is blank, close the previous instance and test a software-rendering fallback:

```bash
bash contrib/linux-distrobox/kilo-fedora.sh software-render
```

If your container has a different name, set `KILO_DISTROBOX_CONTAINER=my-container` for the command. You may also run the helper directly **inside** the container. This script is diagnostic: a successful server log does not mean the main UI appeared.

### What the common log warnings mean

- `Failed to connect to ... /run/dbus/system_bus_socket`: D-Bus service unavailable within the container; often non-fatal. Do not mount the host system bus or run as root solely to silence it.
- `WebGL2 blocklisted`: graphics may be restricted. `software-render` passes `--disable-gpu` as an **optional diagnostic**, not a verified fix, and it may reduce functionality or performance.
- `Automatic updates are not available on this platform`: automatic updates are not available in this packaging setup.
- Kilo's built-in server reporting `Ready`: backend initialization completed, but does **not** confirm the graphical main window or local model connectivity.

The helper sets `KILO_TELEMETRY_LEVEL=off` for the Kilo CLI backend using the [documented flag](https://github.com/Kilo-Org/kilocode/blob/main/packages/kilo-docs/pages/code-with-ai/features/message-feedback.md). **This is not a total offline mode**: Kilo Desktop, feature flags, Anaconda bridge and authentication may still use network services. Evaluate the desktop's own privacy settings before opening private projects. Do not use `--no-sandbox` as a workaround.

Kilo Desktop sources are not present in this public repository. This helper cannot change Desktop Electron internals; see [upstream Linux packaging issue #14851](https://github.com/Kilo-Org/kilocode/issues/14851).

### Test without Kilo or Distrobox

```bash
bash -n contrib/linux-distrobox/kilo-fedora.sh
bash contrib/linux-distrobox/tests/test-helper.sh
```
