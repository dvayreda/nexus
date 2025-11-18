#!/usr/bin/env bash
# nexus-health.sh - Comprehensive system health and status report
# Usage: ./nexus-health.sh [--json]
# Output: Detailed diagnostics for troubleshooting

set -euo pipefail

# Parse arguments
OUTPUT_FORMAT="text"
if [[ "${1:-}" == "--json" ]]; then
    OUTPUT_FORMAT="json"
fi

# Colors (only for text output)
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to print section header (text mode)
print_header() {
    if [ "$OUTPUT_FORMAT" == "text" ]; then
        echo ""
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}$1${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    fi
}

if [ "$OUTPUT_FORMAT" == "json" ]; then
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"hostname\": \"$(hostname)\","
fi

# TEXT OUTPUT
if [ "$OUTPUT_FORMAT" == "text" ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         NEXUS COMPREHENSIVE HEALTH REPORT                ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Hostname: $(hostname)"
    echo "Uptime: $(uptime -p)"
fi

# 1. SYSTEM RESOURCES
print_header "1. SYSTEM RESOURCES"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    echo "CPU:"
    echo "  Load Average: $(uptime | awk -F'load average:' '{print $2}')"
    echo "  Temperature: $(vcgencmd measure_temp 2>/dev/null || echo 'N/A')"

    echo ""
    echo "Memory:"
    free -h | awk 'NR==2 {printf "  Total: %s | Used: %s | Free: %s | Usage: %.1f%%\n", $2, $3, $4, $3*100/$2}'

    echo ""
    echo "Disk Usage:"
    df -h / /mnt/backup | awk 'NR>1 {printf "  %-20s %10s %10s %10s %6s\n", $6, $2, $3, $4, $5}'

    echo ""
    echo "I/O Stats (last 1m):"
    iostat -x 1 2 | tail -n +4 | tail -n 2 | awk '{printf "  Device: %-10s Util: %5s%%\n", $1, $NF}'
fi

# 2. DOCKER STATUS
print_header "2. DOCKER CONTAINERS"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Size}}" | \
        awk 'NR==1 {printf "  %-20s %-30s %s\n", $1, $2, $3} NR>1 {printf "  %-20s %-30s %s\n", $1, $2, $3}'

    echo ""
    echo "Container Health:"
    for container in nexus-postgres nexus-redis nexus-n8n nexus-netdata; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no healthcheck")
            RESTART_COUNT=$(docker inspect --format='{{.RestartCount}}' "$container" 2>/dev/null || echo "0")
            echo "  $container:"
            echo "    Health: $HEALTH"
            echo "    Restart count: $RESTART_COUNT"
        else
            echo "  $container: NOT RUNNING"
        fi
    done
fi

# 3. DATABASE STATUS
print_header "3. DATABASE STATUS"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    echo "PostgreSQL:"
    if docker exec nexus-postgres pg_isready -U faceless &>/dev/null; then
        echo "  Status: READY"
        DB_SIZE=$(docker exec nexus-postgres psql -U faceless -d n8n -tAc \
            "SELECT pg_size_pretty(pg_database_size('n8n'))" 2>/dev/null || echo "Unknown")
        echo "  Database size: $DB_SIZE"

        TABLE_COUNT=$(docker exec nexus-postgres psql -U faceless -d n8n -tAc \
            "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'" 2>/dev/null || echo "0")
        echo "  Tables: $TABLE_COUNT"

        WORKFLOW_COUNT=$(docker exec nexus-postgres psql -U faceless -d n8n -tAc \
            "SELECT COUNT(*) FROM workflow_entity WHERE active=true" 2>/dev/null || echo "0")
        echo "  Active workflows: $WORKFLOW_COUNT"

        EXEC_24H=$(docker exec nexus-postgres psql -U faceless -d n8n -tAc \
            "SELECT COUNT(*) FROM execution_entity WHERE \"startedAt\" > NOW() - INTERVAL '24 hours'" 2>/dev/null || echo "0")
        echo "  Executions (24h): $EXEC_24H"
    else
        echo "  Status: DOWN OR UNREACHABLE"
    fi

    echo ""
    echo "Redis:"
    if docker exec nexus-redis redis-cli ping &>/dev/null; then
        echo "  Status: PONG"
        MEM_USAGE=$(docker exec nexus-redis redis-cli info memory | grep used_memory_human | cut -d: -f2 | tr -d '\r')
        echo "  Memory usage: $MEM_USAGE"
        KEYS=$(docker exec nexus-redis redis-cli dbsize | cut -d: -f2)
        echo "  Keys: $KEYS"
    else
        echo "  Status: DOWN OR UNREACHABLE"
    fi
fi

# 4. N8N STATUS
print_header "4. N8N WORKFLOW ENGINE"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    if docker ps --format '{{.Names}}' | grep -q "nexus-n8n"; then
        echo "Status: RUNNING"

        # Check recent logs for errors
        ERROR_COUNT=$(docker logs nexus-n8n --since 1h 2>&1 | grep -i error | wc -l || echo "0")
        echo "Errors (last 1h): $ERROR_COUNT"

        # Volume mounts
        echo ""
        echo "Volume Mounts:"
        docker inspect nexus-n8n --format='{{range .Mounts}}  {{.Source}} → {{.Destination}}{{"\n"}}{{end}}'
    else
        echo "Status: NOT RUNNING"
    fi
fi

# 5. BACKUP STATUS
print_header "5. BACKUP STATUS"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    if mountpoint -q /mnt/backup; then
        echo "Backup disk: MOUNTED"
        echo "  Path: /mnt/backup"
        df -h /mnt/backup | awk 'NR==2 {printf "  Size: %s | Used: %s | Available: %s | Usage: %s\n", $2, $3, $4, $5}'

        echo ""
        echo "Recent backups:"
        if [ -d /mnt/backup/db ]; then
            echo "  Database dumps:"
            ls -lht /mnt/backup/db/postgres_*.sql.gz 2>/dev/null | head -3 | \
                awk '{printf "    %s %s %s %s\n", $6, $7, $8, $9}' || echo "    No backups found"
        fi

        if [ -d /mnt/backup/files ]; then
            LAST_BACKUP=$(stat -c %y /mnt/backup/files 2>/dev/null | cut -d. -f1 || echo "Unknown")
            echo "  Application files: Last updated $LAST_BACKUP"
        fi
    else
        echo "Backup disk: NOT MOUNTED (CRITICAL)"
    fi
fi

# 6. NETWORK STATUS
print_header "6. NETWORK STATUS"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    echo "Network interfaces:"
    ip -br addr | awk '{printf "  %-15s %s\n", $1, $3}'

    echo ""
    echo "Tailscale:"
    if command -v tailscale &>/dev/null; then
        if tailscale status --json | jq -e '.BackendState == "Running"' &>/dev/null; then
            TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "Unknown")
            echo "  Status: CONNECTED"
            echo "  IP: $TAILSCALE_IP"
        else
            echo "  Status: DISCONNECTED"
        fi
    else
        echo "  Not installed"
    fi

    echo ""
    echo "Port listeners:"
    ss -tlnp 2>/dev/null | grep -E ':(5678|5432|6379|19999|8080)' | \
        awk '{printf "  %-20s %s\n", $4, $5}' || echo "  Unable to query ports"
fi

# 7. STORAGE PATHS
print_header "7. STORAGE PATHS"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    echo "Key directories:"
    for dir in /srv/docker /srv/projects /srv/outputs /srv/scripts; do
        if [ -d "$dir" ]; then
            SIZE=$(du -sh "$dir" 2>/dev/null | cut -f1)
            FILES=$(find "$dir" -type f 2>/dev/null | wc -l)
            printf "  %-30s Size: %-10s Files: %s\n" "$dir" "$SIZE" "$FILES"
        else
            printf "  %-30s MISSING\n" "$dir"
        fi
    done

    echo ""
    echo "Recent carousel outputs:"
    if [ -d /srv/outputs ]; then
        find /srv/outputs -name "*.png" -type f -mtime -7 2>/dev/null | wc -l | \
            xargs -I {} echo "  Files generated (last 7 days): {}"

        LATEST=$(find /srv/outputs -name "*.png" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | head -1 | cut -d' ' -f2- | xargs -I {} stat -c '%y {}' | cut -d. -f1 || echo "None")
        echo "  Latest output: $LATEST"
    else
        echo "  /srv/outputs directory not found"
    fi
fi

# 8. SYSTEM ALERTS
print_header "8. SYSTEM ALERTS"

if [ "$OUTPUT_FORMAT" == "text" ]; then
    ALERTS=()

    # Check disk usage
    DISK_PCT=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$DISK_PCT" -gt 90 ]; then
        ALERTS+=("CRITICAL: Root disk usage at ${DISK_PCT}%")
    elif [ "$DISK_PCT" -gt 80 ]; then
        ALERTS+=("WARNING: Root disk usage at ${DISK_PCT}%")
    fi

    # Check memory
    MEM_PCT=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
    if [ "$MEM_PCT" -gt 90 ]; then
        ALERTS+=("WARNING: Memory usage at ${MEM_PCT}%")
    fi

    # Check container restarts
    for container in nexus-postgres nexus-redis nexus-n8n; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            RESTARTS=$(docker inspect --format='{{.RestartCount}}' "$container" 2>/dev/null || echo "0")
            if [ "$RESTARTS" -gt 5 ]; then
                ALERTS+=("WARNING: $container has restarted $RESTARTS times")
            fi
        fi
    done

    # Check for old backups
    if [ -d /mnt/backup/db ]; then
        LATEST_BACKUP=$(find /mnt/backup/db -name "postgres_*.sql.gz" -type f -printf '%T@\n' 2>/dev/null | \
            sort -rn | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            BACKUP_AGE=$(( ($(date +%s) - ${LATEST_BACKUP%.*}) / 86400 ))
            if [ "$BACKUP_AGE" -gt 2 ]; then
                ALERTS+=("WARNING: Latest backup is $BACKUP_AGE days old")
            fi
        fi
    fi

    if [ ${#ALERTS[@]} -eq 0 ]; then
        echo -e "  ${GREEN}✓ No alerts${NC}"
    else
        for alert in "${ALERTS[@]}"; do
            if [[ $alert == CRITICAL* ]]; then
                echo -e "  ${RED}$alert${NC}"
            else
                echo -e "  ${YELLOW}$alert${NC}"
            fi
        done
    fi
fi

# Footer
if [ "$OUTPUT_FORMAT" == "text" ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                   END OF REPORT                          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
fi

if [ "$OUTPUT_FORMAT" == "json" ]; then
    echo "}"
fi
