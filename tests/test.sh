#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "$0")/.."
for f in manager.sh install.sh bootstrap.sh ui.sh; do bash -n "$f"; done
for cmd in help version; do bash manager.sh "$cmd" >/dev/null; done
D=$(mktemp -d); trap 'rm -rf "$D"' EXIT
cat > "$D/test.csv" <<'CSV'
IP,ORIGIN,CERT_DOMAIN,CERT_ISSUER,GEO_CODE
203.0.113.1,x,example.com,Let's Encrypt,US
203.0.113.2,x,a.example,DigiCert Inc,US
203.0.113.2,x,a.example,DigiCert Inc,US
203.0.113.3,x,b.example,LETS ENCRYPT,US
203.0.113.4,x,c.example,Sectigo,US
CSV
bash manager.sh filter "$D/test.csv" "$D/filtered.csv" > "$D/summary"
[[ $(wc -l < "$D/filtered.csv") == 3 ]]
grep -q 'LETS_ENCRYPT_EXCLUDED: 2' "$D/summary"
grep -q 'RETAINED: 2' "$D/summary"
! grep -qi 'encrypt' "$D/filtered.csv"
# No side-effect for passive actions.
bash manager.sh help >/dev/null
printf 'BASH: PASS\nFILTER: PASS\nDEDUP: PASS\n'

# P5: syntax, menu, version check and SSH safety anchors.
grep -q 'rfs_check_update' manager.sh
grep -q 'SSH: указать порт вручную' ui.sh
grep -q 'lucx-ui)' ui.sh
grep -q 'check-update)' manager.sh
! grep -q 'SSH_TARGET_PORT=2202' manager.sh
! grep -q 'Подготовить SSH 2202' ui.sh
[[ $(printf '0\n' | NO_COLOR=1 bash manager.sh menu | grep -c 'LucX-UI') -ge 1 ]]
printf 'P5_STATIC: PASS\n'

# P6: target IP selection and time validation, all read-only fixtures.
grep -q 'scanner_select_ip' manager.sh
grep -q 'scanner_select_seconds' manager.sh
grep -q 'RFS_TUI_ACTIVE' ui.sh
grep -q 'rfs_banner' ui.sh
! grep -q 'public_ip)' manager.sh
mkdir -p "$D/mockbin"
cat > "$D/mockbin/ip" <<'MOCK'
#!/usr/bin/env bash
printf '2: eth0    inet 8.8.8.8/24 brd 8.8.8.255 scope global eth0\n'
printf '2: eth0    inet 1.1.1.1/24 brd 1.1.1.255 scope global secondary eth0\n'
printf '2: eth0    inet 10.0.0.2/24 brd 10.0.0.255 scope global eth0\n'
MOCK
chmod +x "$D/mockbin/ip"
# Keep subprocess source-only: skip manager.sh entrypoint.
head -n -1 manager.sh > "$D/manager-lib.sh"
result=$(printf '2\n\n' | PATH="$D/mockbin:$PATH" bash -c 'source "$1"; scanner_select_ip; scanner_select_seconds; printf "CHOSEN=%s TIME=%s\n" "$SCAN_SELECTED_IP" "$SCAN_SELECTED_SECONDS"' _ "$D/manager-lib.sh")
grep -q 'CHOSEN=1.1.1.1 TIME=120' <<< "$result"
result=$(printf '9\n1\n0\n300\n' | PATH="$D/mockbin:$PATH" bash -c 'source "$1"; scanner_select_ip; scanner_select_seconds; printf "CHOSEN=%s TIME=%s\n" "$SCAN_SELECTED_IP" "$SCAN_SELECTED_SECONDS"' _ "$D/manager-lib.sh")
grep -q 'CHOSEN=8.8.8.8 TIME=300' <<< "$result"
! grep -q '10.0.0.2' <<< "$result"
printf 'P6_SCANNER_SELECTION: PASS\n'

# P6 v2 block banner: precise text shape without external figlet/toilet dependency.
grep -q 'Compact 7-row pixel font' ui.sh
source_text=$(printf '0\n' | NO_COLOR=1 bash manager.sh menu)
grep -q '█████' <<< "$source_text"
grep -q 'RouterForge Server' <<< "$source_text"
! grep -q '___) |' <<< "$source_text"
printf 'P6_BLOCK_BANNER: PASS\n'
