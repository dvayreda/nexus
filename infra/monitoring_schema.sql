-- Nexus Self-Awareness Monitoring Database
-- Purpose: Track system vitals, service health, and incidents for self-monitoring

-- Create database
-- Note: This must be run as postgres user with createdb privileges
-- Execution: Run via script that first creates DB, then executes this schema

-- Connect to nexus_system database before running the schema below

CREATE SCHEMA IF NOT EXISTS monitoring;

-- System vitals tracking (CPU, memory, disk, temperature)
CREATE TABLE IF NOT EXISTS monitoring.vitals (
    timestamp TIMESTAMPTZ PRIMARY KEY,
    cpu_percent FLOAT NOT NULL CHECK (cpu_percent >= 0 AND cpu_percent <= 100),
    memory_used_gb FLOAT NOT NULL CHECK (memory_used_gb >= 0),
    memory_total_gb FLOAT NOT NULL CHECK (memory_total_gb > 0),
    memory_percent FLOAT GENERATED ALWAYS AS (
        (memory_used_gb / memory_total_gb * 100)::FLOAT
    ) STORED,
    disk_used_gb FLOAT NOT NULL CHECK (disk_used_gb >= 0),
    disk_total_gb FLOAT NOT NULL CHECK (disk_total_gb > 0),
    disk_percent FLOAT GENERATED ALWAYS AS (
        (disk_used_gb / disk_total_gb * 100)::FLOAT
    ) STORED,
    temperature_c FLOAT CHECK (temperature_c IS NULL OR (temperature_c >= 0 AND temperature_c <= 100)),
    swap_used_gb FLOAT NOT NULL CHECK (swap_used_gb >= 0),
    swap_total_gb FLOAT NOT NULL CHECK (swap_total_gb >= 0)
);

-- Create indexes for time-based queries
CREATE INDEX IF NOT EXISTS idx_vitals_timestamp_desc ON monitoring.vitals (timestamp DESC);

-- Service health tracking (Docker containers)
CREATE TABLE IF NOT EXISTS monitoring.service_health (
    id SERIAL PRIMARY KEY,
    check_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    service_name TEXT NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('running', 'stopped', 'restarting', 'dead', 'paused')),
    uptime_seconds BIGINT CHECK (uptime_seconds >= 0),
    restart_count INT DEFAULT 0 CHECK (restart_count >= 0),
    memory_usage_mb FLOAT CHECK (memory_usage_mb IS NULL OR memory_usage_mb >= 0),
    cpu_percent FLOAT CHECK (cpu_percent IS NULL OR (cpu_percent >= 0 AND cpu_percent <= 400))
);

-- Create indexes for service health queries
CREATE INDEX IF NOT EXISTS idx_service_health_check_time ON monitoring.service_health (check_time DESC);
CREATE INDEX IF NOT EXISTS idx_service_health_service_name ON monitoring.service_health (service_name, check_time DESC);

-- Incident logging (problems detected and resolutions)
CREATE TABLE IF NOT EXISTS monitoring.incidents (
    id SERIAL PRIMARY KEY,
    detected_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    issue_type TEXT NOT NULL,
    severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')),
    description TEXT NOT NULL,
    affected_service TEXT,
    resolution_attempted TEXT,
    resolved_at TIMESTAMPTZ,
    resolution_successful BOOLEAN,
    auto_resolved BOOLEAN DEFAULT FALSE,
    notes TEXT
);

-- Create indexes for incident queries
CREATE INDEX IF NOT EXISTS idx_incidents_detected_at ON monitoring.incidents (detected_at DESC);
CREATE INDEX IF NOT EXISTS idx_incidents_unresolved ON monitoring.incidents (detected_at DESC)
    WHERE resolved_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_incidents_service ON monitoring.incidents (affected_service, detected_at DESC);

-- Disk usage breakdown (per mount point)
CREATE TABLE IF NOT EXISTS monitoring.disk_usage (
    id SERIAL PRIMARY KEY,
    check_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    mount_point TEXT NOT NULL,
    used_gb FLOAT NOT NULL CHECK (used_gb >= 0),
    total_gb FLOAT NOT NULL CHECK (total_gb > 0),
    percent_used FLOAT GENERATED ALWAYS AS (
        (used_gb / total_gb * 100)::FLOAT
    ) STORED,
    inodes_used BIGINT CHECK (inodes_used >= 0),
    inodes_total BIGINT CHECK (inodes_total > 0)
);

-- Create indexes for disk usage queries
CREATE INDEX IF NOT EXISTS idx_disk_usage_check_time ON monitoring.disk_usage (check_time DESC);
CREATE INDEX IF NOT EXISTS idx_disk_usage_mount_point ON monitoring.disk_usage (mount_point, check_time DESC);

-- System improvements suggestions (logged by Claude Code or monitoring scripts)
CREATE TABLE IF NOT EXISTS monitoring.improvements (
    id SERIAL PRIMARY KEY,
    suggested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    category TEXT NOT NULL,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    priority TEXT NOT NULL CHECK (priority IN ('low', 'medium', 'high', 'critical')),
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'completed', 'rejected')),
    implemented_at TIMESTAMPTZ,
    implementation_notes TEXT,
    suggested_by TEXT DEFAULT 'monitoring_script'
);

-- Create indexes for improvements queries
CREATE INDEX IF NOT EXISTS idx_improvements_status ON monitoring.improvements (status, priority, suggested_at DESC);

-- Views for common queries

-- Recent vitals (last 24 hours)
CREATE OR REPLACE VIEW monitoring.recent_vitals AS
SELECT
    timestamp,
    cpu_percent,
    memory_percent,
    disk_percent,
    temperature_c,
    (swap_used_gb / NULLIF(swap_total_gb, 0) * 100)::FLOAT AS swap_percent
FROM monitoring.vitals
WHERE timestamp > NOW() - INTERVAL '24 hours'
ORDER BY timestamp DESC;

-- Current service status (latest check per service)
CREATE OR REPLACE VIEW monitoring.current_service_status AS
SELECT DISTINCT ON (service_name)
    service_name,
    status,
    uptime_seconds,
    restart_count,
    check_time,
    memory_usage_mb,
    cpu_percent
FROM monitoring.service_health
ORDER BY service_name, check_time DESC;

-- Active incidents (not resolved)
CREATE OR REPLACE VIEW monitoring.active_incidents AS
SELECT
    id,
    detected_at,
    issue_type,
    severity,
    description,
    affected_service,
    resolution_attempted
FROM monitoring.incidents
WHERE resolved_at IS NULL
ORDER BY
    CASE severity
        WHEN 'critical' THEN 1
        WHEN 'warning' THEN 2
        WHEN 'info' THEN 3
    END,
    detected_at DESC;

-- Pending improvements (not yet implemented)
CREATE OR REPLACE VIEW monitoring.pending_improvements AS
SELECT
    id,
    category,
    title,
    priority,
    status,
    suggested_at,
    description
FROM monitoring.improvements
WHERE status IN ('pending', 'in_progress')
ORDER BY
    CASE priority
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        WHEN 'low' THEN 4
    END,
    suggested_at DESC;

-- Data retention policy (keep 90 days detailed, aggregate older data)
-- This will be implemented via a cron job that runs monthly

COMMENT ON SCHEMA monitoring IS 'Nexus self-awareness monitoring database';
COMMENT ON TABLE monitoring.vitals IS 'System resource usage collected every 5 minutes';
COMMENT ON TABLE monitoring.service_health IS 'Docker service status checks';
COMMENT ON TABLE monitoring.incidents IS 'Problems detected and resolutions attempted';
COMMENT ON TABLE monitoring.disk_usage IS 'Disk usage breakdown per mount point';
COMMENT ON TABLE monitoring.improvements IS 'Suggested optimizations and enhancements';

-- Grant permissions (assuming nexus database user exists)
-- Note: This may need adjustment based on actual PostgreSQL user setup
GRANT USAGE ON SCHEMA monitoring TO nexus;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA monitoring TO nexus;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA monitoring TO nexus;
ALTER DEFAULT PRIVILEGES IN SCHEMA monitoring GRANT SELECT, INSERT, UPDATE ON TABLES TO nexus;
ALTER DEFAULT PRIVILEGES IN SCHEMA monitoring GRANT USAGE, SELECT ON SEQUENCES TO nexus;
