Name:           nebulashell
Version:        1.0.0
Release:        1%{?dist}
Summary:        Fedora launcher for Kilo Desktop via Distrobox — NebulaShell

License:        Apache-2.0
URL:            https://github.com/SpidermanTotro/kilocode
Source0:        nebulashell.sh
Source1:        nebulashell.desktop
Source2:        nebulashell-logo.svg

BuildArch:      noarch

Requires:       distrobox
Requires:       bash >= 5.0
Recommends:     jq
Recommends:     curl

%description
NebulaShell is a Fedora host launcher for Kilo Desktop running inside a
Debian Distrobox container. It provides a unified CLI for launching Kilo,
running diagnostics, configuring Ollama local AI models, and managing
the container lifecycle.

Commands available after install:
  nebulashell doctor          — diagnostics
  nebulashell run             — launch Kilo Desktop
  nebulashell software-render — GPU fallback mode
  nebulashell ollama-check    — verify Ollama
  nebulashell ollama-setup    — configure local AI models

This package does NOT install Kilo Desktop itself; that lives inside
the kilo-debian Distrobox container. Run setup-nebula.sh first.

%prep
# No tarball to unpack; Sources are individual files.

%build
# Nothing to compile.

%install
install -Dm755 %{SOURCE0}  %{buildroot}%{_bindir}/nebulashell
install -Dm644 %{SOURCE1}  %{buildroot}%{_datadir}/applications/nebulashell.desktop
install -Dm644 %{SOURCE2}  %{buildroot}%{_datadir}/icons/hicolor/scalable/apps/nebulashell.svg

%post
update-desktop-database %{_datadir}/applications &>/dev/null || :
gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%postun
update-desktop-database %{_datadir}/applications &>/dev/null || :
gtk-update-icon-cache %{_datadir}/icons/hicolor &>/dev/null || :

%files
%{_bindir}/nebulashell
%{_datadir}/applications/nebulashell.desktop
%{_datadir}/icons/hicolor/scalable/apps/nebulashell.svg

%changelog
* Sat Oct 10 2026 Henric <henric.klein@gmail.com> - 1.0.0-1
- Initial NebulaShell release
- Commands: doctor, run, software-render, ollama-check, ollama-setup
- KILO_DISABLE_TELEMETRY=1 telemetry suppression
- Ollama model picker via NEBULA_OLLAMA_HOST / NEBULA_OLLAMA_MODEL
- SVG logo: dark nebula theme, purple/indigo gradient
