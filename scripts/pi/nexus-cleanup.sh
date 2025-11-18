#!/usr/bin/env bash
# nexus-cleanup.sh - Disk space cleanup and maintenance
# Usage: ./nexus-cleanup.sh [--dry-run] [--aggressive]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
DRY_RUN=false
AGGRESSIVE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --aggressive)
            AGGRESSIVE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --dry-run      Show what would be deleted without deleting"
            echo "  --aggressive   More aggressive cleanup (old logs, caches)"
            echo ""
            echo "This script cleans up:"
            echo "  • Docker images and containers"
            echo "  • Old carousel outputs (>30 days)"
            echo "  • Docker logs"
            echo "  • System package cache"
            echo "  • Temp files"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              NEXUS DISK CLEANUP                          ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo -e "${YELLOW}DRY RUN MODE - No files will be deleted${NC}"
    echo ""
fi

# Function to execute or simulate command
run_or_simulate() {
    local description="$1"
    shift
    local command="$@"

    echo -e "${BLUE}$description${NC}"

    if [ "$DRY_RUN" = true ]; then
        echo "  Would run: $command"
        # Try to estimate what would be freed
        eval "$command --dry-run 2>/dev/null" || true
    else
        eval "$command"
    fi

    echo ""
}

# Get initial disk usage
DISK_BEFORE=$(df / | awk 'NR==2 {print $3}')

echo "━━━ INITIAL DISK STATUS ━━━"
df -h / /srv /mnt/backup | awk 'NR==1 {print} NR>1 {printf "%-20s %10s %10s %10s %6s\n", $6, $2, $3, $4, $5}'
echo ""

# 1. Docker cleanup
echo "━━━ DOCKER CLEANUP ━━━"
echo ""

run_or_simulate "Removing stopped containers..." \
    "docker container prune -f"

run_or_simulate "Removing unused images..." \
    "docker image prune -a -f"

run_or_simulate "Removing unused volumes..." \
    "docker volume prune -f"

run_or_simulate "Removing unused networks..." \
    "docker network prune -f"

if [ "$AGGRESSIVE" = true ]; then
    echo -e "${YELLOW}Aggressive mode: Removing build cache${NC}"
    run_or_simulate "Removing build cache..." \
        "docker builder prune -a -f"
fi

# 2. Docker logs cleanup
echo "━━━ DOCKER LOGS CLEANUP ━━━"
echo ""

if [ "$AGGRESSIVE" = true ]; then
    CONTAINERS=$(docker ps -a --format '{{.Names}}')

    for container in $CONTAINERS; do
        LOG_FILE=$(docker inspect --format='{{.LogPath}}' "$container" 2>/dev/null || echo "")

        if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
            LOG_SIZE=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo "0")
            LOG_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$LOG_SIZE" 2>/dev/null || echo "${LOG_SIZE}B")

            if [ "$LOG_SIZE" -gt 10485760 ]; then  # > 10MB
                echo "Truncating logs for $container ($LOG_SIZE_HR)..."

                if [ "$DRY_RUN" = false ]; then
                    # Truncate log file (keep container running)
                    sudo truncate -s 0 "$LOG_FILE"
                    echo "  Truncated to 0 bytes"
                else
                    echo "  Would truncate $LOG_FILE"
                fi
            fi
        fi
    done
    echo ""
else
    echo "Skipping log cleanup (use --aggressive to enable)"
    echo ""
fi

# 3. Old carousel outputs
echo "━━━ OLD CAROUSEL OUTPUTS ━━━"
echo ""

if [ -d /srv/outputs ]; then
    # Find files older than 30 days
    OLD_FILES=$(find /srv/outputs -type f -mtime +30 2>/dev/null | wc -l)

    if [ "$OLD_FILES" -gt 0 ]; then
        OLD_SIZE=$(find /srv/outputs -type f -mtime +30 -exec stat -c %s {} \; 2>/dev/null | \
            awk '{sum+=$1} END {print sum}')
        OLD_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$OLD_SIZE" 2>/dev/null || echo "${OLD_SIZE}B")

        echo "Found $OLD_FILES file(s) older than 30 days ($OLD_SIZE_HR)"

        if [ "$DRY_RUN" = false ]; then
            echo -n "Delete old carousel outputs? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                find /srv/outputs -type f -mtime +30 -delete
                echo -e "${GREEN}✓ Deleted $OLD_FILES file(s)${NC}"
            else
                echo "Skipped"
            fi
        else
            echo "Would delete $OLD_FILES file(s)"
        fi
    else
        echo "No old files found (>30 days)"
    fi
else
    echo "Outputs directory not found"
fi
echo ""

# 4. Intermediate/failed carousel files
echo "━━━ INCOMPLETE CAROUSEL FILES ━━━"
echo ""

if [ -d /srv/outputs ]; then
    # Find intermediate files without corresponding finals
    INTERMEDIATE=$(find /srv/outputs -name "slide_*.png" ! -name "*_final.png" -type f 2>/dev/null | wc -l)

    if [ "$INTERMEDIATE" -gt 0 ]; then
        INT_SIZE=$(find /srv/outputs -name "slide_*.png" ! -name "*_final.png" -type f -exec stat -c %s {} \; 2>/dev/null | \
            awk '{sum+=$1} END {print sum}')
        INT_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$INT_SIZE" 2>/dev/null || echo "${INT_SIZE}B")

        echo "Found $INTERMEDIATE intermediate file(s) without finals ($INT_SIZE_HR)"

        if [ "$DRY_RUN" = false ]; then
            echo -n "Delete incomplete files? [y/N]: "
            read -r response
            if [[ "$response" =~ ^[Yy]$ ]]; then
                find /srv/outputs -name "slide_*.png" ! -name "*_final.png" -type f -delete
                echo -e "${GREEN}✓ Deleted $INTERMEDIATE file(s)${NC}"
            else
                echo "Skipped"
            fi
        else
            echo "Would delete $INTERMEDIATE file(s)"
        fi
    else
        echo "No incomplete files found"
    fi
else
    echo "Outputs directory not found"
fi
echo ""

# 5. System package cache
echo "━━━ SYSTEM PACKAGE CACHE ━━━"
echo ""

if command -v apt-get &>/dev/null; then
    CACHE_SIZE=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1)
    CACHE_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$CACHE_SIZE" 2>/dev/null || echo "${CACHE_SIZE}B")

    echo "APT cache size: $CACHE_SIZE_HR"

    if [ "$DRY_RUN" = false ]; then
        sudo apt-get clean
        echo -e "${GREEN}✓ Cleaned APT cache${NC}"
    else
        echo "Would clean APT cache"
    fi
fi
echo ""

# 6. Temporary files
echo "━━━ TEMPORARY FILES ━━━"
echo ""

TEMP_DIRS="/tmp /var/tmp"

for dir in $TEMP_DIRS; do
    if [ -d "$dir" ]; then
        # Find files older than 7 days
        OLD_TEMP=$(find "$dir" -type f -mtime +7 2>/dev/null | wc -l)

        if [ "$OLD_TEMP" -gt 0 ]; then
            echo "Found $OLD_TEMP old file(s) in $dir"

            if [ "$AGGRESSIVE" = true ]; then
                if [ "$DRY_RUN" = false ]; then
                    sudo find "$dir" -type f -mtime +7 -delete 2>/dev/null || true
                    echo -e "${GREEN}✓ Deleted old files from $dir${NC}"
                else
                    echo "Would delete old files from $dir"
                fi
            else
                echo "Skipped (use --aggressive to clean)"
            fi
        fi
    fi
done
echo ""

# 7. Old backup files (keep last 30 days of DB backups)
echo "━━━ OLD BACKUP FILES ━━━"
echo ""

if [ -d /mnt/backup/db ]; then
    OLD_BACKUPS=$(find /mnt/backup/db -name "postgres_*.sql.gz" -type f -mtime +30 2>/dev/null | wc -l)

    if [ "$OLD_BACKUPS" -gt 0 ]; then
        OLD_BACKUP_SIZE=$(find /mnt/backup/db -name "postgres_*.sql.gz" -type f -mtime +30 -exec stat -c %s {} \; 2>/dev/null | \
            awk '{sum+=$1} END {print sum}')
        OLD_BACKUP_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$OLD_BACKUP_SIZE" 2>/dev/null || echo "${OLD_BACKUP_SIZE}B")

        echo "Found $OLD_BACKUPS database backup(s) older than 30 days ($OLD_BACKUP_SIZE_HR)"

        if [ "$DRY_RUN" = false ]; then
            find /mnt/backup/db -name "postgres_*.sql.gz" -type f -mtime +30 -delete
            find /mnt/backup/db -name "postgres_*.sql.gz.sha256" -type f -mtime +30 -delete
            echo -e "${GREEN}✓ Deleted old backups${NC}"
        else
            echo "Would delete old backups"
        fi
    else
        echo "No old backups found (>30 days)"
    fi
else
    echo "Backup directory not found"
fi
echo ""

# 8. Journal logs (if aggressive)
if [ "$AGGRESSIVE" = true ]; then
    echo "━━━ SYSTEM JOURNAL CLEANUP ━━━"
    echo ""

    JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[GM]' || echo "unknown")
    echo "Current journal size: $JOURNAL_SIZE"

    if [ "$DRY_RUN" = false ]; then
        sudo journalctl --vacuum-time=7d
        echo -e "${GREEN}✓ Cleaned journals older than 7 days${NC}"
    else
        echo "Would clean journals older than 7 days"
    fi
    echo ""
fi

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "━━━ FINAL DISK STATUS ━━━"
df -h / /srv /mnt/backup | awk 'NR==1 {print} NR>1 {printf "%-20s %10s %10s %10s %6s\n", $6, $2, $3, $4, $5}'
echo ""

if [ "$DRY_RUN" = false ]; then
    DISK_AFTER=$(df / | awk 'NR==2 {print $3}')
    FREED=$((DISK_BEFORE - DISK_AFTER))
    FREED_HR=$(numfmt --to=iec-i --suffix=B $((FREED * 1024)) 2>/dev/null || echo "${FREED}KB")

    if [ "$FREED" -gt 0 ]; then
        echo -e "${GREEN}✓ Freed approximately $FREED_HR${NC}"
    else
        echo "Disk usage unchanged (cleanup may have been minimal)"
    fi
else
    echo -e "${YELLOW}Dry run completed. Re-run without --dry-run to perform cleanup.${NC}"
fi

echo ""
echo "Recommendations:"
echo "  • Run this script monthly to maintain disk space"
echo "  • Use --aggressive for more thorough cleanup"
echo "  • Monitor disk usage: df -h"
echo "  • Check Docker usage: docker system df"
echo ""

if [ "$DRY_RUN" = false ]; then
    echo -e "${GREEN}✓ Cleanup completed${NC}"
else
    echo "Preview completed"
fi
