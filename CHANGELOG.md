# Changelog

## 1.0.0 — первый стабильный релиз / first stable release
- RU/EN Linux server management CLI; tested on Ubuntu 24.04 LTS (amd64).
- Read-only CPU, RAM, SWAP, disk, network, OS, SSH and UFW status dashboard.
- RealiTLScanner integration, optional GeoIP, certificate filtering and CSV reports.
- SSH/UFW tools with explicit confirmation and optional 3x-ui, LucX-UI, RKN Guard, MTProxyL installers.
- Language selection, update checking and user-confirmed self-update.

## Development history (pre-1.0.0)
## 0.1.0-dev (unreleased)
- Initial standalone RouterForge Server CLI with menu.
- Read-only status and modular actions.
- SSH config preparation without service restart.
- Optional UFW ICMP policy with backup and syntax check.
- RealiTLScanner install and 120-second neighboring IPv4 scan with issuer filtering.
- Reserved compatibility surface for RouterForge Core/Portal integration.

- P5: read-only automatic revision checks, configurable SSH port, Y/n prompts and LucX-UI menu installer.
- P6: selectable configured public IPv4 /24 for TLS scanning, configurable timeout default 120 seconds, RF Server ASCII banner and alternate-screen TUI.
- P6 v2: readable cyan block-pixel RF SERVER banner with dark shadow; no external banner utility.
- P7: automatic five-minute read-only update check with installed and available version/revision comparison in the main TUI.

- P8: live RealiTLScanner log tail, deadline countdown, and Ctrl+C cleanup.
- P8 v2: restart RFS UI immediately after verified successful self-update, preserving SSH session.
- P9: fix reports menu/head shadowing; interactive report viewer, compact scan live feed and accurate completion status; optional Country.mmdb installation.

- P10: no-flicker incremental TLS TUI, 30-line history, GeoIP column, RU default / EN secondary, language selection on install and in menu, RU README and EN README.
- P10: RouterForge shared README banner and user-supplied terminal screenshot; resilient idle prompt handling.

- P11: read-only VPS status dashboard with load-first CPU, memory, swap, disk, network, system, and SSH/UFW overview (RU/EN).
