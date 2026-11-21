# RouterForge Server

Standalone, Russian-language VPS administration CLI. Planned integration with RouterForge Core and RouterForge Portal; **no remote control API** in v0.1.0-dev.

## Requirements

Ubuntu 24.04 amd64 (other distributions not yet tested); Bash, Python 3, OpenSSH, `ss`, `curl`, `file`, `timeout`. UFW and `iptables-restore` needed only for firewall commands.

## Install from a verified local checkout

```bash
sudo bash install.sh
vps-manager
```

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

The previous command `vps-manager` remains available as a compatibility alias.

## Data and compatibility

- Reports/backups: `/var/lib/routerforge-server/`.
- Installer files: `/opt/routerforge-server/`.
- Future integration: read-only status JSON and narrow per-action API, explicit pairing, scoped tokens, audit trail, HTTPS/mTLS or outbound-only channel; disabled by default.
- Repeated invocations should not accumulate duplicated managed rules.
- Release channels: dev and main only; beta and stable are tags, not branches.

## Security boundaries

Do not paste arbitrary `curl | bash` commands to root. Clone the repository or download a pinned release, review/check its SHA256, then install. This proof-of-concept intentionally has no auto-update feature yet.
