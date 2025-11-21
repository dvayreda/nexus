# Nexus Monitoring Database

**Self-awareness infrastructure for Nexus platform**

## Overview

The monitoring database enables Nexus to track its own health, detect issues, and maintain historical performance data. This is the foundation for self-awareness and automated incident response.

## Database: `nexus_system`

Separate database from the main n8n database to:
- Isolate monitoring data from application data
- Enable independent backup/restore
- Prevent monitoring from impacting n8n performance

## Schema: `monitoring`

All tables and views are contained in the `monitoring` schema within the `nexus_system` database.

---

## Tables

### `monitoring.vitals`

**Purpose:** Track system resource usage over time

**Collection frequency:** Every 5 minutes via cron job

**Retention:** 90 days detailed, 1 year aggregated

| Column | Type | Description |
|--------|------|-------------|
| timestamp | TIMESTAMPTZ | Primary key, collection time |
| cpu_percent | FLOAT | CPU usage percentage (0-100) |
| memory_used_gb | FLOAT | RAM in use (GB) |
| memory_total_gb | FLOAT | Total RAM (GB) |
| memory_percent | FLOAT | Computed: memory usage % |
| disk_used_gb | FLOAT | Root partition used (GB) |
| disk_total_gb | FLOAT | Root partition total (GB) |
| disk_percent | FLOAT | Computed: disk usage % |
| temperature_c | FLOAT | CPU temperature (°C) |
| swap_used_gb | FLOAT | Swap in use (GB) |
| swap_total_gb | FLOAT | Total swap (GB) |

**Example query:**
```sql
-- Recent vitals (last hour)
SELECT
    timestamp,
    cpu_percent,
    memory_percent,
    disk_percent,
    temperature_c
FROM monitoring.vitals
WHERE timestamp > NOW() - INTERVAL '1 hour'
ORDER BY timestamp DESC;
```

### `monitoring.service_health`

**Purpose:** Track Docker container status and resource usage

**Collection frequency:** Every 5 minutes via cron job

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| check_time | TIMESTAMPTZ | Check timestamp |
| service_name | TEXT | Container name (e.g., 'nexus-n8n') |
| status | TEXT | running, stopped, restarting, dead, paused |
| uptime_seconds | BIGINT | Container uptime in seconds |
| restart_count | INT | Number of restarts |
| memory_usage_mb | FLOAT | Memory usage in MB |
| cpu_percent | FLOAT | CPU usage % |

**Example query:**
```sql
-- Current status of all services (latest check)
SELECT service_name, status, uptime_seconds, restart_count
FROM monitoring.current_service_status
ORDER BY service_name;
```

### `monitoring.incidents`

**Purpose:** Log detected issues and resolution attempts

**Written by:** Monitoring scripts, watchdog scripts

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| detected_at | TIMESTAMPTZ | When issue was detected |
| issue_type | TEXT | Type of issue (e.g., 'service_down', 'memory_pressure') |
| severity | TEXT | info, warning, critical |
| description | TEXT | Human-readable description |
| affected_service | TEXT | Which service is affected (nullable) |
| resolution_attempted | TEXT | What was tried to fix it |
| resolved_at | TIMESTAMPTZ | When issue was resolved (nullable) |
| resolution_successful | BOOLEAN | Did the resolution work? |
| auto_resolved | BOOLEAN | Was it auto-resolved by watchdog? |
| notes | TEXT | Additional context |

**Example query:**
```sql
-- Active incidents (not yet resolved)
SELECT * FROM monitoring.active_incidents;

-- Incident history for a service
SELECT
    detected_at,
    issue_type,
    severity,
    description,
    resolution_attempted
FROM monitoring.incidents
WHERE affected_service = 'nexus-n8n'
ORDER BY detected_at DESC
LIMIT 10;
```

### `monitoring.disk_usage`

**Purpose:** Track disk usage per mount point over time

**Collection frequency:** Every 5 minutes via cron job

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| check_time | TIMESTAMPTZ | Check timestamp |
| mount_point | TEXT | Mount path (e.g., '/', '/mnt/backup') |
| used_gb | FLOAT | Space used (GB) |
| total_gb | FLOAT | Total space (GB) |
| percent_used | FLOAT | Computed: usage % |
| inodes_used | BIGINT | Inodes used |
| inodes_total | BIGINT | Total inodes |

**Example query:**
```sql
-- Current disk usage
SELECT
    mount_point,
    used_gb,
    total_gb,
    percent_used
FROM monitoring.disk_usage
WHERE check_time > NOW() - INTERVAL '10 minutes'
ORDER BY percent_used DESC;
```

### `monitoring.improvements`

**Purpose:** Log suggested optimizations and enhancements

**Written by:** Claude Code, monitoring scripts, manual entries

| Column | Type | Description |
|--------|------|-------------|
| id | SERIAL | Primary key |
| suggested_at | TIMESTAMPTZ | When suggested |
| category | TEXT | Category (e.g., 'performance', 'reliability') |
| title | TEXT | Short description |
| description | TEXT | Detailed description |
| priority | TEXT | low, medium, high, critical |
| status | TEXT | pending, in_progress, completed, rejected |
| implemented_at | TIMESTAMPTZ | When implemented (nullable) |
| implementation_notes | TEXT | Notes on implementation |
| suggested_by | TEXT | Who/what suggested it |

**Example query:**
```sql
-- Pending high-priority improvements
SELECT * FROM monitoring.pending_improvements
WHERE priority IN ('high', 'critical');
```

---

## Views

### `monitoring.recent_vitals`

Pre-filtered view of vitals from the last 24 hours.

```sql
SELECT * FROM monitoring.recent_vitals LIMIT 20;
```

### `monitoring.current_service_status`

Latest status check for each service (uses DISTINCT ON).

```sql
SELECT * FROM monitoring.current_service_status;
```

### `monitoring.active_incidents`

All unresolved incidents, ordered by severity.

```sql
SELECT * FROM monitoring.active_incidents;
```

### `monitoring.pending_improvements`

All pending or in-progress improvements, ordered by priority.

```sql
SELECT * FROM monitoring.pending_improvements;
```

---

## Deployment

### Prerequisites
- PostgreSQL container running (`nexus-postgres`)
- Database user `nexus` with appropriate permissions
- Schema file: `infra/monitoring_schema.sql`

### Steps

1. Copy files to Raspberry Pi:
```bash
# From WSL2
scp /home/dvayr/Projects_linux/nexus/infra/monitoring_schema.sql didac@100.122.207.23:~/
scp /home/dvayr/Projects_linux/nexus/scripts/pi/deploy_monitoring_db.sh didac@100.122.207.23:~/
```

2. Run deployment script on Pi:
```bash
~/ssh-nexus 'bash ~/deploy_monitoring_db.sh'
```

3. Verify deployment:
```bash
~/ssh-nexus 'docker exec -t nexus-postgres psql -U nexus -d nexus_system -c "SELECT table_name FROM information_schema.tables WHERE table_schema='\''monitoring'\'' ORDER BY table_name;"'
```

### Manual Deployment

If you prefer manual deployment:

```bash
# SSH to Pi
~/ssh-nexus

# Create database
docker exec -t nexus-postgres psql -U nexus -d postgres -c "CREATE DATABASE nexus_system OWNER nexus;"

# Execute schema
docker exec -i nexus-postgres psql -U nexus -d nexus_system < ~/monitoring_schema.sql

# Verify
docker exec -t nexus-postgres psql -U nexus -d nexus_system -c '\dt monitoring.*'
```

---

## Usage

### Querying from Scripts

```bash
# Query vitals
~/ssh-nexus 'docker exec -t nexus-postgres psql -U nexus -d nexus_system -tAc "SELECT cpu_percent, memory_percent FROM monitoring.vitals ORDER BY timestamp DESC LIMIT 1"'

# Log incident
~/ssh-nexus 'docker exec -t nexus-postgres psql -U nexus -d nexus_system -c "INSERT INTO monitoring.incidents (issue_type, severity, description) VALUES ('\''test'\'', '\''info'\'', '\''Test incident from script'\'');"'
```

### Connection from Python

```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",  # Or Docker internal hostname
    port=5432,
    database="nexus_system",
    user="nexus",
    password="YOUR_PASSWORD"  # From .env file
)

cur = conn.cursor()
cur.execute("SELECT * FROM monitoring.recent_vitals LIMIT 5")
rows = cur.fetchall()
for row in rows:
    print(row)

conn.close()
```

### Connection from bash (psql)

```bash
# Inside PostgreSQL container or from host with psql client
PGPASSWORD="YOUR_PASSWORD" psql -h localhost -U nexus -d nexus_system -c "SELECT * FROM monitoring.current_service_status;"
```

---

## Data Retention

### Current Policy
- **Detailed vitals:** 90 days
- **Aggregated vitals:** 1 year (hourly averages)
- **Incidents:** Indefinite (or until resolved + 1 year)
- **Disk usage:** 90 days detailed

### Cleanup Script (TODO)

Create monthly cron job to:
1. Aggregate vitals older than 90 days into hourly averages
2. Delete raw vitals older than 90 days
3. Archive resolved incidents older than 1 year
4. Vacuum database to reclaim space

---

## Performance Considerations

### Indexes

All tables have appropriate indexes for time-based queries:
- `idx_vitals_timestamp_desc` - Fast recent vitals queries
- `idx_service_health_check_time` - Fast service status lookups
- `idx_incidents_detected_at` - Fast incident history

### Estimated Storage

**Assumptions:**
- Vitals collected every 5 minutes: 288 rows/day
- 6 Docker services checked every 5 minutes: 1,728 rows/day
- ~10 incidents per month
- Disk usage tracked for 3 mount points: 864 rows/day

**90-day storage estimate:**
- Vitals: 288 * 90 = ~26,000 rows = ~2.6 MB
- Service health: 1,728 * 90 = ~155,000 rows = ~15 MB
- Disk usage: 864 * 90 = ~78,000 rows = ~7.8 MB
- **Total: ~25-30 MB for 90 days**

---

## Troubleshooting

### Database connection issues

```bash
# Check if postgres container is running
~/ssh-nexus 'docker ps | grep nexus-postgres'

# Check database exists
~/ssh-nexus 'docker exec -t nexus-postgres psql -U nexus -d postgres -c "\l"'

# Check schema exists
~/ssh-nexus 'docker exec -t nexus-postgres psql -U nexus -d nexus_system -c "\dn"'
```

### Permission denied errors

```bash
# Grant permissions manually
~/ssh-nexus 'docker exec -t nexus-postgres psql -U postgres -d nexus_system -c "GRANT ALL ON SCHEMA monitoring TO nexus;"'
~/ssh-nexus 'docker exec -t nexus-postgres psql -U postgres -d nexus_system -c "GRANT ALL ON ALL TABLES IN SCHEMA monitoring TO nexus;"'
```

### Empty vitals table

- Check if monitoring scripts are deployed
- Check if cron jobs are running: `~/ssh-nexus 'crontab -l'`
- Manually run vitals script: `~/ssh-nexus '~/nexus_vitals.sh'`

---

## Related Documentation

- [ROADMAP.md](../../ROADMAP.md) - Phase 1: Stability Foundation
- [Operations Guide](../operations/maintenance.md) - Backup procedures
- [Helper Scripts](../../scripts/README.md) - Token optimizers

---

**Last updated:** 2025-01 (Initial monitoring database deployment)
