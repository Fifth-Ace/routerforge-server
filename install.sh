#!/usr/bin/env bash
# Local, idempotent installation. Never modifies SSH, UFW or running services.
set -Eeuo pipefail
umask 022
[[ "$EUID" -eq 0 ]] || { echo 'FAIL: run as root' >&2; exit 1; }
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
for name in manager.sh bootstrap.sh; do
  [[ -f "$source_dir/$name" && ! -L "$source_dir/$name" ]] || { echo "FAIL: missing $name" >&2; exit 1; }
  bash -n "$source_dir/$name"
done
app=/opt/routerforge-server
install -d -m 0755 "$app" /usr/local/bin
# Store complete files before touching any live path.
stage=$(mktemp -d "$app/.stage.XXXXXXXX")
trap 'rm -rf -- "$stage"' EXIT
install -m 0755 "$source_dir/manager.sh" "$stage/manager.sh"
install -m 0755 "$source_dir/bootstrap.sh" "$stage/bootstrap.sh"
revision=${RFS_SOURCE_SHA:-local}
channel=${RFS_SOURCE_CHANNEL:-local}
case "$revision" in
  local) ;;
  *) [[ "$revision" =~ ^[a-f0-9]{40}$ ]] || { echo 'FAIL: invalid revision' >&2; exit 1; } ;;
esac
case "$channel" in dev|main|local) ;; *) echo 'FAIL: invalid channel' >&2; exit 1 ;; esac
printf '%s\n' "$revision" > "$stage/revision"
printf '%s\n' "$channel" > "$stage/channel"
# Existing scanner binaries, reports and user configuration remain unchanged.
for name in manager.sh bootstrap.sh revision channel; do
  mv -f -- "$stage/$name" "$app/$name"
done
ln -sfn "$app/manager.sh" /usr/local/bin/rfs
ln -sfn "$app/manager.sh" /usr/local/bin/vps-manager
[[ -x /usr/local/bin/rfs ]] || { echo 'FAIL: rfs missing' >&2; exit 1; }
/usr/local/bin/rfs --version >/dev/null
printf '=== RESULT ===\nSTATE: PASS\nCOMMAND: rfs\nALIAS: vps-manager\nREVISION: %s\nCHANNEL: %s\nSSH / UFW / SERVICES: UNTOUCHED\n' "$revision" "$channel"
