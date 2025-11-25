---
title: Nexus Instagram Analytics Integration
version: 1.0
last_updated: 2025-11-25
purpose: Track Instagram performance for FactsMind content strategy
---

# Instagram Analytics Integration

**Purpose:** Collect and analyze Instagram performance data to inform FactsMind content strategy decisions.

**Architecture:** Nexus (infrastructure) collects data → PostgreSQL storage → FactsMind (app) consumes insights

---

## Quick Start

### Prerequisites

1. **Instagram Creator Account** ✅
2. **Meta Access Token** (🔴 **Needs valid token** - current token rejected by API)
3. **Instagram App ID** (optional for now)
4. **Instagram App Secret** (optional for now)

### Setup (5 minutes)

#### Step 1: Deploy Database Schema

```bash
# SSH to Pi
~/ssh-nexus

# Deploy schema
docker exec -i nexus-postgres psql -U faceless -d nexus_system < /home/didac/nexus/infra/social_schema.sql
```

#### Step 2: Add Environment Variables to Pi

Create `.instagram_env` file with credentials:

```bash
# SSH to Pi
~/ssh-nexus

# The file is already created at ~/.instagram_env
# Edit it with your valid credentials:
nano ~/.instagram_env
```

File contents:
```bash
export INSTAGRAM_ACCESS_TOKEN="YOUR_VALID_TOKEN_HERE"
export INSTAGRAM_APP_ID="your-app-id"
export INSTAGRAM_APP_SECRET="your-app-secret"
```

**How to get a valid token:**
1. Go to https://developers.facebook.com
2. Select your app
3. Go to **Tools** → **Graph API Explorer**
4. Select your Instagram app from dropdown
5. Click **"Generate Access Token"**
6. Ensure permissions include: `instagram_basic`, `instagram_manage_insights`
7. Copy the full token

#### Step 3: Deploy Sync Script

```bash
# Copy to Pi
scp scripts/pi/nexus-social-sync.sh didac@100.122.207.23:~/nexus-social-sync.sh

# Make executable
~/ssh-nexus 'chmod +x ~/nexus-social-sync.sh'
```

#### Step 3: Test Token Validity

Before running the sync, verify your token works:

```bash
# SSH to Pi and test
TOKEN="YOUR_TOKEN_HERE"
curl -s "https://graph.instagram.com/v18.0/me?access_token=${TOKEN}&fields=id,username,followers_count"

# Should return your account info, not an error
```

#### Step 4: Run Sync Script

```bash
# SSH to Pi
~/ssh-nexus

# Run manually (load env first)
source ~/.instagram_env && ~/nexus-social-sync.sh

# Should output:
# Starting Instagram social sync...
# Account: [your_username] | Followers: XXXX | Posts: XXX
# Processing XX posts...
# Instagram sync complete!
```

#### Step 5: Add Cron Job

Once working manually, schedule it:

```bash
# Add to crontab (daily at 10 AM)
~/ssh-nexus '(crontab -l 2>/dev/null | grep -v nexus-social-sync; echo "0 10 * * * source ~/.instagram_env && ~/nexus-social-sync.sh >> /var/log/nexus-social-sync.log 2>&1") | crontab -'
```

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
