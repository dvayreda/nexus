"""Nexus Social Analytics Module

Provides Instagram data collection and analysis for content strategy.
Used by FactsMind AI to optimize content based on performance metrics.
"""

from .instagram_client import InstagramClient
from .metrics_engine import MetricsEngine

__all__ = ["InstagramClient", "MetricsEngine"]
