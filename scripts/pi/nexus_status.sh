#!/usr/bin/env bash
#
# Nexus Status Reporting Script
# Purpose: Generate comprehensive health report for Claude Code
# Usage: ~/nexus_status.sh
# Location: Should be deployed to Raspberry Pi at ~/nexus_status.sh

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"

# Colors for output (optional, works in terminal)
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🟢 NEXUS STATUS${NC} (accessed via WSL2/SSH)"
echo ""

# Latest vitals
echo -e "${CYAN}Core Vitals:${NC}"

# Get latest vitals (use simple query, format in bash)
VITALS=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT cpu_percent, memory_used_gb, memory_total_gb, memory_percent, disk_used_gb, disk_total_gb, disk_percent, temperature_c, swap_used_gb, swap_total_gb FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1" 2>/dev/null | tr '\r' ' ')

if [[ -n "$VITALS" ]]; then
    CPU=$(echo "$VITALS" | cut -d'|' -f1 | xargs printf "%.1f")
    MEM_USED=$(echo "$VITALS" | cut -d'|' -f2 | xargs printf "%.2f")
    MEM_TOTAL=$(echo "$VITALS" | cut -d'|' -f3 | xargs printf "%.1f")
    MEM_PCT=$(echo "$VITALS" | cut -d'|' -f4 | xargs printf "%.0f")
    DISK_USED=$(echo "$VITALS" | cut -d'|' -f5 | xargs printf "%.0f")
    DISK_TOTAL=$(echo "$VITALS" | cut -d'|' -f6 | xargs printf "%.0f")
    DISK_PCT=$(echo "$VITALS" | cut -d'|' -f7 | xargs printf "%.0f")
    TEMP=$(echo "$VITALS" | cut -d'|' -f8 | xargs printf "%.1f")
    SWAP_USED=$(echo "$VITALS" | cut -d'|' -f9 | xargs printf "%.2f")
    SWAP_TOTAL=$(echo "$VITALS" | cut -d'|' -f10 | xargs printf "%.1f")
    SWAP_PCT=$(awk "BEGIN {printf \"%.0f\", ($SWAP_USED / $SWAP_TOTAL) * 100}")

    echo "├─ CPU: ${CPU}% (4 cores)"
    echo "├─ Memory: ${MEM_USED}/${MEM_TOTAL}GB (${MEM_PCT}%)"
    echo "├─ Disk: ${DISK_USED}/${DISK_TOTAL}GB (${DISK_PCT}%)"
    echo "├─ Temperature: ${TEMP}°C"
    echo "└─ Swap: ${SWAP_USED}/${SWAP_TOTAL}GB (${SWAP_PCT}%)"
else
    echo "No vitals data available (run ~/nexus_vitals.sh first)"
fi

echo ""

# Service status
echo -e "${CYAN}Services:${NC}"
TOTAL_SERVICES=$(docker ps -a --filter "name=nexus-" --format "{{.Names}}" | wc -l)
RUNNING_SERVICES=$(docker ps --filter "name=nexus-" --format "{{.Names}}" | wc -l)

if [[ "$RUNNING_SERVICES" == "$TOTAL_SERVICES" ]]; then
    echo -e "${GREEN}$RUNNING_SERVICES/$TOTAL_SERVICES healthy${NC}"
else
    echo -e "${YELLOW}$RUNNING_SERVICES/$TOTAL_SERVICES running${NC}"
fi

docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<EOF
SELECT
    service_name AS service,
    status,
    CASE
        WHEN uptime_seconds IS NULL THEN 'N/A'
        WHEN uptime_seconds < 3600 THEN ROUND((uptime_seconds / 60.0)::numeric, 0) || 'm'
        WHEN uptime_seconds < 86400 THEN ROUND((uptime_seconds / 3600.0)::numeric, 1) || 'h'
        ELSE ROUND((uptime_seconds / 86400.0)::numeric, 1) || 'd'
    END AS uptime,
    restart_count AS restarts
FROM monitoring.current_service_status
ORDER BY service_name;
EOF

echo ""

# Active incidents
INCIDENT_COUNT=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM monitoring.active_incidents")

if [[ "$INCIDENT_COUNT" -gt "0" ]]; then
    echo -e "${YELLOW}⚠️  Active Incidents: $INCIDENT_COUNT${NC}"
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" <<EOF
SELECT
    detected_at,
    issue_type,
    severity,
    description
FROM monitoring.active_incidents
LIMIT 5;
EOF
    echo ""
else
    echo -e "${GREEN}✅ No active incidents${NC}"
    echo ""
fi

# Last vitals check
LAST_CHECK=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT timestamp FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1")
echo "Last check: $LAST_CHECK"
echo ""

# Health summary
echo -e "${CYAN}Summary:${NC}"

# Check for warnings
WARNINGS=()

# Check memory
MEMORY_PERCENT=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT ROUND(memory_percent::numeric, 0) FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1")
if [[ "$MEMORY_PERCENT" -gt "85" ]]; then
    WARNINGS+=("Memory usage high: ${MEMORY_PERCENT}%")
fi

# Check disk
DISK_PERCENT=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT ROUND(disk_percent::numeric, 0) FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1")
if [[ "$DISK_PERCENT" -gt "85" ]]; then
    WARNINGS+=("Disk usage high: ${DISK_PERCENT}%")
fi

# Check swap
SWAP_PERCENT=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT ROUND((swap_used_gb / NULLIF(swap_total_gb, 0) * 100)::numeric, 0) FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1")
if [[ "$SWAP_PERCENT" -gt "65" ]]; then
    WARNINGS+=("Swap usage elevated: ${SWAP_PERCENT}%")
fi

# Check temperature
TEMP=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT ROUND(temperature_c::numeric, 0) FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1")
if [[ "$TEMP" -gt "70" ]]; then
    WARNINGS+=("Temperature high: ${TEMP}°C")
fi

# Check for stopped services
STOPPED_SERVICES=$(docker ps -a --filter "name=nexus-" --filter "status=exited" --format "{{.Names}}")
if [[ -n "$STOPPED_SERVICES" ]]; then
    while IFS= read -r service; do
        WARNINGS+=("Service stopped: $service")
    done <<< "$STOPPED_SERVICES"
fi

# Print warnings or all clear
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    for warning in "${WARNINGS[@]}"; do
        echo -e "${YELLOW}⚠️  ${warning}${NC}"
    done
else
    echo -e "${GREEN}✅ All systems nominal${NC}"
fi

echo ""
