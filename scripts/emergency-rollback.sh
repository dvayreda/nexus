#!/usr/bin/env bash
#
# EMERGENCY ROLLBACK SCRIPT
# Complete system restore from pre-migration backup
#
# Usage: ./scripts/emergency-rollback.sh
# Run from: WSL2 (/home/dvayr/Projects_linux/nexus/)
#
# What this does:
# 1. Stops n8n container
# 2. Restores PostgreSQL database
# 3. Restores Docker volumes
# 4. Restores /srv/ application files
# 5. Restarts n8n container
# 6. Verifies health
#
# CRITICAL: This script is DESTRUCTIVE and will overwrite current state!
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
SSH_WRAPPER="$HOME/ssh-nexus"
ROLLBACK_COMMIT="8afde4dc9cc0f65a138caa7b558ca900bd9d4b8b"

# Functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

confirm_rollback() {
    echo ""
    log_warn "⚠️  EMERGENCY ROLLBACK - THIS IS DESTRUCTIVE ⚠️"
    echo ""
    echo "This will:"
    echo "  - Stop n8n container"
    echo "  - DROP and RESTORE PostgreSQL database"
    echo "  - OVERWRITE Docker volumes"
    echo "  - OVERWRITE /srv/ application files"
    echo "  - Reset git to commit: $ROLLBACK_COMMIT"
    echo ""
    read -p "Are you ABSOLUTELY SURE you want to proceed? (type 'ROLLBACK' to confirm): " confirm

    if [ "$confirm" != "ROLLBACK" ]; then
        log_error "Rollback cancelled by user"
        exit 1
    fi
}

find_latest_backup() {
    log_info "Finding latest pre-migration backup..."
    BACKUP_DIR=$($SSH_WRAPPER 'ls -td /mnt/backup/pre-migration-* 2>/dev/null | head -1' || echo "")

    if [ -z "$BACKUP_DIR" ]; then
        log_error "No pre-migration backup found at /mnt/backup/pre-migration-*"
        log_error "Cannot proceed with rollback!"
        exit 1
    fi

    log_info "Found backup: $BACKUP_DIR"
}

verify_backup_integrity() {
    log_info "Verifying backup integrity..."

    # Check database backup
    $SSH_WRAPPER "gunzip -t $BACKUP_DIR/db/postgres_n8n.sql.gz" && \
        log_info "✓ Database backup OK" || \
        { log_error "✗ Database backup FAILED!"; exit 1; }

    # Check volumes backup
    $SSH_WRAPPER "[ -d '$BACKUP_DIR/docker-volumes/n8n_data' ]" && \
        log_info "✓ Docker volumes OK" || \
        { log_error "✗ Volumes backup FAILED!"; exit 1; }

    # Check application files backup
    $SSH_WRAPPER "[ -f '$BACKUP_DIR/srv/projects/faceless_prod/scripts/composite.py' ]" && \
        log_info "✓ composite.py backup OK" || \
        { log_error "✗ composite.py backup FAILED!"; exit 1; }

    # Check fonts backup
    $SSH_WRAPPER "[ -d '$BACKUP_DIR/srv/projects/faceless_prod/fonts' ]" && \
        log_info "✓ Fonts backup OK" || \
        log_warn "⚠ Fonts backup not found (may not exist in backup)"

    # Check logo backup
    $SSH_WRAPPER "[ -f '$BACKUP_DIR/srv/projects/faceless_prod/scripts/factsmind_logo.png' ]" && \
        log_info "✓ Logo backup OK" || \
        log_warn "⚠ Logo backup not found (may not exist in backup)"

    BACKUP_SIZE=$($SSH_WRAPPER "du -sh $BACKUP_DIR | cut -f1")
    log_info "Total backup size: $BACKUP_SIZE"
}

stop_n8n() {
    log_info "Stopping n8n container..."
    $SSH_WRAPPER 'docker stop nexus-n8n'
    sleep 3
}

restore_database() {
    log_info "Restoring PostgreSQL database..."

    # Drop and recreate database
    $SSH_WRAPPER 'docker exec -t nexus-postgres psql -U faceless -c "DROP DATABASE IF EXISTS n8n; CREATE DATABASE n8n;"'

    # Restore from backup
    $SSH_WRAPPER "gunzip -c $BACKUP_DIR/db/postgres_n8n.sql.gz | docker exec -i nexus-postgres psql -U faceless -d n8n"

    log_info "✓ Database restored"
}

restore_volumes() {
    log_info "Restoring Docker volumes..."

    $SSH_WRAPPER "sudo rsync -av --delete $BACKUP_DIR/docker-volumes/n8n_data/ /var/lib/docker/volumes/docker_n8n_data/_data/"

    log_info "✓ Volumes restored"
}

restore_files() {
    log_info "Restoring /srv/ application files..."

    $SSH_WRAPPER "rsync -av --delete $BACKUP_DIR/srv/ /srv/"

    log_info "✓ Application files restored"
}

start_n8n() {
    log_info "Starting n8n container..."
    $SSH_WRAPPER 'docker start nexus-n8n'

    log_info "Waiting 15 seconds for startup..."
    sleep 15
}

verify_health() {
    log_info "Verifying system health..."

    # Check container running
    if $SSH_WRAPPER 'docker ps | grep nexus-n8n' > /dev/null; then
        log_info "✓ n8n container running"
    else
        log_error "✗ n8n container NOT running!"
        $SSH_WRAPPER 'docker logs nexus-n8n --tail 50'
        exit 1
    fi

    # Check for errors in logs
    ERROR_COUNT=$($SSH_WRAPPER 'docker logs nexus-n8n --tail 100 2>&1 | grep -i error | wc -l' || echo "0")
    if [ "$ERROR_COUNT" -gt 0 ]; then
        log_warn "Found $ERROR_COUNT errors in logs (check manually)"
    else
        log_info "✓ No errors in logs"
    fi

    # Check composite.py accessible
    if $SSH_WRAPPER 'docker exec nexus-n8n ls /data/scripts/composite.py' > /dev/null 2>&1; then
        log_info "✓ composite.py accessible"
    else
        log_error "✗ composite.py NOT accessible!"
        exit 1
    fi

    # Check logo accessible
    if $SSH_WRAPPER 'docker exec nexus-n8n ls /data/scripts/factsmind_logo.png' > /dev/null 2>&1; then
        log_info "✓ Logo accessible"
    else
        log_warn "⚠ Logo NOT accessible (carousel CTA may fail)"
    fi

    # Check fonts accessible
    if $SSH_WRAPPER 'docker exec nexus-n8n ls /data/fonts/ | grep Montserrat' > /dev/null 2>&1; then
        log_info "✓ Fonts accessible"
    else
        log_error "✗ Fonts NOT accessible!"
        exit 1
    fi
}

rollback_git() {
    log_info "Rolling back git to $ROLLBACK_COMMIT..."

    cd /home/dvayr/Projects_linux/nexus
    git reset --hard $ROLLBACK_COMMIT

    read -p "Force push to origin/main? (y/N): " push_confirm
    if [ "$push_confirm" = "y" ]; then
        log_warn "Force pushing to origin/main..."
        git push --force origin main
        log_info "✓ Git rolled back and pushed"
    else
        log_warn "Git rolled back locally only (not pushed)"
    fi
}

show_final_status() {
    echo ""
    log_info "========================================="
    log_info "ROLLBACK COMPLETE"
    log_info "========================================="
    echo ""
    log_info "Backup used: $BACKUP_DIR"
    log_info "Rollback commit: $ROLLBACK_COMMIT"
    echo ""
    log_info "Next steps:"
    echo "  1. Check n8n UI: http://100.122.207.23:5678"
    echo "  2. Test workflow execution"
    echo "  3. Review logs: ~/ssh-nexus '~/nexus-quick.sh'"
    echo ""
    log_info "Recent logs:"
    $SSH_WRAPPER 'docker logs nexus-n8n --tail 30'
}

# Main execution
main() {
    log_info "NEXUS EMERGENCY ROLLBACK SCRIPT"
    log_info "================================"
    echo ""

    confirm_rollback
    find_latest_backup
    verify_backup_integrity

    echo ""
    log_warn "Starting rollback in 5 seconds... (Ctrl+C to cancel)"
    sleep 5

    stop_n8n
    restore_database
    restore_volumes
    restore_files
    start_n8n
    verify_health

    echo ""
    read -p "Rollback git repository? (y/N): " git_confirm
    if [ "$git_confirm" = "y" ]; then
        rollback_git
    fi

    show_final_status
}

# Run main function
main "$@"
