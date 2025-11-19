#!/usr/bin/env bash
# nexus-restart.sh - Smart container restart with health verification
# Usage: ./nexus-restart.sh [container|all] [--force] [--no-wait]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
CONTAINER=""
FORCE=false
WAIT_FOR_HEALTH=true
COMPOSE_DIR="/srv/docker"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        --no-wait)
            WAIT_FOR_HEALTH=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [container|all] [options]"
            echo ""
            echo "Options:"
            echo "  --force      Force restart even if container is healthy"
            echo "  --no-wait    Don't wait for health checks after restart"
            echo ""
            echo "Containers:"
            echo "  nexus-n8n        n8n workflow engine"
            echo "  nexus-postgres   PostgreSQL database"
            echo "  nexus-redis      Redis cache"
            echo "  nexus-netdata    Netdata monitoring"
            echo "  all              All containers (ordered restart)"
            echo ""
            echo "Examples:"
            echo "  $0 nexus-n8n"
            echo "  $0 all --force"
            exit 0
            ;;
        *)
            CONTAINER="$1"
            shift
            ;;
    esac
done

# Check if running as appropriate user
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. Consider running as regular user with docker group.${NC}"
fi

# Function to check container health
check_health() {
    local container="$1"
    local max_attempts=30
    local attempt=0

    echo -n "Waiting for $container to be healthy"

    while [ $attempt -lt $max_attempts ]; do
        if ! docker ps --format '{{.Names}}' | grep -q "$container"; then
            echo -e " ${RED}✗ Container not running${NC}"
            return 1
        fi

        # Check health status
        HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")

        if [ "$HEALTH" = "healthy" ]; then
            echo -e " ${GREEN}✓ Healthy${NC}"
            return 0
        elif [ "$HEALTH" = "no-healthcheck" ]; then
            # If no health check, verify container is running for 5 seconds
            if [ $attempt -gt 5 ]; then
                echo -e " ${GREEN}✓ Running (no healthcheck)${NC}"
                return 0
            fi
        fi

        echo -n "."
        sleep 1
        ((attempt++))
    done

    echo -e " ${RED}✗ Timeout${NC}"
    return 1
}

# Function to restart a single container
restart_container() {
    local container="$1"

    echo ""
    echo -e "${BLUE}━━━ Restarting $container ━━━${NC}"

    # Check if container exists
    if ! docker ps -a --format '{{.Names}}' | grep -q "$container"; then
        echo -e "${RED}Error: Container $container not found${NC}"
        return 1
    fi

    # Check current status
    IS_RUNNING=$(docker ps --format '{{.Names}}' | grep -c "$container" || echo "0")

    if [ "$IS_RUNNING" -eq 0 ]; then
        echo "Container is not running. Starting..."
        docker start "$container"
    else
        # Check if restart is needed
        if [ "$FORCE" = false ]; then
            HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            RESTART_COUNT=$(docker inspect --format='{{.RestartCount}}' "$container" 2>/dev/null || echo "0")

            if [ "$HEALTH" = "healthy" ] || [ "$HEALTH" = "no-healthcheck" ]; then
                echo -e "${GREEN}Container is healthy${NC}"
                echo -n "Restart anyway? [y/N]: "
                read -r response
                if [[ ! "$response" =~ ^[Yy]$ ]]; then
                    echo "Restart cancelled"
                    return 0
                fi
            fi
        fi

        echo "Restarting container..."
        docker restart "$container"
    fi

    # Wait for health check if requested
    if [ "$WAIT_FOR_HEALTH" = true ]; then
        sleep 2  # Give container time to start
        check_health "$container"
        return $?
    else
        echo -e "${GREEN}✓ Restart initiated${NC}"
        return 0
    fi
}

# Function to restart all containers in correct order
restart_all() {
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║            RESTARTING ALL CONTAINERS                     ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo ""

    if [ "$FORCE" = false ]; then
        echo -e "${YELLOW}This will restart all Nexus containers.${NC}"
        echo -n "Continue? [y/N]: "
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Restart cancelled"
            exit 0
        fi
    fi

    # Define restart order (dependencies first)
    CONTAINERS=(
        "nexus-postgres"
        "nexus-redis"
        "nexus-n8n"
        "nexus-netdata"
    )

    FAILED=0

    for container in "${CONTAINERS[@]}"; do
        if docker ps -a --format '{{.Names}}' | grep -q "$container"; then
            if ! restart_container "$container"; then
                ((FAILED++))
                echo -e "${RED}Failed to restart $container${NC}"
            fi
        else
            echo -e "${YELLOW}Skipping $container (not found)${NC}"
        fi
    done

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    if [ $FAILED -eq 0 ]; then
        echo -e "${GREEN}✓ All containers restarted successfully${NC}"

        # Quick health summary
        echo ""
        echo "Container status:"
        docker ps --format "table {{.Names}}\t{{.Status}}" | grep nexus
        return 0
    else
        echo -e "${RED}✗ $FAILED container(s) failed to restart${NC}"
        echo ""
        echo "Check logs with: ./nexus-logs.sh <container>"
        return 1
    fi
}

# Main logic
if [ -z "$CONTAINER" ]; then
    echo "Error: No container specified"
    echo "Usage: $0 [container|all] [options]"
    echo "Run with --help for more information"
    exit 1
fi

# Check if Docker is running
if ! docker info &>/dev/null; then
    echo -e "${RED}Error: Docker is not running${NC}"
    exit 1
fi

# Handle restart request
if [ "$CONTAINER" = "all" ]; then
    restart_all
    exit $?
else
    restart_container "$CONTAINER"
    exit $?
fi
