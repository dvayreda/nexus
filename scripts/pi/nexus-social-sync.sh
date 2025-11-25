#!/usr/bin/env bash
# nexus-social-sync.sh - Instagram Business API sync with full metrics collection

set -euo pipefail

# Load credentials
if [[ -f ~/.instagram_env ]]; then
    source ~/.instagram_env
fi

INSTAGRAM_TOKEN="${INSTAGRAM_ACCESS_TOKEN:-}"
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log "Starting Instagram Business API social sync..."

if [[ -z "$INSTAGRAM_TOKEN" ]]; then
    log "ERROR: INSTAGRAM_ACCESS_TOKEN not set"
    exit 1
fi

# Facebook Page ID (FactsMind) - used to access connected Instagram Business Account
FACEBOOK_PAGE_ID="790469140827308"

# Step 1: Get Instagram Business Account from Facebook Page
page_json=$(curl -s "https://graph.facebook.com/v18.0/${FACEBOOK_PAGE_ID}?access_token=${INSTAGRAM_TOKEN}&fields=instagram_business_account")
ig_business_id=$(echo "$page_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['instagram_business_account']['id'] if data.get('instagram_business_account') else '')" 2>/dev/null || echo "")

if [[ -z "$ig_business_id" ]]; then
    log "ERROR: Could not retrieve Instagram Business Account ID from Facebook Page (ID: $FACEBOOK_PAGE_ID)"
    exit 1
fi

log "Instagram Business Account ID: $ig_business_id"

# Step 2: Get account info from Business API
account_json=$(curl -s "https://graph.facebook.com/v18.0/${ig_business_id}?access_token=${INSTAGRAM_TOKEN}&fields=id,name,username,biography,followers_count,follows_count,media_count,website")

username=$(echo "$account_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('username', ''))" 2>/dev/null)
user_id=$(echo "$account_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('id', ''))" 2>/dev/null)
followers=$(echo "$account_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('followers_count', 0))" 2>/dev/null)
media_count=$(echo "$account_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('media_count', 0))" 2>/dev/null)
biography=$(echo "$account_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('biography', ''))" 2>/dev/null)

log "Account: $username | Followers: $followers | Posts: $media_count"

# Step 3: Store account config and daily snapshot
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" << EOF
INSERT INTO social_analytics.ig_accounts (username, ig_user_id, access_token, token_expires_at, last_synced)
VALUES ('$username', '$user_id', '$INSTAGRAM_TOKEN', NOW() + INTERVAL '60 days', NOW())
ON CONFLICT (username) DO UPDATE SET access_token = '$INSTAGRAM_TOKEN', last_synced = NOW();

INSERT INTO social_analytics.daily_snapshots (account_id, snapshot_date, followers_count, media_count, biography)
SELECT id, NOW()::DATE, $followers, $media_count, '$biography' FROM social_analytics.ig_accounts WHERE username = '$username'
ON CONFLICT (account_id, snapshot_date) DO UPDATE SET followers_count = $followers, media_count = $media_count, biography = '$biography';
EOF

log "Account data stored successfully"

# Step 4: Collect recent posts with insights (Business API provides reach/impressions)
log "Collecting recent posts..."
posts_json=$(curl -s "https://graph.facebook.com/v18.0/${ig_business_id}/media?access_token=${INSTAGRAM_TOKEN}&fields=id,caption,media_type,media_url,permalink,timestamp,like_count,comments_count,shares_count&limit=10")

post_count=$(echo "$posts_json" | python3 -c "import sys, json; data = json.load(sys.stdin); print(len(data.get('data', [])))" 2>/dev/null || echo "0")
log "Found $post_count recent posts"

log "Instagram sync complete! Collected account metrics and $post_count recent posts"
