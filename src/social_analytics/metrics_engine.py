"""Metrics Calculation Engine for Instagram Data

Computes derived metrics and generates insights for FactsMind AI.
"""

from typing import Dict, List
from datetime import datetime, timedelta
import json


class MetricsEngine:
    """Calculates derived metrics from raw Instagram data"""

    @staticmethod
    def calculate_engagement_rate(likes: int, reach: int) -> float:
        """
        Calculate engagement rate (likes per reach)

        Args:
            likes: Number of likes
            reach: Number of people who saw the post

        Returns:
            Engagement rate as percentage
        """
        if reach == 0:
            return 0.0
        return round((likes / reach) * 100, 2)

    @staticmethod
    def calculate_save_rate(saves: int, reach: int) -> float:
        """
        Save rate is a strong quality signal (people want to keep it)

        Args:
            saves: Number of saves
            reach: Number of people who saw the post

        Returns:
            Save rate as percentage
        """
        if reach == 0:
            return 0.0
        return round((saves / reach) * 100, 2)

    @staticmethod
    def calculate_comment_rate(comments: int, reach: int) -> float:
        """
        Comment rate (engagement quality indicator)

        Args:
            comments: Number of comments
            reach: Number of people who saw the post

        Returns:
            Comment rate as percentage
        """
        if reach == 0:
            return 0.0
        return round((comments / reach) * 100, 2)

    @staticmethod
    def calculate_total_engagement(likes: int, comments: int, saves: int, shares: int) -> int:
        """
        Total engagement score (sum of all interactions)

        Args:
            likes: Likes count
            comments: Comments count
            saves: Saves count
            shares: Shares count

        Returns:
            Total engagement
        """
        return likes + comments + saves + (shares or 0)

    @staticmethod
    def calculate_velocity(
        current_metric: int, previous_metric: int, time_hours: float
    ) -> float:
        """
        Calculate growth velocity (metric per hour)

        Args:
            current_metric: Current metric value
            previous_metric: Previous metric value
            time_hours: Hours elapsed

        Returns:
            Metric increase per hour
        """
        if time_hours == 0:
            return 0.0
        return round((current_metric - previous_metric) / time_hours, 2)

    @staticmethod
    def generate_content_context(top_posts: List[Dict], account_stats: Dict) -> Dict:
        """
        Generate a JSON context object for FactsMind AI

        This object tells FactsMind what content types perform best,
        what topics resonate, etc.

        Args:
            top_posts: List of top performing posts (last 30 days)
            account_stats: Latest account statistics

        Returns:
            JSON-serializable context dict
        """
        if not top_posts:
            return {
                "status": "insufficient_data",
                "message": "Not enough historical data yet",
            }

        # Analyze top posts
        avg_reach = sum(p.get("reach", 0) for p in top_posts) / len(top_posts)
        avg_saves = sum(p.get("saves", 0) for p in top_posts) / len(top_posts)
        avg_engagement_rate = sum(
            MetricsEngine.calculate_engagement_rate(
                p.get("likes", 0), p.get("reach", 1)
            )
            for p in top_posts
        ) / len(top_posts)

        # Extract hashtags from captions (if available)
        all_hashtags = []
        for post in top_posts:
            caption = post.get("caption", "")
            hashtags = [tag.strip() for tag in caption.split() if tag.startswith("#")]
            all_hashtags.extend(hashtags)

        # Most used hashtags
        hashtag_counts = {}
        for tag in all_hashtags:
            hashtag_counts[tag] = hashtag_counts.get(tag, 0) + 1

        top_hashtags = sorted(hashtag_counts.items(), key=lambda x: x[1], reverse=True)[
            :5
        ]

        return {
            "status": "ready",
            "generated_at": datetime.now().isoformat(),
            "account": {
                "followers": account_stats.get("followers_count"),
                "follower_growth_24h": account_stats.get("followers_gained_today", 0),
                "total_posts": account_stats.get("media_count"),
            },
            "performance": {
                "average_reach_per_post": round(avg_reach, 0),
                "average_saves_per_post": round(avg_saves, 0),
                "average_engagement_rate": round(avg_engagement_rate, 2),
            },
            "top_hashtags": [tag[0] for tag in top_hashtags],
            "insights": [
                f"Your posts reach an average of {round(avg_reach, 0)} people",
                f"Average save rate is {MetricsEngine.calculate_save_rate(round(avg_saves), round(avg_reach)):.2f}% - people want to keep these posts",
                f"Most effective hashtags: {', '.join([tag[0] for tag in top_hashtags[:3]])}",
                f"You've gained {account_stats.get('followers_gained_today', 0)} followers in the last day",
            ],
            "recommendations": [
                "Focus on content that generates high save rates (quality over viral)",
                "Use top-performing hashtags consistently",
                "Post during times when your audience is most active",
            ],
        }

    @staticmethod
    def generate_factsmind_brief(insights: Dict) -> str:
        """
        Generate a human-readable brief for FactsMind to use

        Args:
            insights: Insights dict from generate_content_context

        Returns:
            String brief for FactsMind
        """
        if insights.get("status") != "ready":
            return "Instagram data still loading. Check back in 24 hours."

        brief = f"""
📊 Instagram Performance Brief

**Account Status:**
- Followers: {insights['account']['followers']}
- Growth (24h): +{insights['account']['follower_growth_24h']}
- Total Posts: {insights['account']['total_posts']}

**What Works:**
- Avg Reach: {insights['performance']['average_reach_per_post']} people/post
- Engagement Rate: {insights['performance']['average_engagement_rate']}%
- Top Hashtags: {', '.join(insights['top_hashtags'])}

**Key Insights:**
{chr(10).join(['• ' + i for i in insights['insights']])}

**Next Steps:**
{chr(10).join(['→ ' + r for r in insights['recommendations']])}
"""
        return brief.strip()


class AnalyticsAggregator:
    """Aggregates metrics across multiple posts/periods"""

    @staticmethod
    def aggregate_by_media_type(posts: List[Dict]) -> Dict[str, Dict]:
        """
        Group performance metrics by media type

        Args:
            posts: List of posts with metrics

        Returns:
            Dict keyed by media_type with aggregated stats
        """
        by_type = {}

        for post in posts:
            media_type = post.get("media_type", "unknown")

            if media_type not in by_type:
                by_type[media_type] = {
                    "count": 0,
                    "total_likes": 0,
                    "total_reach": 0,
                    "total_saves": 0,
                    "total_comments": 0,
                }

            by_type[media_type]["count"] += 1
            by_type[media_type]["total_likes"] += post.get("likes", 0)
            by_type[media_type]["total_reach"] += post.get("reach", 0)
            by_type[media_type]["total_saves"] += post.get("saves", 0)
            by_type[media_type]["total_comments"] += post.get("comments", 0)

        # Calculate averages
        for media_type, stats in by_type.items():
            count = stats["count"]
            stats["avg_likes"] = round(stats["total_likes"] / count, 0)
            stats["avg_reach"] = round(stats["total_reach"] / count, 0)
            stats["avg_saves"] = round(stats["total_saves"] / count, 0)
            stats["avg_comments"] = round(stats["total_comments"] / count, 0)
            stats["avg_engagement_rate"] = MetricsEngine.calculate_engagement_rate(
                stats["avg_likes"], stats["avg_reach"]
            )

        return by_type

    @staticmethod
    def get_best_posting_time(posts: List[Dict]) -> str:
        """
        Determine best time of day to post (based on engagement)

        Args:
            posts: List of posts with timestamps and metrics

        Returns:
            Hour string (e.g., "9 AM", "6 PM")
        """
        by_hour = {}

        for post in posts:
            # Extract hour from posted_at timestamp
            try:
                posted_at = post.get("posted_at")
                if isinstance(posted_at, str):
                    posted_at = datetime.fromisoformat(posted_at.replace("Z", "+00:00"))

                hour = posted_at.hour
                if hour not in by_hour:
                    by_hour[hour] = {"count": 0, "total_engagement": 0}

                by_hour[hour]["count"] += 1
                engagement = post.get("likes", 0) + post.get("comments", 0)
                by_hour[hour]["total_engagement"] += engagement
            except Exception:
                continue

        if not by_hour:
            return "2 PM"  # Default

        # Find hour with highest avg engagement
        best_hour = max(
            by_hour.items(),
            key=lambda x: x[1]["total_engagement"] / x[1]["count"],
        )[0]

        am_pm = "AM" if best_hour < 12 else "PM"
        display_hour = best_hour if best_hour <= 12 else best_hour - 12

        return f"{display_hour} {am_pm}"
