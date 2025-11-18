#!/usr/bin/env bash
# nexus-n8n-status.sh - n8n workflow debugging and execution analysis
# Usage: ./nexus-n8n-status.sh [--workflow-id ID] [--last N]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
WORKFLOW_ID=""
LAST_N="10"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --workflow-id)
            WORKFLOW_ID="$2"
            shift 2
            ;;
        --last)
            LAST_N="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--workflow-id ID] [--last N]"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║            N8N WORKFLOW STATUS & DEBUG                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if n8n is running
echo -e "${BLUE}━━━ CONTAINER STATUS ━━━${NC}"
if ! docker ps --format '{{.Names}}' | grep -q "nexus-n8n"; then
    echo -e "${RED}ERROR: n8n container is not running${NC}"
    echo ""
    echo "Recent logs:"
    docker logs nexus-n8n --tail 20 2>&1 || echo "Unable to fetch logs"
    exit 1
fi

CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' nexus-n8n)
RESTART_COUNT=$(docker inspect --format='{{.RestartCount}}' nexus-n8n)
STARTED_AT=$(docker inspect --format='{{.State.StartedAt}}' nexus-n8n | cut -d. -f1 | sed 's/T/ /')

echo "Status: $CONTAINER_STATUS"
echo "Started: $STARTED_AT"
echo "Restart count: $RESTART_COUNT"
echo ""

# Check database connectivity
echo -e "${BLUE}━━━ DATABASE CONNECTION ━━━${NC}"
if docker exec nexus-postgres pg_isready -U faceless &>/dev/null; then
    echo -e "${GREEN}✓ PostgreSQL is reachable${NC}"
else
    echo -e "${RED}✗ PostgreSQL connection failed${NC}"
fi

if docker exec nexus-redis redis-cli ping &>/dev/null; then
    echo -e "${GREEN}✓ Redis is reachable${NC}"
else
    echo -e "${RED}✗ Redis connection failed${NC}"
fi
echo ""

# List all workflows
echo -e "${BLUE}━━━ ACTIVE WORKFLOWS ━━━${NC}"
docker exec nexus-postgres psql -U faceless -d n8n -c \
    "SELECT id, name, active, \"createdAt\", \"updatedAt\" FROM workflow_entity ORDER BY \"updatedAt\" DESC LIMIT 10" \
    2>/dev/null || echo "Unable to query workflows"
echo ""

# Execution statistics
echo -e "${BLUE}━━━ EXECUTION STATISTICS ━━━${NC}"
echo "Last 24 hours:"
docker exec nexus-postgres psql -U faceless -d n8n -tAc "
    SELECT
        finished::text as status,
        COUNT(*) as count,
        ROUND(AVG(EXTRACT(EPOCH FROM (\"stoppedAt\" - \"startedAt\")))) as avg_duration_sec
    FROM execution_entity
    WHERE \"startedAt\" > NOW() - INTERVAL '24 hours'
    GROUP BY finished
    ORDER BY finished DESC
" 2>/dev/null | awk -F'|' '{printf "  Status: %-10s Count: %-5s Avg Duration: %s sec\n", $1, $2, $3}' || echo "Unable to query executions"

echo ""
echo "Last 7 days (daily breakdown):"
docker exec nexus-postgres psql -U faceless -d n8n -tAc "
    SELECT
        DATE(\"startedAt\") as date,
        COUNT(*) as total,
        SUM(CASE WHEN finished = true THEN 1 ELSE 0 END) as successful,
        SUM(CASE WHEN finished = false THEN 1 ELSE 0 END) as failed
    FROM execution_entity
    WHERE \"startedAt\" > NOW() - INTERVAL '7 days'
    GROUP BY DATE(\"startedAt\")
    ORDER BY date DESC
" 2>/dev/null | awk -F'|' 'NR>0 {printf "  %s: Total: %-4s Success: %-4s Failed: %-4s\n", $1, $2, $3, $4}' || echo "Unable to query daily stats"
echo ""

# Recent executions
echo -e "${BLUE}━━━ RECENT EXECUTIONS (Last $LAST_N) ━━━${NC}"
if [ -n "$WORKFLOW_ID" ]; then
    echo "Filtering by workflow ID: $WORKFLOW_ID"
    WHERE_CLAUSE="WHERE \"workflowId\" = '$WORKFLOW_ID'"
else
    WHERE_CLAUSE=""
fi

docker exec nexus-postgres psql -U faceless -d n8n -c "
    SELECT
        e.id,
        w.name as workflow,
        e.finished,
        e.\"startedAt\",
        e.\"stoppedAt\",
        EXTRACT(EPOCH FROM (e.\"stoppedAt\" - e.\"startedAt\")) as duration_sec,
        e.mode
    FROM execution_entity e
    LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
    $WHERE_CLAUSE
    ORDER BY e.\"startedAt\" DESC
    LIMIT $LAST_N
" 2>/dev/null || echo "Unable to query recent executions"
echo ""

# Error analysis
echo -e "${BLUE}━━━ ERROR ANALYSIS (Last 24h) ━━━${NC}"
ERROR_COUNT=$(docker exec nexus-postgres psql -U faceless -d n8n -tAc \
    "SELECT COUNT(*) FROM execution_entity WHERE finished = false AND \"startedAt\" > NOW() - INTERVAL '24 hours'" \
    2>/dev/null || echo "0")

echo "Failed executions: $ERROR_COUNT"

if [ "$ERROR_COUNT" -gt 0 ]; then
    echo ""
    echo "Recent failures:"
    docker exec nexus-postgres psql -U faceless -d n8n -c "
        SELECT
            e.id,
            w.name as workflow,
            e.\"startedAt\",
            LEFT(e.\"stoppedAt\"::text, 19) as stopped
        FROM execution_entity e
        LEFT JOIN workflow_entity w ON e.\"workflowId\" = w.id
        WHERE e.finished = false
        AND e.\"startedAt\" > NOW() - INTERVAL '24 hours'
        ORDER BY e.\"startedAt\" DESC
        LIMIT 5
    " 2>/dev/null
fi
echo ""

# Volume mount verification
echo -e "${BLUE}━━━ VOLUME MOUNTS ━━━${NC}"
echo "Checking critical paths inside container:"
for path in /data/outputs /data/scripts /data/templates /data/workflows; do
    if docker exec nexus-n8n test -d "$path" 2>/dev/null; then
        FILE_COUNT=$(docker exec nexus-n8n find "$path" -type f 2>/dev/null | wc -l || echo "0")
        echo -e "  ${GREEN}✓${NC} $path (${FILE_COUNT} files)"
    else
        echo -e "  ${RED}✗${NC} $path (NOT FOUND)"
    fi
done
echo ""

# Recent container logs
echo -e "${BLUE}━━━ RECENT LOGS (Last 20 lines) ━━━${NC}"
docker logs nexus-n8n --tail 20 2>&1
echo ""

# Performance metrics
echo -e "${BLUE}━━━ CONTAINER METRICS ━━━${NC}"
docker stats nexus-n8n --no-stream --format \
    "CPU: {{.CPUPerc}}\nMemory: {{.MemUsage}}\nNetwork I/O: {{.NetIO}}\nBlock I/O: {{.BlockIO}}"
echo ""

# Queue status (Redis)
echo -e "${BLUE}━━━ QUEUE STATUS (Redis) ━━━${NC}"
if docker exec nexus-redis redis-cli ping &>/dev/null; then
    QUEUE_LENGTH=$(docker exec nexus-redis redis-cli llen n8n:queue 2>/dev/null || echo "0")
    echo "Queue length: $QUEUE_LENGTH"

    PENDING_JOBS=$(docker exec nexus-redis redis-cli keys "n8n:job:*" 2>/dev/null | wc -l || echo "0")
    echo "Pending jobs: $PENDING_JOBS"
else
    echo "Unable to check Redis queue"
fi
echo ""

# Recommendations
echo -e "${BLUE}━━━ QUICK DIAGNOSTICS ━━━${NC}"
if [ "$ERROR_COUNT" -gt 5 ]; then
    echo -e "${YELLOW}⚠ High failure rate detected${NC}"
    echo "  Recommended actions:"
    echo "  1. Check external API credentials"
    echo "  2. Verify volume mounts"
    echo "  3. Check disk space and memory"
fi

if [ "$RESTART_COUNT" -gt 3 ]; then
    echo -e "${YELLOW}⚠ Container has restarted $RESTART_COUNT times${NC}"
    echo "  Recommended actions:"
    echo "  1. Check for OOM (out of memory) events: dmesg | grep -i oom"
    echo "  2. Review container logs for crash dumps"
    echo "  3. Verify database connectivity"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                   END OF REPORT                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
