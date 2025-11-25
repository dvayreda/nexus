#!/usr/bin/env bash
# nexus-social-sync.sh - Sync Instagram data daily for FactsMind analysis
# Purpose: Collect Instagram metrics and store in Nexus PostgreSQL
# Usage: source ~/.instagram_env && ~/nexus-social-sync.sh
# Cron: 0 10 * * * source ~/.instagram_env && ~/nexus-social-sync.sh >> /var/log/nexus-social-sync.log 2>&1

set -euo pipefail

# Load Instagram credentials from env file
if [[ -f ~/.instagram_env ]]; then
    source ~/.instagram_env
fi

# Configuration (from environment)
INSTAGRAM_TOKEN="${INSTAGRAM_ACCESS_TOKEN:-}"
INSTAGRAM_APP_ID="${INSTAGRAM_APP_ID:-}"
INSTAGRAM_APP_SECRET="${INSTAGRAM_APP_SECRET:-}"
POSTGRES_CONTAINER="nexus-postgres"
POSTGRES_USER="faceless"
POSTGRES_DB="nexus_system"

# Logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $1" >&2
}

# ============================================
# INSTAGRAM API CALLS
# ============================================

# Function to make API request
instagram_api() {
    local endpoint="$1"
    local url="https://graph.instagram.com/v18.0${endpoint}"

    curl -s -X GET "${url}?access_token=${INSTAGRAM_TOKEN}"
}

# Get user info
get_user_info() {
    log "Fetching Instagram account info..."

    response=$(instagram_api "/me?fields=id,username,name,followers_count,following_count,media_count,biography,website,profile_picture_url,verified")

    echo "$response"
}

# Get recent posts
get_recent_posts() {
    local user_id="$1"
    local limit="${2:-25}"

    log "Fetching recent posts (limit: $limit)..."

    instagram_api "/${user_id}/media?fields=id,media_type,caption,media_url,permalink,timestamp,like_count,comments_count,shares_count&limit=${limit}"
}

# Get post insights
get_post_insights() {
    local post_id="$1"

    instagram_api "/${post_id}/insights?metric=engagement,impressions,reach,saved,video_views"
}

# ============================================
# DATABASE OPERATIONS
# ============================================

query_db() {
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -tAc "$1"
}

query_db_json() {
    docker exec -i "$POSTGRES_CONTAINER" psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" --json -c "$1"
}

# ============================================
# MAIN SYNC ROUTINE
# ============================================

main() {
    log "Starting Instagram social sync..."

    # Validate credentials
    if [[ -z "$INSTAGRAM_TOKEN" ]]; then
        log_error "INSTAGRAM_ACCESS_TOKEN not set in environment"
        exit 1
    fi

    # Get user info
    user_info=$(get_user_info)

    if echo "$user_info" | grep -q "error"; then
        log_error "Failed to fetch user info: $(echo "$user_info" | jq -r '.error.message // "Unknown error"')"
        exit 1
    fi

    # Extract data
    user_id=$(echo "$user_info" | jq -r '.id')
    username=$(echo "$user_info" | jq -r '.username')
    followers=$(echo "$user_info" | jq -r '.followers_count')
    following=$(echo "$user_info" | jq -r '.following_count')
    media_count=$(echo "$user_info" | jq -r '.media_count')

    log "Account: $username | Followers: $followers | Posts: $media_count"

    # Store account config and get account_id
    account_id=$(query_db "
        INSERT INTO social_analytics.ig_accounts 
        (username, ig_user_id, access_token, app_id, token_expires_at, last_synced)
        VALUES ('$username', $user_id, '$INSTAGRAM_TOKEN', '$INSTAGRAM_APP_ID', NOW() + INTERVAL '60 days', NOW())
        ON CONFLICT (username) DO UPDATE SET 
            access_token = '$INSTAGRAM_TOKEN',
            last_synced = NOW(),
            token_expires_at = NOW() + INTERVAL '60 days'
        RETURNING id;
    " | tr -d '\r')

    if [[ -z "$account_id" ]]; then
        log_error "Failed to store account config"
        exit 1
    fi

    log "Account ID: $account_id"

    # Store daily snapshot
    query_db "
        INSERT INTO social_analytics.daily_snapshots
        (account_id, snapshot_date, followers_count, following_count, media_count, biography, verified)
        VALUES ($account_id, NOW()::DATE, $followers, $following, $media_count, 
                'Synced on $(date)', ${user_info | jq -r '.verified // false'})
        ON CONFLICT (account_id, snapshot_date) DO UPDATE SET
            followers_count = $followers,
            following_count = $following,
            media_count = $media_count
    "

    log "Daily snapshot stored"

    # Get recent posts (last 25)
    posts_json=$(get_recent_posts "$user_id" 25)

    if echo "$posts_json" | grep -q "error"; then
        log_error "Failed to fetch posts"
        exit 1
    fi

    # Process each post
    post_count=$(echo "$posts_json" | jq '.data | length')
    log "Processing $post_count posts..."

    for i in $(seq 0 $((post_count - 1))); do
        post=$(echo "$posts_json" | jq ".data[$i]")
        post_id=$(echo "$post" | jq -r '.id')
        post_type=$(echo "$post" | jq -r '.media_type')
        caption=$(echo "$post" | jq -r '.caption // "No caption"' | sed "s/'/''/g")
        timestamp=$(echo "$post" | jq -r '.timestamp')
        permalink=$(echo "$post" | jq -r '.permalink')

        # Store post
        post_db_id=$(query_db "
            INSERT INTO social_analytics.ig_posts
            (account_id, ig_post_id, media_type, caption, permalink, posted_at)
            VALUES ($account_id, $post_id, '$post_type', '$caption', '$permalink', '$timestamp')
            ON CONFLICT (ig_post_id) DO UPDATE SET
                caption = '$caption',
                updated_at = NOW()
            RETURNING id;
        " | tr -d '\r')

        # Get post insights
        insights=$(get_post_insights "$post_id")

        # Extract metrics from insights
        likes=$(echo "$insights" | jq '.data[] | select(.name=="engagement") | .values[0].value // 0' | head -1)
        reach=$(echo "$insights" | jq '.data[] | select(.name=="reach") | .values[0].value // 0' | head -1)
        impressions=$(echo "$insights" | jq '.data[] | select(.name=="impressions") | .values[0].value // 0' | head -1)
        saved=$(echo "$insights" | jq '.data[] | select(.name=="saved") | .values[0].value // 0' | head -1)

        # Use direct counts as fallback
        likes=${likes:-$(echo "$post" | jq -r '.like_count // 0')}
        comments=$(echo "$post" | jq -r '.comments_count // 0')
        shares=$(echo "$post" | jq -r '.shares_count // 0')

        # Store metrics
        query_db "
            INSERT INTO social_analytics.post_metrics
            (post_id, measured_at, likes_count, comments_count, shares_count, saves_count, reach, impressions)
            VALUES ($post_db_id, NOW(), $likes, $comments, $shares, $saved, $reach, $impressions)
            ON CONFLICT (post_id, measured_at) DO UPDATE SET
                likes_count = $likes,
                comments_count = $comments,
                shares_count = $shares,
                saves_count = $saved,
                reach = $reach,
                impressions = $impressions
        "

        log "  ✓ Post $post_id: $post_type | Likes: $likes | Reach: $reach"
    done

    log "Instagram sync complete!"
    log "Data available for FactsMind analysis in social_analytics schema"
}

# Run main function
main "$@"
