"""Instagram Graph API Client for Nexus

Handles authentication, data collection, and token refresh for Instagram.
"""

import os
import json
import requests
from datetime import datetime, timedelta
from typing import Dict, List, Optional
import psycopg2
from psycopg2.extras import RealDictCursor


class InstagramClient:
    """Instagram Graph API client with automatic token refresh"""

    BASE_URL = "https://graph.instagram.com/v18.0"

    def __init__(self, access_token: str, app_id: str, app_secret: str):
        """
        Initialize Instagram client

        Args:
            access_token: Instagram user access token
            app_id: Meta app ID
            app_secret: Meta app secret
        """
        self.access_token = access_token
        self.app_id = app_id
        self.app_secret = app_secret
        self.ig_user_id = None
        self.username = None

    def refresh_long_lived_token(self) -> str:
        """
        Exchange short-lived token for long-lived token (60 days)

        Returns:
            New long-lived access token
        """
        url = f"{self.BASE_URL}/oauth/access_token"
        params = {
            "grant_type": "ig_refresh_access_token",
            "access_token": self.access_token,
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            if "access_token" in data:
                self.access_token = data["access_token"]
                return self.access_token
            else:
                raise Exception(f"Token refresh failed: {data.get('error', 'Unknown error')}")
        except Exception as e:
            raise Exception(f"Instagram API error during token refresh: {str(e)}")

    def get_user_info(self) -> Dict:
        """
        Get authenticated user's Instagram account info

        Returns:
            Dict with user_id, username, and account info
        """
        url = f"{self.BASE_URL}/me"
        params = {
            "fields": "id,username,name,biography,website,profile_picture_url,followers_count,following_count,media_count,ig_id",
            "access_token": self.access_token,
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()

            self.ig_user_id = data.get("id")
            self.username = data.get("username")

            return data
        except Exception as e:
            raise Exception(f"Failed to get user info: {str(e)}")

    def get_recent_posts(self, limit: int = 10) -> List[Dict]:
        """
        Get user's recent posts with metrics

        Args:
            limit: Number of posts to fetch

        Returns:
            List of post dictionaries with engagement metrics
        """
        if not self.ig_user_id:
            self.get_user_info()

        url = f"{self.BASE_URL}/{self.ig_user_id}/media"
        params = {
            "fields": "id,media_type,media_product_type,caption,media_url,permalink,timestamp,like_count,comments_count,shares_count,ig_reels_aggregated_stats",
            "limit": limit,
            "access_token": self.access_token,
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json().get("data", [])
        except Exception as e:
            raise Exception(f"Failed to get recent posts: {str(e)}")

    def get_post_insights(self, post_id: str) -> Dict:
        """
        Get detailed insights for a specific post

        Args:
            post_id: Instagram post ID

        Returns:
            Dict with engagement metrics
        """
        url = f"{self.BASE_URL}/{post_id}/insights"
        params = {
            "metric": "engagement,impressions,reach,saved,video_views",
            "access_token": self.access_token,
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json()
        except Exception as e:
            raise Exception(f"Failed to get post insights: {str(e)}")

    def get_account_insights(self, metric: str = "impressions,reach,follower_count") -> List[Dict]:
        """
        Get account-level insights

        Args:
            metric: Comma-separated metrics to fetch

        Returns:
            List of insight dictionaries
        """
        if not self.ig_user_id:
            self.get_user_info()

        url = f"{self.BASE_URL}/{self.ig_user_id}/insights"
        params = {
            "metric": metric,
            "period": "day",
            "access_token": self.access_token,
        }

        try:
            response = requests.get(url, params=params)
            response.raise_for_status()
            return response.json().get("data", [])
        except Exception as e:
            raise Exception(f"Failed to get account insights: {str(e)}")

    def validate_token(self) -> bool:
        """
        Validate that the access token is still valid

        Returns:
            True if token is valid, False otherwise
        """
        try:
            url = f"{self.BASE_URL}/debug_token"
            params = {
                "input_token": self.access_token,
                "access_token": self.access_token,
            }
            response = requests.get(url, params=params)
            response.raise_for_status()
            data = response.json()
            return data.get("data", {}).get("is_valid", False)
        except Exception as e:
            print(f"Token validation error: {str(e)}")
            return False


class InstagramDatabaseManager:
    """Manages Instagram data storage in PostgreSQL"""

    def __init__(self, db_host: str, db_user: str, db_password: str, db_name: str):
        """
        Initialize database manager

        Args:
            db_host: PostgreSQL host
            db_user: PostgreSQL user
            db_password: PostgreSQL password
            db_name: Database name
        """
        self.db_host = db_host
        self.db_user = db_user
        self.db_password = db_password
        self.db_name = db_name
        self.connection = None

    def connect(self):
        """Connect to PostgreSQL"""
        try:
            self.connection = psycopg2.connect(
                host=self.db_host,
                user=self.db_user,
                password=self.db_password,
                database=self.db_name,
            )
        except Exception as e:
            raise Exception(f"Database connection failed: {str(e)}")

    def disconnect(self):
        """Disconnect from PostgreSQL"""
        if self.connection:
            self.connection.close()

    def store_account_config(
        self,
        username: str,
        ig_user_id: int,
        access_token: str,
        app_id: str,
        app_secret: str,
    ) -> int:
        """
        Store or update Instagram account configuration

        Returns:
            Account ID in database
        """
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)

        try:
            cursor.execute(
                """
                INSERT INTO social_analytics.ig_accounts 
                (username, ig_user_id, access_token, app_id, app_secret, token_expires_at)
                VALUES (%s, %s, %s, %s, %s, %s)
                ON CONFLICT (username) DO UPDATE SET
                    access_token = EXCLUDED.access_token,
                    token_expires_at = NOW() + INTERVAL '60 days'
                RETURNING id;
                """,
                (
                    username,
                    ig_user_id,
                    access_token,
                    app_id,
                    app_secret,
                    datetime.now() + timedelta(days=60),
                ),
            )
            account_id = cursor.fetchone()["id"]
            self.connection.commit()
            return account_id
        except Exception as e:
            self.connection.rollback()
            raise Exception(f"Failed to store account config: {str(e)}")
        finally:
            cursor.close()

    def store_daily_snapshot(self, account_id: int, user_data: Dict):
        """
        Store daily account snapshot (followers, posts count, etc)

        Args:
            account_id: Account ID in database
            user_data: User info from Instagram API
        """
        cursor = self.connection.cursor()

        try:
            cursor.execute(
                """
                INSERT INTO social_analytics.daily_snapshots
                (account_id, snapshot_date, followers_count, following_count, media_count, verified, biography)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (account_id, snapshot_date) DO UPDATE SET
                    followers_count = EXCLUDED.followers_count,
                    following_count = EXCLUDED.following_count,
                    media_count = EXCLUDED.media_count
                """,
                (
                    account_id,
                    datetime.now().date(),
                    user_data.get("followers_count"),
                    user_data.get("following_count"),
                    user_data.get("media_count"),
                    user_data.get("verified", False),
                    user_data.get("biography"),
                ),
            )
            self.connection.commit()
        except Exception as e:
            self.connection.rollback()
            raise Exception(f"Failed to store daily snapshot: {str(e)}")
        finally:
            cursor.close()

    def store_post(self, account_id: int, post_data: Dict) -> int:
        """
        Store Instagram post metadata

        Args:
            account_id: Account ID in database
            post_data: Post data from Instagram API

        Returns:
            Post ID in database
        """
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)

        try:
            cursor.execute(
                """
                INSERT INTO social_analytics.ig_posts
                (account_id, ig_post_id, media_type, caption, media_url, permalink, posted_at)
                VALUES (%s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (ig_post_id) DO UPDATE SET
                    caption = EXCLUDED.caption,
                    updated_at = NOW()
                RETURNING id;
                """,
                (
                    account_id,
                    post_data.get("id"),
                    post_data.get("media_type"),
                    post_data.get("caption"),
                    post_data.get("media_url"),
                    post_data.get("permalink"),
                    post_data.get("timestamp"),
                ),
            )
            post_id = cursor.fetchone()["id"]
            self.connection.commit()
            return post_id
        except Exception as e:
            self.connection.rollback()
            raise Exception(f"Failed to store post: {str(e)}")
        finally:
            cursor.close()

    def store_post_metrics(self, post_id: int, metrics: Dict):
        """
        Store post engagement metrics (time-series)

        Args:
            post_id: Post ID in database
            metrics: Engagement metrics
        """
        cursor = self.connection.cursor()

        try:
            cursor.execute(
                """
                INSERT INTO social_analytics.post_metrics
                (post_id, measured_at, likes_count, comments_count, shares_count, saves_count, reach, impressions)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
                ON CONFLICT (post_id, measured_at) DO UPDATE SET
                    likes_count = EXCLUDED.likes_count,
                    comments_count = EXCLUDED.comments_count,
                    saves_count = EXCLUDED.saves_count,
                    reach = EXCLUDED.reach,
                    impressions = EXCLUDED.impressions
                """,
                (
                    post_id,
                    datetime.now(),
                    metrics.get("likes"),
                    metrics.get("comments"),
                    metrics.get("shares"),
                    metrics.get("saves"),
                    metrics.get("reach"),
                    metrics.get("impressions"),
                ),
            )
            self.connection.commit()
        except Exception as e:
            self.connection.rollback()
            raise Exception(f"Failed to store post metrics: {str(e)}")
        finally:
            cursor.close()

    def get_latest_account_data(self, account_id: int) -> Dict:
        """Get latest account stats for FactsMind"""
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)

        try:
            cursor.execute(
                """
                SELECT * FROM social_analytics.account_current_stats
                WHERE ig_user_id = (
                    SELECT ig_user_id FROM social_analytics.ig_accounts WHERE id = %s
                )
                LIMIT 1
                """,
                (account_id,),
            )
            return cursor.fetchone() or {}
        finally:
            cursor.close()

    def get_top_posts_30d(self, account_id: int, limit: int = 5) -> List[Dict]:
        """Get top performing posts from last 30 days"""
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)

        try:
            cursor.execute(
                """
                SELECT * FROM social_analytics.top_posts_30d
                WHERE ig_post_id IN (
                    SELECT ig_post_id FROM social_analytics.ig_posts 
                    WHERE account_id = %s
                )
                LIMIT %s
                """,
                (account_id, limit),
            )
            return cursor.fetchall()
        finally:
            cursor.close()

    def get_content_strategy_insights(self, account_id: int) -> List[Dict]:
        """Get content type performance for strategy decisions"""
        cursor = self.connection.cursor(cursor_factory=RealDictCursor)

        try:
            cursor.execute(
                """
                SELECT * FROM social_analytics.content_strategy_insights
                """
            )
            return cursor.fetchall()
        finally:
            cursor.close()
