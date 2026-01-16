#!/bin/bash

# =========================
# ServiceGuard - Linux
# =========================

# Salvar em /usr/local/sbin/serviceguard.sh
# Configurar permissões e arquivo de log:
#   sudo chown root:root /usr/local/sbin/serviceguard.sh
#   sudo chmod 750 /usr/local/sbin/serviceguard.sh
#   sudo touch /var/log/serviceguard.log
#   sudo chown root:root /var/log/serviceguard.log
#   sudo chmod 640 /var/log/serviceguard.log

# Serviços a monitorar
SERVICES=(
  "wazuh-agent"
  "auditd"
  "sysmon"
)

LOG_FILE="/var/log/serviceguard.log"
HOSTNAME=$(hostname -s)

# Garante locale em inglês (Jan, Feb, Mar...)
export LC_TIME=C

log_msg() {
    local MESSAGE="$1"
    echo "$MESSAGE" >> "$LOG_FILE"
}

for SERVICE in "${SERVICES[@]}"; do

    # Verifica se o serviço existe
    if ! systemctl list-unit-files --type=service | grep -q "^${SERVICE}.service"; then
        continue
    fi

    STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null)

    if [ "$STATUS" != "active" ]; then

        # Tenta iniciar o serviço
        systemctl start "$SERVICE" 2>/dev/null
        sleep 3

        NEW_STATUS=$(systemctl is-active "$SERVICE" 2>/dev/null)

        if [ "$NEW_STATUS" = "active" ]; then
            TIMESTAMP=$(date +"%b %d %H:%M:%S")
            MSG="$TIMESTAMP $HOSTNAME ServiceGuard: CRITICO: O servico $SERVICE estava PARADO e foi REINICIADO."

            log_msg "$MSG"
        fi
    fi

done
