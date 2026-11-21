#!/usr/bin/env bash
# Local, idempotent installation. Never modifies SSH, UFW or running services.
set -Eeuo pipefail
umask 022
[[ "$EUID" -eq 0 ]] || { echo 'FAIL: run as root' >&2; exit 1; }
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
for name in manager.sh bootstrap.sh ui.sh locale.sh status.sh; do
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
install -m 0644 "$source_dir/ui.sh" "$stage/ui.sh"
install -m 0644 "$source_dir/locale.sh" "$stage/locale.sh"
install -m 0644 "$source_dir/status.sh" "$stage/status.sh"
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
for name in manager.sh bootstrap.sh ui.sh locale.sh status.sh revision channel; do
  mv -f -- "$stage/$name" "$app/$name"
done
# Language selection on first install only; read from controlling TTY even with curl | bash.
# Existing installations retain their selected language, including self-updates.
if [[ ! -f "$app/language" ]]; then
  selected=${RFS_LANG:-ru}
  if [[ -z "${RFS_LANG:-}" && -r /dev/tty && -w /dev/tty ]]; then
    printf 'Язык интерфейса / Interface language [1=Русский (default), 2=English]: ' > /dev/tty
    answer=''; IFS= read -r answer < /dev/tty || true
    case "$answer" in 2|en|EN) selected=en ;; *) selected=ru ;; esac
  fi
  [[ "$selected" == ru || "$selected" == en ]] || selected=ru
  printf '%s\n' "$selected" > "$app/language"
  chmod 0644 "$app/language"
fi
ln -sfn "$app/manager.sh" /usr/local/bin/rfs
ln -sfn "$app/manager.sh" /usr/local/bin/vps-manager
[[ -x /usr/local/bin/rfs ]] || { echo 'FAIL: rfs missing' >&2; exit 1; }
/usr/local/bin/rfs --version >/dev/null
printf '=== RESULT ===\nSTATE: PASS\nCOMMAND: rfs\nALIAS: vps-manager\nREVISION: %s\nCHANNEL: %s\nSSH / UFW / SERVICES: UNTOUCHED\n' "$revision" "$channel"
