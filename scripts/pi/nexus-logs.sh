#!/usr/bin/env bash
# nexus-logs.sh - Smart log viewer with filtering and analysis
# Usage: ./nexus-logs.sh [container] [--errors] [--tail N] [--follow] [--since TIME]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
CONTAINER=""
FILTER=""
TAIL_LINES="100"
FOLLOW=false
SINCE=""

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --errors)
            FILTER="error"
            shift
            ;;
        --warnings)
            FILTER="warning"
            shift
            ;;
        --tail)
            TAIL_LINES="$2"
            shift 2
            ;;
        --follow|-f)
            FOLLOW=true
            shift
            ;;
        --since)
            SINCE="$2"
            shift 2
            ;;
        --help|-h)
            echo "Usage: $0 [container] [options]"
            echo ""
            echo "Options:"
            echo "  --errors         Show only error messages"
            echo "  --warnings       Show only warning messages"
            echo "  --tail N         Show last N lines (default: 100)"
            echo "  --follow, -f     Follow log output"
            echo "  --since TIME     Show logs since timestamp (e.g., '1h', '30m', '2024-01-01')"
            echo ""
            echo "Containers:"
            echo "  nexus-n8n        n8n workflow engine"
            echo "  nexus-postgres   PostgreSQL database"
            echo "  nexus-redis      Redis cache"
            echo "  nexus-netdata    Netdata monitoring"
            echo "  all              All containers"
            echo ""
            echo "Examples:"
            echo "  $0 nexus-n8n --errors"
            echo "  $0 nexus-postgres --tail 50 --since 1h"
            echo "  $0 all --follow"
            exit 0
            ;;
        *)
            if [ -z "$CONTAINER" ]; then
                CONTAINER="$1"
            fi
            shift
            ;;
    esac
done

# If no container specified, show menu
if [ -z "$CONTAINER" ]; then
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                NEXUS LOG VIEWER                          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""
    echo "Available containers:"
    echo ""

    CONTAINERS=(nexus-n8n nexus-postgres nexus-redis nexus-netdata)
    INDEX=1

    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            STATUS="${GREEN}[RUNNING]${NC}"
            # Get log size
            LOG_FILE=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null || echo "")
            if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
                LOG_SIZE=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo "0")
                LOG_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$LOG_SIZE" 2>/dev/null || echo "${LOG_SIZE}B")
            else
                LOG_SIZE_HR="N/A"
            fi
        else
            STATUS="${RED}[STOPPED]${NC}"
            LOG_SIZE_HR="N/A"
        fi

        echo -e "  $INDEX) $container $STATUS (Log size: $LOG_SIZE_HR)"
        ((INDEX++))
    done

    echo ""
    echo "  $INDEX) all (show all containers)"
    echo ""
    echo -n "Select container (1-$INDEX) or enter name: "
    read -r selection

    # Map selection to container name
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        if [ "$selection" -le "${#CONTAINERS[@]}" ]; then
            CONTAINER="${CONTAINERS[$((selection-1))]}"
        elif [ "$selection" -eq "$INDEX" ]; then
            CONTAINER="all"
        else
            echo "Invalid selection"
            exit 1
        fi
    else
        CONTAINER="$selection"
    fi
fi

# Build docker logs command
build_logs_command() {
    local container="$1"
    local cmd="docker logs"

    if [ -n "$SINCE" ]; then
        cmd="$cmd --since $SINCE"
    fi

    if [ "$FOLLOW" = true ]; then
        cmd="$cmd -f"
    else
        cmd="$cmd --tail $TAIL_LINES"
    fi

    cmd="$cmd $container 2>&1"

    echo "$cmd"
}

# Filter logs
filter_logs() {
    if [ "$FILTER" = "error" ]; then
        grep -i -E "(error|failed|exception|fatal)" --color=always
    elif [ "$FILTER" = "warning" ]; then
        grep -i -E "(warn|warning|deprecated)" --color=always
    else
        cat
    fi
}

# Display logs
display_logs() {
    local container="$1"

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Logs: $container${NC}"
    if [ -n "$FILTER" ]; then
        echo -e "${BLUE}Filter: $FILTER${NC}"
    fi
    if [ -n "$SINCE" ]; then
        echo -e "${BLUE}Since: $SINCE${NC}"
    fi
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "$container"; then
        echo -e "${RED}Error: Container $container not found${NC}"
        return 1
    fi

    # Build and execute command
    local cmd=$(build_logs_command "$container")
    eval "$cmd" | filter_logs
}

# Main logic
if [ "$CONTAINER" = "all" ]; then
    # Show logs from all containers
    CONTAINERS=(nexus-n8n nexus-postgres nexus-redis nexus-netdata)

    if [ "$FOLLOW" = true ]; then
        echo -e "${YELLOW}Note: Follow mode not supported for 'all'. Showing snapshots.${NC}"
        FOLLOW=false
    fi

    for container in "${CONTAINERS[@]}"; do
        if docker ps --format '{{.Names}}' | grep -q "$container"; then
            display_logs "$container"
            echo ""
        fi
    done
else
    # Show logs from specific container
    display_logs "$CONTAINER"
fi

# If not following, show log analysis
if [ "$FOLLOW" = false ] && [ "$CONTAINER" != "all" ]; then
    echo ""
    echo -e "${BLUE}━━━ LOG ANALYSIS ━━━${NC}"

    # Count error levels
    ERROR_COUNT=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | grep -ic "error" || echo "0")
    WARN_COUNT=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | grep -ic "warn" || echo "0")
    INFO_COUNT=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | grep -ic "info" || echo "0")

    echo "Log level distribution (last $TAIL_LINES lines):"
    echo "  Errors:   $ERROR_COUNT"
    echo "  Warnings: $WARN_COUNT"
    echo "  Info:     $INFO_COUNT"

    # Find most common error patterns
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo ""
        echo "Most common error patterns:"
        docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
            grep -i "error" | \
            sed 's/[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}[T ][0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}//g' | \
            sed 's/[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}//g' | \
            sort | uniq -c | sort -rn | head -5 | \
            awk '{$1=$1; print "  "$0}'
    fi

    # Container-specific analysis
    echo ""
    case "$CONTAINER" in
        nexus-n8n)
            echo "n8n-specific checks:"

            # Check for workflow errors
            WORKFLOW_ERRORS=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -i "workflow.*error" | wc -l || echo "0")
            echo "  Workflow errors: $WORKFLOW_ERRORS"

            # Check for API errors
            API_ERRORS=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -iE "(api.*error|request.*failed)" | wc -l || echo "0")
            echo "  API errors: $API_ERRORS"

            # Check for database connection issues
            DB_ERRORS=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -iE "(database.*error|connection.*failed|postgres)" | wc -l || echo "0")
            echo "  Database issues: $DB_ERRORS"
            ;;

        nexus-postgres)
            echo "PostgreSQL-specific checks:"

            # Check for connection errors
            CONN_ERRORS=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -i "connection" | wc -l || echo "0")
            echo "  Connection messages: $CONN_ERRORS"

            # Check for slow queries
            SLOW_QUERIES=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -i "slow query" | wc -l || echo "0")
            echo "  Slow queries: $SLOW_QUERIES"
            ;;

        nexus-redis)
            echo "Redis-specific checks:"

            # Check for memory warnings
            MEM_WARNINGS=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -i "memory" | wc -l || echo "0")
            echo "  Memory-related messages: $MEM_WARNINGS"

            # Check for connection issues
            CONN_ISSUES=$(docker logs "$CONTAINER" --tail "$TAIL_LINES" 2>&1 | \
                grep -i "connection" | wc -l || echo "0")
            echo "  Connection messages: $CONN_ISSUES"
            ;;
    esac

    echo ""
    echo "Tip: Use --follow to monitor logs in real-time"
    echo "Tip: Use --errors to show only error messages"
    echo "Tip: Use --since 1h to show logs from the last hour"
fi
