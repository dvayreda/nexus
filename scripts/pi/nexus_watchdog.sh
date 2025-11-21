#!/usr/bin/env bash
#
# Nexus Self-Healing Watchdog Script
# Purpose: Detect unhealthy services and auto-restart them
# Usage: ~/nexus_watchdog.sh [--dry-run]
# Cron: */5 * * * * ~/nexus_watchdog.sh >> /var/log/nexus_watchdog.log 2>&1
# Location: Should be deployed to Raspberry Pi at ~/nexus_watchdog.sh

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"
MAX_RESTART_ATTEMPTS=3
RESTART_BACKOFF_SECONDS=30
DRY_RUN=false

# Telegram configuration (will be populated from .env later)
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Check for dry-run flag
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
    echo "[DRY-RUN MODE] No actions will be taken"
fi

# Logging functions
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $1"
}

log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1"
}

# Telegram alert function
send_telegram_alert() {
    local message="$1"
    local severity="${2:-warning}"  # info, warning, critical

    # Only send if Telegram is configured
    if [[ -z "$TELEGRAM_BOT_TOKEN" ]] || [[ -z "$TELEGRAM_CHAT_ID" ]]; then
        return 0
    fi

    # Add severity emoji
    case "$severity" in
        critical)
            message="🔴 CRITICAL: $message"
            ;;
        warning)
            message="⚠️  WARNING: $message"
            ;;
        info)
            message="ℹ️  INFO: $message"
            ;;
    esac

    # Send via Telegram API
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=[NEXUS] $message" \
        -d "parse_mode=HTML" > /dev/null 2>&1 || true
}

# Log incident to database
log_incident() {
    local issue_type="$1"
    local severity="$2"  # info, warning, critical
    local description="$3"
    local affected_service="${4:-NULL}"
    local resolution_attempted="${5:-NULL}"

    # Escape single quotes in strings
    description="${description//\'/\'\'}"
    resolution_attempted="${resolution_attempted//\'/\'\'}"

    local sql="INSERT INTO monitoring.incidents (issue_type, severity, description, affected_service, resolution_attempted, auto_resolved) VALUES ('$issue_type', '$severity', '$description', "

    if [[ "$affected_service" == "NULL" ]]; then
        sql+="NULL, "
    else
        sql+="'$affected_service', "
    fi

    if [[ "$resolution_attempted" == "NULL" ]]; then
        sql+="NULL, "
    else
        sql+="'$resolution_attempted', "
    fi

    sql+="FALSE);"

    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql" > /dev/null 2>&1
}

# Resolve incident in database
resolve_incident() {
    local issue_type="$1"
    local affected_service="$2"
    local success="$3"  # true/false

    local sql="UPDATE monitoring.incidents SET resolved_at = NOW(), resolution_successful = $success, auto_resolved = TRUE WHERE issue_type = '$issue_type' AND affected_service = '$affected_service' AND resolved_at IS NULL;"

    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$sql" > /dev/null 2>&1
}

# Check and restart a service
check_and_restart_service() {
    local service="$1"

    # Get service status
    local status=$(docker inspect "$service" --format '{{.State.Status}}' 2>/dev/null || echo "not_found")

    if [[ "$status" == "not_found" ]]; then
        log_warn "Service $service not found, skipping"
        return 0
    fi

    if [[ "$status" != "running" ]]; then
        log_warn "Service $service is $status"

        # Check how many times this service has restarted recently
        local recent_incidents=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM monitoring.incidents WHERE affected_service = '$service' AND issue_type = 'service_down' AND detected_at > NOW() - INTERVAL '1 hour'" 2>/dev/null || echo "0")

        if [[ "$recent_incidents" -ge "$MAX_RESTART_ATTEMPTS" ]]; then
            log_error "Service $service has failed $recent_incidents times in the last hour - NOT restarting (manual intervention required)"
            log_incident "service_down_max_retries" "critical" "Service $service failed $MAX_RESTART_ATTEMPTS times in 1 hour, manual intervention required" "$service" "None (max retries exceeded)"
            send_telegram_alert "Service $service has failed $MAX_RESTART_ATTEMPTS times in 1 hour. Manual intervention required!" "critical"
            return 1
        fi

        # Log incident
        log_incident "service_down" "warning" "Service $service is $status, attempting restart" "$service" "docker restart"

        # Restart service (if not dry-run)
        if [[ "$DRY_RUN" == "false" ]]; then
            log_info "Restarting $service (attempt $(($recent_incidents + 1))/$MAX_RESTART_ATTEMPTS)..."

            if docker restart "$service" > /dev/null 2>&1; then
                sleep "$RESTART_BACKOFF_SECONDS"

                # Check if restart was successful
                local new_status=$(docker inspect "$service" --format '{{.State.Status}}')

                if [[ "$new_status" == "running" ]]; then
                    log_info "✓ Service $service restarted successfully"
                    resolve_incident "service_down" "$service" "true"
                    send_telegram_alert "Service $service was down and has been restarted successfully" "info"
                else
                    log_error "✗ Service $service restart failed (status: $new_status)"
                    resolve_incident "service_down" "$service" "false"
                    send_telegram_alert "Service $service restart failed! Status: $new_status" "warning"
                fi
            else
                log_error "✗ Failed to restart $service"
                resolve_incident "service_down" "$service" "false"
                send_telegram_alert "Failed to restart service $service!" "warning"
            fi
        else
            log_info "[DRY-RUN] Would restart $service"
        fi
    fi
}

# Check disk usage
check_disk_usage() {
    # Get current disk usage
    local disk_percent=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    if [[ "$disk_percent" -gt "95" ]]; then
        log_error "Disk usage critical: ${disk_percent}%"
        log_incident "disk_full" "critical" "Disk usage at ${disk_percent}%, cleanup required" "NULL" "NULL"
        send_telegram_alert "Disk usage CRITICAL: ${disk_percent}%! Cleanup needed immediately!" "critical"
    elif [[ "$disk_percent" -gt "90" ]]; then
        log_warn "Disk usage high: ${disk_percent}%"

        # Check if we've already logged this recently
        local recent_disk_warnings=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM monitoring.incidents WHERE issue_type = 'disk_high' AND detected_at > NOW() - INTERVAL '1 hour'" 2>/dev/null || echo "0")

        if [[ "$recent_disk_warnings" -eq "0" ]]; then
            log_incident "disk_high" "warning" "Disk usage at ${disk_percent}%, monitoring" "NULL" "NULL"
            send_telegram_alert "Disk usage high: ${disk_percent}%" "warning"
        fi
    elif [[ "$disk_percent" -gt "85" ]]; then
        log_warn "Disk usage elevated: ${disk_percent}%"

        # Check if we've already logged this recently
        local recent_disk_info=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM monitoring.incidents WHERE issue_type = 'disk_elevated' AND detected_at > NOW() - INTERVAL '6 hours'" 2>/dev/null || echo "0")

        if [[ "$recent_disk_info" -eq "0" ]]; then
            log_incident "disk_elevated" "info" "Disk usage at ${disk_percent}%" "NULL" "NULL"
        fi
    fi
}

# Check memory pressure
check_memory_pressure() {
    # Get swap usage
    local swap_info=$(free | grep Swap)
    local swap_total=$(echo "$swap_info" | awk '{print $2}')
    local swap_used=$(echo "$swap_info" | awk '{print $3}')

    # Avoid division by zero
    if [[ "$swap_total" -eq "0" ]]; then
        return 0
    fi

    local swap_percent=$((swap_used * 100 / swap_total))

    if [[ "$swap_percent" -gt "90" ]]; then
        log_error "Memory pressure critical: swap at ${swap_percent}%"
        log_incident "memory_pressure" "critical" "Swap usage at ${swap_percent}%, system may be unstable" "NULL" "NULL"
        send_telegram_alert "Memory pressure CRITICAL: swap at ${swap_percent}%!" "critical"
    elif [[ "$swap_percent" -gt "80" ]]; then
        log_warn "Memory pressure high: swap at ${swap_percent}%"

        # Check if we've already logged this recently
        local recent_memory_warnings=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM monitoring.incidents WHERE issue_type = 'memory_pressure' AND detected_at > NOW() - INTERVAL '1 hour'" 2>/dev/null || echo "0")

        if [[ "$recent_memory_warnings" -eq "0" ]]; then
            log_incident "memory_pressure" "warning" "Swap usage at ${swap_percent}%" "NULL" "NULL"
            send_telegram_alert "Memory pressure high: swap at ${swap_percent}%" "warning"
        fi
    fi
}

# Main watchdog loop
log_info "Starting Nexus watchdog check..."

# Check all Nexus services
SERVICES=$(docker ps -a --filter "name=nexus-" --format "{{.Names}}")

for service in $SERVICES; do
    check_and_restart_service "$service"
done

# Check system resources
check_disk_usage
check_memory_pressure

log_info "Watchdog check complete"
