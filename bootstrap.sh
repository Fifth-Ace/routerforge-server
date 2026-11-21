#!/usr/bin/env bash
# RouterForge Server remote installer/updater; downloads a pinned GitHub commit.
set -Eeuo pipefail
umask 077
REPO='Fifth-Ace/routerforge-server'
CHANNEL='main'
MODE='install'
for arg in "$@"; do
  case "$arg" in
    --channel=dev) CHANNEL=dev ;;
    --channel=main) CHANNEL=main ;;
    --lang=ru) export RFS_LANG=ru ;;
    --lang=en) export RFS_LANG=en ;;
    --install) MODE=install ;;
    --update) MODE=update ;;
    *) printf 'FAIL: unknown argument: %s\n' "$arg" >&2; exit 2 ;;
  esac
done
[[ "$EUID" -eq 0 ]] || { echo 'FAIL: run as root (sudo bash bootstrap.sh)' >&2; exit 1; }
for cmd in curl tar python3 sha256sum mktemp flock; do
  command -v "$cmd" >/dev/null || { echo "FAIL: missing $cmd" >&2; exit 1; }
done
if [[ "$MODE" == update && ! -f /opt/routerforge-server/manager.sh ]]; then
  echo 'FAIL: RouterForge Server is not installed' >&2; exit 1
fi
install -d -m 0700 /var/lock/routerforge-server
exec 9>/var/lock/routerforge-server/bootstrap.lock
flock -n 9 || { echo 'FAIL: another install/update is running' >&2; exit 1; }
tmp=$(mktemp -d /tmp/rfs-install.XXXXXXXX)
trap 'rm -rf -- "$tmp"' EXIT
printf '=== PRECHECK / GITHUB ===\nREPO: %s\nCHANNEL: %s\nMODE: %s\n' "$REPO" "$CHANNEL" "$MODE"
api="https://api.github.com/repos/$REPO/commits/$CHANNEL"
curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 10 --max-time 45 \
  -H 'Accept: application/vnd.github+json' -H 'User-Agent: RouterForge-Server' "$api" -o "$tmp/commit.json"
sha=$(python3 - "$tmp/commit.json" <<'PY'
import json,re,sys
with open(sys.argv[1],encoding='utf-8') as f: s=json.load(f)['sha']
if not re.fullmatch(r'[a-f0-9]{40}',s): raise SystemExit('Invalid commit SHA')
print(s)
PY
)
printf 'COMMIT: %s\n' "$sha"
curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 15 --max-time 120 \
  "https://codeload.github.com/$REPO/tar.gz/$sha" -o "$tmp/source.tar.gz"
# Content comes from GitHub at the exact commit, not a moving branch after resolving SHA.
tar -tzf "$tmp/source.tar.gz" >/dev/null
mkdir "$tmp/source"
tar -xzf "$tmp/source.tar.gz" --strip-components=1 -C "$tmp/source" \
  --no-same-owner --no-same-permissions
for name in install.sh manager.sh bootstrap.sh ui.sh locale.sh status.sh; do
  [[ -f "$tmp/source/$name" && ! -L "$tmp/source/$name" ]] || { echo "FAIL: $name missing" >&2; exit 1; }
  bash -n "$tmp/source/$name"
done
printf 'GATE: PASS / PINNED COMMIT + BASH SYNTAX\n'
RFS_SOURCE_SHA="$sha" RFS_SOURCE_CHANNEL="$CHANNEL" bash "$tmp/source/install.sh"
printf '=== RESULT ===\nSTATE: PASS\nREVISION: %s\nCOMMAND: rfs\n' "$sha"
