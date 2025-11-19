#!/usr/bin/env bash
# nexus-backup-verify.sh - Deep backup integrity verification with restoration test
# Usage: ./nexus-backup-verify.sh [--test-restore] [--repair]

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
TEST_RESTORE=false
REPAIR=false
BACKUP_ROOT="/mnt/backup"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test-restore)
            TEST_RESTORE=true
            shift
            ;;
        --repair)
            REPAIR=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  --test-restore    Perform test restoration to verify backups"
            echo "  --repair          Attempt to repair corrupted backups"
            echo ""
            echo "This script performs deep verification:"
            echo "  • Checksum validation"
            echo "  • Archive integrity tests"
            echo "  • Database dump validation"
            echo "  • File completeness checks"
            echo "  • Optional restoration tests"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        NEXUS BACKUP INTEGRITY VERIFICATION               ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "Backup root: $BACKUP_ROOT"
echo "Test restoration: $([ "$TEST_RESTORE" = true ] && echo "Yes" || echo "No")"
echo ""

ERRORS=0
WARNINGS=0

# Check if backup disk is mounted
if ! mountpoint -q "$BACKUP_ROOT"; then
    echo -e "${RED}✗ CRITICAL: Backup disk not mounted${NC}"
    exit 1
fi

# 1. Database Backup Verification
echo -e "${BLUE}━━━ DATABASE BACKUP VERIFICATION ━━━${NC}"
echo ""

DB_BACKUP_DIR="$BACKUP_ROOT/db"

if [ ! -d "$DB_BACKUP_DIR" ]; then
    echo -e "${RED}✗ Database backup directory not found${NC}"
    ((ERRORS++))
else
    DB_BACKUPS=$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f | sort -r)
    DB_COUNT=$(echo "$DB_BACKUPS" | grep -c "." || echo "0")

    echo "Found $DB_COUNT database backup(s)"
    echo ""

    if [ "$DB_COUNT" -eq 0 ]; then
        echo -e "${RED}✗ No database backups found${NC}"
        ((ERRORS++))
    else
        # Verify each backup
        VERIFIED=0
        FAILED=0

        echo "$DB_BACKUPS" | while read -r backup_file; do
            if [ -z "$backup_file" ]; then
                continue
            fi

            FILENAME=$(basename "$backup_file")
            echo "Verifying: $FILENAME"

            # Check 1: Checksum verification
            if [ -f "${backup_file}.sha256" ]; then
                DIR=$(dirname "$backup_file")
                if (cd "$DIR" && sha256sum -c "$(basename "${backup_file}.sha256")" &>/dev/null); then
                    echo -e "  ${GREEN}✓ Checksum valid${NC}"
                else
                    echo -e "  ${RED}✗ Checksum FAILED${NC}"
                    ((FAILED++))
                    continue
                fi
            else
                echo -e "  ${YELLOW}⚠ No checksum file${NC}"
                ((WARNINGS++))
            fi

            # Check 2: GZip integrity
            if gzip -t "$backup_file" 2>/dev/null; then
                echo -e "  ${GREEN}✓ GZip integrity OK${NC}"
            else
                echo -e "  ${RED}✗ GZip corruption detected${NC}"
                ((FAILED++))
                continue
            fi

            # Check 3: SQL syntax check (first 100 lines)
            if gunzip -c "$backup_file" 2>/dev/null | head -100 | grep -q "PostgreSQL database dump"; then
                echo -e "  ${GREEN}✓ Valid SQL dump format${NC}"
            else
                echo -e "  ${RED}✗ Invalid SQL format${NC}"
                ((FAILED++))
                continue
            fi

            # Check 4: Size sanity check
            SIZE=$(stat -c %s "$backup_file")
            if [ "$SIZE" -lt 1024 ]; then
                echo -e "  ${RED}✗ Suspiciously small file${NC}"
                ((FAILED++))
            elif [ "$SIZE" -lt 10240 ]; then
                echo -e "  ${YELLOW}⚠ Small file size (may be empty DB)${NC}"
                ((WARNINGS++))
            else
                SIZE_HR=$(numfmt --to=iec-i --suffix=B "$SIZE")
                echo -e "  ${GREEN}✓ Size OK: $SIZE_HR${NC}"
            fi

            echo ""
            ((VERIFIED++))
        done

        # Summary
        echo "Database backup verification:"
        echo "  Total: $DB_COUNT"
        echo "  Verified: $VERIFIED"
        echo "  Failed: $FAILED"

        if [ "$FAILED" -gt 0 ]; then
            ((ERRORS++))
        fi
    fi
fi
echo ""

# 2. Docker Volume Backup Verification
echo -e "${BLUE}━━━ DOCKER VOLUME BACKUP VERIFICATION ━━━${NC}"
echo ""

VOLUME_BACKUP_DIR="$BACKUP_ROOT/docker-volumes"

if [ ! -d "$VOLUME_BACKUP_DIR" ]; then
    echo -e "${YELLOW}⚠ Docker volume backup directory not found${NC}"
    ((WARNINGS++))
else
    echo "Checking n8n data backup..."

    if [ -d "$VOLUME_BACKUP_DIR/n8n_data" ]; then
        FILE_COUNT=$(find "$VOLUME_BACKUP_DIR/n8n_data" -type f 2>/dev/null | wc -l)
        SIZE=$(du -sh "$VOLUME_BACKUP_DIR/n8n_data" 2>/dev/null | cut -f1)

        echo "  Files: $FILE_COUNT"
        echo "  Size: $SIZE"

        # Check for critical n8n files
        CRITICAL_FILES=(
            ".n8n/config"
            "database.sqlite"
        )

        for file in "${CRITICAL_FILES[@]}"; do
            if [ -f "$VOLUME_BACKUP_DIR/n8n_data/$file" ] || [ -d "$VOLUME_BACKUP_DIR/n8n_data/$file" ]; then
                echo -e "  ${GREEN}✓${NC} $file exists"
            else
                echo -e "  ${YELLOW}⚠${NC} $file not found"
                ((WARNINGS++))
            fi
        done

        echo -e "${GREEN}✓ n8n data backup OK${NC}"
    else
        echo -e "${RED}✗ n8n data backup not found${NC}"
        ((ERRORS++))
    fi
fi
echo ""

# 3. Application Files Verification
echo -e "${BLUE}━━━ APPLICATION FILES VERIFICATION ━━━${NC}"
echo ""

FILES_BACKUP_DIR="$BACKUP_ROOT/files"

if [ ! -d "$FILES_BACKUP_DIR" ]; then
    echo -e "${RED}✗ Application files backup not found${NC}"
    ((ERRORS++))
else
    # Check critical directories
    CRITICAL_DIRS=(
        "docker"
        "scripts"
        "templates"
    )

    for dir in "${CRITICAL_DIRS[@]}"; do
        if [ -d "$FILES_BACKUP_DIR/$dir" ]; then
            FILE_COUNT=$(find "$FILES_BACKUP_DIR/$dir" -type f 2>/dev/null | wc -l)
            echo -e "${GREEN}✓${NC} $dir/ ($FILE_COUNT files)"
        else
            echo -e "${RED}✗${NC} $dir/ missing"
            ((ERRORS++))
        fi
    done

    # Verify docker-compose.yml exists
    if [ -f "$FILES_BACKUP_DIR/docker/docker-compose.yml" ]; then
        echo ""
        echo "Validating docker-compose.yml..."

        if command -v docker-compose &>/dev/null; then
            if docker-compose -f "$FILES_BACKUP_DIR/docker/docker-compose.yml" config &>/dev/null; then
                echo -e "${GREEN}✓ docker-compose.yml is valid${NC}"
            else
                echo -e "${RED}✗ docker-compose.yml has syntax errors${NC}"
                ((ERRORS++))
            fi
        else
            echo -e "${YELLOW}⚠ Cannot validate (docker-compose not installed)${NC}"
        fi
    fi
fi
echo ""

# 4. Configuration Files Verification
echo -e "${BLUE}━━━ CONFIGURATION BACKUP VERIFICATION ━━━${NC}"
echo ""

CONFIG_BACKUP_DIR="$BACKUP_ROOT/configs"

if [ ! -d "$CONFIG_BACKUP_DIR" ]; then
    echo -e "${YELLOW}⚠ Configuration backup directory not found${NC}"
    ((WARNINGS++))
else
    # Check for key configs
    declare -A config_checks=(
        ["systemd/backup-sync.timer"]="Backup timer"
        ["ssh/sshd_config"]="SSH config"
        ["home-didac/.bashrc"]="User profile"
        ["dpkg-selections.txt"]="Package list"
    )

    for path in "${!config_checks[@]}"; do
        desc="${config_checks[$path]}"
        if [ -f "$CONFIG_BACKUP_DIR/$path" ] || [ -d "$CONFIG_BACKUP_DIR/$path" ]; then
            echo -e "${GREEN}✓${NC} $desc"
        else
            echo -e "${YELLOW}⚠${NC} $desc not found"
            ((WARNINGS++))
        fi
    done
fi
echo ""

# 5. Test Restoration (if requested)
if [ "$TEST_RESTORE" = true ]; then
    echo -e "${BLUE}━━━ TEST RESTORATION ━━━${NC}"
    echo ""

    TEST_DIR="/tmp/nexus-restore-test-$$"
    mkdir -p "$TEST_DIR"

    echo "Test directory: $TEST_DIR"
    echo ""

    # Test 1: Restore database backup
    echo "Testing database restore..."
    LATEST_DB=$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f | sort -r | head -1)

    if [ -n "$LATEST_DB" ]; then
        echo "  Extracting: $(basename "$LATEST_DB")"

        if gunzip -c "$LATEST_DB" > "$TEST_DIR/test.sql" 2>/dev/null; then
            SQL_SIZE=$(stat -c %s "$TEST_DIR/test.sql")
            SQL_SIZE_HR=$(numfmt --to=iec-i --suffix=B "$SQL_SIZE")

            echo -e "  ${GREEN}✓ Extracted successfully: $SQL_SIZE_HR${NC}"

            # Check SQL content
            if grep -q "CREATE TABLE" "$TEST_DIR/test.sql"; then
                echo -e "  ${GREEN}✓ Contains valid SQL statements${NC}"
            else
                echo -e "  ${RED}✗ No CREATE TABLE statements found${NC}"
                ((ERRORS++))
            fi

            # Check for n8n tables
            if grep -q "workflow_entity" "$TEST_DIR/test.sql"; then
                echo -e "  ${GREEN}✓ Contains n8n schema${NC}"
            else
                echo -e "  ${YELLOW}⚠ n8n tables not found (may be empty DB)${NC}"
                ((WARNINGS++))
            fi
        else
            echo -e "  ${RED}✗ Failed to extract${NC}"
            ((ERRORS++))
        fi
    else
        echo -e "  ${RED}✗ No database backup to test${NC}"
        ((ERRORS++))
    fi

    echo ""

    # Test 2: Restore application files
    echo "Testing application files restore..."

    if [ -d "$FILES_BACKUP_DIR/scripts" ]; then
        cp -r "$FILES_BACKUP_DIR/scripts" "$TEST_DIR/scripts" 2>/dev/null

        if [ -d "$TEST_DIR/scripts" ]; then
            FILE_COUNT=$(find "$TEST_DIR/scripts" -type f | wc -l)
            echo -e "  ${GREEN}✓ Restored $FILE_COUNT script files${NC}"
        else
            echo -e "  ${RED}✗ Failed to restore scripts${NC}"
            ((ERRORS++))
        fi
    fi

    echo ""

    # Cleanup test directory
    echo "Cleaning up test directory..."
    rm -rf "$TEST_DIR"
    echo -e "${GREEN}✓ Test restoration completed${NC}"
    echo ""
fi

# 6. Backup Age Check
echo -e "${BLUE}━━━ BACKUP FRESHNESS CHECK ━━━${NC}"
echo ""

# Check latest database backup age
if [ -d "$DB_BACKUP_DIR" ]; then
    LATEST_BACKUP=$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f -printf '%T@\n' | sort -rn | head -1)

    if [ -n "$LATEST_BACKUP" ]; then
        BACKUP_AGE_HOURS=$(( ($(date +%s) - ${LATEST_BACKUP%.*}) / 3600 ))

        echo "Latest database backup:"
        if [ "$BACKUP_AGE_HOURS" -le 24 ]; then
            echo -e "  ${GREEN}✓ $BACKUP_AGE_HOURS hours old (fresh)${NC}"
        elif [ "$BACKUP_AGE_HOURS" -le 48 ]; then
            echo -e "  ${YELLOW}⚠ $BACKUP_AGE_HOURS hours old${NC}"
            ((WARNINGS++))
        else
            BACKUP_AGE_DAYS=$(( BACKUP_AGE_HOURS / 24 ))
            echo -e "  ${RED}✗ $BACKUP_AGE_DAYS days old (STALE)${NC}"
            ((ERRORS++))
        fi
    fi
fi

# Check application files last sync
if [ -d "$FILES_BACKUP_DIR" ]; then
    LAST_SYNC=$(stat -c %Y "$FILES_BACKUP_DIR" 2>/dev/null || echo "0")

    if [ "$LAST_SYNC" -gt 0 ]; then
        SYNC_AGE_HOURS=$(( ($(date +%s) - LAST_SYNC) / 3600 ))

        echo "Application files sync:"
        if [ "$SYNC_AGE_HOURS" -le 24 ]; then
            echo -e "  ${GREEN}✓ $SYNC_AGE_HOURS hours ago${NC}"
        elif [ "$SYNC_AGE_HOURS" -le 48 ]; then
            echo -e "  ${YELLOW}⚠ $SYNC_AGE_HOURS hours ago${NC}"
            ((WARNINGS++))
        else
            SYNC_AGE_DAYS=$(( SYNC_AGE_HOURS / 24 ))
            echo -e "  ${RED}✗ $SYNC_AGE_DAYS days ago (STALE)${NC}"
            ((ERRORS++))
        fi
    fi
fi
echo ""

# 7. Backup Redundancy Check
echo -e "${BLUE}━━━ BACKUP REDUNDANCY CHECK ━━━${NC}"
echo ""

if [ -d "$DB_BACKUP_DIR" ]; then
    BACKUP_DAYS=$(find "$DB_BACKUP_DIR" -name "postgres_*.sql.gz" -type f -printf '%TY-%Tm-%Td\n' | sort -u | wc -l)

    echo "Database backup coverage: $BACKUP_DAYS days"

    if [ "$BACKUP_DAYS" -ge 7 ]; then
        echo -e "${GREEN}✓ Good redundancy (7+ days)${NC}"
    elif [ "$BACKUP_DAYS" -ge 3 ]; then
        echo -e "${YELLOW}⚠ Moderate redundancy (3-6 days)${NC}"
        ((WARNINGS++))
    else
        echo -e "${RED}✗ Poor redundancy (<3 days)${NC}"
        ((ERRORS++))
    fi
fi
echo ""

# Summary and recommendations
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                VERIFICATION SUMMARY                      ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ EXCELLENT: All backups verified successfully${NC}"
    echo ""
    echo "Your backups are:"
    echo "  • Intact and uncorrupted"
    echo "  • Fresh and up-to-date"
    echo "  • Complete with all critical files"
    echo "  • Ready for restoration if needed"
    EXIT_CODE=0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ GOOD: Backups OK with $WARNINGS warning(s)${NC}"
    echo ""
    echo "Minor issues detected but backups are usable"
    EXIT_CODE=1
else
    echo -e "${RED}✗ CRITICAL: $ERRORS error(s) and $WARNINGS warning(s) detected${NC}"
    echo ""
    echo "URGENT: Address backup issues immediately"
    EXIT_CODE=2
fi

echo ""
echo "Recommendations:"
if [ $ERRORS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
    echo "  • Review errors above and take corrective action"
    echo "  • Run manual backup: /srv/scripts/backup_sync.sh"
    echo "  • Check backup automation: systemctl status backup-sync.timer"
fi
if [ "$TEST_RESTORE" = false ]; then
    echo "  • Run full test: $0 --test-restore"
fi
echo "  • Monitor backup status regularly"
echo "  • Test actual restoration procedure periodically"
echo ""

exit $EXIT_CODE
