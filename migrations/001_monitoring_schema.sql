-- Nexus Token Monitoring Database Schema
-- Version: 1.0
-- Created: 2025-11-18
-- Description: Complete schema for token usage monitoring and analytics

BEGIN;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================================
-- TABLE: api_calls
-- Purpose: Track individual API requests with detailed metrics
-- =====================================================================

CREATE TABLE IF NOT EXISTS api_calls (
    id SERIAL PRIMARY KEY,

    -- Request identification
    request_id UUID DEFAULT gen_random_uuid() NOT NULL,
    correlation_id VARCHAR(100), -- Links to carousel_id or workflow_execution_id

    -- API details
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100),
    endpoint VARCHAR(200),

    -- Timing
    timestamp TIMESTAMPTZ DEFAULT NOW() NOT NULL,
    duration_ms INTEGER,

    -- Token metrics
    prompt_tokens INTEGER DEFAULT 0,
    completion_tokens INTEGER DEFAULT 0,
    total_tokens INTEGER DEFAULT 0,

    -- Cost tracking
    cost_usd DECIMAL(10, 6) DEFAULT 0.000000,
    rate_limit_remaining INTEGER,

    -- Request context
    operation VARCHAR(100),
    user_id VARCHAR(100),

    -- Quality metrics
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,

    -- Prompt tracking (for A/B testing)
    prompt_version VARCHAR(50),
    temperature DECIMAL(3, 2),
    max_tokens INTEGER,

    -- Constraints
    CONSTRAINT api_calls_provider_check CHECK (
        provider IN ('groq', 'gemini', 'claude', 'openai', 'pexels', 'other')
    )
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_api_calls_timestamp ON api_calls(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_api_calls_provider ON api_calls(provider);
CREATE INDEX IF NOT EXISTS idx_api_calls_correlation ON api_calls(correlation_id);
CREATE INDEX IF NOT EXISTS idx_api_calls_operation ON api_calls(operation);
CREATE INDEX IF NOT EXISTS idx_api_calls_success ON api_calls(success);
CREATE INDEX IF NOT EXISTS idx_api_calls_date ON api_calls(DATE(timestamp));

COMMENT ON TABLE api_calls IS 'Individual API call tracking with tokens, costs, and performance metrics';

-- =====================================================================
-- TABLE: daily_usage_summary
-- Purpose: Aggregated daily metrics for fast reporting
-- =====================================================================

CREATE TABLE IF NOT EXISTS daily_usage_summary (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100),

    -- Aggregated metrics
    total_calls INTEGER DEFAULT 0,
    successful_calls INTEGER DEFAULT 0,
    failed_calls INTEGER DEFAULT 0,

    total_prompt_tokens BIGINT DEFAULT 0,
    total_completion_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,

    total_cost_usd DECIMAL(10, 2) DEFAULT 0.00,
    avg_tokens_per_call DECIMAL(10, 2),

    -- Performance metrics
    avg_duration_ms INTEGER,
    p95_duration_ms INTEGER,
    p99_duration_ms INTEGER,

    -- Updated timestamp
    last_updated TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    UNIQUE(date, provider, model)
);

CREATE INDEX IF NOT EXISTS idx_daily_summary_date ON daily_usage_summary(date DESC);
CREATE INDEX IF NOT EXISTS idx_daily_summary_provider ON daily_usage_summary(provider);

COMMENT ON TABLE daily_usage_summary IS 'Daily aggregated usage metrics for efficient reporting';

-- =====================================================================
-- TABLE: cost_budgets
-- Purpose: Manage cost budgets and alerts
-- =====================================================================

CREATE TABLE IF NOT EXISTS cost_budgets (
    id SERIAL PRIMARY KEY,

    -- Budget scope
    period_type VARCHAR(20) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- Limits
    budget_usd DECIMAL(10, 2) NOT NULL,
    warning_threshold_pct INTEGER DEFAULT 80,

    -- Filtering (NULL = applies to all)
    provider VARCHAR(50),
    operation VARCHAR(100),

    -- Status tracking
    current_spend_usd DECIMAL(10, 2) DEFAULT 0.00,
    alert_sent BOOLEAN DEFAULT FALSE,
    alert_sent_at TIMESTAMPTZ,

    -- Metadata
    created_at TIMESTAMPTZ DEFAULT NOW(),
    created_by VARCHAR(100),
    notes TEXT,

    -- Constraints
    CONSTRAINT cost_budgets_period_check CHECK (
        period_type IN ('daily', 'weekly', 'monthly', 'annual')
    ),
    CONSTRAINT cost_budgets_threshold_check CHECK (
        warning_threshold_pct BETWEEN 1 AND 100
    )
);

CREATE INDEX IF NOT EXISTS idx_budgets_active ON cost_budgets(start_date, end_date) WHERE CURRENT_DATE BETWEEN start_date AND end_date;

COMMENT ON TABLE cost_budgets IS 'Budget management and alerting thresholds';

-- =====================================================================
-- TABLE: carousel_performance
-- Purpose: Track carousel generation performance and social metrics
-- =====================================================================

CREATE TABLE IF NOT EXISTS carousel_performance (
    id SERIAL PRIMARY KEY,
    carousel_id UUID UNIQUE NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Generation metrics
    total_time_seconds DECIMAL(10, 3),
    groq_time_seconds DECIMAL(10, 3),
    gemini_time_seconds DECIMAL(10, 3),
    rendering_time_seconds DECIMAL(10, 3),

    -- Quality scores (1-10 scale)
    fact_accuracy_score INTEGER CHECK (fact_accuracy_score BETWEEN 1 AND 10),
    brand_fit_score INTEGER CHECK (brand_fit_score BETWEEN 1 AND 10),
    engagement_score INTEGER CHECK (engagement_score BETWEEN 1 AND 10),

    -- API metrics
    groq_tokens INTEGER DEFAULT 0,
    gemini_tokens INTEGER DEFAULT 0,
    claude_tokens INTEGER DEFAULT 0,
    total_cost_usd DECIMAL(10, 6) DEFAULT 0.000000,

    -- Instagram/Social performance
    published_at TIMESTAMPTZ,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    saves INTEGER DEFAULT 0,
    reach INTEGER DEFAULT 0,
    impressions INTEGER DEFAULT 0,

    -- A/B testing
    prompt_version VARCHAR(50),
    template_version VARCHAR(50),

    -- Content metadata
    topic VARCHAR(200),
    fact_source VARCHAR(200),
    image_source VARCHAR(200),

    -- Notes
    notes TEXT
);

CREATE INDEX IF NOT EXISTS idx_carousel_generated ON carousel_performance(generated_at DESC);
CREATE INDEX IF NOT EXISTS idx_carousel_published ON carousel_performance(published_at DESC);
CREATE INDEX IF NOT EXISTS idx_carousel_topic ON carousel_performance(topic);
CREATE INDEX IF NOT EXISTS idx_carousel_prompt_version ON carousel_performance(prompt_version);

COMMENT ON TABLE carousel_performance IS 'Carousel generation performance and social media analytics';

-- =====================================================================
-- TABLE: alert_history
-- Purpose: Log all alerts sent for audit trail
-- =====================================================================

CREATE TABLE IF NOT EXISTS alert_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    alert_type VARCHAR(50) NOT NULL,
    severity VARCHAR(20) NOT NULL,
    message TEXT NOT NULL,
    recipient VARCHAR(100),
    channel VARCHAR(50), -- 'telegram', 'email', 'slack'
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    metadata JSONB,

    CONSTRAINT alert_severity_check CHECK (
        severity IN ('info', 'warning', 'critical')
    )
);

CREATE INDEX IF NOT EXISTS idx_alert_timestamp ON alert_history(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_alert_type ON alert_history(alert_type);

COMMENT ON TABLE alert_history IS 'Audit trail of all monitoring alerts';

-- =====================================================================
-- VIEWS: Reporting and Analytics
-- =====================================================================

-- View: Hourly usage for real-time dashboards
CREATE OR REPLACE VIEW v_hourly_usage AS
SELECT
    DATE_TRUNC('hour', timestamp) AS hour,
    provider,
    model,
    COUNT(*) AS calls,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS total_cost,
    AVG(duration_ms) AS avg_duration_ms,
    SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 AS success_rate
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY hour, provider, model
ORDER BY hour DESC;

COMMENT ON VIEW v_hourly_usage IS 'Hourly aggregated metrics for the past 7 days';

-- View: Cost breakdown by operation
CREATE OR REPLACE VIEW v_cost_by_operation AS
SELECT
    operation,
    provider,
    COUNT(*) AS total_calls,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS total_cost,
    AVG(cost_usd) AS avg_cost_per_call,
    SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 AS success_rate,
    AVG(duration_ms) AS avg_duration_ms
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '30 days'
GROUP BY operation, provider
ORDER BY total_cost DESC;

COMMENT ON VIEW v_cost_by_operation IS 'Cost analysis by operation type for the past 30 days';

-- View: Carousel ROI analysis
CREATE OR REPLACE VIEW v_carousel_roi AS
SELECT
    carousel_id,
    generated_at,
    published_at,
    total_cost_usd AS production_cost,
    (likes + comments * 2 + shares * 3 + saves * 4) AS engagement_score,
    CASE
        WHEN total_cost_usd > 0 THEN
            (likes + comments * 2 + shares * 3 + saves * 4) / total_cost_usd
        ELSE 0
    END AS roi_score,
    prompt_version,
    template_version,
    topic,
    impressions,
    reach
FROM carousel_performance
WHERE published_at IS NOT NULL
ORDER BY roi_score DESC;

COMMENT ON VIEW v_carousel_roi IS 'ROI analysis for published carousels';

-- View: Current budget status
CREATE OR REPLACE VIEW v_budget_status AS
SELECT
    cb.id,
    cb.period_type,
    cb.start_date,
    cb.end_date,
    cb.budget_usd,
    cb.warning_threshold_pct,
    cb.provider,
    cb.operation,
    COALESCE(SUM(ac.cost_usd), 0) AS current_spend,
    cb.budget_usd - COALESCE(SUM(ac.cost_usd), 0) AS remaining,
    (COALESCE(SUM(ac.cost_usd), 0) / cb.budget_usd * 100) AS usage_pct,
    CASE
        WHEN (COALESCE(SUM(ac.cost_usd), 0) / cb.budget_usd * 100) >= 100 THEN 'exceeded'
        WHEN (COALESCE(SUM(ac.cost_usd), 0) / cb.budget_usd * 100) >= cb.warning_threshold_pct THEN 'warning'
        ELSE 'ok'
    END AS status
FROM cost_budgets cb
LEFT JOIN api_calls ac ON
    ac.timestamp BETWEEN cb.start_date AND cb.end_date
    AND (cb.provider IS NULL OR ac.provider = cb.provider)
    AND (cb.operation IS NULL OR ac.operation = cb.operation)
WHERE CURRENT_DATE BETWEEN cb.start_date AND cb.end_date
GROUP BY cb.id;

COMMENT ON VIEW v_budget_status IS 'Real-time budget tracking with status indicators';

-- =====================================================================
-- TRIGGERS: Automatic data management
-- =====================================================================

-- Trigger: Auto-update daily summary on new API call
CREATE OR REPLACE FUNCTION update_daily_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_usage_summary (
        date, provider, model,
        total_calls, successful_calls, failed_calls,
        total_prompt_tokens, total_completion_tokens, total_tokens,
        total_cost_usd
    )
    VALUES (
        DATE(NEW.timestamp), NEW.provider, NEW.model,
        1,
        CASE WHEN NEW.success THEN 1 ELSE 0 END,
        CASE WHEN NEW.success THEN 0 ELSE 1 END,
        NEW.prompt_tokens,
        NEW.completion_tokens,
        NEW.total_tokens,
        NEW.cost_usd
    )
    ON CONFLICT (date, provider, model) DO UPDATE SET
        total_calls = daily_usage_summary.total_calls + 1,
        successful_calls = daily_usage_summary.successful_calls + CASE WHEN NEW.success THEN 1 ELSE 0 END,
        failed_calls = daily_usage_summary.failed_calls + CASE WHEN NEW.success THEN 0 ELSE 1 END,
        total_prompt_tokens = daily_usage_summary.total_prompt_tokens + NEW.prompt_tokens,
        total_completion_tokens = daily_usage_summary.total_completion_tokens + NEW.completion_tokens,
        total_tokens = daily_usage_summary.total_tokens + NEW.total_tokens,
        total_cost_usd = daily_usage_summary.total_cost_usd + NEW.cost_usd,
        last_updated = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_daily_summary ON api_calls;
CREATE TRIGGER trigger_update_daily_summary
    AFTER INSERT ON api_calls
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_summary();

COMMENT ON FUNCTION update_daily_summary IS 'Automatically update daily summary when new API calls are logged';

-- Trigger: Update budget current spend
CREATE OR REPLACE FUNCTION update_budget_spend()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE cost_budgets
    SET current_spend_usd = (
        SELECT COALESCE(SUM(cost_usd), 0)
        FROM api_calls
        WHERE timestamp BETWEEN start_date AND end_date
            AND (provider IS NULL OR api_calls.provider = cost_budgets.provider)
            AND (operation IS NULL OR api_calls.operation = cost_budgets.operation)
    )
    WHERE CURRENT_DATE BETWEEN start_date AND end_date;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_budget_spend ON api_calls;
CREATE TRIGGER trigger_update_budget_spend
    AFTER INSERT ON api_calls
    FOR EACH ROW
    EXECUTE FUNCTION update_budget_spend();

-- =====================================================================
-- FUNCTIONS: Utility functions
-- =====================================================================

-- Function: Get token usage summary for a date range
CREATE OR REPLACE FUNCTION get_usage_summary(
    start_date DATE,
    end_date DATE,
    p_provider VARCHAR DEFAULT NULL
)
RETURNS TABLE (
    provider VARCHAR,
    total_calls BIGINT,
    total_tokens BIGINT,
    total_cost DECIMAL,
    avg_tokens_per_call DECIMAL,
    success_rate DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ac.provider,
        COUNT(*)::BIGINT AS total_calls,
        SUM(ac.total_tokens)::BIGINT AS total_tokens,
        SUM(ac.cost_usd)::DECIMAL(10, 2) AS total_cost,
        AVG(ac.total_tokens)::DECIMAL(10, 2) AS avg_tokens_per_call,
        (SUM(CASE WHEN ac.success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100)::DECIMAL(5, 2) AS success_rate
    FROM api_calls ac
    WHERE ac.timestamp >= start_date
      AND ac.timestamp < end_date + INTERVAL '1 day'
      AND (p_provider IS NULL OR ac.provider = p_provider)
    GROUP BY ac.provider
    ORDER BY total_cost DESC;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION get_usage_summary IS 'Get comprehensive usage summary for a date range';

-- =====================================================================
-- INITIAL DATA: Default budgets
-- =====================================================================

-- Insert default daily budget
INSERT INTO cost_budgets (
    period_type, start_date, end_date,
    budget_usd, warning_threshold_pct,
    created_by, notes
) VALUES (
    'daily',
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '365 days',
    5.00,
    80,
    'system',
    'Default daily budget - adjust as needed'
) ON CONFLICT DO NOTHING;

-- Insert default monthly budget
INSERT INTO cost_budgets (
    period_type, start_date, end_date,
    budget_usd, warning_threshold_pct,
    created_by, notes
) VALUES (
    'monthly',
    DATE_TRUNC('month', CURRENT_DATE)::DATE,
    (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '12 months')::DATE,
    150.00,
    85,
    'system',
    'Default monthly budget - adjust as needed'
) ON CONFLICT DO NOTHING;

-- =====================================================================
-- GRANT PERMISSIONS
-- =====================================================================

-- Grant access to application user (adjust username as needed)
-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO nexus;
-- GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO nexus;

COMMIT;

-- =====================================================================
-- VERIFICATION QUERIES
-- =====================================================================

-- Verify tables created
SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND tablename LIKE '%api_%' OR tablename LIKE '%budget%' OR tablename LIKE '%carousel%';

-- Verify indexes created
SELECT indexname, tablename FROM pg_indexes WHERE schemaname = 'public' AND tablename IN ('api_calls', 'daily_usage_summary', 'cost_budgets', 'carousel_performance');

-- Verify views created
SELECT viewname FROM pg_views WHERE schemaname = 'public' AND viewname LIKE 'v_%';

-- Verify triggers created
SELECT trigger_name, event_object_table FROM information_schema.triggers WHERE trigger_schema = 'public';

-- =====================================================================
-- EXAMPLE QUERIES
-- =====================================================================

-- Example 1: Today's spending
-- SELECT * FROM get_usage_summary(CURRENT_DATE, CURRENT_DATE, NULL);

-- Example 2: Budget status
-- SELECT * FROM v_budget_status;

-- Example 3: Top carousels by ROI
-- SELECT * FROM v_carousel_roi LIMIT 10;

-- Example 4: Hourly usage trend
-- SELECT * FROM v_hourly_usage WHERE hour >= NOW() - INTERVAL '24 hours';

-- =====================================================================
-- MAINTENANCE NOTES
-- =====================================================================

-- Run VACUUM ANALYZE monthly to optimize performance
-- VACUUM ANALYZE api_calls;
-- VACUUM ANALYZE daily_usage_summary;

-- Archive old data (older than 90 days) to reduce table size
-- CREATE TABLE api_calls_archive (LIKE api_calls INCLUDING ALL);
-- INSERT INTO api_calls_archive SELECT * FROM api_calls WHERE timestamp < NOW() - INTERVAL '90 days';
-- DELETE FROM api_calls WHERE timestamp < NOW() - INTERVAL '90 days';

-- =====================================================================
-- END OF SCHEMA
-- =====================================================================
