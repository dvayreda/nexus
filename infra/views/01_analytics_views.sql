-- Nexus Analytics Views
-- Purpose: Provide "Schema-as-API" for FactsMind analytics queries
-- These views abstract raw data into actionable insights
-- Last Updated: 2025-11-25

-- ============================================
-- 1. Account Health Summary
-- ============================================
-- Current status snapshot for the account
CREATE OR REPLACE VIEW social_analytics.view_account_health AS
SELECT
    a.id as account_id,
    a.username,
    a.ig_user_id,
    a.biography,
    ds.followers_count,
    ds.following_count,
    ds.media_count,
    ds.verified,
    ds.snapshot_date as last_snapshot_date,
    a.last_synced,
    -- Calculate growth vs 7 days ago
    COALESCE(
        (ds.followers_count - LAG(ds.followers_count) OVER (
            PARTITION BY a.id ORDER BY ds.snapshot_date
        )), 0
    ) as followers_7day_change,
    -- Growth percentage
    CASE 
        WHEN LAG(ds.followers_count) OVER (PARTITION BY a.id ORDER BY ds.snapshot_date) > 0
        THEN ROUND(
            ((ds.followers_count - LAG(ds.followers_count) OVER (
                PARTITION BY a.id ORDER BY ds.snapshot_date
            )) / LAG(ds.followers_count) OVER (
                PARTITION BY a.id ORDER BY ds.snapshot_date
            ) * 100)::numeric, 2
        )
        ELSE 0
    END as followers_growth_percent_7day
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.daily_snapshots ds ON a.id = ds.account_id
    AND ds.snapshot_date = (
        SELECT MAX(snapshot_date) FROM social_analytics.daily_snapshots 
        WHERE account_id = a.id
    )
WHERE a.active = TRUE;

-- ============================================
-- 2. Content Performance by Type
-- ============================================
-- Compare engagement across carousel vs reels vs images
CREATE OR REPLACE VIEW social_analytics.view_content_performance_by_type AS
SELECT
    a.id as account_id,
    a.username,
    COALESCE(p.media_type, 'UNKNOWN') as content_type,
    COUNT(DISTINCT p.id) as total_posts,
    ROUND(AVG(COALESCE(pm.likes_count, 0))::numeric, 2) as avg_likes,
    ROUND(AVG(COALESCE(pm.comments_count, 0))::numeric, 2) as avg_comments,
    ROUND(AVG(COALESCE(pm.saves_count, 0))::numeric, 2) as avg_saves,
    ROUND(AVG(COALESCE(pm.reach, 0))::numeric, 2) as avg_reach,
    ROUND(AVG(COALESCE(pm.impressions, 0))::numeric, 2) as avg_impressions,
    -- Engagement rate: (likes + comments + saves) / reach
    CASE 
        WHEN AVG(COALESCE(pm.reach, 1)) > 0 THEN
            ROUND(
                (AVG(COALESCE(pm.likes_count, 0)) + 
                 AVG(COALESCE(pm.comments_count, 0)) + 
                 AVG(COALESCE(pm.saves_count, 0))) / 
                AVG(COALESCE(pm.reach, 1)) * 100
                ::numeric, 2
            )
        ELSE 0
    END as avg_engagement_rate_percent,
    -- Save rate: saves / reach
    CASE 
        WHEN AVG(COALESCE(pm.reach, 1)) > 0 THEN
            ROUND(
                AVG(COALESCE(pm.saves_count, 0)) / 
                AVG(COALESCE(pm.reach, 1)) * 100
                ::numeric, 2
            )
        ELSE 0
    END as avg_save_rate_percent,
    MAX(p.posted_at) as most_recent_post,
    CURRENT_TIMESTAMP as calculated_at
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.ig_posts p ON a.id = p.account_id
LEFT JOIN social_analytics.post_metrics pm ON p.id = pm.post_id
    AND pm.measured_at = (
        SELECT MAX(measured_at) FROM social_analytics.post_metrics 
        WHERE post_id = p.id
    )
WHERE a.active = TRUE
GROUP BY a.id, a.username, p.media_type
ORDER BY a.id, total_posts DESC;

-- ============================================
-- 3. Best Posting Times Analysis
-- ============================================
-- Optimal hours of day for posting based on engagement
CREATE OR REPLACE VIEW social_analytics.view_best_posting_times AS
SELECT
    a.id as account_id,
    a.username,
    EXTRACT(HOUR FROM p.posted_at) as posting_hour,
    COUNT(DISTINCT p.id) as posts_in_hour,
    ROUND(AVG(COALESCE(pm.likes_count, 0))::numeric, 2) as avg_likes,
    ROUND(AVG(COALESCE(pm.saves_count, 0))::numeric, 2) as avg_saves,
    ROUND(AVG(COALESCE(pm.reach, 0))::numeric, 2) as avg_reach,
    CASE 
        WHEN AVG(COALESCE(pm.reach, 1)) > 0 THEN
            ROUND(
                (AVG(COALESCE(pm.likes_count, 0)) + 
                 AVG(COALESCE(pm.saves_count, 0))) / 
                AVG(COALESCE(pm.reach, 1)) * 100
                ::numeric, 2
            )
        ELSE 0
    END as avg_engagement_rate_percent,
    -- Rank best hours
    RANK() OVER (
        PARTITION BY a.id ORDER BY 
        AVG(COALESCE(pm.reach, 0)) DESC
    ) as hour_rank_by_reach
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.ig_posts p ON a.id = p.account_id
LEFT JOIN social_analytics.post_metrics pm ON p.id = pm.post_id
    AND pm.measured_at = (
        SELECT MAX(measured_at) FROM social_analytics.post_metrics 
        WHERE post_id = p.id
    )
WHERE a.active = TRUE
    AND p.posted_at IS NOT NULL
GROUP BY a.id, a.username, EXTRACT(HOUR FROM p.posted_at)
ORDER BY a.id, posting_hour;

-- ============================================
-- 4. Top Performing Posts
-- ============================================
-- Your best posts ranked by engagement
CREATE OR REPLACE VIEW social_analytics.view_top_posts_30d AS
SELECT
    a.id as account_id,
    a.username,
    p.id as post_id,
    p.ig_post_id,
    p.media_type,
    p.caption,
    p.permalink,
    p.posted_at,
    COALESCE(pm.likes_count, 0) as likes,
    COALESCE(pm.comments_count, 0) as comments,
    COALESCE(pm.saves_count, 0) as saves,
    COALESCE(pm.reach, 0) as reach,
    CASE 
        WHEN pm.reach > 0 THEN
            ROUND(
                ((pm.likes_count + pm.comments_count + pm.saves_count)::numeric / pm.reach * 100),
                2
            )
        ELSE 0
    END as engagement_rate_percent,
    RANK() OVER (
        PARTITION BY a.id ORDER BY pm.reach DESC NULLS LAST
    ) as rank_by_reach
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.ig_posts p ON a.id = p.account_id
    AND p.posted_at >= NOW() - INTERVAL '30 days'
LEFT JOIN social_analytics.post_metrics pm ON p.id = pm.post_id
    AND pm.measured_at = (
        SELECT MAX(measured_at) FROM social_analytics.post_metrics 
        WHERE post_id = p.id
    )
WHERE a.active = TRUE
ORDER BY a.id, rank_by_reach;

-- ============================================
-- 5. Growth Velocity
-- ============================================
-- How fast you're growing (followers per day)
CREATE OR REPLACE VIEW social_analytics.view_growth_velocity AS
SELECT
    a.id as account_id,
    a.username,
    COALESCE(ds1.snapshot_date, CURRENT_DATE) as snapshot_date,
    COALESCE(ds1.followers_count, 0) as followers_today,
    COALESCE(
        (ds1.followers_count - 
         LAG(ds1.followers_count) OVER (PARTITION BY a.id ORDER BY ds1.snapshot_date)),
        0
    ) as followers_change_1day,
    COALESCE(
        (ds1.followers_count - 
         LAG(ds1.followers_count, 7) OVER (PARTITION BY a.id ORDER BY ds1.snapshot_date)),
        0
    ) as followers_change_7day,
    COALESCE(
        (ds1.followers_count - 
         LAG(ds1.followers_count, 30) OVER (PARTITION BY a.id ORDER BY ds1.snapshot_date)),
        0
    ) as followers_change_30day,
    COALESCE(ds1.media_count, 0) as posts_today,
    COALESCE(
        (ds1.media_count - 
         LAG(ds1.media_count) OVER (PARTITION BY a.id ORDER BY ds1.snapshot_date)),
        0
    ) as new_posts_1day
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.daily_snapshots ds1 ON a.id = ds1.account_id
WHERE a.active = TRUE
    AND ds1.snapshot_date >= NOW()::DATE - INTERVAL '90 days'
ORDER BY a.id, ds1.snapshot_date DESC;

-- ============================================
-- 6. Engagement Rate Over Time
-- ============================================
-- Track engagement trends
CREATE OR REPLACE VIEW social_analytics.view_engagement_trend AS
SELECT
    a.id as account_id,
    a.username,
    DATE(pm.measured_at) as measurement_date,
    COUNT(DISTINCT p.id) as posts_measured,
    ROUND(AVG(COALESCE(pm.likes_count, 0))::numeric, 2) as avg_likes,
    ROUND(AVG(COALESCE(pm.comments_count, 0))::numeric, 2) as avg_comments,
    ROUND(AVG(COALESCE(pm.saves_count, 0))::numeric, 2) as avg_saves,
    ROUND(AVG(COALESCE(pm.reach, 0))::numeric, 2) as avg_reach,
    CASE 
        WHEN AVG(COALESCE(pm.reach, 1)) > 0 THEN
            ROUND(
                (AVG(COALESCE(pm.likes_count, 0)) + 
                 AVG(COALESCE(pm.comments_count, 0)) + 
                 AVG(COALESCE(pm.saves_count, 0))) / 
                AVG(COALESCE(pm.reach, 1)) * 100
                ::numeric, 2
            )
        ELSE 0
    END as avg_engagement_rate_percent
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.ig_posts p ON a.id = p.account_id
LEFT JOIN social_analytics.post_metrics pm ON p.id = pm.post_id
WHERE a.active = TRUE
GROUP BY a.id, a.username, DATE(pm.measured_at)
ORDER BY a.id, DATE(pm.measured_at) DESC;

-- ============================================
-- 7. Strategy Summary (For FactsMind)
-- ============================================
-- All key metrics in one place
CREATE OR REPLACE VIEW social_analytics.view_strategy_summary AS
SELECT
    a.id as account_id,
    a.username,
    -- Account metrics
    (SELECT followers_count FROM social_analytics.daily_snapshots 
     WHERE account_id = a.id ORDER BY snapshot_date DESC LIMIT 1) as current_followers,
    (SELECT media_count FROM social_analytics.daily_snapshots 
     WHERE account_id = a.id ORDER BY snapshot_date DESC LIMIT 1) as total_posts,
    -- Best performing content type
    (SELECT content_type FROM social_analytics.view_content_performance_by_type 
     WHERE account_id = a.id ORDER BY avg_engagement_rate_percent DESC NULLS LAST LIMIT 1) as best_content_type,
    (SELECT ROUND(avg_engagement_rate_percent::numeric, 2) FROM social_analytics.view_content_performance_by_type 
     WHERE account_id = a.id ORDER BY avg_engagement_rate_percent DESC NULLS LAST LIMIT 1) as best_type_engagement_rate,
    -- Best posting hour
    (SELECT posting_hour FROM social_analytics.view_best_posting_times 
     WHERE account_id = a.id AND hour_rank_by_reach = 1) as best_posting_hour,
    -- Growth rate
    (SELECT followers_change_7day FROM social_analytics.view_growth_velocity 
     WHERE account_id = a.id ORDER BY snapshot_date DESC LIMIT 1) as followers_gained_7days,
    -- Latest engagement rate
    (SELECT avg_engagement_rate_percent FROM social_analytics.view_engagement_trend 
     WHERE account_id = a.id ORDER BY measurement_date DESC LIMIT 1) as latest_engagement_rate,
    -- Data freshness
    a.last_synced,
    CURRENT_TIMESTAMP as generated_at
FROM social_analytics.ig_accounts a
WHERE a.active = TRUE;
