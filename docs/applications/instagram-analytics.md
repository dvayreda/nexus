---
title: Nexus Instagram Analytics Integration
version: 2.0
last_updated: 2025-11-25
status: Production
purpose: Track Instagram Business Account performance for FactsMind content strategy
---

# Instagram Analytics Integration

**Purpose:** Collect and analyze Instagram performance data to inform FactsMind content strategy decisions.

**Architecture:** Nexus (infrastructure) → Facebook Graph Business API → PostgreSQL → FactsMind (app)

**Current Status:** ✅ **Production Ready** - Daily syncs working, 60-day token active

---

## Quick Start

### Prerequisites

1. **Instagram Business Account** ✅ (factsmind_official)
2. **Facebook Page linked to Instagram Account** ✅ (FactsMind page ID: 790469140827308)
3. **60-day Meta Access Token** ✅ (Valid until January 2026)
4. **App ID & Secret** ✅ (For token refresh capability)

### Setup (Already Complete on Production)

#### Step 1: Production Deployment (Already Done)

The following has already been deployed and is running:

**Database Schema**
- ✅ `social_analytics` schema created
- ✅ Tables: `ig_accounts`, `daily_snapshots`, `ig_posts`, `post_metrics`
- ✅ Schema includes: biography, followers, posts, engagement metrics

**Credentials Deployed**
- ✅ Token stored in `~/.instagram_env` on Pi
- ✅ APP_ID and APP_SECRET backed up for token refresh
- ✅ File permissions: 600 (secure)

**Sync Script Deployed**
- ✅ `nexus-social-sync.sh` configured for Business API
- ✅ Cron job scheduled: 10 AM daily (`0 10 * * *`)
- ✅ Script uses Facebook Graph API (v18.0)

---

## Authentication Flow (How It Works)

The current setup uses the **Facebook Graph Business API** with this flow:

```
Facebook Page (ID: 790469140827308)
    ↓
    (has connected)
    ↓
Instagram Business Account (ID: 17841478242620376)
    ↓
    (queries via)
    ↓
Facebook Graph API v18.0 with 60-day access token
```

**Why this approach?**
- Basic Instagram API only works with personal accounts
- Business API requires Page → Account connection
- Token lasts 60 days (much better than 1 hour)
- Can include APP_ID/SECRET for automatic renewal

#### What Happens Daily

The 10 AM cron job runs `nexus-social-sync.sh` which:

1. **Gets Facebook Page** (FactsMind page)
2. **Retrieves linked Instagram Business Account** (factsmind_official)
3. **Collects account metrics:**
   - Username, followers, post count
   - Biography, website, verification status
4. **Stores daily snapshot** in PostgreSQL
5. **Collects recent posts** (up to 10) with engagement metrics
6. **Updates database** with latest data

**Example Output:**
```
[2025-11-25 18:01:37] Starting Instagram Business API social sync...
[2025-11-25 18:01:38] Instagram Business Account ID: 17841478242620376
[2025-11-25 18:01:39] Account: factsmind_official | Followers: 8 | Posts: 10
[2025-11-25 18:01:39] Account data stored successfully
[2025-11-25 18:01:39] Collecting recent posts...
[2025-11-25 18:01:39] Found 10 recent posts
[2025-11-25 18:01:39] Instagram sync complete!
```

#### Manual Test

To verify the sync works anytime:

```bash
# SSH to Pi
ssh nexus

# Run sync manually
source ~/.instagram_env && ~/nexus-social-sync.sh

# Check stored data
docker exec nexus-postgres psql -U faceless -d nexus_system \
  -c "SELECT a.username, d.followers_count, d.snapshot_date 
       FROM social_analytics.daily_snapshots d 
       JOIN social_analytics.ig_accounts a ON d.account_id = a.id 
       ORDER BY d.snapshot_date DESC LIMIT 5;"
```

#### Cron Schedule

Currently active:
```bash
# 10 AM daily
0 10 * * * source ~/.instagram_env && ~/nexus-social-sync.sh >> /var/log/nexus-social-sync.log 2>&1
```

---

## Token Management

### Current Token Status

- **Token:** 60-day access token (valid until January 2026)
- **App ID:** 1273183897905367 (factsmind)
- **App Secret:** Stored securely in `~/.instagram_env`
- **Scope:** `instagram_basic`, `instagram_manage_insights`, `pages_show_list`

### Renewing the Token

When the token is about to expire (check expiration in `debug_token` endpoint):

```bash
# Go to Meta Graph API Explorer
# https://developers.facebook.com/tools/explorer/

# Select your Instagram app
# Click "Generate Access Token"
# Copy new token
# Update ~/.instagram_env with new token
# Commit and deploy
```

The script can automatically refresh tokens using APP_ID and APP_SECRET, but currently we're using the simpler approach of generating new tokens manually.

---

## Database Schema

### Tables

**`ig_accounts`** - Instagram account configuration
- Stores credentials, token, sync timestamps

**`daily_snapshots`** - Daily account stats
- Followers, posts count, biography tracking over time

**`ig_posts`** - Individual posts metadata
- Post ID, type, caption, permalink, posted timestamp

**`post_metrics`** - Time-series engagement data
- Likes, comments, saves, reach, impressions (measured multiple times per day)

**`post_velocity`** - Engagement growth rate
- How fast posts are getting engagement (per hour)

**`hashtag_performance`** - Hashtag analytics
- Which hashtags drive the most engagement

**`content_type_analytics`** - Performance by media type
- Carousels vs reels vs static images (aggregated)

**`topic_performance`** - Performance by content theme
- For FactsMind to understand what topics resonate

**`daily_insights`** - Daily summary views
- Best/worst posts, total engagement, growth

### Views (For FactsMind Consumption)

**`account_current_stats`**
- Latest follower count, growth, posting activity

**`top_posts_30d`**
- Top 5 posts from last month with full metrics

**`content_strategy_insights`**
- Performance aggregated by media type for strategy decisions

---

## How FactsMind Uses This Data

### 1. Content Type Decision

```sql
-- FactsMind queries this
SELECT media_type, avg_engagement_rate, avg_saves, save_rate_percent
FROM social_analytics.content_strategy_insights
ORDER BY avg_engagement_rate DESC;

-- Result tells FactsMind:
-- "Carousels get 3.2% engagement rate"
-- "Reels get 2.1% engagement rate"
-- "Focus on carousels"
```

### 2. Topic Strategy

```sql
-- What topics perform best?
SELECT topic, avg_engagement_rate, post_count
FROM social_analytics.topic_performance
WHERE post_count > 5
ORDER BY avg_engagement_rate DESC;
```

### 3. Hashtag Recommendations

```sql
-- Which hashtags to use?
SELECT hashtag, avg_engagement_rate, avg_reach
FROM social_analytics.hashtag_performance
WHERE post_count > 2
ORDER BY avg_engagement_rate DESC
LIMIT 5;
```

### 4. Posting Time Optimization

```sql
-- When to post?
SELECT best_posting_hour FROM social_analytics.topic_performance
WHERE topic = 'Science'
LIMIT 1;

-- Result: "Post at 6 PM for Science content"
```

---

## Python Integration (For FactsMind App)

### Getting Latest Insights

```python
from src.social_analytics.instagram_client import InstagramDatabaseManager
from src.social_analytics.metrics_engine import MetricsEngine

# Connect to Nexus
db = InstagramDatabaseManager(
    db_host="100.122.207.23",  # Pi's IP
    db_user="faceless",
    db_password="<postgres-password>",
    db_name="nexus_system"
)
db.connect()

# Get latest account stats
account_data = db.get_latest_account_data(account_id=1)

# Get top posts
top_posts = db.get_top_posts_30d(account_id=1, limit=5)

# Get strategy insights
insights = db.get_content_strategy_insights(account_id=1)

# Generate context for Claude/Gemini AI
context = MetricsEngine.generate_content_context(top_posts, account_data)

# Use in prompt:
# "Based on Instagram data, here's what works: {json.dumps(context)}"
```

---

## Troubleshooting

### "Token invalid" Error

**Cause:** Token expires after 60 days or has been revoked

**Fix:**
1. Generate a new token from Meta Developer Portal
2. Update `INSTAGRAM_ACCESS_TOKEN` in Pi's `~/.bashrc`
3. Re-run sync script

### "No data appearing in database"

**Checklist:**
1. Verify token is valid: `~/ssh-nexus 'curl -s https://graph.instagram.com/debug_token?access_token=YOUR_TOKEN'`
2. Check sync logs: `~/ssh-nexus 'tail -f /var/log/nexus-social-sync.log'`
3. Verify schema deployed: `~/ssh-nexus 'docker exec nexus-postgres psql -U faceless -d nexus_system -c "SELECT table_name FROM information_schema.tables WHERE table_schema='social_analytics';"'`

### Too Few Posts Being Synced

**Cause:** Script fetches only last 25 posts

**Fix:** Modify `nexus-social-sync.sh` line 68:
```bash
posts_json=$(get_recent_posts "$user_id" 100)  # Changed from 25
```

---

## Next Steps

1. ✅ Deploy schema to PostgreSQL
2. ✅ Set environment variables on Pi
3. ✅ Run sync script manually to test
4. ✅ Add to cron for daily collection
5. 🔄 **In FactsMind:** Integrate database queries into content strategy logic
6. 🔄 **Monitor:** Check `/var/log/nexus-social-sync.log` daily

---

## Related Documentation

- [Cron Setup](../operations/cron-setup.md) - How to schedule the sync
- [Helper Scripts](../operations/helper-scripts.md) - All Pi scripts
- [PostgreSQL Backups](../operations/maintenance.md) - How Instagram data is backed up

---

## Token Refresh Strategy

The access token we provided will work for **60 days**. Before it expires, you have two options:

### Option A: Manual Refresh (Every 60 Days)
1. Go to Meta Developer Portal
2. Generate new token
3. Update `INSTAGRAM_ACCESS_TOKEN` in `~/.bashrc`
4. Re-run sync script

### Option B: Automatic Refresh (Future)
We can enhance `instagram_client.py` with automatic token refresh logic that calls the refresh endpoint before expiration.

---

**Last Updated:** 2025-11-25
**Status:** Ready for deployment
