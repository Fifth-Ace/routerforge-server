#!/usr/bin/env bash
# RouterForge Server language catalog; Russian is the default.
# Source from manager.sh only, never execute as a standalone program.
RFS_LANG=${RFS_LANG:-}
if [[ -z "$RFS_LANG" && -r "${APP_DIR:-/opt/routerforge-server}/language" ]]; then
  IFS= read -r RFS_LANG < "${APP_DIR:-/opt/routerforge-server}/language" || true
fi
[[ "$RFS_LANG" == ru || "$RFS_LANG" == en ]] || RFS_LANG=ru
export RFS_LANG

declare -A RFS_EN=()
RFS_EN['СИСТЕМА И ДИАГНОСТИКА']='SYSTEM AND DIAGNOSTICS'
RFS_EN['SSH И ЗАЩИТА']='SSH AND SECURITY'
RFS_EN['СКАНИРОВАНИЕ И ОТЧЁТЫ']='SCANNING AND REPORTS'
RFS_EN['УСТАНОВКА СЕРВИСОВ']='INSTALL SERVICES'
RFS_EN['НАСТРОЙКИ']='SETTINGS'
RFS_EN['Состояние VPS']='VPS status'
RFS_EN['Обновить Ubuntu']='Update Ubuntu'
RFS_EN['Подготовить SSH: указать порт вручную (без рестарта)']='Configure SSH: custom port (no restart)'
RFS_EN['Статус UFW']='UFW status'
RFS_EN['Разрешить действующие SSH-порты в UFW']='Allow configured SSH ports in UFW'
RFS_EN['ICMP DROP (опасно — отдельно подтверждается)']='ICMP DROP (dangerous, requires approval)'
RFS_EN['Установить RealiTLScanner']='Install RealiTLScanner'
RFS_EN['Сканировать соседнюю сеть /24 (IP + время)']='Scan adjacent /24 (IP + duration)'
RFS_EN['Посмотреть отчёты']='View reports'
RFS_EN['Установить / обновить базу GeoIP Country.mmdb']='Install / update GeoIP Country.mmdb'
RFS_EN['Классический 3x-ui (MHSanaei)']='Classic 3x-ui (MHSanaei)'
RFS_EN['Обновить RFS']='Update RFS'
RFS_EN['Проверить обновления RFS']='Check RFS updates'
RFS_EN['Выход']='Exit'
RFS_EN['Выбор [0 — выход]: ']='Choice [0 — exit]: '
RFS_EN['Enter — в меню...']='Enter — back to menu...'
RFS_EN['Сборка']='Build'
RFS_EN['Канал']='Channel'
RFS_EN['Установлена']='Installed'
RFS_EN['Доступна']='Available'
RFS_EN['АКТУАЛЬНО']='CURRENT'
RFS_EN['ОБНОВЛЕНИЕ']='UPDATE'
RFS_EN['Проверка обновлений недоступна']='Update check unavailable'
RFS_EN['Язык / Language']='Language / Язык'
RFS_EN['Выберите язык [1 — Русский, 2 — English, 0 — назад]: ']='Select language [1 — Русский, 2 — English, 0 — back]: '
RFS_EN['Русский']='Russian'
RFS_EN['Английский']='English'
RFS_EN['Язык интерфейса установлен']='Interface language set'
RFS_EN['Выполнить apt update + upgrade без вопросов?']='Run unattended apt update + upgrade?'
RFS_EN['Подготовить конфигурацию SSH?']='Stage SSH configuration?'
RFS_EN['Неверный номер отчёта']='Invalid report number'
RFS_EN['Отчётов пока нет']='No reports available'
RFS_EN['Номер отчёта [0 — назад]: ']='Report number [0 — back]: '
RFS_EN['ПАРАМЕТРЫ СКАНИРОВАНИЯ']='SCAN PARAMETERS'
RFS_EN['РЕЗУЛЬТАТЫ (БЕЗ LETS ENCRYPT)']='RESULTS (EXCLUDING LETS ENCRYPT)'
RFS_EN['ЗАВЕРШЕНИЕ / ПОСЛЕДНИЕ СОБЫТИЯ']='COMPLETION / LATEST EVENTS'
RFS_EN['Укажите номер IP из списка.']='Enter an IP number from the list.'
RFS_EN['Выберите привязанный к VPS публичный IPv4:']='Choose a public IPv4 assigned to this VPS:'
RFS_EN['Номер IP [1], 0 — отмена: ']='IP number [1], 0 — cancel: '
RFS_EN['Продолжительность сканирования в секундах']='Scan duration in seconds'
RFS_EN['Укажите целое число секунд от 1 до 86400.']='Enter an integer from 1 to 86400 seconds.'
RFS_EN['Ожидание успешных TLS-подключений...']='Waiting for successful TLS connections...'
RFS_EN['Сеть']='Network'
RFS_EN['Прошло']='Elapsed'
RFS_EN['Осталось']='Remaining'
RFS_EN['Лимит']='Limit'
RFS_EN['Времени использовано']='Time used'
RFS_EN['СКАНИРОВАНИЕ']='SCANNING'
RFS_EN['ЗАВЕРШЕНО']='COMPLETED'
RFS_EN['ЛИМИТ ВРЕМЕНИ']='TIME LIMIT'
RFS_EN['ПРЕРВАНО ИЛИ ОШИБКА']='STOPPED OR ERROR'
RFS_EN['Последняя активность']='Last activity'
RFS_EN['Успешных TLS-подключений']='Successful TLS connections'
RFS_EN['IP']='IP'
RFS_EN['ДОМЕН']='DOMAIN'
RFS_EN['ИЗДАТЕЛЬ']='ISSUER'
RFS_EN['СТРАНА']='COUNTRY'
RFS_EN['ИТОГ СКАНИРОВАНИЯ']='SCAN SUMMARY'
RFS_EN['Найдено']='Found'
RFS_EN['Исключено Let’s Encrypt']='Excluded Let’s Encrypt'
RFS_EN['Загрузить базу Country.mmdb для определения страны IP?']='Download Country.mmdb for IP geolocation?'
RFS_EN['Country.mmdb уже существует. Обновить базу GeoIP?']='Country.mmdb exists. Update GeoIP database?'
RFS_EN['Запустить сканирование']='Start scanning'
RFS_EN['Ответьте Y или n']='Answer Y or n'
RFS_EN['Новая версия доступна: пункт 10 или rfs self-update.']='Update available: option 10 or rfs self-update.'
RFS_EN['Обновить RouterForge Server из']='Update RouterForge Server from'
RFS_EN['Only program files are replaced. SSH, UFW and system services are untouched.']='Only program files are replaced. SSH, UFW and system services are untouched.'

RFS_EN['Введите новый SSH-порт (1–65535, пусто — отмена): ']='New SSH port (1–65535, blank to cancel): '
RFS_EN['Отчётов пока нет']='No reports available'

RFS_EN['PRECHECK / READ ONLY']='PRECHECK / READ ONLY'
RFS_EN['PRECHECK / APT']='PRECHECK / APT'
RFS_EN['PRECHECK / SSH / CONFIG ONLY']='PRECHECK / SSH / CONFIG ONLY'
RFS_EN['FIREWALL / READ ONLY']='FIREWALL / READ ONLY'
RFS_EN['PRECHECK / SSH PORTS']='PRECHECK / SSH PORTS'
RFS_EN['SECURITY / ICMP RULES']='SECURITY / ICMP RULES'
RFS_EN['SCANNER / INSTALL']='SCANNER / INSTALL'
RFS_EN['SCANNER / SCOPE']='SCANNER / SCOPE'
RFS_EN['UPDATE / ROUTERFORGE SERVER']='UPDATE / ROUTERFORGE SERVER'
RFS_EN['REPORTS / READ ONLY']='REPORTS / READ ONLY'
RFS_EN['Добавить ALLOW TCP для всех SSH-портов из конфига? UFW не будет включён']='Add UFW TCP ALLOW for all configured SSH ports? UFW will not be enabled'
RFS_EN['Установить 10 DROP ICMP-правил (INPUT + FORWARD) как на скриншоте?']='Install 10 ICMP DROP rules (INPUT + FORWARD)?'
RFS_EN['Применить правила командой ufw reload?']='Apply rules using ufw reload?'
RFS_EN['Загрузить сканер XTLS/RealiTLScanner из GitHub Releases?']='Download XTLS/RealiTLScanner from GitHub Releases?'
RFS_EN['Неизвестный пункт']='Unknown option'
RFS_EN['SUMMARY: отсутствует (сканирование могло быть прервано)']='SUMMARY: missing (scan may have been interrupted)'
RFS_EN['Выберите привязанный к VPS публичный IPv4:']='Choose a public IPv4 assigned to this VPS:'
RFS_EN['Получено']='Received'
RFS_EN['Ответьте Y или n']='Answer Y or n'
RFS_EN['Выполнить apt update + upgrade без вопросов?']='Run apt update + upgrade without additional prompts?'
RFS_EN['Отчётов пока нет']='No reports available'
RFS_EN['Неверный номер отчёта']='Invalid report number'
RFS_EN['Загрузить базу Country.mmdb для определения страны IP?']='Download Country.mmdb IP geolocation database?'
RFS_EN['Country.mmdb уже существует. Обновить базу GeoIP?']='Country.mmdb exists. Update GeoIP database?'
RFS_EN['root required']='root required'
RFS_EN['Missing os-release']='missing os-release'
RFS_EN['Ubuntu required']='Ubuntu required'
RFS_EN['sshd missing']='sshd missing'
RFS_EN['Cannot read sshd config']='cannot read sshd configuration'
RFS_EN['No configured SSH ports']='no configured SSH ports'
RFS_EN['Invalid TCP port']='invalid TCP port'
RFS_EN['SSH validation failed: restored original drop-in']='SSH validation failed: restored original drop-in'
RFS_EN['Install ufw first']='install ufw first'
RFS_EN['iptables-restore missing']='iptables-restore missing'
RFS_EN['/etc/ufw/before.rules missing']='/etc/ufw/before.rules missing'
RFS_EN['UFW before.rules test failed']='UFW before.rules test failed'
RFS_EN['Requires curl, python3 and file; install packages first']='requires curl, python3 and file; install packages first'
RFS_EN['unzip required']='unzip required'
RFS_EN['Scanner executable missing in zip']='scanner executable missing in zip'
RFS_EN['Scanner executable missing in tar']='scanner executable missing in tar'
RFS_EN['Downloaded executable not ELF']='downloaded executable is not ELF'
RFS_EN['iproute2 is required']='iproute2 is required'
RFS_EN['python3 is required']='python3 is required'
RFS_EN['Requires curl, python3, sha256sum']='requires curl, python3, sha256sum'
RFS_EN['GeoIP download failed']='GeoIP download failed'
RFS_EN['GeoIP database format invalid']='GeoIP database format invalid'
RFS_EN['Install scanner first']='install scanner first'
RFS_EN['timeout missing']='timeout missing'
RFS_EN['Cannot calculate public IPv4 network']='cannot calculate public IPv4 network'
RFS_EN['Unknown installed channel. Reinstall from GitHub first']='unknown installed channel; reinstall from GitHub first'
RFS_EN['Bootstrap not installed']='bootstrap not installed'
RFS_EN['Report directory unavailable']='report directory unavailable'
RFS_EN['Язык интерфейса установлен']='Interface language set'

RFS_EN['Действующие SSH-порты']='Existing SSH ports'

RFS_EN['Выбран IP VPS']='Selected VPS IP'
RFS_EN['Целевая сеть']='Target network'
RFS_EN['Лимит времени']='Time limit'
RFS_EN['Потоков']='Threads'
RFS_EN['ВНИМАНИЕ: выбранный IP определяет сеть /24, но не исходящий IP соединений.']='NOTICE: chosen IP sets /24 scope, not the outgoing source IP.'
RFS_EN['Соседние IP могут принадлежать другим клиентам. Необходимо разрешение владельца сети.']='Neighboring IPs may belong to other customers. Network-owner authorization required.'
RFS_EN['Запустить сканирование сети']='Scan network'
RFS_EN['Путь к отчёту']='Report path'
RFS_EN['Отчёт сохранён успешно']='Report saved successfully'
RFS_EN['Код завершения сканера']='Scanner exit code'
RFS_EN['ПРЕДУПРЕЖДЕНИЕ: сканер завершился с ошибкой, см. scanner.log']='WARNING: scanner exited unexpectedly; see scanner.log'
RFS_EN['GeoIP недоступна, сканирование продолжится без неё']='GeoIP unavailable; scanning continues without it'
RFS_EN['Скачать и запустить установщик']='Download and run installer'
RFS_EN['Подтвердить выполнение установщика']='Confirm execution of installer'
RFS_EN['Внешний установщик может изменить firewall, Docker, сервисы и порты.']='External installer may change firewall, Docker, services and ports.'
RFS_EN['RouterForge Server не контролирует изменения, выполняемые внешним проектом.']='RouterForge Server does not control changes performed by the external project.'

rfs_t(){
 if [[ "$RFS_LANG" == en && -n "${RFS_EN[$1]+present}" ]]; then
   printf '%s' "${RFS_EN[$1]}"
 else
   printf '%s' "$1"
 fi
}
rfs_language_menu(){
 local answer temp
 printf '
[1] Русский  [2] English  [0] %s
' "$(rfs_t 'Выход')"
 read -r -p "$(rfs_t 'Выберите язык [1 — Русский, 2 — English, 0 — назад]: ')" answer || return 0
 case "${answer:-0}" in
  1) answer=ru ;; 2) answer=en ;; 0) return 0 ;; *) return 1 ;;
 esac
 if (( EUID != 0 )); then printf 'Root privileges required to save language
' >&2; return 1; fi
 temp=$(mktemp "${APP_DIR:-/opt/routerforge-server}/.language.XXXXXX") || return 1
 printf '%s
' "$answer" > "$temp"
 chmod 0644 "$temp"
 mv -f -- "$temp" "${APP_DIR:-/opt/routerforge-server}/language"
 RFS_LANG=$answer
 export RFS_LANG
 printf '%s: %s
' "$(rfs_t 'Язык интерфейса установлен')" "$answer"
}
