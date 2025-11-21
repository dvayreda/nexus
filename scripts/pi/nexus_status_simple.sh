#!/usr/bin/env bash
#
# Nexus Status Reporting Script (Simplified for SSH/PowerShell compatibility)
# Purpose: Generate health report for Claude Code
# Usage: ~/nexus_status_simple.sh
# Location: Should be deployed to Raspberry Pi at ~/nexus_status_simple.sh

set -euo pipefail

# Configuration
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"

echo "🟢 NEXUS STATUS (accessed via WSL2/SSH)"
echo ""

# Core Vitals - Get from database
echo "Core Vitals:"
LATEST=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT cpu_percent, memory_percent, disk_percent, temperature_c, (swap_used_gb / NULLIF(swap_total_gb, 0) * 100) FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1" 2>/dev/null | tr '\r' ' ' || echo "")

if [[ -n "$LATEST" ]]; then
    CPU=$(echo "$LATEST" | cut -d'|' -f1)
    MEM=$(echo "$LATEST" | cut -d'|' -f2)
    DISK=$(echo "$LATEST" | cut -d'|' -f3)
    TEMP=$(echo "$LATEST" | cut -d'|' -f4)
    SWAP=$(echo "$LATEST" | cut -d'|' -f5)

    printf "├─ CPU: %.1f%% (4 cores)\n" "$CPU"
    printf "├─ Memory: %.0f%%\n" "$MEM"
    printf "├─ Disk: %.0f%%\n" "$DISK"
    printf "├─ Temperature: %.1f°C\n" "$TEMP"
    printf "└─ Swap: %.0f%%\n" "$SWAP"
else
    echo "No vitals data (run ~/nexus_vitals.sh first)"
fi
echo ""

# Services - Get from Docker directly
echo "Services:"
TOTAL=$(docker ps -a --filter "name=nexus-" --format "{{.Names}}" | wc -l)
RUNNING=$(docker ps --filter "name=nexus-" --format "{{.Names}}" | wc -l)

if [[ "$RUNNING" == "$TOTAL" ]]; then
    echo "✅ $RUNNING/$TOTAL healthy"
else
    echo "⚠️  $RUNNING/$TOTAL running"
fi

# List services
docker ps --filter "name=nexus-" --format "├─ {{.Names}}: {{.Status}}"
echo ""

# Active incidents
INCIDENTS=$(docker exec -t "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM monitoring.incidents WHERE resolved_at IS NULL" 2>/dev/null || echo "0")

if [[ "$INCIDENTS" -gt "0" ]]; then
    echo "⚠️  Active Incidents: $INCIDENTS"
    echo "(Check database for details)"
else
    echo "✅ No active incidents"
fi
echo ""

# Warnings
echo "Health Summary:"
WARNINGS=0

# Check thresholds
if [[ -n "$LATEST" ]]; then
    MEM_INT=$(printf "%.0f" "$MEM")
    DISK_INT=$(printf "%.0f" "$DISK")
    SWAP_INT=$(printf "%.0f" "$SWAP")
    TEMP_INT=$(printf "%.0f" "$TEMP")

    if [[ "$MEM_INT" -gt "85" ]]; then
        echo "⚠️  Memory usage high: ${MEM_INT}%"
        ((WARNINGS++))
    fi

    if [[ "$DISK_INT" -gt "85" ]]; then
        echo "⚠️  Disk usage high: ${DISK_INT}%"
        ((WARNINGS++))
    fi

    if [[ "$SWAP_INT" -gt "65" ]]; then
        echo "⚠️  Swap usage elevated: ${SWAP_INT}%"
        ((WARNINGS++))
    fi

    if [[ "$TEMP_INT" -gt "70" ]]; then
        echo "⚠️  Temperature high: ${TEMP_INT}°C"
        ((WARNINGS++))
    fi
fi

# Check for stopped services
if [[ "$RUNNING" -lt "$TOTAL" ]]; then
    echo "⚠️  Some services are not running"
    ((WARNINGS++))
fi

if [[ "$WARNINGS" -eq "0" ]]; then
    echo "✅ All systems nominal"
fi
echo ""
