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

# P7: show the installed vs remote revision accurately, even when semver is equal.
head -n -1 manager.sh > "$D/manager-lib-p7.sh"
result=$(bash -c '
  source "$1"
  APP_DIR="$2"
  mkdir -p "$APP_DIR"
  printf "dev\n" > "$APP_DIR/channel"
  printf "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n" > "$APP_DIR/revision"
  curl(){
    case "$*" in
      *api.github.com*) printf "{\"sha\":\"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb\"}" ;;
      *raw.githubusercontent.com*) printf "#!/bin/bash\nVERSION=0.1.1-dev\n" ;;
    esac
  }
  rfs_update_probe
  rfs_update_status_text
  printf "\nSTATE=%s\n" "$RFS_UPDATE_STATE"
' _ "$D/manager-lib-p7.sh" "$D/version-state")
grep -q 'Установлена: 0.1.0-dev (aaaaaaaaaaaa)' <<< "$result"
grep -q 'Доступна: 0.1.1-dev (bbbbbbbbbbbb)' <<< "$result"
grep -q 'STATE=available' <<< "$result"
result=$(bash -c '
  source "$1"
  APP_DIR="$2"
  curl(){ printf "{\"sha\":\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\"}"; }
  rfs_update_probe
  rfs_update_status_text
  printf "\nSTATE=%s\n" "$RFS_UPDATE_STATE"
' _ "$D/manager-lib-p7.sh" "$D/version-state")
grep -q 'АКТУАЛЬНО' <<< "$result"
grep -q 'STATE=current' <<< "$result"
result=$(bash -c '
  source "$1"
  APP_DIR="$2"
  curl(){ return 6; }
  rfs_update_probe
  rfs_update_status_text
  printf "\nSTATE=%s\n" "$RFS_UPDATE_STATE"
' _ "$D/manager-lib-p7.sh" "$D/version-state")
grep -q 'Проверка обновлений недоступна' <<< "$result"
grep -q 'STATE=unavailable' <<< "$result"
grep -q 'rfs_update_refresh' ui.sh
grep -q 'read -r -t 300' ui.sh
! grep -q 'read -r -t 30 ' ui.sh
printf 'P7_VERSION_COMPARE: PASS\n'

# P7v2: Enter alone must exit the main menu (non-TTY smoke).
main_output=$(printf '\n' | NO_COLOR=1 bash manager.sh menu)
[[ $(grep -c 'RouterForge Server' <<< "$main_output") -ge 1 ]]
! grep -q 'Неизвестный пункт' <<< "$main_output"
grep -q 'choice=${choice:-0}' ui.sh
printf 'P7_DEFAULT_EXIT: PASS\n'

# P8: progress countdown and log tail invariants (read-only mock).
grep -q 'rfs_scan_render' manager.sh
grep -q 'Успешных TLS-подключений' manager.sh
grep -q 'Успешных TLS-подключений' manager.sh
grep -q 'trap - INT TERM EXIT' manager.sh
grep -q 'scanner.log' manager.sh
printf 'P8_LIVE_PROGRESS_STATIC: PASS\n'

# P8 v2: successful self-update must hand off to a fresh process.
grep -q 'request_reexec=1' ui.sh
grep -q 'exec "$APP_DIR/manager.sh" menu' ui.sh
# Isolated menu simulation, no root, no network, no installed service changes.
mkdir -p "$D/app"
printf '%040d\n' 1 > "$D/app/revision"
cat > "$D/restart-fixture.sh" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
head -n -1 "$1" > "$2/manager-lib.sh"
source "$2/manager-lib.sh"
APP_DIR="$2/app"
source ./ui.sh
rfs_terminal_on(){ RFS_TUI_ACTIVE=0; }
rfs_update_refresh(){ :; }
rfs_draw_menu(){ :; }
rfs_redraw(){ :; }
rfs_banner(){ :; }
rfs_line(){ :; }
rfs_pause(){ :; }
self_update(){ printf '%040d\n' 2 > "$APP_DIR/revision"; }
result=0
rfs_menu || result=$?
[[ $result == 75 ]] || { echo "RESTART_EXPECTED_75_GOT_$result"; exit 1; }
MOCK
# Avoid starting any app: test only the subshell restart signal.
printf '10\n' | bash "$D/restart-fixture.sh" "$PWD/manager.sh" "$D" >/dev/null
printf 'P8_SELF_UPDATE_REEXEC: PASS\n'

# P9 regression checks: head must resolve to the system utility; report viewing is read-only.
! grep -q '^head(){' manager.sh
grep -q '^rfs_heading(){' manager.sh
grep -q 'scanner_geoip_install' manager.sh
grep -q 'Country.mmdb' manager.sh
grep -q 'Установить / обновить базу GeoIP' ui.sh
mkdir -p "$D/report-fixture/reports/20261121T155654Z-81-29-155-200"
printf 'selected_ip=81.29.155.200\n' > "$D/report-fixture/reports/20261121T155654Z-81-29-155-200/scope.txt"
printf 'RETAINED: 14 / LETS_ENCRYPT_EXCLUDED: 20\n' > "$D/report-fixture/reports/20261121T155654Z-81-29-155-200/summary.txt"
result=$(printf '1\n' | bash -c 'source "$1"; STATE_DIR="$2"; reports' _ "$D/manager-lib.sh" "$D/report-fixture")
grep -q 'RETAINED: 14' <<< "$result"
grep -q '81.29.155.200' <<< "$result"
result=$(printf '0\n' | bash -c 'source "$1"; STATE_DIR="$2"; reports' _ "$D/manager-lib.sh" "$D/report-fixture")
! grep -q 'RETAINED: 14' <<< "$result"
log="$D/mockscanner.log"
printf '%s\n' 'time=2026-11-21T15:57:55.452Z level=INFO msg="Connected to target" feasible=true ip=81.29.155.174 cert-domain=example.org cert-issuer="Lets Encrypt"' > "$log"
result=$(NO_COLOR=1 bash -c 'source "$1"; rfs_scan_render "$(($(date +%s)-2))" 120 "$2" 81.29.155.0/24 81.29.155.200 0 1' _ "$D/manager-lib.sh" "$log")
grep -q 'Успешных TLS-подключений: 1' <<< "$result"
grep -q 'ЗАВЕРШЕНО' <<< "$result"
! grep -q '66% лимита времени' <<< "$result"
printf 'P9_REPORTS_AND_PROGRESS: PASS\n'
