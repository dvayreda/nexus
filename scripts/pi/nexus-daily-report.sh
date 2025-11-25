#!/usr/bin/env bash
# nexus-daily-report.sh - Daily health summary sent via Telegram
# Usage: ~/nexus-daily-report.sh
# Cron: 0 8 * * * /home/didac/nexus-daily-report.sh >> /var/log/nexus-daily-report.log 2>&1

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"

# Load Telegram credentials from bashrc
TELEGRAM_BOT_TOKEN=$(grep "^export TELEGRAM_BOT_TOKEN" ~/.bashrc 2>/dev/null | cut -d'"' -f2 || echo "")
TELEGRAM_CHAT_ID=$(grep "^export TELEGRAM_CHAT_ID" ~/.bashrc 2>/dev/null | cut -d'"' -f2 || echo "")

# Send to Telegram
send_telegram() {
    local message="$1"
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        echo "[ERROR] Telegram not configured"
        return 1
    fi
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=$message" \
        -d "parse_mode=HTML" > /dev/null 2>&1
}

# Helper: query postgres
query_db() {
    docker exec "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$1" -tAc "$2" 2>/dev/null | tr -d '\r' || echo ""
}

# ============ COLLECT DATA ============

# Current vitals
VITALS=$(query_db "$POSTGRES_DB" "SELECT cpu_percent, memory_used_gb, memory_total_gb, disk_used_gb, disk_total_gb, temperature_c, swap_used_gb, swap_total_gb FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1")

if [[ -n "$VITALS" ]]; then
    CPU=$(echo "$VITALS" | cut -d'|' -f1 | xargs printf "%.0f")
    MEM_USED=$(echo "$VITALS" | cut -d'|' -f2 | xargs printf "%.1f")
    MEM_TOTAL=$(echo "$VITALS" | cut -d'|' -f3 | xargs printf "%.0f")
    MEM_PCT=$(awk "BEGIN {printf \"%.0f\", ($MEM_USED / $MEM_TOTAL) * 100}")
    DISK_USED=$(echo "$VITALS" | cut -d'|' -f4 | xargs printf "%.0f")
    DISK_TOTAL=$(echo "$VITALS" | cut -d'|' -f5 | xargs printf "%.0f")
    DISK_PCT=$(awk "BEGIN {printf \"%.0f\", ($DISK_USED / $DISK_TOTAL) * 100}")
    TEMP=$(echo "$VITALS" | cut -d'|' -f6 | xargs printf "%.0f")
    SWAP_USED=$(echo "$VITALS" | cut -d'|' -f7 | xargs printf "%.1f")
    SWAP_TOTAL=$(echo "$VITALS" | cut -d'|' -f8 | xargs printf "%.0f")
    SWAP_PCT=$(awk "BEGIN {printf \"%.0f\", ($SWAP_USED / $SWAP_TOTAL) * 100}")
else
    CPU="?" MEM_USED="?" MEM_TOTAL="?" MEM_PCT="?" DISK_USED="?" DISK_TOTAL="?" DISK_PCT="?" TEMP="?" SWAP_USED="?" SWAP_TOTAL="?" SWAP_PCT="?"
fi

# 24h averages for trends
AVG_24H=$(query_db "$POSTGRES_DB" "SELECT ROUND(AVG(cpu_percent)::numeric,0), ROUND(AVG((memory_used_gb/memory_total_gb)*100)::numeric,0) FROM monitoring.vitals WHERE timestamp > NOW() - INTERVAL '24 hours'")
CPU_AVG=$(echo "$AVG_24H" | cut -d'|' -f1 | xargs)
MEM_AVG=$(echo "$AVG_24H" | cut -d'|' -f2 | xargs)

# Service status
SERVICES_TOTAL=$(docker ps -a --filter "name=nexus-" --format "{{.Names}}" | wc -l)
SERVICES_RUNNING=$(docker ps --filter "name=nexus-" --format "{{.Names}}" | wc -l)

# Service restarts (24h)
RESTARTS=$(query_db "$POSTGRES_DB" "SELECT service_name, COUNT(*) FROM monitoring.service_health WHERE check_time > NOW() - INTERVAL '24 hours' AND restart_count > 0 GROUP BY service_name HAVING COUNT(*) > 1")

# Active incidents
INCIDENTS=$(query_db "$POSTGRES_DB" "SELECT issue_type, severity, description, detected_at FROM monitoring.incidents WHERE resolved_at IS NULL ORDER BY detected_at DESC LIMIT 3")
INCIDENT_COUNT=$(query_db "$POSTGRES_DB" "SELECT COUNT(*) FROM monitoring.incidents WHERE resolved_at IS NULL")

# Recently resolved (last 24h)
RESOLVED=$(query_db "$POSTGRES_DB" "SELECT issue_type, resolved_at FROM monitoring.incidents WHERE resolved_at > NOW() - INTERVAL '24 hours' LIMIT 3")

# Workflow activity (24h)
WORKFLOW_TOTAL=$(query_db "n8n" "SELECT COUNT(*) FROM execution_entity WHERE \"startedAt\" > NOW() - INTERVAL '24 hours'" || echo "0")
WORKFLOW_SUCCESS=$(query_db "n8n" "SELECT COUNT(*) FROM execution_entity WHERE \"startedAt\" > NOW() - INTERVAL '24 hours' AND finished = true AND \"stoppedAt\" IS NOT NULL" || echo "0")
if [[ "$WORKFLOW_TOTAL" -gt 0 ]]; then
    WORKFLOW_RATE=$(awk "BEGIN {printf \"%.0f\", ($WORKFLOW_SUCCESS / $WORKFLOW_TOTAL) * 100}")
else
    WORKFLOW_RATE="N/A"
fi

# Backup status
BACKUP_DISK=""
if mountpoint -q /mnt/backup 2>/dev/null; then
    BACKUP_INFO=$(df -h /mnt/backup | awk 'NR==2 {print $3"/"$2" ("$5")"}')
    BACKUP_DISK="✅ $BACKUP_INFO"
else
    BACKUP_DISK="❌ Not mounted"
fi
LAST_BACKUP=$(ls -lt /mnt/backup/files/ 2>/dev/null | head -2 | tail -1 | awk '{print $6, $7, $8}' || echo "Unknown")

# Database size
DB_SIZE=$(query_db "$POSTGRES_DB" "SELECT pg_size_pretty(pg_database_size('$POSTGRES_DB'))")
N8N_SIZE=$(query_db "n8n" "SELECT pg_size_pretty(pg_database_size('n8n'))" || echo "?")

# ============ BUILD MESSAGE ============

MSG="🌅 <b>NEXUS Morning Report</b>
$(date '+%Y-%m-%d %H:%M')
"

# Problems section
PROBLEMS=""

# Active incidents
if [[ "$INCIDENT_COUNT" -gt 0 ]] && [[ -n "$INCIDENTS" ]]; then
    while IFS='|' read -r type severity desc detected; do
        PROBLEMS+="• <b>$type</b> ($severity)
  $desc
  Since: $detected
"
    done <<< "$INCIDENTS"
fi

# Service restarts
if [[ -n "$RESTARTS" ]]; then
    while IFS='|' read -r svc count; do
        PROBLEMS+="• <b>$svc</b> restarted ${count}x (24h)
"
    done <<< "$RESTARTS"
fi

# Resource warnings
[[ "$MEM_PCT" != "?" ]] && [[ "$MEM_PCT" -gt 85 ]] && PROBLEMS+="• Memory high: ${MEM_PCT}%
"
[[ "$DISK_PCT" != "?" ]] && [[ "$DISK_PCT" -gt 85 ]] && PROBLEMS+="• Disk high: ${DISK_PCT}%
"
[[ "$SWAP_PCT" != "?" ]] && [[ "$SWAP_PCT" -gt 65 ]] && PROBLEMS+="• Swap elevated: ${SWAP_PCT}%
"
[[ "$TEMP" != "?" ]] && [[ "$TEMP" -gt 70 ]] && PROBLEMS+="• Temperature high: ${TEMP}°C
"

if [[ -n "$PROBLEMS" ]]; then
    MSG+="
⚠️ <b>PROBLEMS</b>
$PROBLEMS"
fi

# Resolved section
if [[ -n "$RESOLVED" ]]; then
    MSG+="
✅ <b>RESOLVED (24h)</b>
"
    while IFS='|' read -r type resolved_at; do
        MSG+="• $type - $resolved_at
"
    done <<< "$RESOLVED"
fi

# Current status
MSG+="
📊 <b>STATUS</b>
CPU: ${CPU}% (avg 24h: ${CPU_AVG}%)
Memory: ${MEM_USED}/${MEM_TOTAL}GB (${MEM_PCT}%)
Disk: ${DISK_USED}/${DISK_TOTAL}GB (${DISK_PCT}%)
Temp: ${TEMP}°C | Swap: ${SWAP_PCT}%

Services: ${SERVICES_RUNNING}/${SERVICES_TOTAL} running
"

# Workflows
MSG+="
📈 <b>ACTIVITY (24h)</b>
Workflows: ${WORKFLOW_TOTAL} (${WORKFLOW_RATE}% success)
"

# Backup
MSG+="
💾 <b>BACKUP</b>
Disk: ${BACKUP_DISK}
Last: ${LAST_BACKUP}
"

# Database
MSG+="
🗄️ <b>DATABASE</b>
nexus_system: ${DB_SIZE}
n8n: ${N8N_SIZE}
"

# Footer
if [[ -z "$PROBLEMS" ]]; then
    MSG+="
✅ All systems nominal"
fi

# ============ SEND ============

echo "[$(date)] Sending daily report..."
if send_telegram "$MSG"; then
    echo "[$(date)] Report sent successfully"
else
    echo "[$(date)] Failed to send report"
    exit 1
fi
