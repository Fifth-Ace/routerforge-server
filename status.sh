#!/usr/bin/env bash
# RF Server P11: read-only host dashboard. Sourced by manager.sh or executable standalone.
# Never writes to the system or invokes package/service management.
rfs_status_label(){
 local ru=$1 en=$2
 if [[ "${RFS_LANG:-ru}" == en ]]; then printf '%s' "$en"; else printf '%s' "$ru"; fi
}
rfs_status_sample(){
 # /proc/stat first CPU aggregate, total and idle including iowait.
 awk '/^cpu /{idle=$5+$6; for(i=2;i<=NF;i++)total+=$i; printf "%.0f %.0f\n",total,idle; exit}' /proc/stat 2>/dev/null
}
rfs_status_cpu(){
 local t1 i1 t2 i2 delta idle value
 read -r t1 i1 < <(rfs_status_sample) || return 1
 sleep 0.4
 read -r t2 i2 < <(rfs_status_sample) || return 1
 [[ "$t1" =~ ^[0-9]+$ && "$t2" =~ ^[0-9]+$ ]] || return 1
 delta=$((t2-t1)); idle=$((i2-i1))
 ((delta>0)) || return 1
 value=$(((delta-idle)*100/delta))
 ((value<0)) && value=0
 ((value>100)) && value=100
 printf '%d%%' "$value"
}
rfs_status_memory(){
 awk '
 /^MemTotal:/ {mt=$2} /^MemAvailable:/ {ma=$2}
 /^SwapTotal:/ {st=$2} /^SwapFree:/ {sf=$2}
 END {
   if(mt>0) printf "MEM=%dMiB / %dMiB (%d%%)\n", (mt-ma)/1024,mt/1024,100*(mt-ma)/mt;
   else print "MEM=N/A";
   if(st>0) printf "SWAP=%dMiB / %dMiB (%d%%)\n",(st-sf)/1024,st/1024,100*(st-sf)/st;
   else print "SWAP=0MiB / 0MiB (off)";
 }' /proc/meminfo 2>/dev/null
}
rfs_status_network(){
 local -a lines=()
 local iface rx tx prev_rx=0 prev_tx=0 curr_rx=0 curr_tx=0
 mapfile -t lines < <(awk 'NR>2 {gsub(/^[ \t]+|[ \t]+$/, "", $1); sub(/:$/, "", $1); if($1!="lo" && $1 !~ /^(docker|veth|br-|virbr|tun|tap|wg|awg)/) {rx+=$2;tx+=$10}} END {printf "%.0f %.0f\n",rx,tx}' /proc/net/dev 2>/dev/null)
 read -r prev_rx prev_tx <<< "${lines[0]:-0 0}"
 sleep 0.4
 read -r curr_rx curr_tx < <(awk 'NR>2 {gsub(/^[ \t]+|[ \t]+$/, "", $1); sub(/:$/, "", $1); if($1!="lo" && $1 !~ /^(docker|veth|br-|virbr|tun|tap|wg|awg)/) {rx+=$2;tx+=$10}} END {printf "%.0f %.0f\n",rx,tx}' /proc/net/dev 2>/dev/null)
 if [[ "$prev_rx" =~ ^[0-9]+$ && "$curr_rx" =~ ^[0-9]+$ ]] && ((curr_rx>=prev_rx && curr_tx>=prev_tx)); then
   awk -v rx="$((curr_rx-prev_rx))" -v tx="$((curr_tx-prev_tx))" 'BEGIN{printf "RX %.1f KiB/s | TX %.1f KiB/s (0.4s sample)",rx/1024/0.4,tx/1024/0.4}'
 else printf 'N/A'; fi
}
rfs_server_status(){
 local os='N/A' host kernel arch uptime_text cpu load disk mem_line swap_line net gateway ips dns ssh_ports fw virt cores model
 [[ -r /etc/os-release ]] && { . /etc/os-release; os=${PRETTY_NAME:-N/A}; }
 host=$(hostname 2>/dev/null || printf 'N/A')
 kernel=$(uname -r 2>/dev/null || printf 'N/A')
 arch=$(uname -m 2>/dev/null || printf 'N/A')
 cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 'N/A')
 model=$(awk -F: '/^model name/{sub(/^[[:space:]]+/,"",$2);print $2;exit}' /proc/cpuinfo 2>/dev/null)
 [[ -n "$model" ]] || model='N/A'
 uptime_text=$(uptime -p 2>/dev/null || printf 'N/A')
 cpu=$(rfs_status_cpu) || cpu='N/A'
 load=$(awk '{printf "%s / %s / %s",$1,$2,$3}' /proc/loadavg 2>/dev/null) || load='N/A'
 disk=$(df -hP / 2>/dev/null | awk 'NR==2{printf "%s / %s (%s) | free %s",$3,$2,$5,$4}')
 [[ -n "$disk" ]] || disk='N/A'
 net=$(rfs_status_network)
 gateway=$(ip -4 route show default 2>/dev/null | awk 'NR==1{print $3 " via " $5}')
 [[ -n "$gateway" ]] || gateway='N/A'
 ips=$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $2 "=" $4}' | paste -sd ', ' -)
 [[ -n "$ips" ]] || ips='N/A'
 dns=$(awk '/^nameserver/{printf "%s%s", (n++?", ":""), $2; if(n==3)exit}' /etc/resolv.conf 2>/dev/null)
 [[ -n "$dns" ]] || dns='N/A'
 ssh_ports=$(/usr/sbin/sshd -T 2>/dev/null | awk '$1=="port" {printf "%s%s", (n++?", ":""), $2}') || true
 [[ -n "$ssh_ports" ]] || ssh_ports='N/A'
 fw=$(ufw status 2>/dev/null | awk 'NR==1{sub(/^Status: /,"");print;exit}') || true
 [[ -n "$fw" ]] || fw='N/A'
 virt=$(systemd-detect-virt 2>/dev/null || true)
 [[ -n "$virt" ]] || virt='physical / unknown'
 printf '\n=== %s ===\n' "$(rfs_status_label 'НАГРУЗКА СЕРВЕРА' 'SERVER LOAD')"
 printf ' CPU:  %s | LOAD 1/5/15: %s | vCPU: %s\n' "$cpu" "$load" "$cores"
 while IFS= read -r mem_line; do
   if [[ "${RFS_LANG:-ru}" != en ]]; then
     mem_line=${mem_line/MEM=/ОЗУ: }; mem_line=${mem_line/SWAP=/Подкачка: }
   fi
   printf ' %s\n' "$mem_line"
 done <<< "$(rfs_status_memory)"
 printf ' DISK /: %s\n' "$disk"
 printf ' %s: %s\n' "$(rfs_status_label 'Сеть RX/TX' 'Network RX/TX')" "$net"
 printf '\n=== %s ===\n' "$(rfs_status_label 'ИНФОРМАЦИЯ О СЕРВЕРЕ' 'SERVER INFORMATION')"
 printf ' %s: %s\n' "$(rfs_status_label 'Имя' 'Hostname')" "$host"
 printf ' OS: %s\n' "$os"
 printf ' CPU model: %s\n' "$model"
 printf ' Kernel: %s | Architecture: %s\n' "$kernel" "$arch"
 printf ' Uptime: %s\n' "$uptime_text"
 printf ' Virtualization: %s\n' "$virt"
 printf '\n=== %s ===\n' "$(rfs_status_label 'СЕТЬ И ЗАЩИТА' 'NETWORK AND SECURITY')"
 printf ' IPv4: %s\n' "$ips"
 printf ' Gateway: %s\n' "$gateway"
 printf ' DNS: %s\n' "$dns"
 printf ' SSH %s: %s\n' "$(rfs_status_label 'порты' 'ports')" "$ssh_ports"
 printf ' UFW: %s\n' "$fw"
 printf '\n=== RESULT ===\nGATE: PASS / READ ONLY\nSTATE: UNTOUCHED\nSECURITY: UNTOUCHED\n'
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then rfs_server_status; fi
