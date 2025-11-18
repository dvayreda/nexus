#!/usr/bin/env bash
# nexus-compare.sh - Compare system state before/after changes
# Usage: ./nexus-compare.sh save [name]  - Save current state
#        ./nexus-compare.sh compare [name] - Compare with saved state

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# State directory
STATE_DIR="/tmp/nexus-states"
mkdir -p "$STATE_DIR"

# Function to save current state
save_state() {
    local name="${1:-default}"
    local state_file="$STATE_DIR/state_${name}.txt"

    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║            SAVING SYSTEM STATE                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "State name: $name"
    echo "Saving to: $state_file"
    echo ""

    # Create state snapshot
    {
        echo "=== NEXUS STATE SNAPSHOT ==="
        echo "Timestamp: $(date -Iseconds)"
        echo "Hostname: $(hostname)"
        echo ""

        echo "=== DOCKER CONTAINERS ==="
        docker ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}\t{{.Size}}'
        echo ""

        echo "=== CONTAINER DETAILS ==="
        for container in nexus-n8n nexus-postgres nexus-redis nexus-netdata; do
            if docker ps -a --format '{{.Names}}' | grep -q "$container"; then
                echo "Container: $container"
                echo "  Status: $(docker inspect --format='{{.State.Status}}' "$container")"
                echo "  Health: $(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo 'no-healthcheck')"
                echo "  Restart count: $(docker inspect --format='{{.RestartCount}}' "$container")"
                echo "  Started: $(docker inspect --format='{{.State.StartedAt}}' "$container" | cut -d. -f1)"
                echo ""
            fi
        done

        echo "=== DISK USAGE ==="
        df -h / /srv /mnt/backup
        echo ""

        echo "=== MEMORY USAGE ==="
        free -h
        echo ""

        echo "=== DOCKER VOLUMES ==="
        docker volume ls
        echo ""

        echo "=== DOCKER IMAGES ==="
        docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}'
        echo ""

        echo "=== NETWORK INTERFACES ==="
        ip -br addr
        echo ""

        echo "=== LISTENING PORTS ==="
        ss -tlnp 2>/dev/null | grep -E ':(5678|5432|6379|19999|8080)' || echo "No ports found"
        echo ""

        echo "=== SYSTEMD TIMERS ==="
        systemctl list-timers --no-pager | grep -E '(backup|nexus)' || echo "No timers found"
        echo ""

        echo "=== FILE COUNTS ==="
        if [ -d /srv/outputs ]; then
            echo "Carousel outputs: $(find /srv/outputs -type f 2>/dev/null | wc -l) files"
        fi
        if [ -d /mnt/backup/db ]; then
            echo "Database backups: $(find /mnt/backup/db -name '*.sql.gz' 2>/dev/null | wc -l) files"
        fi
        echo ""

        echo "=== RECENT DOCKER EVENTS (Last 100) ==="
        docker events --since 24h --until 1s 2>/dev/null | tail -100 || echo "No recent events"
        echo ""

        echo "=== N8N WORKFLOW STATS ==="
        if docker ps --format '{{.Names}}' | grep -q "nexus-postgres"; then
            docker exec nexus-postgres psql -U faceless -d n8n -tAc \
                "SELECT COUNT(*) as workflows FROM workflow_entity WHERE active=true" 2>/dev/null || echo "Unable to query"

            docker exec nexus-postgres psql -U faceless -d n8n -tAc \
                "SELECT COUNT(*) as executions_24h FROM execution_entity WHERE \"startedAt\" > NOW() - INTERVAL '24 hours'" 2>/dev/null || echo "Unable to query"
        fi
        echo ""

        echo "=== END OF SNAPSHOT ==="
    } > "$state_file"

    echo -e "${GREEN}✓ State saved successfully${NC}"
    echo ""
    echo "To compare later, run:"
    echo "  $0 compare $name"
}

# Function to compare with saved state
compare_state() {
    local name="${1:-default}"
    local state_file="$STATE_DIR/state_${name}.txt"

    if [ ! -f "$state_file" ]; then
        echo -e "${RED}Error: State '$name' not found${NC}"
        echo ""
        echo "Available states:"
        ls -1 "$STATE_DIR"/state_*.txt 2>/dev/null | sed 's/.*state_/  /' | sed 's/\.txt$//' || echo "  None"
        exit 1
    fi

    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║         COMPARING SYSTEM STATE                           ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    SAVED_TIME=$(grep "^Timestamp:" "$state_file" | cut -d: -f2- | xargs)
    echo "Comparing with state saved at: $SAVED_TIME"
    echo "Current time: $(date -Iseconds)"
    echo ""

    # Save current state to temp file
    TEMP_STATE=$(mktemp)
    save_state "temp" > /dev/null 2>&1
    cp "$STATE_DIR/state_temp.txt" "$TEMP_STATE"

    # Compare container status
    echo -e "${BLUE}━━━ CONTAINER STATUS CHANGES ━━━${NC}"
    echo ""

    for container in nexus-n8n nexus-postgres nexus-redis nexus-netdata; do
        # Get old status
        OLD_STATUS=$(grep -A 4 "^Container: $container" "$state_file" | grep "Status:" | cut -d: -f2- | xargs || echo "unknown")
        OLD_RESTARTS=$(grep -A 4 "^Container: $container" "$state_file" | grep "Restart count:" | cut -d: -f2- | xargs || echo "0")

        # Get new status
        NEW_STATUS=$(grep -A 4 "^Container: $container" "$TEMP_STATE" | grep "Status:" | cut -d: -f2- | xargs || echo "unknown")
        NEW_RESTARTS=$(grep -A 4 "^Container: $container" "$TEMP_STATE" | grep "Restart count:" | cut -d: -f2- | xargs || echo "0")

        echo "$container:"

        # Compare status
        if [ "$OLD_STATUS" != "$NEW_STATUS" ]; then
            echo -e "  Status: ${YELLOW}$OLD_STATUS → $NEW_STATUS${NC}"
        else
            echo -e "  Status: ${GREEN}$OLD_STATUS (unchanged)${NC}"
        fi

        # Compare restart count
        if [ "$OLD_RESTARTS" != "$NEW_RESTARTS" ]; then
            echo -e "  Restarts: ${YELLOW}$OLD_RESTARTS → $NEW_RESTARTS${NC}"
        else
            echo "  Restarts: $OLD_RESTARTS (unchanged)"
        fi

        echo ""
    done

    # Compare disk usage
    echo -e "${BLUE}━━━ DISK USAGE CHANGES ━━━${NC}"
    echo ""

    # Extract disk usage for root
    OLD_DISK=$(grep -A 3 "^=== DISK USAGE ===" "$state_file" | grep " /$" | awk '{print $5}' | sed 's/%//' || echo "0")
    NEW_DISK=$(grep -A 3 "^=== DISK USAGE ===" "$TEMP_STATE" | grep " /$" | awk '{print $5}' | sed 's/%//' || echo "0")

    echo "Root filesystem (/):"
    if [ "$OLD_DISK" -ne "$NEW_DISK" ]; then
        DIFF=$((NEW_DISK - OLD_DISK))
        if [ "$DIFF" -gt 5 ]; then
            echo -e "  ${RED}${OLD_DISK}% → ${NEW_DISK}% (+${DIFF}% INCREASED)${NC}"
        elif [ "$DIFF" -lt -5 ]; then
            echo -e "  ${GREEN}${OLD_DISK}% → ${NEW_DISK}% (${DIFF}% decreased)${NC}"
        else
            echo -e "  ${YELLOW}${OLD_DISK}% → ${NEW_DISK}% (${DIFF}%)${NC}"
        fi
    else
        echo -e "  ${GREEN}${OLD_DISK}% (unchanged)${NC}"
    fi

    # Extract disk usage for /srv
    OLD_SRV=$(grep -A 3 "^=== DISK USAGE ===" "$state_file" | grep " /srv$" | awk '{print $5}' | sed 's/%//' || echo "0")
    NEW_SRV=$(grep -A 3 "^=== DISK USAGE ===" "$TEMP_STATE" | grep " /srv$" | awk '{print $5}' | sed 's/%//' || echo "0")

    if [ "$OLD_SRV" != "0" ] && [ "$NEW_SRV" != "0" ]; then
        echo ""
        echo "/srv:"
        if [ "$OLD_SRV" -ne "$NEW_SRV" ]; then
            DIFF=$((NEW_SRV - OLD_SRV))
            if [ "$DIFF" -gt 0 ]; then
                echo -e "  ${YELLOW}${OLD_SRV}% → ${NEW_SRV}% (+${DIFF}%)${NC}"
            else
                echo -e "  ${GREEN}${OLD_SRV}% → ${NEW_SRV}% (${DIFF}%)${NC}"
            fi
        else
            echo -e "  ${GREEN}${OLD_SRV}% (unchanged)${NC}"
        fi
    fi
    echo ""

    # Compare memory usage
    echo -e "${BLUE}━━━ MEMORY USAGE CHANGES ━━━${NC}"
    echo ""

    OLD_MEM=$(grep -A 2 "^=== MEMORY USAGE ===" "$state_file" | grep "^Mem:" | awk '{print $3}')
    NEW_MEM=$(grep -A 2 "^=== MEMORY USAGE ===" "$TEMP_STATE" | grep "^Mem:" | awk '{print $3}')

    echo "Memory used:"
    if [ "$OLD_MEM" != "$NEW_MEM" ]; then
        echo -e "  ${YELLOW}$OLD_MEM → $NEW_MEM${NC}"
    else
        echo -e "  ${GREEN}$OLD_MEM (unchanged)${NC}"
    fi
    echo ""

    # Compare file counts
    echo -e "${BLUE}━━━ FILE COUNT CHANGES ━━━${NC}"
    echo ""

    OLD_OUTPUTS=$(grep "^Carousel outputs:" "$state_file" | awk '{print $3}' || echo "0")
    NEW_OUTPUTS=$(grep "^Carousel outputs:" "$TEMP_STATE" | awk '{print $3}' || echo "0")

    echo "Carousel outputs:"
    if [ "$OLD_OUTPUTS" != "$NEW_OUTPUTS" ]; then
        DIFF=$((NEW_OUTPUTS - OLD_OUTPUTS))
        if [ "$DIFF" -gt 0 ]; then
            echo -e "  ${GREEN}$OLD_OUTPUTS → $NEW_OUTPUTS (+$DIFF files)${NC}"
        else
            echo -e "  ${YELLOW}$OLD_OUTPUTS → $NEW_OUTPUTS ($DIFF files)${NC}"
        fi
    else
        echo -e "  $OLD_OUTPUTS (unchanged)"
    fi

    OLD_BACKUPS=$(grep "^Database backups:" "$state_file" | awk '{print $3}' || echo "0")
    NEW_BACKUPS=$(grep "^Database backups:" "$TEMP_STATE" | awk '{print $3}' || echo "0")

    echo "Database backups:"
    if [ "$OLD_BACKUPS" != "$NEW_BACKUPS" ]; then
        DIFF=$((NEW_BACKUPS - OLD_BACKUPS))
        if [ "$DIFF" -gt 0 ]; then
            echo -e "  ${GREEN}$OLD_BACKUPS → $NEW_BACKUPS (+$DIFF files)${NC}"
        else
            echo -e "  ${YELLOW}$OLD_BACKUPS → $NEW_BACKUPS ($DIFF files)${NC}"
        fi
    else
        echo "  $OLD_BACKUPS (unchanged)"
    fi
    echo ""

    # Compare workflow stats
    echo -e "${BLUE}━━━ WORKFLOW STATISTICS ━━━${NC}"
    echo ""

    OLD_EXECS=$(grep -A 1 "^=== N8N WORKFLOW STATS ===" "$state_file" | tail -1 | grep -oP '\d+' || echo "0")
    NEW_EXECS=$(grep -A 1 "^=== N8N WORKFLOW STATS ===" "$TEMP_STATE" | tail -1 | grep -oP '\d+' || echo "0")

    echo "Workflow executions (24h):"
    if [ "$OLD_EXECS" != "$NEW_EXECS" ]; then
        DIFF=$((NEW_EXECS - OLD_EXECS))
        if [ "$DIFF" -gt 0 ]; then
            echo -e "  ${GREEN}$OLD_EXECS → $NEW_EXECS (+$DIFF executions)${NC}"
        else
            echo -e "  ${YELLOW}$OLD_EXECS → $NEW_EXECS ($DIFF executions)${NC}"
        fi
    else
        echo "  $OLD_EXECS (unchanged)"
    fi
    echo ""

    # Show Docker image changes
    echo -e "${BLUE}━━━ DOCKER IMAGE CHANGES ━━━${NC}"
    echo ""

    # Extract image lists
    OLD_IMAGES=$(grep -A 100 "^=== DOCKER IMAGES ===" "$state_file" | tail -n +2 | grep -v "^===" | awk '{print $1":"$2}' | sort)
    NEW_IMAGES=$(grep -A 100 "^=== DOCKER IMAGES ===" "$TEMP_STATE" | tail -n +2 | grep -v "^===" | awk '{print $1":"$2}' | sort)

    # Find added images
    ADDED=$(comm -13 <(echo "$OLD_IMAGES") <(echo "$NEW_IMAGES"))
    if [ -n "$ADDED" ]; then
        echo "Added images:"
        echo "$ADDED" | sed 's/^/  + /'
    fi

    # Find removed images
    REMOVED=$(comm -23 <(echo "$OLD_IMAGES") <(echo "$NEW_IMAGES"))
    if [ -n "$REMOVED" ]; then
        echo "Removed images:"
        echo "$REMOVED" | sed 's/^/  - /'
    fi

    if [ -z "$ADDED" ] && [ -z "$REMOVED" ]; then
        echo -e "${GREEN}No changes${NC}"
    fi
    echo ""

    # Cleanup temp file
    rm -f "$TEMP_STATE"
    rm -f "$STATE_DIR/state_temp.txt"

    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                   END OF COMPARISON                      ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
}

# Function to list saved states
list_states() {
    echo "Saved states:"
    echo ""

    if [ -n "$(ls -1 "$STATE_DIR"/state_*.txt 2>/dev/null)" ]; then
        for state_file in "$STATE_DIR"/state_*.txt; do
            NAME=$(basename "$state_file" | sed 's/state_//' | sed 's/\.txt$//')
            TIMESTAMP=$(grep "^Timestamp:" "$state_file" | cut -d: -f2- | xargs || echo "unknown")
            SIZE=$(stat -c %s "$state_file" | numfmt --to=iec-i --suffix=B)

            echo "  $NAME"
            echo "    Saved: $TIMESTAMP"
            echo "    Size: $SIZE"
            echo ""
        done
    else
        echo "  No saved states found"
    fi
}

# Main logic
case "${1:-}" in
    save)
        save_state "${2:-default}"
        ;;
    compare)
        compare_state "${2:-default}"
        ;;
    list)
        list_states
        ;;
    *)
        echo "Usage: $0 {save|compare|list} [name]"
        echo ""
        echo "Commands:"
        echo "  save [name]     Save current system state"
        echo "  compare [name]  Compare with saved state"
        echo "  list            List all saved states"
        echo ""
        echo "Examples:"
        echo "  $0 save before-upgrade"
        echo "  $0 compare before-upgrade"
        echo "  $0 list"
        exit 1
        ;;
esac
