#!/usr/bin/env bash
# RouterForge Server P4: colorful sectional TUI and opt-in third-party installers.
# This file is sourced by manager.sh, not executed directly.
if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  RFS_RESET=$'\033[0m'; RFS_BOLD=$'\033[1m'; RFS_BLUE=$'\033[36m'
  RFS_GREEN=$'\033[32m'; RFS_YELLOW=$'\033[33m'; RFS_DIM=$'\033[2m'
else
  RFS_RESET=; RFS_BOLD=; RFS_BLUE=; RFS_GREEN=; RFS_YELLOW=; RFS_DIM=
fi
rfs_line(){ printf '%s\n' '──────────────────────────────────────────────────'; }
rfs_title(){ printf '\n%s%s%s\n' "$RFS_BLUE" "$1" "$RFS_RESET"; }
rfs_option(){ printf ' %s[%s]%s %s\n' "$RFS_GREEN" "$1" "$RFS_RESET" "$2"; }
rfs_pause(){ if [[ -t 0 ]]; then read -r -p 'Enter — продолжить...' _ || true; fi; }
rfs_menu(){
 while :; do
  printf '\n%s%s RouterForge Server %s %s\n' "$RFS_BOLD" "$RFS_BLUE" "$VERSION" "$RFS_RESET"
  rfs_line
  rfs_title 'СИСТЕМА И ДИАГНОСТИКА'
  rfs_option 1 'Состояние VPS'; rfs_option 2 'Обновить Ubuntu'
  rfs_title 'SSH И ЗАЩИТА'
  rfs_option 3 'Подготовить SSH 2202 (без перезапуска)'
  rfs_option 4 'Статус UFW'; rfs_option 5 'Разрешить SSH-порты в UFW'
  printf ' %s[6]%s ICMP DROP (опасно — отдельно подтверждается)\n' "$RFS_YELLOW" "$RFS_RESET"
  rfs_title 'СКАНИРОВАНИЕ И ОТЧЁТЫ'
  rfs_option 7 'Установить RealiTLScanner'; rfs_option 8 'Сканировать разрешённую сеть /24 (120 с)'
  rfs_option 9 'Посмотреть отчёты'
  rfs_title 'УСТАНОВКА СЕРВИСОВ'
  rfs_option 11 'Классический 3x-ui (MHSanaei)'
  rfs_option 12 'RKN Guard (Flecksis)'
  rfs_option 13 'MTProxyL (Liafanx)'
  rfs_title 'ROUTERFORGE SERVER'
  rfs_option 10 'Обновить RFS'; rfs_option 0 'Выход'
  rfs_line
  local choice
  read -r -p 'Выбор: ' choice || break
  case "$choice" in
   1) status || true;; 2) updates || true;; 3) ssh_prepare || true;;
   4) ufw_status || true;; 5) ufw_ssh || true;; 6) ufw_icmp || true;;
   7) scanner_install || true;; 8) scanner_run || true;; 9) reports || true;;
   10) self_update || true;;
   11) rfs_install_third_party 3x-ui || true;;
   12) rfs_install_third_party rkn-guard || true;;
   13) rfs_install_third_party mtproxyl || true;;
   0) break;; *) info 'Неизвестный пункт';;
  esac
  rfs_pause
 done
}
rfs_install_third_party(){
 root || return 1
 local name=${1:-} url ref extra=() tmp sum
 case "$name" in
  3x-ui)
   ref='MHSanaei/3x-ui / master'; url='https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh'
   # Both projects use x-ui: never run upstream installer over an existing panel.
   if [[ -e /usr/local/x-ui || -e /etc/x-ui || -e /etc/systemd/system/x-ui.service ]] || command -v x-ui >/dev/null 2>&1; then
    die 'Обнаружен существующий x-ui/LucX. Установка заблокирована во избежание перезаписи.'; return 1
   fi
   ;;
  rkn-guard)
   ref='Flecksis/rkn-guard / master'; url='https://raw.githubusercontent.com/Flecksis/rkn-guard/master/install.sh'
   extra=(install)
   ;;
  mtproxyl)
   ref='Liafanx/MTProxyL / main'; url='https://raw.githubusercontent.com/Liafanx/MTProxyL/main/install.sh'
   ;;
  *) die 'Unknown installer'; return 1;;
 esac
 command -v curl >/dev/null || { die 'curl не установлен'; return 1; }
 head "THIRD-PARTY / $name"
 info "SOURCE: $ref"
 info "URL: $url"
 info 'Внешний установщик может изменить firewall, Docker, сервисы и порты.'
 info 'RouterForge Server не контролирует изменения, выполняемые внешним проектом.'
 confirm "Скачать и запустить установщик $name от root?" || { info CANCELLED; return 0; }
 tmp=$(mktemp /tmp/rfs-external.XXXXXXXX.sh) || return 1
 if ! curl --proto '=https' --tlsv1.2 -fsSL --retry 2 --connect-timeout 10 --max-time 90 "$url" -o "$tmp"; then
  rm -f "$tmp"; die 'Download failed'; return 1
 fi
 if ! bash -n "$tmp"; then rm -f "$tmp"; die 'Upstream Bash syntax invalid'; return 1; fi
 sum=$(sha256sum "$tmp" | awk '{print $1}')
 info "DOWNLOADED_SHA256: $sum"
 info 'Этот SHA256 — идентификатор загрузки, не независимая проверка издателя.'
 if ! confirm "Подтвердить выполнение полученного $name (SHA выше)?"; then
  rm -f "$tmp"; info CANCELLED; return 0
 fi
 bash "$tmp" "${extra[@]}"
 local rc=$?
 rm -f "$tmp"
 return "$rc"
}
# Preserve the existing CLI name for compatibility, replace only interactive menu.
menu(){ rfs_menu; }
