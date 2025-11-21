#!/usr/bin/env bash
#
# Deploy Nexus Monitoring Database
# Purpose: Create nexus_system database and monitoring schema for self-awareness
# Usage: ~/deploy_monitoring_db.sh
# Location: Should be deployed to Raspberry Pi at ~/deploy_monitoring_db.sh

set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Nexus (Raspberry Pi)
if [[ ! -f /.dockerenv ]] && [[ $(uname -m) != "aarch64" ]]; then
    log_warn "This script should run on the Raspberry Pi"
fi

log_info "Deploying Nexus Monitoring Database..."

# Database connection details (from existing postgres container)
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="nexus"  # Adjust if different
POSTGRES_DB="n8n"      # Connect to existing DB first
NEW_DB="nexus_system"

# Check if PostgreSQL container is running
if ! docker ps | grep -q "$POSTGRES_CONTAINER"; then
    log_error "PostgreSQL container '$POSTGRES_CONTAINER' is not running!"
    log_info "Start it with: cd /srv/docker && sudo docker compose up -d postgres"
    exit 1
fi

log_info "PostgreSQL container is running"

# Check if nexus_system database already exists
DB_EXISTS=$(docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname='$NEW_DB'")

if [[ "$DB_EXISTS" == "1" ]]; then
    log_warn "Database '$NEW_DB' already exists"
    read -p "Do you want to recreate it? This will delete all existing data! (yes/NO): " CONFIRM
    if [[ "$CONFIRM" != "yes" ]]; then
        log_info "Skipping database creation"
    else
        log_warn "Dropping existing database..."
        docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c "DROP DATABASE $NEW_DB;"
        log_info "Creating database '$NEW_DB'..."
        docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c "CREATE DATABASE $NEW_DB OWNER $POSTGRES_USER;"
    fi
else
    log_info "Creating database '$NEW_DB'..."
    docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d postgres -c "CREATE DATABASE $NEW_DB OWNER $POSTGRES_USER;"
fi

# Copy schema file into container (use heredoc to avoid file transfer issues)
log_info "Deploying monitoring schema..."

# Read the schema file and execute it via heredoc
SCHEMA_FILE="/home/didac/monitoring_schema.sql"  # Temporary location on Pi

if [[ ! -f "$SCHEMA_FILE" ]]; then
    log_error "Schema file not found at $SCHEMA_FILE"
    log_info "Please copy infra/monitoring_schema.sql to the Pi first"
    exit 1
fi

# Execute schema in PostgreSQL container
docker exec -i $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB < "$SCHEMA_FILE"

log_info "Verifying deployment..."

# Verify schema exists
SCHEMA_EXISTS=$(docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -tAc "SELECT 1 FROM information_schema.schemata WHERE schema_name='monitoring'")

if [[ "$SCHEMA_EXISTS" == "1" ]]; then
    log_info "✓ Schema 'monitoring' created successfully"
else
    log_error "✗ Schema creation failed"
    exit 1
fi

# Count tables
TABLE_COUNT=$(docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -tAc "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='monitoring' AND table_type='BASE TABLE'")

log_info "✓ Created $TABLE_COUNT tables in monitoring schema"

# List tables
log_info "Tables created:"
docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -c "SELECT table_name FROM information_schema.tables WHERE table_schema='monitoring' AND table_type='BASE TABLE' ORDER BY table_name;"

# List views
VIEW_COUNT=$(docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -tAc "SELECT COUNT(*) FROM information_schema.views WHERE table_schema='monitoring'")
log_info "✓ Created $VIEW_COUNT views in monitoring schema"

# Test insert (verify permissions)
log_info "Testing permissions with sample insert..."
docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -c "
INSERT INTO monitoring.vitals (timestamp, cpu_percent, memory_used_gb, memory_total_gb, disk_used_gb, disk_total_gb, temperature_c, swap_used_gb, swap_total_gb)
VALUES (NOW(), 45.0, 2.8, 4.0, 100.0, 256.0, 52.0, 0.5, 2.0);
"

# Verify insert
ROW_COUNT=$(docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -tAc "SELECT COUNT(*) FROM monitoring.vitals")

if [[ "$ROW_COUNT" -ge "1" ]]; then
    log_info "✓ Permissions verified - test row inserted successfully"
else
    log_error "✗ Permission test failed"
    exit 1
fi

log_info ""
log_info "================================"
log_info "Monitoring Database Deployed!"
log_info "================================"
log_info ""
log_info "Database: $NEW_DB"
log_info "Schema: monitoring"
log_info "Tables: $TABLE_COUNT"
log_info "Views: $VIEW_COUNT"
log_info ""
log_info "Next steps:"
log_info "1. Deploy monitoring scripts (nexus_vitals.sh, nexus_status.sh)"
log_info "2. Configure cron jobs for automated collection"
log_info "3. Test with: docker exec -t $POSTGRES_CONTAINER psql -U $POSTGRES_USER -d $NEW_DB -c 'SELECT * FROM monitoring.recent_vitals LIMIT 5;'"
log_info ""
log_info "Connection string: postgresql://$POSTGRES_USER@localhost/$NEW_DB"
