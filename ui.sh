#!/usr/bin/env bash
# RouterForge Server P6: colorful sectional TUI and opt-in third-party installers.
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
rfs_pause(){ if [[ -t 0 ]]; then read -r -p 'Enter — в меню...' _ || true; fi; }
rfs_terminal_on(){
 if [[ -t 0 && -t 1 && "${TERM:-dumb}" != dumb ]]; then
   RFS_TUI_ACTIVE=1
   printf '\033[?1049h\033[?25h'
 else RFS_TUI_ACTIVE=0; fi
}
rfs_terminal_off(){
 if [[ "${RFS_TUI_ACTIVE:-0}" == 1 ]]; then
   printf '\033[0m\033[?25h\033[?1049l'
 fi
}
rfs_redraw(){
 if [[ "${RFS_TUI_ACTIVE:-0}" == 1 ]]; then printf '\033[H\033[2J'; fi
 return 0
}
rfs_banner(){
 # Compact 7-row pixel font with cyan highlights and a dark lower edge.
 # Plain Unicode fallback works when NO_COLOR=1; no external font dependency.
 local c_top c_mid c_low c_shadow
 if [[ -t 1 && -z ${NO_COLOR:-} ]]; then
  c_top=$'\033[1;96m'; c_mid=$'\033[96m'; c_low=$'\033[36m'; c_shadow=$'\033[90m'
 else
  c_top=; c_mid=; c_low=; c_shadow=
 fi
 printf '%s%s%s\n' "$c_top" '  ████  █████     ████ █████ ████  █   █ █████ ████' "$RFS_RESET"
 printf '%s%s%s\n' "$c_top" '  █   █ █        █     █     █   █ █   █ █     █   █' "$RFS_RESET"
 printf '%s%s%s\n' "$c_mid" '  █   █ █        █     █     █   █ █   █ █     █   █' "$RFS_RESET"
 printf '%s%s%s\n' "$c_mid" '  ████  ████      ███  ████  ████  █   █ ████  ████' "$RFS_RESET"
 printf '%s%s%s\n' "$c_mid" '  █ █   █            █ █     █ █    █ █  █     █ █' "$RFS_RESET"
 printf '%s%s%s\n' "$c_low" '  █  █  █            █ █     █  █   █ █  █     █  █' "$RFS_RESET"
 printf '%s%s%s\n' "$c_low" '  █   █ █        ████  █████ █   █   █   █████ █   █' "$RFS_RESET"
 printf '%s%s%s\n' "$c_shadow" '   ▀   ▀ ▀        ▀▀▀▀  ▀▀▀▀▀ ▀   ▀   ▀   ▀▀▀▀▀ ▀   ▀' "$RFS_RESET"
 printf '  %sRouterForge Server%s  %s%s%s\n' "$RFS_BOLD" "$RFS_RESET" "$RFS_DIM" "$VERSION" "$RFS_RESET"
}
rfs_draw_menu(){
 rfs_redraw
 rfs_banner
 rfs_line
 rfs_update_display
 rfs_title 'СИСТЕМА И ДИАГНОСТИКА'
 rfs_option 1 'Состояние VPS'; rfs_option 2 'Обновить Ubuntu'
 rfs_title 'SSH И ЗАЩИТА'
 rfs_option 3 'Подготовить SSH: указать порт вручную (без рестарта)'
 rfs_option 4 'Статус UFW'; rfs_option 5 'Разрешить действующие SSH-порты в UFW'
 printf ' %s[6]%s ICMP DROP (опасно — отдельно подтверждается)\n' "$RFS_YELLOW" "$RFS_RESET"
 rfs_title 'СКАНИРОВАНИЕ И ОТЧЁТЫ'
 rfs_option 7 'Установить RealiTLScanner'; rfs_option 8 'Сканировать соседнюю сеть /24 (IP + время)'
 rfs_option 9 'Посмотреть отчёты'
 rfs_title 'УСТАНОВКА СЕРВИСОВ'
 rfs_option 11 'Классический 3x-ui (MHSanaei)'
 rfs_option 12 'LucX-UI (AlexeyLCP)'
 rfs_option 13 'RKN Guard (Flecksis)'
 rfs_option 14 'MTProxyL (Liafanx)'
 rfs_title 'ROUTERFORGE SERVER'
 rfs_option 10 'Обновить RFS'; rfs_option 15 'Проверить обновления RFS'
 rfs_option 0 'Выход'
 rfs_line
}
rfs_update_refresh(){
 # Cache the last check for five minutes, unless manually forced.
 local force=${1:-0} now
 now=$(date +%s)
 if [[ "$force" == 1 || -z "${RFS_UPDATE_LAST_CHECK:-}" ]] ||
    (( now - RFS_UPDATE_LAST_CHECK >= 300 )); then
   rfs_update_probe
   RFS_UPDATE_LAST_CHECK=$now
 fi
}
rfs_update_display(){
 local line state_color=
 line=$(rfs_update_status_text)
 case "${RFS_UPDATE_STATE:-unavailable}" in
  available) state_color="$RFS_YELLOW" ;;
  current) state_color="$RFS_GREEN" ;;
  *) state_color="$RFS_DIM" ;;
 esac
 printf ' %s%s%s\n' "$state_color" "$line" "$RFS_RESET"
}
rfs_menu(){
 # Read-only check on entry and every five minutes while waiting for input.
 # No background worker, no automatic installation or service changes.
 (
  trap 'rfs_terminal_off' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  rfs_terminal_on
  local choice rc before_revision after_revision request_reexec=0
  rfs_update_refresh 1
  while :; do
   rfs_update_refresh
   rfs_draw_menu
   if [[ "${RFS_TUI_ACTIVE:-0}" == 1 ]]; then
     if read -r -t 30 -p 'Выбор [0 — выход]: ' choice; then
       rc=0
     else
       rc=$?
     fi
   else
     read -r -p 'Выбор [0 — выход]: ' choice || break
     rc=0
   fi
   if [[ "${RFS_TUI_ACTIVE:-0}" == 1 && "$rc" != 0 ]]; then
     # Bash uses statuses >128 for timeout, 1 for EOF/disconnected input.
     if (( rc > 128 )); then continue; fi
     break
   fi
   # Empty Enter exits the main menu; timeout/EOF above never implies selection.
   choice=${choice:-0}
   [[ "$choice" == 0 ]] && break
   rfs_redraw
   rfs_banner
   rfs_line
   case "$choice" in
    1) status || true;; 2) updates || true;; 3) ssh_prepare || true;;
    4) ufw_status || true;; 5) ufw_ssh || true;; 6) ufw_icmp || true;;
    7) scanner_install || true;; 8) scanner_run || true;; 9) reports || true;;
    10)
      before_revision=$(cat "$APP_DIR/revision" 2>/dev/null || printf 'unknown')
      if self_update; then
        after_revision=$(cat "$APP_DIR/revision" 2>/dev/null || printf 'unknown')
        if [[ "$after_revision" =~ ^[a-f0-9]{40}$ && "$after_revision" != "$before_revision" ]]; then
          info "RFS_RESTART: $before_revision -> $after_revision"
          request_reexec=1
          break
        fi
      else
        info 'RFS_UPDATE: FAILED / current menu remains active'
      fi
      ;;
    15) rfs_update_refresh 1; rfs_update_display;;
    11) rfs_install_third_party 3x-ui || true;;
    12) rfs_install_third_party lucx-ui || true;;
    13) rfs_install_third_party rkn-guard || true;;
    14) rfs_install_third_party mtproxyl || true;;
    *) info 'Неизвестный пункт';;
   esac
   rfs_pause
  done
  # Return a distinct status after alternate-screen EXIT cleanup.
  # Parent shell execs fresh code instead of reusing previously sourced functions.
  if [[ "$request_reexec" == 1 ]]; then return 75; fi
 )
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
  lucx-ui)
   ref='AlexeyLCP/lucx-ui / main'; url='https://raw.githubusercontent.com/AlexeyLCP/lucx-ui/main/install.sh'
   # Both LucX and classic 3x-ui use x-ui files/service. Block accidental replacement.
   if [[ -e /usr/local/x-ui || -e /etc/x-ui || -e /etc/systemd/system/x-ui.service ]] || command -v x-ui >/dev/null 2>&1; then
    die 'Найдена установленная панель x-ui/LucX. Перед миграцией нужна отдельная резервная копия; автоматическая установка заблокирована.'; return 1
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
menu(){
 local result=0
 rfs_menu || result=$?
 if (( result == 75 )); then
   if [[ -x "$APP_DIR/manager.sh" ]]; then
     exec "$APP_DIR/manager.sh" menu
   fi
   die 'Installed RFS entrypoint missing after update'
   return 1
 fi
 return "$result"
}
