Name:           kilo-desktop-fedora
Version:        0.1.0
Release:        1%{?dist}
Summary:        Fedora launcher and diagnostics for Kilo Desktop (Distrobox)

License:        Apache-2.0
URL:            https://github.com/SpidermanTotro/kilocode
# The source tarball is the contrib/linux-distrobox directory from the fork.
# To build: spectool -g kilo-desktop.spec  OR  rpmbuild -ba kilo-desktop.spec
Source0:        kilo-fedora.sh
Source1:        kilo-desktop-distrobox.desktop

BuildArch:      noarch

# Requires the Distrobox tool to be present on the Fedora host.
Requires:       distrobox
# bash 5+ is standard on Fedora 36+
Requires:       bash >= 5.0

%description
A Fedora host launcher script and .desktop entry for Kilo Desktop running
inside a Debian Distrobox container.

This package installs:
  - /usr/local/bin/kilo-fedora   — run, doctor, software-render, ollama-check
  - A .desktop entry so Kilo Desktop appears in Fedora's application menu

It does NOT install Kilo Desktop itself; that lives inside the kilo-debian
Distrobox container. See README.md for setup instructions.

%prep
# Nothing to unpack; Sources are individual files.

%build
# Nothing to compile.

%install
install -Dm755 %{SOURCE0} %{buildroot}%{_bindir}/kilo-fedora
install -Dm644 %{SOURCE1} \
  %{buildroot}%{_datadir}/applications/kilo-desktop-distrobox.desktop

%files
%license LICENSE
%{_bindir}/kilo-fedora
%{_datadir}/applications/kilo-desktop-distrobox.desktop

%changelog
* Thu Oct 09 2025 Henric <henric.klein@gmail.com> - 0.1.0-1
- Initial Fedora RPM: launcher, doctor, software-render, ollama-check commands
- Correct telemetry suppression via KILO_DISABLE_TELEMETRY=1
- Ollama model verification via KILO_OLLAMA_HOST / KILO_OLLAMA_MODEL
