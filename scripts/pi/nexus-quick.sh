#!/usr/bin/env bash
# nexus-quick.sh - Fast health check for Nexus system (< 2 seconds)
# Usage: ./nexus-quick.sh
# Returns: 0 if healthy, 1 if issues detected

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Status tracking
ISSUES=0

echo "=== NEXUS QUICK HEALTH CHECK ==="
echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check 1: Docker daemon
echo -n "Docker daemon: "
if systemctl is-active --quiet docker; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    ((ISSUES++))
fi

# Check 2: Critical containers
echo -n "PostgreSQL:    "
if docker ps --format '{{.Names}}' | grep -q "nexus-postgres"; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Down${NC}"
    ((ISSUES++))
fi

echo -n "Redis:         "
if docker ps --format '{{.Names}}' | grep -q "nexus-redis"; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Down${NC}"
    ((ISSUES++))
fi

echo -n "n8n:           "
if docker ps --format '{{.Names}}' | grep -q "nexus-n8n"; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Down${NC}"
    ((ISSUES++))
fi

# Check 3: Disk space
echo -n "Disk space:    "
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -lt 80 ]; then
    echo -e "${GREEN}✓ ${DISK_USAGE}% used${NC}"
elif [ "$DISK_USAGE" -lt 90 ]; then
    echo -e "${YELLOW}⚠ ${DISK_USAGE}% used${NC}"
    ((ISSUES++))
else
    echo -e "${RED}✗ ${DISK_USAGE}% used (CRITICAL)${NC}"
    ((ISSUES++))
fi

# Check 4: Memory
echo -n "Memory:        "
MEM_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3*100/$2}')
if [ "$MEM_USAGE" -lt 85 ]; then
    echo -e "${GREEN}✓ ${MEM_USAGE}% used${NC}"
else
    echo -e "${YELLOW}⚠ ${MEM_USAGE}% used${NC}"
fi

# Check 5: Backup disk
echo -n "Backup disk:   "
if mountpoint -q /mnt/backup; then
    BACKUP_USAGE=$(df -h /mnt/backup | awk 'NR==2 {print $5}' | sed 's/%//')
    if [ "$BACKUP_USAGE" -lt 80 ]; then
        echo -e "${GREEN}✓ Mounted (${BACKUP_USAGE}%)${NC}"
    else
        echo -e "${YELLOW}⚠ Mounted (${BACKUP_USAGE}%)${NC}"
    fi
else
    echo -e "${RED}✗ Not mounted${NC}"
    ((ISSUES++))
fi

# Check 6: n8n workflow executions (last hour)
echo -n "Workflows:     "
WORKFLOW_CHECK=$(docker exec nexus-postgres psql -U faceless -d n8n -tAc \
    "SELECT COUNT(*) FROM execution_entity WHERE \"startedAt\" > NOW() - INTERVAL '1 hour'" 2>/dev/null || echo "0")
if [ "$WORKFLOW_CHECK" -gt 0 ]; then
    echo -e "${GREEN}✓ ${WORKFLOW_CHECK} executions (1h)${NC}"
else
    echo -e "${YELLOW}⚠ No recent executions${NC}"
fi

echo ""
echo "==================================="

# Summary
if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}Status: HEALTHY${NC}"
    exit 0
else
    echo -e "${RED}Status: ISSUES DETECTED ($ISSUES)${NC}"
    echo "Run ./nexus-health.sh for detailed diagnostics"
    exit 1
fi
