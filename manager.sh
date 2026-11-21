#!/usr/bin/env bash
# RouterForge Server - standalone Ubuntu CLI manager
set -Eeuo pipefail
VERSION=0.1.0-dev
APP_DIR=/opt/routerforge-server
STATE_DIR=/var/lib/routerforge-server
CONF_DIR=/etc/routerforge-server
LOG_DIR=/var/log/routerforge-server
SCAN_SECONDS=120
SCAN_THREADS=2
RFS_SELF_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
if [[ -r "$APP_DIR/locale.sh" ]]; then source "$APP_DIR/locale.sh";
elif [[ -r "$RFS_SELF_DIR/locale.sh" ]]; then source "$RFS_SELF_DIR/locale.sh";
else RFS_LANG=ru; rfs_t(){ printf '%s' "$1"; }; fi
mkdir_state(){ install -d -m 0750 "$STATE_DIR" "$STATE_DIR/reports" "$STATE_DIR/backups" "$LOG_DIR"; }
rfs_heading(){ printf '\n=== %s ===\n' "$(rfs_t "$*")"; }
info(){ printf '%s\n' "$(rfs_t "$*")"; }
die(){ printf 'STATE: FAIL / %s\n' "$(rfs_t "$*")" >&2; return 1; }
root(){ (( EUID == 0 )) || { die 'root required'; return 1; }; }
ubuntu(){ [[ -f /etc/os-release ]] || { die 'Missing os-release'; return 1; }; . /etc/os-release; [[ "${ID:-}" == ubuntu ]] || { die 'Ubuntu required'; return 1; }; }
confirm(){
 local reply
 read -r -p "$(rfs_t "$1") [Y/n]: " reply || return 1
 case "${reply,,}" in ''|y|yes|д|да) return 0;; n|no|н|нет) return 1;; *) info 'Ответьте Y или n'; return 1;; esac
}
port_listeners(){ ss -H -ltnp 2>/dev/null | grep -E ':(22|222|2202)([[:space:]]|$)' || true; }
status(){
 rfs_heading 'PRECHECK / READ ONLY'; printf 'RFS_VERSION: %s\n' "$VERSION"; sed -n 's/^PRETTY_NAME=/OS: /p' /etc/os-release || true
 rfs_heading SSH; /usr/sbin/sshd -T 2>/dev/null | awk '$1=="port"{print}' || true; port_listeners
 rfs_heading UFW; if command -v ufw >/dev/null; then ufw status verbose; else info 'UFW: missing'; fi
 rfs_heading NETWORK; ip -4 route show default || true
 rfs_heading RESULT; info 'STATE: PASS / NO CHANGES'
}
updates(){ root || return 1; ubuntu || return 1; rfs_heading 'PRECHECK / APT'; confirm 'Выполнить apt update + upgrade без вопросов?' || { info 'CANCELLED'; return; }; export DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l; apt-get update && apt-get -y -o Dpkg::Options::=--force-confold upgrade; rfs_heading RESULT; info 'APT: PASS'; }
ssh_prepare(){
 root || return 1
 command -v /usr/sbin/sshd >/dev/null 2>&1 || [[ -x /usr/sbin/sshd ]] || { die 'sshd missing'; return 1; }
 rfs_heading 'PRECHECK / SSH / CONFIG ONLY'
 # Read-only preflight. Do not create /run/sshd or restart sockets.
 local current target stamp file backup temp
 current=$(/usr/sbin/sshd -T 2>/dev/null | awk '$1=="port" {print $2}' | sort -nu) || { die 'Cannot read sshd config'; return 1; }
 [[ -n "$current" ]] || { die 'No configured SSH ports'; return 1; }
 printf '%s:\n%s\n' "$(rfs_t 'Действующие SSH-порты')" "$current"
 port_listeners
 read -r -p "$(rfs_t 'Введите новый SSH-порт (1–65535, пусто — отмена): ')" target || return 1
 [[ -n "$target" ]] || { info 'CANCELLED'; return 0; }
 [[ "$target" =~ ^[0-9]{1,5}$ ]] && ((10#$target>=1 && 10#$target<=65535)) || { die 'Invalid TCP port'; return 1; }
 target=$((10#$target))
 if printf '%s\n' "$current" | grep -qx "$target"; then
   info "SSH_CONFIG_$target: PASS / already configured"
   info 'SSH_SERVICE / SOCKET: UNTOUCHED'
   return 0
 fi
 info "NEW_PORT: $target / existing ports preserved"
 info 'Only sshd_config drop-in will be staged; no restart/reload, no UFW changes.'
 confirm 'Подготовить конфигурацию SSH?' || { info CANCELLED; return 0; }
 mkdir_state
 install -d -m 0755 /etc/ssh/sshd_config.d
 stamp=$(date -u +%Y%m%dT%H%M%SZ)
 file=/etc/ssh/sshd_config.d/00-routerforge-server-ports.conf
 backup="$STATE_DIR/backups/ssh-$stamp"
 install -d -m 0700 "$backup"
 cp -a /etc/ssh/sshd_config "$backup/sshd_config"
 [[ ! -f "$file" ]] || cp -a "$file" "$backup/dropin.conf"
 # Preserve the effective configured ports plus the new one.
 temp=$(mktemp /etc/ssh/sshd_config.d/.rfs-ports.XXXXXXXX)
 { printf '%s\n' "$current" | awk '{print "Port " $1}'; printf 'Port %s\n' "$target"; } | sort -u > "$temp"
 chmod 0644 "$temp"
 mv -f "$temp" "$file"
 if ! /usr/sbin/sshd -t || ! /usr/sbin/sshd -T | awk '$1=="port"{print $2}' | grep -qx "$target"; then
   if [[ -f "$backup/dropin.conf" ]]; then cp -a "$backup/dropin.conf" "$file"; else rm -f "$file"; fi
   die 'SSH validation failed: restored original drop-in'; return 1
 fi
 info "SSH_CONFIG_$target: STAGED"
 info 'LISTENER: unchanged; new port is NOT live until separately activated.'
 info 'SSH_SOCKET / SSH_SERVICE / UFW: UNTOUCHED'
}
ufw_status(){ rfs_heading 'FIREWALL / READ ONLY'; command -v ufw >/dev/null && ufw status verbose || info 'UFW unavailable'; }
ufw_ssh(){
 root || return 1; command -v ufw >/dev/null || { die 'Install ufw first'; return 1; }
 rfs_heading 'PRECHECK / SSH PORTS'; local ports; ports=$(/usr/sbin/sshd -T | awk '$1=="port"{print $2}' | sort -nu)
 printf '%s\n' "$ports"
 confirm 'Добавить ALLOW TCP для всех SSH-портов из конфига? UFW не будет включён' || return 0
 while read -r p; do [[ "$p" =~ ^[0-9]+$ ]] || continue; ufw allow "$p/tcp"; done <<< "$ports"
 rfs_heading RESULT; info 'UFW SSH RULES: PASS / UFW enable unchanged'
}
# Dangerous policy is deliberately opt-in; disabling ICMP unreachables can break PMTUD.
ufw_icmp(){
 root || return 1; command -v iptables-restore >/dev/null || { die 'iptables-restore missing'; return 1; }
 [[ -f /etc/ufw/before.rules ]] || { die '/etc/ufw/before.rules missing'; return 1; }
 rfs_heading 'SECURITY / ICMP RULES'; info 'WARNING: DROP destination-unreachable/time-exceeded may break PMTUD and network diagnostics.'
 confirm 'Установить 10 DROP ICMP-правил (INPUT + FORWARD) как на скриншоте?' || { info CANCELLED; return; }
 mkdir_state; local stamp tmp; stamp=$(date -u +%Y%m%dT%H%M%SZ); tmp=$(mktemp)
 cp -a /etc/ufw/before.rules "$STATE_DIR/backups/before.rules.$stamp"
 cp /etc/ufw/before.rules "$tmp"
 python3 - "$tmp" <<'PY'
import pathlib,re,sys
p=pathlib.Path(sys.argv[1]); s=p.read_text()
s=re.sub(r'^# BEGIN ROUTERFORGE ICMP DROP\n.*?^# END ROUTERFORGE ICMP DROP\n','',s,flags=re.M|re.S)
s=re.sub(r'^# BEGIN VPS-BOOTSTRAP ICMP DROP\n.*?^# END VPS-BOOTSTRAP ICMP DROP\n','',s,flags=re.M|re.S)
# Avoid accumulating duplicate rules in old files.
for chain in ('ufw-before-input','ufw-before-forward'):
    kinds=('destination-unreachable','time-exceeded','parameter-problem','echo-request','source-quench')
    for kind in kinds:
        s=re.sub(r'^-A '+chain+r' -p icmp --icmp-type '+kind+r' -j DROP\n','',s,flags=re.M)
    marker=f'-A {chain} '
    hit=re.search('^'+re.escape(marker),s,re.M)
    if not hit: raise SystemExit('Missing UFW anchor: '+chain)
    rules=''.join(f'-A {chain} -p icmp --icmp-type {k} -j DROP\n' for k in kinds)
    s=s[:hit.start()]+'# BEGIN ROUTERFORGE ICMP DROP\n'+rules+'# END ROUTERFORGE ICMP DROP\n'+s[hit.start():]
p.write_text(s)
PY
 if ! iptables-restore --test < "$tmp"; then rm -f "$tmp"; die 'UFW before.rules test failed'; return 1; fi
 install -m 0640 "$tmp" /etc/ufw/before.rules; rm -f "$tmp"
 if ufw status | grep -q '^Status: active'; then
   info 'UFW ACTIVE: rules written; live reload requires separate approval.'
   if confirm 'Применить правила командой ufw reload?'; then ufw reload; fi
 else info 'UFW INACTIVE: rules staged only'; fi
 rfs_heading RESULT; info 'ICMP_RULES: 10 / STAGED'; info "BACKUP: $STATE_DIR/backups/before.rules.$stamp"
}
scanner_install(){
 root || return 1; ubuntu || return 1
 command -v curl >/dev/null && command -v python3 >/dev/null && command -v file >/dev/null || { die 'Requires curl, python3 and file; install packages first'; return 1; }
 rfs_heading 'SCANNER / INSTALL'; confirm 'Загрузить сканер XTLS/RealiTLScanner из GitHub Releases?' || return 0
 mkdir_state; local tmp tag url name; tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN
 python3 - "$tmp" <<'PY'
import json,urllib.request,re,pathlib,sys
folder=pathlib.Path(sys.argv[1]); req=urllib.request.Request('https://api.github.com/repos/XTLS/RealiTLScanner/releases/latest',headers={'User-Agent':'RouterForgeServer/0.1'})
with urllib.request.urlopen(req,timeout=25) as resp: release=json.load(resp)
assets=[a for a in release.get('assets',[]) if re.search(r'linux.*(amd64|x86_64|64)',a['name'],re.I) and not re.search(r'arm|checksum|sha256',a['name'],re.I)]
if not assets: raise SystemExit('No supported Linux amd64 release asset')
(folder/'url').write_text(assets[0]['browser_download_url']); (folder/'tag').write_text(release['tag_name'])
PY
 url=$(cat "$tmp/url"); tag=$(cat "$tmp/tag"); info "TAG: $tag"
 curl -fsSL --retry 2 --connect-timeout 15 --max-time 180 "$url" -o "$tmp/archive"
 if file "$tmp/archive" | grep -qi 'Zip archive'; then
   command -v unzip >/dev/null || { die 'unzip required'; return 1; }
   local entry; entry=$(unzip -Z1 "$tmp/archive" | grep -Ei '(^|/)realitlscanner$' | head -1)
   [[ -n "$entry" ]] || { die 'Scanner executable missing in zip'; return 1; }
   unzip -p "$tmp/archive" "$entry" > "$tmp/scanner"
 elif file "$tmp/archive" | grep -qi 'gzip compressed'; then
   local entry; entry=$(tar -tzf "$tmp/archive" | grep -Ei '(^|/)realitlscanner$' | head -1)
   [[ -n "$entry" ]] || { die 'Scanner executable missing in tar'; return 1; }
   tar -xOzf "$tmp/archive" "$entry" > "$tmp/scanner"
 else cp "$tmp/archive" "$tmp/scanner"; fi
 [[ "$(od -An -tx1 -N4 "$tmp/scanner" | tr -d ' \n')" == 7f454c46 ]] || { die 'Downloaded executable not ELF'; return 1; }
 install -d -m 0755 "$APP_DIR/bin"; install -m 0755 "$tmp/scanner" "$APP_DIR/bin/RealiTLScanner"
 printf '%s\n' "$tag" > "$APP_DIR/bin/scanner-version"
 rfs_heading RESULT; info "SCANNER_INSTALLED: $tag"
}
scanner_filter(){
 local src=$1 output=$2
 python3 - "$src" "$output" <<'PY'
import sys,csv,pathlib
src=pathlib.Path(sys.argv[1]); target=pathlib.Path(sys.argv[2]); required=('IP','CERT_DOMAIN','CERT_ISSUER'); cols=required+('GEO_CODE',); lang=__import__('os').environ.get('RFS_LANG','ru')
with src.open(encoding='utf-8-sig',newline='') as f:
  reader=csv.DictReader(f)
  if not reader.fieldnames or any(c not in reader.fieldnames for c in required):
    raise SystemExit('Unexpected scanner CSV columns: '+str(reader.fieldnames))
  records=set(); excluded=0
  for row in reader:
    record=tuple((row.get(c) or ('N/A' if c=='GEO_CODE' else '')).strip() for c in cols)
    if 'let\'s encrypt' in record[2].casefold() or 'lets encrypt' in record[2].casefold(): excluded+=1; continue
    if all(record): records.add(record)
records=sorted(records)
with target.open('w',encoding='utf-8',newline='') as f:
  writer=csv.writer(f); writer.writerow(cols);writer.writerows(records)
widths=[max([len(c)]+[len(r[i]) for r in records]) for i,c in enumerate(cols)]
fmt='  '.join('{:<'+str(w)+'}' for w in widths)
print(fmt.format(*(('IP','ДОМЕН','ИЗДАТЕЛЬ','СТРАНА') if lang=='ru' else ('IP','DOMAIN','ISSUER','COUNTRY'))));print(fmt.format(*('-'*w for w in widths)))
for r in records: print(fmt.format(*r))
print((f'Найдено: {len(records)} / Исключено Let’s Encrypt: {excluded}' if lang=='ru' else f'Found: {len(records)} / Excluded Let’s Encrypt: {excluded}')); print(f'RETAINED: {len(records)} / LETS_ENCRYPT_EXCLUDED: {excluded}')
PY
}
public_ip(){ curl -4fsS --connect-timeout 5 --max-time 10 https://api.ipify.org; }
# Only globally routable addresses configured on the VPS are offered.
# The selection determines the target /24; RealiTLScanner has no source-IP bind flag.
scanner_local_ips(){
 command -v ip >/dev/null || { die 'iproute2 is required'; return 1; }
 command -v python3 >/dev/null || { die 'python3 is required'; return 1; }
 ip -o -4 addr show scope global | python3 -c '
import sys,ipaddress
seen=set()
for line in sys.stdin:
    cols=line.split()
    if "inet" not in cols: continue
    n=cols.index("inet")
    if n+1>=len(cols): continue
    try: addr=ipaddress.ip_interface(cols[n+1]).ip
    except ValueError: continue
    if addr.is_global and addr not in seen:
        seen.add(addr)
        print(addr)
'
}
scanner_select_ip(){
 local -a addresses=()
 local ip answer count i
 mapfile -t addresses < <(scanner_local_ips)
 count=${#addresses[@]}
 if (( count == 0 )); then
   info 'PUBLIC_IPV4: no directly assigned public IPv4 detected.'
   info 'NAT / routed-IP environments require manual verification; refusing to infer /24 from outbound IP.'
   return 1
 fi
 if (( count == 1 )); then
   SCAN_SELECTED_IP=${addresses[0]}
   info "SELECTED_IPV4: $SCAN_SELECTED_IP (only public IPv4)"
   return 0
 fi
 info 'Выберите привязанный к VPS публичный IPv4:'
 for ((i=0;i<count;i++)); do printf '  [%d] %s\n' "$((i+1))" "${addresses[i]}"; done
 while :; do
   read -r -p "$(rfs_t 'Номер IP [1], 0 — отмена: ')" answer || return 1
   answer=${answer:-1}
   [[ "$answer" == 0 ]] && { info 'CANCELLED'; return 1; }
   if [[ "$answer" =~ ^[0-9]+$ ]] && (( 10#$answer >= 1 && 10#$answer <= count )); then
     SCAN_SELECTED_IP=${addresses[10#$answer-1]}
     info "SELECTED_IPV4: $SCAN_SELECTED_IP"
     return 0
   fi
   info 'Укажите номер IP из списка.'
 done
}
scanner_select_seconds(){
 local answer
 while :; do
   read -r -p "$(rfs_t 'Продолжительность сканирования в секундах') [${SCAN_SECONDS}]: " answer || return 1
   answer=${answer:-$SCAN_SECONDS}
   if [[ "$answer" =~ ^[0-9]{1,5}$ ]] && ((10#$answer >= 1 && 10#$answer <= 86400)); then
     SCAN_SELECTED_SECONDS=$((10#$answer))
     return 0
   fi
   info 'Укажите целое число секунд от 1 до 86400.'
 done
}
# P8: Follow scanner.log while running, with a live countdown.
# The full log is always written to the report, regardless of terminal capabilities.
# P9: optional Country.mmdb; called explicitly or offered if missing.
# Source is the GeoIP link documented by XTLS/RealiTLScanner.
scanner_geoip_install(){
 root || return 1
 local dest="$APP_DIR/bin/Country.mmdb" temp size sha
 if [[ -f "$dest" ]]; then
   confirm 'Country.mmdb уже существует. Обновить базу GeoIP?' || { info CANCELLED; return 0; }
 else
   confirm 'Загрузить базу Country.mmdb для определения страны IP?' || { info CANCELLED; return 0; }
 fi
 command -v curl >/dev/null && command -v python3 >/dev/null && command -v sha256sum >/dev/null || { die 'Requires curl, python3, sha256sum'; return 1; }
 install -d -m 0755 "$APP_DIR/bin"
 temp=$(mktemp "$APP_DIR/bin/.Country.mmdb.XXXXXXXX") || return 1
 if ! curl --proto '=https' --tlsv1.2 -fL --retry 2 --connect-timeout 15 --max-time 180 \
   'https://github.com/Loyalsoldier/geoip/releases/latest/download/Country.mmdb' -o "$temp"; then
   rm -f -- "$temp"; die 'GeoIP download failed'; return 1
 fi
 if ! python3 - "$temp" <<'PYMMDB'
from pathlib import Path
import sys
p=Path(sys.argv[1]); size=p.stat().st_size
assert 100_000 <= size <= 100_000_000, 'Unexpected Country.mmdb size'
with p.open('rb') as f:
    f.seek(max(0,size-131072)); tail=f.read()
assert b'\xab\xcd\xefMaxMind.com' in tail, 'Missing MaxMind DB metadata marker'
print('GEOIP_FORMAT: PASS / MAXMIND_DB_METADATA')
PYMMDB
 then
   rm -f -- "$temp"; die 'GeoIP database format invalid'; return 1
 fi
 chmod 0644 "$temp"
 sha=$(sha256sum "$temp" | awk '{print $1}')
 mv -f -- "$temp" "$dest"
 info "GEOIP_INSTALLED: $dest"
 info "GEOIP_SHA256: $sha (download fingerprint, not a publisher signature)"
}
# P10: produce one fixed-height frame, then update only modified terminal rows.
# Never clear the entire screen after initial draw.
rfs_scan_frame(){
 local start=$1 duration=$2 log=$3 network=$4 source_ip=$5 worker=$6 final=${7:-0}
 local elapsed remaining width=24 filled empty bar shade now maxrows
 now=$(date +%s); elapsed=$((now-start)); ((elapsed<0)) && elapsed=0
 remaining=$((duration-elapsed)); ((remaining<0)) && remaining=0
 filled=$((elapsed*width/duration)); ((filled>width)) && filled=$width
 empty=$((width-filled))
 printf -v bar '%*s' "$filled" ''; bar=${bar// /█}
 printf -v shade '%*s' "$empty" ''; shade=${shade// /░}
 maxrows=30
 if [[ -t 1 ]]; then
   local term_rows; term_rows=$(tput lines 2>/dev/null || printf '40')
   [[ "$term_rows" =~ ^[0-9]+$ ]] || term_rows=40
   if (( term_rows < maxrows + 10 )); then maxrows=$((term_rows-10)); fi
   ((maxrows<3)) && maxrows=3
 fi
 printf ' RF SERVER / TLS SCANNER\n'
 printf ' %s: %-18s | VPS IP: %s\n' "$(rfs_t 'Сеть')" "$network" "$source_ip"
 printf ' %s: %ds | %s: %ds | %s: %ds\n' "$(rfs_t 'Прошло')" "$elapsed" "$(rfs_t 'Осталось')" "$remaining" "$(rfs_t 'Лимит')" "$duration"
 if [[ "$final" == 0 ]]; then
   printf ' [%s%s] %d%% %s\n' "$bar" "$shade" "$((elapsed*100/duration))" "$(rfs_t 'Времени использовано')"
   printf ' %s (Ctrl+C)\n' "$(rfs_t 'СКАНИРОВАНИЕ')"
 elif [[ "$final" == 1 ]]; then
   printf ' %s: %ds\n' "$(rfs_t 'ЗАВЕРШЕНО')" "$elapsed"
 elif [[ "$final" == 124 ]]; then
   printf ' %s: %ds\n' "$(rfs_t 'ЛИМИТ ВРЕМЕНИ')" "$elapsed"
 else
   printf ' %s: %s\n' "$(rfs_t 'ПРЕРВАНО ИЛИ ОШИБКА')" "$final"
 fi
 RFS_SCAN_MAX_ROWS=$maxrows python3 - "$log" <<'PYLOG'
from collections import deque
from pathlib import Path
import re,sys,os
p=Path(sys.argv[1]); limit=max(3,min(30,int(os.environ.get('RFS_SCAN_MAX_ROWS','30'))))
rows=deque(maxlen=limit); total=0; last='—'; lang=os.environ.get('RFS_LANG','ru')
if p.is_file():
    for line in p.open(encoding='utf-8',errors='replace'):
        if 'msg="Connected to target"' not in line: continue
        total+=1
        def get(k):
            match=re.search(r'(?<![\w-])'+re.escape(k)+r'=(?:"([^"]*)"|([^\s]+))',line)
            return ((match.group(1) or match.group(2)) if match else '-')
        tm=re.search(r'time=([^\s]+)',line)
        last=tm.group(1)[11:19] if tm else '—'
        rows.append((get('ip'),get('cert-domain'),get('cert-issuer'),get('geo')))
if lang=='ru':
    print(f' Успешных TLS-подключений: {total} | Последняя активность: {last} | Последние {limit}')
    print(' IP               ДОМЕН                         ИЗДАТЕЛЬ           ГЕО')
else:
    print(f' Successful TLS: {total} | Last activity: {last} | Last {limit}')
    print(' IP               DOMAIN                        ISSUER            GEO')
if not rows: print(' Ожидание TLS-подключений...' if lang=='ru' else ' Waiting for TLS connections...')
for ip,domain,issuer,geo in rows:
    print(f' {ip:<15.15}  {domain:<29.29}  {issuer:<17.17} {geo:<5.5}')
print(' ' + '─'*70)
PYLOG
}
rfs_scan_render(){
 local content i total previous
 content=$(rfs_scan_frame "$@") || return 1
 if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
   local -a newlines=()
   mapfile -t newlines <<< "$content"
   if [[ "${RFS_SCAN_FIRST_FRAME:-1}" == 1 ]]; then
     printf '\033[H\033[2J\033[?25l'
     RFS_SCAN_FIRST_FRAME=0
   fi
   total=${#newlines[@]}; previous=${#RFS_SCAN_PREV_LINES[@]}
   for ((i=0;i<total;i++)); do
     if [[ "${RFS_SCAN_PREV_LINES[i]-}" != "${newlines[i]}" ]]; then
       printf '\033[%d;1H\033[2K%s' "$((i+1))" "${newlines[i]}"
     fi
   done
   for ((i=total;i<previous;i++)); do printf '\033[%d;1H\033[2K' "$((i+1))"; done
   RFS_SCAN_PREV_LINES=("${newlines[@]}")
   printf '\033[%d;1H' "$((total+1))"
 else
   printf '%s\n' "$content"
 fi
}
scanner_run(){ (
 root || exit 1
 [[ -x "$APP_DIR/bin/RealiTLScanner" ]] || { die 'Install scanner first'; exit 1; }
 command -v timeout >/dev/null || { die 'timeout missing'; exit 1; }
 local cidr stamp report rc=0 worker='' start elapsed next_log=0
 local SCAN_SELECTED_IP= SCAN_SELECTED_SECONDS=
 local RFS_SCAN_FIRST_FRAME=1
 local -a RFS_SCAN_PREV_LINES=()
 rfs_heading 'SCANNER / SCOPE'
 scanner_select_ip || { info 'SCANNER: CANCELLED / no network changes'; exit 0; }
 scanner_select_seconds || { info 'SCANNER: CANCELLED'; exit 0; }
 cidr=$(python3 - "$SCAN_SELECTED_IP" <<'PYIP'
import ipaddress,sys
p=ipaddress.ip_address(sys.argv[1]); assert p.version==4 and p.is_global
print(ipaddress.ip_network(f'{p}/24',strict=False))
PYIP
) || { die 'Cannot calculate public IPv4 network'; exit 1; }
 printf "%s: %s\n" "$(rfs_t 'Выбран IP VPS')" "$SCAN_SELECTED_IP"
 printf "%s: %s\n" "$(rfs_t 'Целевая сеть')" "$cidr"
 printf "%s: %s c / %s: %s\n" "$(rfs_t 'Лимит времени')" "$SCAN_SELECTED_SECONDS" "$(rfs_t 'Потоков')" "$SCAN_THREADS"
 info 'ВНИМАНИЕ: выбранный IP определяет сеть /24, но не исходящий IP соединений.'
 info 'Соседние IP могут принадлежать другим клиентам. Необходимо разрешение владельца сети.'
 confirm "$(rfs_t 'Запустить сканирование сети') $cidr (TCP 443)?" || { info CANCELLED; exit 0; }
 if [[ ! -f "$APP_DIR/bin/Country.mmdb" ]]; then
   scanner_geoip_install || info 'GeoIP недоступна, сканирование продолжится без неё'
 fi
 mkdir_state
 stamp=$(date -u +%Y%m%dT%H%M%SZ)
 report="$STATE_DIR/reports/${stamp}-${SCAN_SELECTED_IP//./-}"
 install -d -m 0750 "$report"
 printf 'selected_ip=%s\ntarget_cidr=%s\nscan_seconds=%s\n' "$SCAN_SELECTED_IP" "$cidr" "$SCAN_SELECTED_SECONDS" > "$report/scope.txt"
 : > "$report/scanner.log"
 (cd "$APP_DIR/bin" && exec timeout --signal=INT --kill-after=5 "${SCAN_SELECTED_SECONDS}s" \
   ./RealiTLScanner -addr "$cidr" -port 443 \
   -thread "$SCAN_THREADS" -timeout 5 -out "$report/raw.csv") > "$report/scanner.log" 2>&1 &
 worker=$!
 # Keep traps inside the scanner subshell; never mutate the main menu's traps.
 trap '[[ -z "$worker" ]] || { kill -TERM "$worker" 2>/dev/null || true; wait "$worker" 2>/dev/null || true; }; exit 130' INT
 trap '[[ -z "$worker" ]] || { kill -TERM "$worker" 2>/dev/null || true; wait "$worker" 2>/dev/null || true; }; exit 143' TERM
 trap 'printf '\033[?25h'; [[ -z "$worker" ]] || { if kill -0 "$worker" 2>/dev/null; then kill -TERM "$worker" 2>/dev/null || true; wait "$worker" 2>/dev/null || true; fi; }' EXIT
 start=$(date +%s)
 while kill -0 "$worker" 2>/dev/null; do
   if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
     rfs_scan_render "$start" "$SCAN_SELECTED_SECONDS" "$report/scanner.log" "$cidr" "$SCAN_SELECTED_IP" "$worker"
   else
     elapsed=$(( $(date +%s) - start ))
     if (( elapsed >= next_log )); then
       printf 'SCAN_PROGRESS: elapsed=%ds remaining=%ds\n' "$elapsed" "$((SCAN_SELECTED_SECONDS>elapsed?SCAN_SELECTED_SECONDS-elapsed:0))"
       tail -n 4 "$report/scanner.log" || true
       next_log=$((elapsed+10))
     fi
   fi
   sleep 1
 done
 if wait "$worker"; then rc=0; else rc=$?; fi
 worker=''
 trap - INT TERM EXIT
 if [[ -t 1 && "${TERM:-dumb}" != dumb ]]; then
   rfs_scan_render "$start" "$SCAN_SELECTED_SECONDS" "$report/scanner.log" "$cidr" "$SCAN_SELECTED_IP" 0 "$([[ $rc == 0 ]] && echo 1 || echo "$rc")"
 fi
 [[ -t 1 ]] && printf '\033[?25h' || true
 printf "%s: %s\n" "$(rfs_t 'Код завершения сканера')" "$rc"
 if [[ "$rc" != 0 && "$rc" != 124 && "$rc" != 130 ]]; then
   info 'ПРЕДУПРЕЖДЕНИЕ: сканер завершился с ошибкой, см. scanner.log'
 fi
 [[ -f "$report/raw.csv" ]] || { die "Scanner produced no CSV: $report/scanner.log"; exit 1; }
 scanner_filter "$report/raw.csv" "$report/filtered.csv" | tee "$report/summary.txt"
 rfs_heading RESULT; printf "%s: %s\n" "$(rfs_t 'Путь к отчёту')" "$report"; info 'Отчёт сохранён успешно'
) }

# Read-only update probe. A semantic version alone cannot distinguish dev builds:
# show both VERSION and the exact installed/available commit identifiers.
rfs_update_probe(){
 local channel local_sha remote_sha response raw remote_version
 RFS_UPDATE_STATE=unavailable
 RFS_UPDATE_LOCAL_VERSION="$VERSION"
 RFS_UPDATE_REMOTE_VERSION='unknown'
 RFS_UPDATE_LOCAL_SHA='local'
 RFS_UPDATE_REMOTE_SHA='unknown'
 channel=dev
 [[ -r "$APP_DIR/channel" ]] && channel=$(cat "$APP_DIR/channel")
 RFS_UPDATE_CHANNEL="$channel"
 [[ -r "$APP_DIR/revision" ]] && RFS_UPDATE_LOCAL_SHA=$(cat "$APP_DIR/revision")
 [[ "$channel" == dev || "$channel" == main ]] || return 0
 command -v curl >/dev/null && command -v python3 >/dev/null || return 0
 response=$(curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 3 --max-time 8 \
   -H 'Accept: application/vnd.github+json' -H 'User-Agent: RouterForge-Server' \
   "https://api.github.com/repos/Fifth-Ace/routerforge-server/commits/$channel" 2>/dev/null) || return 0
 remote_sha=$(printf '%s' "$response" | python3 -c 'import json,sys,re; s=json.load(sys.stdin).get("sha",""); print(s if re.fullmatch("[a-f0-9]{40}",s) else "")' 2>/dev/null) || return 0
 [[ "$remote_sha" =~ ^[a-f0-9]{40}$ ]] || return 0
 RFS_UPDATE_REMOTE_SHA=$remote_sha
 if [[ "$RFS_UPDATE_LOCAL_SHA" == "$remote_sha" ]]; then
   RFS_UPDATE_REMOTE_VERSION="$VERSION"
   RFS_UPDATE_STATE=current
 else
   # Resolve the version string from the exact pinned commit. If this second
   # request fails, do not pretend the remote release has the local version.
   raw=$(curl --proto '=https' --tlsv1.2 -fsSL --connect-timeout 3 --max-time 6 \
     "https://raw.githubusercontent.com/Fifth-Ace/routerforge-server/$remote_sha/manager.sh" 2>/dev/null) || raw=
   remote_version=$(printf '%s\n' "$raw" | sed -nE 's/^VERSION=([0-9A-Za-z.+_-]+)$/\1/p' | sed -n '1p')
   [[ -z "$remote_version" ]] || RFS_UPDATE_REMOTE_VERSION="$remote_version"
   RFS_UPDATE_STATE=available
 fi
 return 0
}
rfs_update_version_label(){
 local version=$1 sha=$2
 if [[ "$sha" =~ ^[a-f0-9]{40}$ ]]; then
   if [[ "$version" == unknown ]]; then
     printf 'ревизия %s' "${sha:0:12}"
   else
     printf '%s (%s)' "$version" "${sha:0:12}"
   fi
 else
   printf '%s (%s)' "$version" "$sha"
 fi
}
rfs_update_status_text(){
 local installed available
 installed=$(rfs_update_version_label "$RFS_UPDATE_LOCAL_VERSION" "$RFS_UPDATE_LOCAL_SHA")
 if [[ "$RFS_UPDATE_STATE" == unavailable ]]; then
   printf '%s: %s  |  %s' "$(rfs_t 'Установлена')" "$installed" "$(rfs_t 'Проверка обновлений недоступна')"
   return
 fi
 available=$(rfs_update_version_label "$RFS_UPDATE_REMOTE_VERSION" "$RFS_UPDATE_REMOTE_SHA")
 if [[ "$RFS_UPDATE_STATE" == current ]]; then
   printf '%s: %s  →  %s: %s  [%s]' "$(rfs_t 'Установлена')" "$installed" "$(rfs_t 'Доступна')" "$available" "$(rfs_t 'АКТУАЛЬНО')"
 else
   printf '%s: %s  →  %s: %s  [%s]' "$(rfs_t 'Установлена')" "$installed" "$(rfs_t 'Доступна')" "$available" "$(rfs_t 'ОБНОВЛЕНИЕ')"
 fi
}
rfs_check_update(){
 rfs_update_probe
 printf '%s\n' "$(rfs_update_status_text)"
 if [[ "$RFS_UPDATE_STATE" == available ]]; then
   info 'Новая версия доступна: пункт 10 или rfs self-update.'
 fi
}

self_update(){
 root || return 1
 local channel
 channel=dev
 if [[ -f "$APP_DIR/channel" ]]; then channel=$(cat "$APP_DIR/channel"); fi
 [[ "$channel" == dev || "$channel" == main ]] || { die 'Unknown installed channel. Reinstall from GitHub first'; return 1; }
 [[ -f "$APP_DIR/bootstrap.sh" ]] || { die 'Bootstrap not installed'; return 1; }
 rfs_heading 'UPDATE / ROUTERFORGE SERVER'
 info "CHANNEL: $channel"
 info 'Only program files are replaced. SSH, UFW and system services are untouched.'
 confirm "Обновить RouterForge Server из $channel?" || { info CANCELLED; return 0; }
 bash "$APP_DIR/bootstrap.sh" --update "--channel=$channel"
}
reports(){
 rfs_heading 'REPORTS / READ ONLY'
 local -a names=()
 local i choice selected rootpath
 [[ -d "$STATE_DIR/reports" ]] || { info 'Отчётов пока нет'; return 0; }
 mapfile -t names < <(find "$STATE_DIR/reports" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r | /usr/bin/head -n 20)
 ((${#names[@]})) || { info 'Отчётов пока нет'; return 0; }
 for ((i=0;i<${#names[@]};i++)); do
   printf ' [%2d] %s\n' "$((i+1))" "${names[i]}"
 done
 read -r -p "$(rfs_t 'Номер отчёта [0 — назад]: ')" choice || return 0
 choice=${choice:-0}
 [[ "$choice" == 0 ]] && return 0
 [[ "$choice" =~ ^[0-9]{1,2}$ ]] && ((10#$choice>=1 && 10#$choice<=${#names[@]})) || { info 'Неверный номер отчёта'; return 1; }
 selected=${names[10#$choice-1]}
 rootpath="$STATE_DIR/reports/$selected"
 [[ -d "$rootpath" && ! -L "$rootpath" ]] || { die 'Report directory unavailable'; return 1; }
 rfs_heading "REPORT / $selected"
 if [[ -f "$rootpath/scope.txt" && ! -L "$rootpath/scope.txt" ]]; then
   info "=== $(rfs_t 'ПАРАМЕТРЫ СКАНИРОВАНИЯ') ==="
   cat -- "$rootpath/scope.txt"
 fi
 if [[ -f "$rootpath/summary.txt" && ! -L "$rootpath/summary.txt" ]]; then
   info "=== $(rfs_t 'РЕЗУЛЬТАТЫ (БЕЗ LETS ENCRYPT)') ==="
   cat -- "$rootpath/summary.txt"
 else
   info 'SUMMARY: отсутствует (сканирование могло быть прервано)'
 fi
 if [[ -f "$rootpath/scanner.log" && ! -L "$rootpath/scanner.log" ]]; then
   info "=== $(rfs_t 'ЗАВЕРШЕНИЕ / ПОСЛЕДНИЕ СОБЫТИЯ') ==="
   grep -E 'Scanning completed|level=(WARN|ERROR)' "$rootpath/scanner.log" | tail -n 5 || true
 fi
 info "REPORT_PATH: $rootpath"
}

menu(){
 while :; do
  printf '\nRouterForge Server %s\n' "$VERSION"
  cat <<'TXT'
  1) Статус VPS (без изменений)
  2) Обновление Ubuntu
  3) SSH: подготовить порт 2202 (без рестарта)
  4) UFW: статус
  5) UFW: разрешить текущие SSH-порты
  6) UFW: ICMP DROP (опасные правила, подтверждение)
  7) RealiTLScanner: установка
  8) RealiTLScanner: соседи IPv4 /24 / 120 секунд
  9) Отчёты
  10) Обновить RouterForge Server
  0) Выход
TXT
  local choice; read -r -p 'Выбор: ' choice || break
  case "$choice" in
   1) status || true;; 2) updates || true;; 3) ssh_prepare || true;;
   4) ufw_status || true;; 5) ufw_ssh || true;; 6) ufw_icmp || true;;
   7) scanner_install || true;; 8) scanner_run || true;; 9) reports || true;;
   16) scanner_geoip_install || true;;
   10) self_update || true;; 0) break;; *) info 'Неизвестный пункт';;
  esac
 done
}
help_text(){
 if [[ "$RFS_LANG" == en ]]; then
  cat <<'TXT'
RouterForge Server
Usage: rfs [menu|status|update|check-update|ssh-prepare|ufw-status|ufw-ssh|ufw-icmp|scanner-install|scan|reports|self-update|language|lang ru|lang en|filter CSV OUTPUT]
SSH and firewall are never restarted/activated automatically by setup or update.
TXT
 else
  cat <<'TXT'
RouterForge Server
Использование: rfs [menu|status|update|check-update|ssh-prepare|ufw-status|ufw-ssh|ufw-icmp|scanner-install|scan|reports|self-update|language|lang ru|lang en|filter CSV OUTPUT]
Подготовка порта не перезапускает SSH. RFS не включает UFW автоматически.
TXT
 fi
}
main(){
 case "${1:-menu}" in
 menu) menu;; status) status;; update) updates;; ssh-prepare) ssh_prepare;; ufw-status) ufw_status;; ufw-ssh) ufw_ssh;; ufw-icmp) ufw_icmp;;
 scanner-install) scanner_install;; scan) scanner_run;; reports) reports;; self-update) self_update;; filter) [[ $# == 3 ]] || { help_text; return 2; }; scanner_filter "$2" "$3";;
 check-update) rfs_check_update;; language) rfs_language_menu;; lang) [[ "${2:-}" == ru || "${2:-}" == en ]] || return 2; [[ "$EUID" == 0 ]] || return 1; local tmp; tmp=$(mktemp "$APP_DIR/.language.XXXXXX"); printf "%s\n" "$2" > "$tmp"; chmod 0644 "$tmp"; mv -f "$tmp" "$APP_DIR/language";; version|--version) echo "$VERSION";; help|--help|-h) help_text;; *) help_text; return 2;;
 esac
}
if [[ -f "$APP_DIR/ui.sh" ]]; then source "$APP_DIR/ui.sh"; elif [[ -f "$(dirname "${BASH_SOURCE[0]}")/ui.sh" ]]; then source "$(dirname "${BASH_SOURCE[0]}")/ui.sh"; fi
main "$@"
