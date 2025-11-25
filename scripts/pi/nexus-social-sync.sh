#!/usr/bin/env bash
# nexus-social-sync.sh - Minimal sync for Instagram Product API

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

log "Starting Instagram social sync..."

if [[ -z "$INSTAGRAM_TOKEN" ]]; then
    log "ERROR: INSTAGRAM_ACCESS_TOKEN not set"
    exit 1
fi

# Get account info
account_json=$(curl -s "https://graph.instagram.com/v18.0/me?access_token=${INSTAGRAM_TOKEN}&fields=id,username,followers_count,media_count")

username=$(echo "$account_json" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
user_id=$(echo "$account_json" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
followers=$(echo "$account_json" | grep -o '"followers_count":[0-9]*' | cut -d':' -f2)
media_count=$(echo "$account_json" | grep -o '"media_count":[0-9]*' | cut -d':' -f2)

log "Account: $username | Followers: $followers | Posts: $media_count"

# Store account
docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" << EOF
INSERT INTO social_analytics.ig_accounts (username, ig_user_id, access_token, token_expires_at, last_synced)
VALUES ('$username', $user_id, '$INSTAGRAM_TOKEN', NOW() + INTERVAL '60 days', NOW())
ON CONFLICT (username) DO UPDATE SET access_token = '$INSTAGRAM_TOKEN', last_synced = NOW();

INSERT INTO social_analytics.daily_snapshots (account_id, snapshot_date, followers_count, media_count)
SELECT id, NOW()::DATE, $followers, $media_count FROM social_analytics.ig_accounts WHERE username = '$username'
ON CONFLICT (account_id, snapshot_date) DO UPDATE SET followers_count = $followers, media_count = $media_count;
EOF

log "Data stored successfully"
log "Instagram sync complete!"
