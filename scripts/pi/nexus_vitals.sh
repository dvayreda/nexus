#!/usr/bin/env bash
#
# Nexus Vitals Collection Script
# Purpose: Collect system vitals and store in monitoring database
# Usage: ~/nexus_vitals.sh [--verbose]
# Cron: */5 * * * * ~/nexus_vitals.sh >> /var/log/nexus_vitals.log 2>&1
# Location: Should be deployed to Raspberry Pi at ~/nexus_vitals.sh

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"
VERBOSE=false

# Check for verbose flag
if [[ "${1:-}" == "--verbose" ]]; then
    VERBOSE=true
fi

log() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    fi
}

# Collect system vitals

# CPU usage (average over last minute)
CPU_PERCENT=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')

# Memory usage
MEMORY_INFO=$(free -g | grep Mem)
MEMORY_TOTAL=$(echo "$MEMORY_INFO" | awk '{print $2}')
MEMORY_USED=$(echo "$MEMORY_INFO" | awk '{print $3}')

# If memory shows as 0GB (because it's less than 1GB), use MB and convert
if [[ "$MEMORY_TOTAL" == "0" ]]; then
    MEMORY_INFO_MB=$(free -m | grep Mem)
    MEMORY_TOTAL_MB=$(echo "$MEMORY_INFO_MB" | awk '{print $2}')
    MEMORY_USED_MB=$(echo "$MEMORY_INFO_MB" | awk '{print $3}')
    MEMORY_TOTAL=$(awk "BEGIN {printf \"%.2f\", $MEMORY_TOTAL_MB/1024}")
    MEMORY_USED=$(awk "BEGIN {printf \"%.2f\", $MEMORY_USED_MB/1024}")
fi

# Disk usage (root partition)
DISK_INFO=$(df -BG / | tail -1)
DISK_TOTAL=$(echo "$DISK_INFO" | awk '{print $2}' | sed 's/G//')
DISK_USED=$(echo "$DISK_INFO" | awk '{print $3}' | sed 's/G//')

# Temperature (Raspberry Pi specific)
if command -v vcgencmd &> /dev/null; then
    TEMP_RAW=$(vcgencmd measure_temp)
    TEMPERATURE=$(echo "$TEMP_RAW" | grep -o -E '[0-9.]+')
else
    TEMPERATURE="NULL"
fi

# Swap usage
SWAP_INFO=$(free -g | grep Swap)
SWAP_TOTAL=$(echo "$SWAP_INFO" | awk '{print $2}')
SWAP_USED=$(echo "$SWAP_INFO" | awk '{print $3}')

# If swap shows as 0GB, use MB and convert
if [[ "$SWAP_TOTAL" == "0" ]] && [[ "$SWAP_USED" == "0" ]]; then
    SWAP_INFO_MB=$(free -m | grep Swap)
    SWAP_TOTAL_MB=$(echo "$SWAP_INFO_MB" | awk '{print $2}')
    SWAP_USED_MB=$(echo "$SWAP_INFO_MB" | awk '{print $3}')
    SWAP_TOTAL=$(awk "BEGIN {printf \"%.2f\", $SWAP_TOTAL_MB/1024}")
    SWAP_USED=$(awk "BEGIN {printf \"%.2f\", $SWAP_USED_MB/1024}")
fi

log "Collected vitals: CPU=${CPU_PERCENT}%, Mem=${MEMORY_USED}/${MEMORY_TOTAL}GB, Disk=${DISK_USED}/${DISK_TOTAL}GB, Temp=${TEMPERATURE}°C, Swap=${SWAP_USED}/${SWAP_TOTAL}GB"

# Insert into database
SQL="INSERT INTO monitoring.vitals (timestamp, cpu_percent, memory_used_gb, memory_total_gb, disk_used_gb, disk_total_gb, temperature_c, swap_used_gb, swap_total_gb) VALUES (NOW(), $CPU_PERCENT, $MEMORY_USED, $MEMORY_TOTAL, $DISK_USED, $DISK_TOTAL, $TEMPERATURE, $SWAP_USED, $SWAP_TOTAL);"

# Execute SQL
if docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$SQL" > /dev/null 2>&1; then
    log "✓ Vitals logged to database"
else
    echo "[ERROR] Failed to log vitals to database" >&2
    exit 1
fi

# Collect disk usage breakdown (detailed by mount point)
collect_disk_usage() {
    # Get all mount points (excluding tmpfs, devtmpfs, etc.)
    df -BG | grep -v "tmpfs\|devtmpfs\|overlay" | tail -n +2 | while read -r line; do
        MOUNT=$(echo "$line" | awk '{print $6}')
        USED=$(echo "$line" | awk '{print $3}' | sed 's/G//')
        TOTAL=$(echo "$line" | awk '{print $2}' | sed 's/G//')

        # Get inode info
        INODE_INFO=$(df -i "$MOUNT" | tail -1)
        INODES_USED=$(echo "$INODE_INFO" | awk '{print $3}')
        INODES_TOTAL=$(echo "$INODE_INFO" | awk '{print $2}')

        # Insert into database
        DISK_SQL="INSERT INTO monitoring.disk_usage (check_time, mount_point, used_gb, total_gb, inodes_used, inodes_total) VALUES (NOW(), '$MOUNT', $USED, $TOTAL, $INODES_USED, $INODES_TOTAL);"

        docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$DISK_SQL" > /dev/null 2>&1

        log "  ✓ Logged disk usage for $MOUNT"
    done
}

collect_disk_usage

# Collect service health
collect_service_health() {
    # Get all Docker containers with nexus- prefix
    docker ps -a --filter "name=nexus-" --format "{{.Names}}" | while read -r service; do
        # Get container status
        STATUS=$(docker inspect "$service" --format '{{.State.Status}}')

        # Get uptime (if running)
        if [[ "$STATUS" == "running" ]]; then
            STARTED=$(docker inspect "$service" --format '{{.State.StartedAt}}')
            UPTIME=$(( $(date +%s) - $(date -d "$STARTED" +%s) ))
        else
            UPTIME="NULL"
        fi

        # Get restart count
        RESTART_COUNT=$(docker inspect "$service" --format '{{.RestartCount}}')

        # Get memory usage (if running)
        if [[ "$STATUS" == "running" ]]; then
            MEMORY_STATS=$(docker stats "$service" --no-stream --format "{{.MemUsage}}" | awk '{print $1}')
            # Convert to MB (handle MiB/GiB)
            if [[ "$MEMORY_STATS" == *"GiB"* ]]; then
                MEMORY_MB=$(echo "$MEMORY_STATS" | sed 's/GiB//' | awk '{printf "%.2f", $1 * 1024}')
            else
                MEMORY_MB=$(echo "$MEMORY_STATS" | sed 's/MiB//')
            fi

            # Get CPU usage
            CPU_STATS=$(docker stats "$service" --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
        else
            MEMORY_MB="NULL"
            CPU_STATS="NULL"
        fi

        # Insert into database
        SERVICE_SQL="INSERT INTO monitoring.service_health (check_time, service_name, status, uptime_seconds, restart_count, memory_usage_mb, cpu_percent) VALUES (NOW(), '$service', '$STATUS', $UPTIME, $RESTART_COUNT, $MEMORY_MB, $CPU_STATS);"

        docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$SERVICE_SQL" > /dev/null 2>&1

        log "  ✓ Logged health for $service ($STATUS)"
    done
}

collect_service_health

if [[ "$VERBOSE" == "true" ]]; then
    echo "✓ Vitals collection complete"
fi
