#!/usr/bin/env bash
set -Eeuo pipefail
# Installs from the directory containing this install.sh (offline or cloned repo).
[[ $EUID == 0 ]] || { echo 'Run as root'; exit 1; }
DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ -f "$DIR/manager.sh" ]] || { echo 'manager.sh missing'; exit 1; }
bash -n "$DIR/manager.sh"
install -d -m 0755 /opt/routerforge-server
install -m 0755 "$DIR/manager.sh" /opt/routerforge-server/manager.sh
ln -sfn /opt/routerforge-server/manager.sh /usr/local/bin/rfs
ln -sfn /opt/routerforge-server/manager.sh /usr/local/bin/vps-manager
printf 'STATE: PASS\nCOMMAND: rfs\nALIAS: vps-manager\nNO SSH / UFW / VPS CHANGES\n'
