-- Nexus Social Analytics Schema
-- Purpose: Track Instagram account performance and post-level metrics
-- Used by: FactsMind AI for content strategy decisions

-- Create schema
CREATE SCHEMA IF NOT EXISTS social_analytics;

-- ============================================
-- 1. Instagram Account Configuration
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.ig_accounts (
    id SERIAL PRIMARY KEY,
    username VARCHAR(255) UNIQUE NOT NULL,
    ig_user_id BIGINT UNIQUE NOT NULL,
    access_token TEXT NOT NULL,
    token_expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    last_synced TIMESTAMP,
    active BOOLEAN DEFAULT TRUE,
    app_id VARCHAR(255),
    app_secret VARCHAR(255) ENCRYPTED
);

-- ============================================
-- 2. Daily Account Snapshots (Growth Tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.daily_snapshots (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES social_analytics.ig_accounts(id),
    snapshot_date DATE NOT NULL,
    followers_count BIGINT,
    following_count BIGINT,
    media_count BIGINT,
    biography TEXT,
    website_url TEXT,
    verified BOOLEAN,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, snapshot_date)
);

CREATE INDEX IF NOT EXISTS idx_daily_snapshots_account_date 
ON social_analytics.daily_snapshots(account_id, snapshot_date DESC);

-- ============================================
-- 3. Posts (Content Metadata)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.ig_posts (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES social_analytics.ig_accounts(id),
    ig_post_id BIGINT UNIQUE NOT NULL,
    media_type VARCHAR(50), -- CAROUSEL_ALBUM, IMAGE, VIDEO, REELS
    caption TEXT,
    media_url TEXT,
    permalink TEXT,
    posted_at TIMESTAMP NOT NULL,
    first_seen_at TIMESTAMP DEFAULT NOW(),
    hashtags TEXT[], -- Array of extracted hashtags
    mention_count INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ig_posts_account_date 
ON social_analytics.ig_posts(account_id, posted_at DESC);

CREATE INDEX IF NOT EXISTS idx_ig_posts_media_type 
ON social_analytics.ig_posts(account_id, media_type);

-- ============================================
-- 4. Post Metrics (Time-Series Performance Data)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.post_metrics (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES social_analytics.ig_posts(id),
    measured_at TIMESTAMP NOT NULL,
    likes_count BIGINT,
    comments_count BIGINT,
    shares_count BIGINT,
    saves_count BIGINT,
    reach BIGINT,
    impressions BIGINT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(post_id, measured_at)
);

CREATE INDEX IF NOT EXISTS idx_post_metrics_post_date 
ON social_analytics.post_metrics(post_id, measured_at DESC);

-- ============================================
-- 5. Engagement Velocity (Growth Rate Tracking)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.post_velocity (
    id SERIAL PRIMARY KEY,
    post_id INTEGER NOT NULL REFERENCES social_analytics.ig_posts(id),
    measured_at TIMESTAMP NOT NULL,
    likes_per_hour DECIMAL(10, 2),
    comments_per_hour DECIMAL(10, 2),
    saves_per_hour DECIMAL(10, 2),
    reach_per_hour DECIMAL(10, 2),
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(post_id, measured_at)
);

-- ============================================
-- 6. Hashtag Performance (What Works?)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.hashtag_performance (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES social_analytics.ig_accounts(id),
    hashtag VARCHAR(255) NOT NULL,
    post_count INT DEFAULT 0,
    avg_engagement_rate DECIMAL(5, 2),
    avg_reach BIGINT,
    last_used_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, hashtag)
);

-- ============================================
-- 7. Content Type Performance (Analytics by Type)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.content_type_analytics (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES social_analytics.ig_accounts(id),
    media_type VARCHAR(50),
    avg_likes DECIMAL(12, 2),
    avg_comments DECIMAL(12, 2),
    avg_saves DECIMAL(12, 2),
    avg_reach DECIMAL(12, 2),
    avg_engagement_rate DECIMAL(5, 2),
    post_count INT,
    calculated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, media_type)
);

-- ============================================
-- 8. Topic/Theme Performance (For Content Strategy)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.topic_performance (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES social_analytics.ig_accounts(id),
    topic VARCHAR(255) NOT NULL,
    post_count INT DEFAULT 0,
    avg_engagement_rate DECIMAL(5, 2),
    avg_reach BIGINT,
    top_hashtags TEXT[],
    best_posting_hour INT,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, topic)
);

-- ============================================
-- 9. Insights Summary (Daily Quick Stats)
-- ============================================
CREATE TABLE IF NOT EXISTS social_analytics.daily_insights (
    id SERIAL PRIMARY KEY,
    account_id INTEGER NOT NULL REFERENCES social_analytics.ig_accounts(id),
    insight_date DATE NOT NULL,
    total_engagement BIGINT,
    total_reach BIGINT,
    total_impressions BIGINT,
    best_post_id INTEGER REFERENCES social_analytics.ig_posts(id),
    worst_post_id INTEGER REFERENCES social_analytics.ig_posts(id),
    avg_engagement_rate DECIMAL(5, 2),
    follower_growth INT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(account_id, insight_date)
);

-- ============================================
-- VIEWS FOR FACTSMIND CONSUMPTION
-- ============================================

-- Latest account metrics
CREATE OR REPLACE VIEW social_analytics.account_current_stats AS
SELECT 
    a.username,
    a.ig_user_id,
    d.followers_count,
    d.following_count,
    d.media_count,
    d.snapshot_date,
    LAG(d.followers_count) OVER (
        PARTITION BY a.id ORDER BY d.snapshot_date DESC
    ) as previous_followers,
    (d.followers_count - LAG(d.followers_count) OVER (
        PARTITION BY a.id ORDER BY d.snapshot_date DESC
    )) as followers_gained_today
FROM social_analytics.ig_accounts a
LEFT JOIN social_analytics.daily_snapshots d 
    ON a.id = d.account_id
WHERE a.active = TRUE
ORDER BY d.snapshot_date DESC;

-- Last 30 days top posts
CREATE OR REPLACE VIEW social_analytics.top_posts_30d AS
SELECT 
    p.ig_post_id,
    p.caption,
    p.media_type,
    p.posted_at,
    MAX(m.likes_count) as likes,
    MAX(m.comments_count) as comments,
    MAX(m.saves_count) as saves,
    MAX(m.reach) as reach,
    ROUND(
        (MAX(m.saves_count)::DECIMAL / NULLIF(MAX(m.reach), 0) * 100), 2
    ) as save_rate
FROM social_analytics.ig_posts p
LEFT JOIN social_analytics.post_metrics m ON p.id = m.post_id
WHERE p.posted_at > NOW() - INTERVAL '30 days'
GROUP BY p.id, p.ig_post_id, p.caption, p.media_type, p.posted_at
ORDER BY MAX(m.reach) DESC;

-- Content performance summary for strategy
CREATE OR REPLACE VIEW social_analytics.content_strategy_insights AS
SELECT 
    c.media_type,
    c.post_count,
    ROUND(c.avg_likes, 0) as avg_likes,
    ROUND(c.avg_comments, 0) as avg_comments,
    ROUND(c.avg_saves, 0) as avg_saves,
    ROUND(c.avg_reach, 0) as avg_reach,
    ROUND(c.avg_engagement_rate, 2) as avg_engagement_rate,
    ROUND(
        c.avg_saves / NULLIF(c.avg_reach, 0) * 100, 2
    ) as save_rate_percent
FROM social_analytics.content_type_analytics c
ORDER BY c.avg_engagement_rate DESC;

-- Grant permissions (adjust to your user)
GRANT USAGE ON SCHEMA social_analytics TO faceless;
GRANT SELECT ON ALL TABLES IN SCHEMA social_analytics TO faceless;
GRANT INSERT, UPDATE ON social_analytics.ig_accounts TO faceless;
GRANT INSERT, UPDATE ON social_analytics.daily_snapshots TO faceless;
GRANT INSERT ON social_analytics.ig_posts TO faceless;
GRANT INSERT ON social_analytics.post_metrics TO faceless;
GRANT INSERT ON social_analytics.daily_insights TO faceless;

-- Table comments for documentation
COMMENT ON TABLE social_analytics.ig_accounts IS 'Instagram account credentials and configuration';
COMMENT ON TABLE social_analytics.daily_snapshots IS 'Daily account metrics snapshots (followers, posts, etc)';
COMMENT ON TABLE social_analytics.ig_posts IS 'Individual Instagram posts with metadata';
COMMENT ON TABLE social_analytics.post_metrics IS 'Time-series metrics for each post (likes, comments, reach, etc)';
COMMENT ON TABLE social_analytics.post_velocity IS 'Growth velocity of posts (engagement rate per hour)';
COMMENT ON TABLE social_analytics.hashtag_performance IS 'Which hashtags drive the most engagement';
COMMENT ON TABLE social_analytics.content_type_analytics IS 'Performance aggregated by media type (carousel, video, etc)';
COMMENT ON TABLE social_analytics.topic_performance IS 'Performance grouped by topic or theme';
COMMENT ON TABLE social_analytics.daily_insights IS 'Daily summary insights for quick analysis';
