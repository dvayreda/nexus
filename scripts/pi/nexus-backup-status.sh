#!/usr/bin/env bash
# nexus-backup-status.sh - Verify backup integrity and status
# Usage: ./nexus-backup-status.sh [--verify-checksums]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Parse arguments
VERIFY_CHECKSUMS=false
if [[ "${1:-}" == "--verify-checksums" ]]; then
    VERIFY_CHECKSUMS=true
fi

BACKUP_ROOT="/mnt/backup"
ISSUES=0

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              NEXUS BACKUP STATUS REPORT                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Check if backup disk is mounted
echo -e "${BLUE}━━━ BACKUP DISK STATUS ━━━${NC}"
if ! mountpoint -q "$BACKUP_ROOT"; then
    echo -e "${RED}✗ CRITICAL: Backup disk not mounted at $BACKUP_ROOT${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Backup disk mounted${NC}"
df -h "$BACKUP_ROOT" | awk 'NR==2 {printf "  Total: %s | Used: %s | Available: %s | Usage: %s\n", $2, $3, $4, $5}'

DISK_USAGE_PCT=$(df "$BACKUP_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE_PCT" -gt 80 ]; then
    echo -e "${YELLOW}⚠ WARNING: Disk usage above 80%${NC}"
    ((ISSUES++))
fi
echo ""

# Check database backups
echo -e "${BLUE}━━━ DATABASE BACKUPS ━━━${NC}"
DB_BACKUP_DIR="$BACKUP_ROOT/db"

if [ ! -d "$DB_BACKUP_DIR" ]; then
    echo -e "${RED}✗ Database backup directory not found${NC}"
    ((ISSUES++))
else
    BACKUP_COUNT=$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f | wc -l)
    echo "Total database backups: $BACKUP_COUNT"

    if [ "$BACKUP_COUNT" -eq 0 ]; then
        echo -e "${RED}✗ No database backups found!${NC}"
        ((ISSUES++))
    else
        echo ""
        echo "Recent database backups:"
        find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f -printf '%T@ %p %s\n' | \
            sort -rn | head -5 | while read timestamp path size; do
                DATE=$(date -d @"${timestamp%.*}" '+%Y-%m-%d %H:%M:%S')
                SIZE_HR=$(numfmt --to=iec-i --suffix=B "$size" 2>/dev/null || echo "${size}B")
                FILENAME=$(basename "$path")
                echo "  $DATE - $FILENAME ($SIZE_HR)"

                # Check for corresponding checksum file
                if [ -f "${path}.sha256" ]; then
                    echo -e "    ${GREEN}✓ Checksum file exists${NC}"
                else
                    echo -e "    ${YELLOW}⚠ No checksum file${NC}"
                fi
            done

        # Check age of latest backup
        LATEST_BACKUP=$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f -printf '%T@\n' | sort -rn | head -1)
        if [ -n "$LATEST_BACKUP" ]; then
            BACKUP_AGE_DAYS=$(( ($(date +%s) - ${LATEST_BACKUP%.*}) / 86400 ))
            echo ""
            if [ "$BACKUP_AGE_DAYS" -eq 0 ]; then
                echo -e "${GREEN}✓ Latest backup is from today${NC}"
            elif [ "$BACKUP_AGE_DAYS" -eq 1 ]; then
                echo -e "${GREEN}✓ Latest backup is 1 day old${NC}"
            elif [ "$BACKUP_AGE_DAYS" -le 2 ]; then
                echo -e "${YELLOW}⚠ Latest backup is $BACKUP_AGE_DAYS days old${NC}"
                ((ISSUES++))
            else
                echo -e "${RED}✗ Latest backup is $BACKUP_AGE_DAYS days old (STALE)${NC}"
                ((ISSUES++))
            fi
        fi

        # Verify checksums if requested
        if [ "$VERIFY_CHECKSUMS" = true ]; then
            echo ""
            echo "Verifying checksums (this may take a while)..."
            CHECKSUM_ERRORS=0
            find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz.sha256" -type f | while read checksum_file; do
                DIR=$(dirname "$checksum_file")
                if (cd "$DIR" && sha256sum -c "$(basename "$checksum_file")" &>/dev/null); then
                    echo -e "  ${GREEN}✓${NC} $(basename "$checksum_file")"
                else
                    echo -e "  ${RED}✗${NC} $(basename "$checksum_file") FAILED"
                    ((CHECKSUM_ERRORS++))
                fi
            done

            if [ "$CHECKSUM_ERRORS" -gt 0 ]; then
                echo -e "${RED}✗ $CHECKSUM_ERRORS checksum verification(s) failed${NC}"
                ((ISSUES++))
            fi
        fi
    fi
fi
echo ""

# Check application files backup
echo -e "${BLUE}━━━ APPLICATION FILES BACKUP ━━━${NC}"
FILES_BACKUP_DIR="$BACKUP_ROOT/files"

if [ ! -d "$FILES_BACKUP_DIR" ]; then
    echo -e "${RED}✗ Application files backup directory not found${NC}"
    ((ISSUES++))
else
    echo -e "${GREEN}✓ Backup directory exists${NC}"

    # Check key subdirectories
    for subdir in docker outputs scripts templates; do
        if [ -d "$FILES_BACKUP_DIR/$subdir" ]; then
            SIZE=$(du -sh "$FILES_BACKUP_DIR/$subdir" 2>/dev/null | cut -f1)
            FILES=$(find "$FILES_BACKUP_DIR/$subdir" -type f 2>/dev/null | wc -l)
            echo "  $subdir/: $SIZE ($FILES files)"
        else
            echo -e "  ${YELLOW}⚠ $subdir/: Not found${NC}"
        fi
    done

    # Check last modification time
    LAST_SYNC=$(stat -c %Y "$FILES_BACKUP_DIR" 2>/dev/null || echo "0")
    if [ "$LAST_SYNC" -gt 0 ]; then
        SYNC_AGE_HOURS=$(( ($(date +%s) - LAST_SYNC) / 3600 ))
        echo ""
        if [ "$SYNC_AGE_HOURS" -le 24 ]; then
            echo -e "${GREEN}✓ Last sync: $SYNC_AGE_HOURS hours ago${NC}"
        elif [ "$SYNC_AGE_HOURS" -le 48 ]; then
            echo -e "${YELLOW}⚠ Last sync: $SYNC_AGE_HOURS hours ago${NC}"
        else
            SYNC_AGE_DAYS=$(( SYNC_AGE_HOURS / 24 ))
            echo -e "${RED}✗ Last sync: $SYNC_AGE_DAYS days ago (STALE)${NC}"
            ((ISSUES++))
        fi
    fi
fi
echo ""

# Check Docker volume backups
echo -e "${BLUE}━━━ DOCKER VOLUME BACKUPS ━━━${NC}"
DOCKER_BACKUP_DIR="$BACKUP_ROOT/docker-volumes"

if [ ! -d "$DOCKER_BACKUP_DIR" ]; then
    echo -e "${YELLOW}⚠ Docker volumes backup directory not found${NC}"
else
    echo -e "${GREEN}✓ Docker volumes backup directory exists${NC}"

    # Check n8n_data backup
    if [ -d "$DOCKER_BACKUP_DIR/n8n_data" ]; then
        SIZE=$(du -sh "$DOCKER_BACKUP_DIR/n8n_data" 2>/dev/null | cut -f1)
        FILES=$(find "$DOCKER_BACKUP_DIR/n8n_data" -type f 2>/dev/null | wc -l)
        echo "  n8n_data: $SIZE ($FILES files)"

        # Check for critical n8n files
        if [ -f "$DOCKER_BACKUP_DIR/n8n_data/.n8n/config" ]; then
            echo -e "    ${GREEN}✓ n8n config found${NC}"
        else
            echo -e "    ${YELLOW}⚠ n8n config not found${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ n8n_data backup not found${NC}"
    fi
fi
echo ""

# Check configuration backups
echo -e "${BLUE}━━━ CONFIGURATION BACKUPS ━━━${NC}"
CONFIG_BACKUP_DIR="$BACKUP_ROOT/configs"

if [ ! -d "$CONFIG_BACKUP_DIR" ]; then
    echo -e "${YELLOW}⚠ Configuration backup directory not found${NC}"
else
    echo -e "${GREEN}✓ Configuration backup directory exists${NC}"

    # Check key config backups
    declare -A config_checks=(
        ["systemd"]="Systemd units"
        ["ssh"]="SSH configuration"
        ["docker"]="Docker daemon config"
        ["home-didac"]="User home directory"
    )

    for key in "${!config_checks[@]}"; do
        if [ -d "$CONFIG_BACKUP_DIR/$key" ]; then
            SIZE=$(du -sh "$CONFIG_BACKUP_DIR/$key" 2>/dev/null | cut -f1)
            echo "  ${config_checks[$key]}: $SIZE"
        else
            echo -e "  ${config_checks[$key]}: ${YELLOW}Not found${NC}"
        fi
    done

    # Check package lists
    if [ -f "$CONFIG_BACKUP_DIR/dpkg-selections.txt" ]; then
        PKG_COUNT=$(wc -l < "$CONFIG_BACKUP_DIR/dpkg-selections.txt")
        echo "  Package list: $PKG_COUNT packages"
    else
        echo -e "  Package list: ${YELLOW}Not found${NC}"
    fi
fi
echo ""

# Backup automation status
echo -e "${BLUE}━━━ BACKUP AUTOMATION ━━━${NC}"

# Check systemd timers
if systemctl list-timers backup-sync.timer 2>/dev/null | grep -q backup-sync; then
    echo -e "${GREEN}✓ backup-sync.timer is active${NC}"
    NEXT_RUN=$(systemctl list-timers backup-sync.timer --no-pager | awk 'NR==2 {print $1, $2}')
    echo "  Next run: $NEXT_RUN"
else
    echo -e "${YELLOW}⚠ backup-sync.timer not found or inactive${NC}"
fi

if systemctl list-timers pg-backup.timer 2>/dev/null | grep -q pg-backup; then
    echo -e "${GREEN}✓ pg-backup.timer is active${NC}"
    NEXT_RUN=$(systemctl list-timers pg-backup.timer --no-pager | awk 'NR==2 {print $1, $2}')
    echo "  Next run: $NEXT_RUN"
else
    echo -e "${YELLOW}⚠ pg-backup.timer not found or inactive${NC}"
fi

# Check backup logs
if [ -f "/var/log/backup_sync.log" ]; then
    echo ""
    echo "Recent backup log entries:"
    tail -5 /var/log/backup_sync.log | sed 's/^/  /'
fi
echo ""

# Recovery readiness test
echo -e "${BLUE}━━━ RECOVERY READINESS ━━━${NC}"
RECOVERY_CHECKS=0
RECOVERY_PASSED=0

# Check 1: Database backup exists
if [ -n "$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f 2>/dev/null | head -1)" ]; then
    echo -e "${GREEN}✓${NC} Database backup available"
    ((RECOVERY_PASSED++))
else
    echo -e "${RED}✗${NC} Database backup missing"
fi
((RECOVERY_CHECKS++))

# Check 2: n8n data backed up
if [ -d "$DOCKER_BACKUP_DIR/n8n_data" ]; then
    echo -e "${GREEN}✓${NC} n8n data backup available"
    ((RECOVERY_PASSED++))
else
    echo -e "${RED}✗${NC} n8n data backup missing"
fi
((RECOVERY_CHECKS++))

# Check 3: Application files backed up
if [ -d "$FILES_BACKUP_DIR" ]; then
    echo -e "${GREEN}✓${NC} Application files backed up"
    ((RECOVERY_PASSED++))
else
    echo -e "${RED}✗${NC} Application files not backed up"
fi
((RECOVERY_CHECKS++))

# Check 4: Restore instructions exist
if [ -f "$BACKUP_ROOT/RESTORE_INSTRUCTIONS.md" ]; then
    echo -e "${GREEN}✓${NC} Restore instructions available"
    ((RECOVERY_PASSED++))
else
    echo -e "${YELLOW}⚠${NC} Restore instructions missing"
fi
((RECOVERY_CHECKS++))

echo ""
echo "Recovery readiness: $RECOVERY_PASSED/$RECOVERY_CHECKS checks passed"
echo ""

# Summary
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                      SUMMARY                             ║"
echo "╚═══════════════════════════════════════════════════════════╝"

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Backup status: HEALTHY${NC}"
    echo "  All backups are up-to-date and accessible"
else
    echo -e "${YELLOW}⚠ Backup status: $ISSUES ISSUE(S) DETECTED${NC}"
    echo "  Review the warnings above and take corrective action"
fi

echo ""
echo "Recommendations:"
if [ "$VERIFY_CHECKSUMS" = false ]; then
    echo "  • Run with --verify-checksums to validate backup integrity"
fi
echo "  • Test restore procedure periodically"
echo "  • Monitor backup disk space (current: ${DISK_USAGE_PCT}%)"
echo "  • Verify systemd timers are running"
echo ""

exit $ISSUES
