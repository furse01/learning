#!/usr/bin/env bash
#
# install.sh — установщик random-логгера
#   1. Создаёт /opt/app и логгер /opt/app/random_logger.sh
#   2. Создаёт systemd-юнит random-logger.service (автозагрузка)
#   3. Создаёт конфиг logrotate /etc/logrotate.d/random-logger
#   4. Включает и запускает сервис + таймер logrotate
#
# Запуск: sudo ./install.sh

set -euo pipefail

# ---------- проверка root ----------
if [[ $EUID -ne 0 ]]; then
  echo "Ошибка: запусти через sudo — sudo $0" >&2
  exit 1
fi

# ---------- переменные ----------
APP_DIR="/opt/app"
LOGGER="${APP_DIR}/random_logger.sh"
SERVICE="/etc/systemd/system/random-logger.service"
LOGROTATE="/etc/logrotate.d/random-logger"

# ============================================================
# 1. Папка
# ============================================================
mkdir -p "$APP_DIR"

# ============================================================
# 2. Логгер
# ============================================================
cat >"$LOGGER" <<'LOGGER_EOF'
#!/usr/bin/env bash

dir="/opt/app"
file="${dir}/log.txt"

mkdir -p "$dir"
touch "$file"

generate_random_string() {
    local len=$(( RANDOM % 20 + 1 ))
    tr -dc 'A-Za-z0-9' </dev/urandom | head -c "$len"
}

while true; do
    stroka="$(generate_random_string)"
    echo "$stroka" >> "$file"
    sleep 17
done
LOGGER_EOF

chmod 755 "$LOGGER"
chown root:root "$LOGGER"

# ============================================================
# 3. systemd
# ============================================================
cat >"$SERVICE" <<SERVICE_EOF
[Unit]
Description=Random string logger to ${APP_DIR}/log.txt
After=network.target

[Service]
Type=simple
ExecStart=${LOGGER}
Restart=always
RestartSec=5
User=root

[Install]
WantedBy=multi-user.target
SERVICE_EOF

chmod 644 "$SERVICE"
chown root:root "$SERVICE"

# ============================================================
# 4. logrotate
# ============================================================
cat >"$LOGROTATE" <<'LOGROTATE_EOF'
/opt/app/log.txt {
    daily
    rotate 7
    missingok
    notifempty
    compress
    delaycompress
    copytruncate
    create 0644 root root
    dateext
    dateformat -%Y-%m-%d
}
LOGROTATE_EOF

chmod 644 "$LOGROTATE"
chown root:root "$LOGROTATE"

# ============================================================
# 5. Включаем сервис
# ============================================================
systemctl daemon-reload
systemctl enable --now random-logger.service

# ============================================================
# 6. Включаем logrotate.timer
# ============================================================
if systemctl list-unit-files 2>/dev/null | grep -q '^logrotate.timer'; then
  systemctl enable --now logrotate.timer
  LOGROTATE_TIMER_STATUS="$(systemctl is-enabled logrotate.timer) / $(systemctl is-active logrotate.timer)"
else
  LOGROTATE_TIMER_STATUS="не найден (установи пакет logrotate)"
  echo "Внимание: logrotate.timer не найден." >&2
  echo "Установи пакет: sudo pacman -S logrotate" >&2
fi

# ============================================================
# 7. Итог
# ============================================================
echo
echo "======================================"
echo "  Установка завершена"
echo "======================================"
echo "Логгер:        ${LOGGER}"
echo "Юнит:          ${SERVICE}"
echo "Ротация:       ${LOGROTATE}"
echo
echo "Сервис:        $(systemctl is-enabled random-logger.service) / $(systemctl is-active random-logger.service)"
echo "logrotate:     ${LOGROTATE_TIMER_STATUS}"
echo
echo "Проверка:"
echo "  systemctl status random-logger.service"
echo "  tail -f ${APP_DIR}/log.txt"
echo "  systemctl list-timers | grep logrotate"
echo
