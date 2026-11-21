# Changelog

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
