# RouterForge Server

Standalone, Russian-language VPS administration CLI. Planned integration with RouterForge Core and RouterForge Portal; **no remote control API** in v0.1.0-dev.

## Requirements

Ubuntu 24.04 amd64 (other distributions not yet tested); Bash, Python 3, OpenSSH, `ss`, `curl`, `file`, `timeout`. UFW and `iptables-restore` needed only for firewall commands.

## Install from a verified local checkout

```bash
sudo bash install.sh
rfs
```

## P4: Color menu and installers

The `rfs` command opens a color-coded menu split into system, security, scanning, third-party services, and maintenance. Third-party installers are downloaded directly from upstream only after confirmation and SHA256 display. Existing x-ui/LucX installations block the classic 3x-ui installer to avoid overwriting a running panel.

Third-party menu entries: MHSanaei/3x-ui, Flecksis/rkn-guard, Liafanx/MTProxyL.

## What the menu does

- VPS status: read-only.
- Ubuntu APT update/upgrade: explicit confirmation.
- SSH port 2202: prepares config only. **Never restarts SSH/socket**; previously configured ports are preserved. SSH activation is explicitly outside the automated flow until a safe remote rollback is implemented.
- UFW: inspection, SSH allow-listing and *optional* 10 ICMP DROP rules. **Never auto-enables UFW.** The ICMP policy can break Path MTU Discovery.
- RealiTLScanner: on-demand installation from XTLS official GitHub release (ELF checked, release signature/checksum verification is not yet available); scan adjacent public IPv4 `/24` only on operator confirmation; capped at 120 seconds and two threads; filter Let's Encrypt certificate issuers; CSV output and console summary.

Neighboring IPs can belong to other tenants; scan only where authorized. Scans from VPS networks can violate provider rules.

## CLI

```bash
rfs status
rfs ssh-prepare
rfs scanner-install
rfs scan
rfs filter raw.csv filtered.csv
```

## Data and compatibility

- Reports/backups: `/var/lib/routerforge-server/`.
- Installer files: `/opt/routerforge-server/`.
- Future integration: read-only status JSON and narrow per-action API, explicit pairing, scoped tokens, audit trail, HTTPS/mTLS or outbound-only channel; disabled by default.
- Repeated invocations should not accumulate duplicated managed rules.
- Release channels: dev and main only; beta and stable are tags, not branches.

## Security boundaries

Do not paste arbitrary `curl | bash` commands to root. Clone the repository or download a pinned release, review/check its SHA256, then install. Self-update is available via `rfs self-update`; it updates only RouterForge Server program files.


## P5: updates, SSH port, confirmations and LucX

- `rfs` performs a read-only GitHub `dev`/`main` revision check on opening the menu; **no auto-install**. `rfs check-update` repeats the check, `rfs self-update` installs after confirmation. If offline, the menu still works.
- SSH preparation prompts for a TCP port (1–65535). No port is preselected, and no SSH/socket restart or firewall change occurs automatically. Previously configured ports remain; activation needs a separate verified procedure.
- Prompts use `Y/n`; Enter defaults to Yes. Always read the action description first.
- LucX-UI is listed immediately after classic 3x-ui. Because both use x-ui paths and services, installation is blocked if either panel exists; migration requires a separate backup workflow. Installer source: `AlexeyLCP/lucx-ui`.

## P6: multihomed TLS scan and refreshed TUI

- Option 8 lists directly configured, globally routable IPv4 addresses from `ip -o -4 addr show scope global`. If one is present, it is selected automatically; if multiple exist, choose by number (Enter defaults to the first). No silently guessed egress IP on NAT-only VPS.
- The selected IPv4 determines which adjacent `/24` is scanned; it **does not bind outbound connections** to that source IP. RealiTLScanner CLI has no source-address option. Check the VPS routing/policy before scanning if the source IP matters.
- Time limit in seconds is prompted interactively; Enter = 120 seconds. Accepted range: 1–86400 seconds. Two scanner threads remain the default. Scope and limit saved in each report's `scope.txt`.
- Interactive TTY menu uses an alternate terminal screen and redraws in place, restoring the prior screen on exit. Piped/non-TTY mode does not use terminal control codes. RF Server ASCII banner is original and intentionally distinct from MTProxyL artwork.

The P6 banner uses built-in 7-row block letters “RF SERVER” with optional ANSI cyan shading and a subtle shadow; no figlet dependency.

## P7: automatic update comparison

- On menu startup and every five minutes while an interactive TTY menu is idle, checks `dev`/`main` read-only. A manual check (option 15 / `rfs check-update`) is also available. No background daemon.
- Shows `Установлена: 0.1.0-dev (local SHA) → Доступна: 0.1.0-dev (remote SHA)` with green *current* or yellow *update available*. Dev builds share the same semantic version and must be distinguished by commit.
- For a differing commit, the remote VERSION is fetched from `manager.sh` pinned to that exact commit. If the version file is unavailable, it shows the remote revision without inventing a version.
- Network failure is displayed as unavailable, not as current. Update installation always requires explicit confirmation.

## P8: live TLS scanner progress

- While the scanner runs, the terminal shows elapsed time, remaining seconds, a progress bar and the last ten log lines. The countdown is a **time-limit countdown**, not a measure of scan completion.
- The full raw output is preserved in each report's `scanner.log`; `scope.txt`, CSV filtering and selected IP/time are unchanged.
- Ctrl+C requests a stop; interactive rendering uses the existing terminal screen without continuously scrolling. Non-TTY runs print sparse progress lines.
