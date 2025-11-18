# Comprehensive Token Usage Monitoring Guide

**Version:** 1.0
**Last Updated:** 2025-11-18
**Status:** Implementation Ready

---

## Table of Contents

1. [Overview](#overview)
2. [Token Monitoring Approaches](#token-monitoring-approaches)
3. [Architecture Patterns](#architecture-patterns)
4. [Implementation Strategies](#implementation-strategies)
5. [Database Schema](#database-schema)
6. [API Client Integration](#api-client-integration)
7. [Frontend Dashboard Design](#frontend-dashboard-design)
8. [Analytics & Reporting](#analytics--reporting)
9. [Cost Tracking](#cost-tracking)
10. [Alerting & Notifications](#alerting--notifications)
11. [Best Practices](#best-practices)

---

## Overview

### Why Monitor Token Usage?

Token usage monitoring is critical for:
- **Cost Control**: Track spending across multiple AI providers
- **Performance Optimization**: Identify inefficient prompts
- **Capacity Planning**: Forecast resource needs
- **Quality Analysis**: Correlate token usage with output quality
- **Budget Alerts**: Get notified before exceeding limits
- **A/B Testing**: Compare prompt strategies

### Current Nexus State

**Providers in Use:**
- Groq (llama-3.3-8b-8192) - Fact generation
- Gemini (gemini-2.5-flash) - Content expansion + images
- Claude (anthropic) - Declared but not actively used

**Current Gaps:**
- ❌ No token counting in API responses
- ❌ No cost tracking
- ❌ No usage analytics
- ❌ No monitoring dashboard

---

## Token Monitoring Approaches

### Approach 1: Response-Based Tracking (Recommended)

**Method:** Capture token counts directly from API responses

**Pros:**
- Most accurate (provider-reported)
- No estimation errors
- Includes all token types (input/output/system)
- Provider-specific optimizations visible

**Cons:**
- Requires API support
- Different response formats per provider

**Implementation:**
```python
# Groq example
response = client.chat.completions.create(...)
usage = {
    'prompt_tokens': response.usage.prompt_tokens,
    'completion_tokens': response.usage.completion_tokens,
    'total_tokens': response.usage.total_tokens,
    'model': response.model
}

# Gemini example
response = model.generate_content(...)
usage = {
    'prompt_tokens': response.usage_metadata.prompt_token_count,
    'completion_tokens': response.usage_metadata.candidates_token_count,
    'total_tokens': response.usage_metadata.total_token_count
}
```

### Approach 2: Tiktoken Estimation (Fallback)

**Method:** Pre-calculate tokens using tiktoken library

**Pros:**
- Works offline
- Predictable before API call
- Useful for budget checks

**Cons:**
- Estimation only (not exact)
- Requires model-specific tokenizers
- Doesn't capture provider optimizations

**Implementation:**
```python
import tiktoken

def estimate_tokens(text: str, model: str = "gpt-4") -> int:
    encoding = tiktoken.encoding_for_model(model)
    return len(encoding.encode(text))
```

### Approach 3: Character-Based Approximation (Quick & Dirty)

**Method:** Rough estimation using character counts

**Formula:**
- English: ~4 characters per token
- Code: ~3 characters per token
- Multilingual: ~5 characters per token

**Pros:**
- Zero dependencies
- Extremely fast
- Good for ballpark estimates

**Cons:**
- Very inaccurate (±30% error)
- Varies by language

**Use Cases:**
- Quick estimates in CLI tools
- Rough capacity planning
- Non-critical logging

### Approach 4: Hybrid Multi-Layer Tracking

**Method:** Combine all approaches for different purposes

**Strategy:**
1. **Pre-call:** Tiktoken estimation for budget checks
2. **Post-call:** Response-based actual tracking
3. **Logging:** Character approximation for quick debugging
4. **Analytics:** Response-based storage in database

**Best For:** Production systems requiring accuracy + debugging

---

## Architecture Patterns

### Pattern 1: Decorator-Based Tracking

**Use Case:** Minimal code changes, automatic tracking

```python
from functools import wraps
import time
from typing import Callable, Any
from dataclasses import dataclass

@dataclass
class APIMetrics:
    provider: str
    model: str
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    duration_seconds: float
    cost_usd: float
    timestamp: str

def track_tokens(provider: str):
    """Decorator to automatically track API token usage"""
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            start_time = time.time()

            # Execute API call
            response = func(*args, **kwargs)

            # Extract usage from response
            usage = extract_usage(provider, response)

            # Calculate cost
            cost = calculate_cost(provider, usage)

            # Log metrics
            metrics = APIMetrics(
                provider=provider,
                model=usage['model'],
                prompt_tokens=usage['prompt_tokens'],
                completion_tokens=usage['completion_tokens'],
                total_tokens=usage['total_tokens'],
                duration_seconds=time.time() - start_time,
                cost_usd=cost,
                timestamp=datetime.utcnow().isoformat()
            )

            # Store to database
            store_metrics(metrics)

            return response
        return wrapper
    return decorator

# Usage
@track_tokens('groq')
def generate_with_groq(prompt: str) -> str:
    response = groq_client.chat.completions.create(...)
    return response.choices[0].message.content
```

### Pattern 2: Context Manager Pattern

**Use Case:** Explicit tracking scope, better error handling

```python
from contextlib import contextmanager

@contextmanager
def track_api_call(provider: str, operation: str):
    """Context manager for tracking API calls"""
    start_time = time.time()
    metrics = {
        'provider': provider,
        'operation': operation,
        'start_time': start_time
    }

    try:
        yield metrics
    except Exception as e:
        metrics['error'] = str(e)
        raise
    finally:
        metrics['duration'] = time.time() - start_time
        store_metrics(metrics)

# Usage
with track_api_call('groq', 'fact_generation') as tracker:
    response = groq_client.chat.completions.create(...)
    tracker['tokens'] = response.usage.total_tokens
    tracker['cost'] = calculate_cost('groq', response.usage)
```

### Pattern 3: Observer Pattern

**Use Case:** Multiple monitoring systems, decoupled architecture

```python
from abc import ABC, abstractmethod
from typing import List

class MetricsObserver(ABC):
    @abstractmethod
    def on_api_call(self, metrics: dict):
        pass

class DatabaseLogger(MetricsObserver):
    def on_api_call(self, metrics: dict):
        db.insert('api_metrics', metrics)

class CostTracker(MetricsObserver):
    def on_api_call(self, metrics: dict):
        daily_total = get_daily_total() + metrics['cost']
        if daily_total > BUDGET_LIMIT:
            send_alert(f"Budget exceeded: ${daily_total}")

class PrometheusExporter(MetricsObserver):
    def on_api_call(self, metrics: dict):
        token_counter.inc(metrics['total_tokens'])
        cost_gauge.set(metrics['cost'])

class APIClient:
    def __init__(self):
        self.observers: List[MetricsObserver] = []

    def attach(self, observer: MetricsObserver):
        self.observers.append(observer)

    def notify(self, metrics: dict):
        for observer in self.observers:
            observer.on_api_call(metrics)

    def call_api(self, prompt: str):
        response = self._make_request(prompt)
        metrics = self._extract_metrics(response)
        self.notify(metrics)
        return response

# Usage
client = APIClient()
client.attach(DatabaseLogger())
client.attach(CostTracker())
client.attach(PrometheusExporter())
```

### Pattern 4: Event-Driven Streaming

**Use Case:** Real-time monitoring, high-volume systems

```python
import asyncio
from asyncio import Queue

class MetricsStream:
    def __init__(self):
        self.queue = Queue()
        self.subscribers = []

    async def publish(self, metrics: dict):
        await self.queue.put(metrics)

    async def process(self):
        while True:
            metrics = await self.queue.get()
            # Batch processing for efficiency
            await self.batch_insert_db(metrics)
            await self.update_realtime_dashboard(metrics)
            await self.check_alerts(metrics)

# Global stream
metrics_stream = MetricsStream()

# In API client
async def generate_text(prompt: str):
    response = await api_call(prompt)
    await metrics_stream.publish({
        'timestamp': time.time(),
        'tokens': response.usage.total_tokens,
        'cost': calculate_cost(response)
    })
    return response
```

---

## Implementation Strategies

### Strategy 1: Minimal Invasive (Quick Start)

**Timeline:** 1-2 hours
**Complexity:** Low
**Accuracy:** Medium

**Steps:**
1. Add simple logging to existing API clients
2. Use character-based estimation
3. Log to text files
4. Manual analysis

**Code:**
```python
# In api_clients/groq_client.py
def generate_text(prompt: str) -> str:
    response = self.client.chat.completions.create(...)

    # Simple logging
    with open('/var/log/nexus/tokens.log', 'a') as f:
        f.write(f"{datetime.now()}|groq|{len(prompt)}|{len(response.text)}\n")

    return response.choices[0].message.content
```

### Strategy 2: Database Integration (Production Ready)

**Timeline:** 4-8 hours
**Complexity:** Medium
**Accuracy:** High

**Steps:**
1. Create database schema (see below)
2. Implement response-based tracking
3. Add structured logging
4. Create basic SQL views for reporting

### Strategy 3: Full Observability Stack (Enterprise)

**Timeline:** 2-3 days
**Complexity:** High
**Accuracy:** Very High

**Components:**
- Structured logging (structlog)
- Time-series database (Prometheus/InfluxDB)
- Metrics aggregation (Grafana)
- Real-time dashboard (custom React/Vue app)
- Alerting (Telegram/Email)
- Cost forecasting (ML-based)

---

## Database Schema

### Core Tables

#### `api_calls` - Individual API Request Tracking

```sql
CREATE TABLE api_calls (
    id SERIAL PRIMARY KEY,

    -- Request identification
    request_id UUID DEFAULT gen_random_uuid(),
    correlation_id VARCHAR(100), -- Links to carousel_id or workflow_execution_id

    -- API details
    provider VARCHAR(50) NOT NULL, -- 'groq', 'gemini', 'claude', 'pexels'
    model VARCHAR(100),
    endpoint VARCHAR(200),

    -- Timing
    timestamp TIMESTAMPTZ DEFAULT NOW(),
    duration_ms INTEGER,

    -- Token metrics
    prompt_tokens INTEGER,
    completion_tokens INTEGER,
    total_tokens INTEGER,

    -- Cost tracking
    cost_usd DECIMAL(10, 6),
    rate_limit_remaining INTEGER,

    -- Request context
    operation VARCHAR(100), -- 'fact_generation', 'content_expansion', 'image_generation'
    user_id VARCHAR(100),

    -- Quality metrics (optional)
    success BOOLEAN DEFAULT TRUE,
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,

    -- Prompt tracking (for A/B testing)
    prompt_version VARCHAR(50),
    temperature DECIMAL(3, 2),
    max_tokens INTEGER,

    -- Indexes
    CONSTRAINT api_calls_provider_check CHECK (provider IN ('groq', 'gemini', 'claude', 'openai', 'pexels'))
);

CREATE INDEX idx_api_calls_timestamp ON api_calls(timestamp DESC);
CREATE INDEX idx_api_calls_provider ON api_calls(provider);
CREATE INDEX idx_api_calls_correlation ON api_calls(correlation_id);
CREATE INDEX idx_api_calls_operation ON api_calls(operation);
```

#### `daily_usage_summary` - Aggregated Daily Metrics

```sql
CREATE TABLE daily_usage_summary (
    id SERIAL PRIMARY KEY,
    date DATE NOT NULL,
    provider VARCHAR(50) NOT NULL,
    model VARCHAR(100),

    -- Aggregated metrics
    total_calls INTEGER DEFAULT 0,
    successful_calls INTEGER DEFAULT 0,
    failed_calls INTEGER DEFAULT 0,

    total_prompt_tokens BIGINT DEFAULT 0,
    total_completion_tokens BIGINT DEFAULT 0,
    total_tokens BIGINT DEFAULT 0,

    total_cost_usd DECIMAL(10, 2) DEFAULT 0.00,
    avg_tokens_per_call DECIMAL(10, 2),

    -- Performance
    avg_duration_ms INTEGER,
    p95_duration_ms INTEGER,

    -- Updated timestamp
    last_updated TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(date, provider, model)
);

CREATE INDEX idx_daily_summary_date ON daily_usage_summary(date DESC);
```

#### `cost_budgets` - Budget Management

```sql
CREATE TABLE cost_budgets (
    id SERIAL PRIMARY KEY,

    -- Budget scope
    period_type VARCHAR(20) NOT NULL, -- 'daily', 'weekly', 'monthly'
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- Limits
    budget_usd DECIMAL(10, 2) NOT NULL,
    warning_threshold_pct INTEGER DEFAULT 80, -- Alert at 80%

    -- Filtering (optional)
    provider VARCHAR(50), -- NULL = all providers
    operation VARCHAR(100), -- NULL = all operations

    -- Status
    current_spend_usd DECIMAL(10, 2) DEFAULT 0.00,
    alert_sent BOOLEAN DEFAULT FALSE,

    CONSTRAINT cost_budgets_period_check CHECK (period_type IN ('daily', 'weekly', 'monthly'))
);
```

#### `carousel_performance` - Content Performance Tracking

```sql
CREATE TABLE carousel_performance (
    id SERIAL PRIMARY KEY,
    carousel_id UUID UNIQUE NOT NULL,
    generated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Generation metrics
    total_time_seconds DECIMAL(10, 3),
    groq_time_seconds DECIMAL(10, 3),
    gemini_time_seconds DECIMAL(10, 3),
    rendering_time_seconds DECIMAL(10, 3),

    -- Quality scores (1-10 scale)
    fact_accuracy_score INTEGER CHECK (fact_accuracy_score BETWEEN 1 AND 10),
    brand_fit_score INTEGER CHECK (brand_fit_score BETWEEN 1 AND 10),
    engagement_score INTEGER CHECK (engagement_score BETWEEN 1 AND 10),

    -- API metrics (linked to api_calls)
    groq_tokens INTEGER,
    gemini_tokens INTEGER,
    claude_tokens INTEGER,
    total_cost_usd DECIMAL(10, 6),

    -- Instagram performance (manual or API)
    published_at TIMESTAMPTZ,
    likes INTEGER DEFAULT 0,
    comments INTEGER DEFAULT 0,
    shares INTEGER DEFAULT 0,
    saves INTEGER DEFAULT 0,
    reach INTEGER,
    impressions INTEGER,

    -- A/B testing
    prompt_version VARCHAR(50),
    template_version VARCHAR(50),

    -- Content metadata
    topic VARCHAR(200),
    fact_source VARCHAR(200),
    image_source VARCHAR(200) -- 'pexels', 'gemini', 'local'
);

CREATE INDEX idx_carousel_generated ON carousel_performance(generated_at DESC);
CREATE INDEX idx_carousel_performance ON carousel_performance(engagement_score DESC);
```

### SQL Views for Analytics

#### `v_hourly_usage` - Hourly Token Usage

```sql
CREATE VIEW v_hourly_usage AS
SELECT
    DATE_TRUNC('hour', timestamp) AS hour,
    provider,
    model,
    COUNT(*) AS calls,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS total_cost,
    AVG(duration_ms) AS avg_duration_ms
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY hour, provider, model
ORDER BY hour DESC;
```

#### `v_cost_by_operation` - Cost Breakdown by Operation

```sql
CREATE VIEW v_cost_by_operation AS
SELECT
    operation,
    provider,
    COUNT(*) AS total_calls,
    SUM(total_tokens) AS total_tokens,
    SUM(cost_usd) AS total_cost,
    AVG(cost_usd) AS avg_cost_per_call,
    SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 AS success_rate
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '30 days'
GROUP BY operation, provider
ORDER BY total_cost DESC;
```

#### `v_carousel_roi` - Content ROI Analysis

```sql
CREATE VIEW v_carousel_roi AS
SELECT
    carousel_id,
    generated_at,
    total_cost_usd AS production_cost,
    (likes + comments * 2 + shares * 3 + saves * 4) AS engagement_score,
    CASE
        WHEN total_cost_usd > 0 THEN
            (likes + comments * 2 + shares * 3 + saves * 4) / total_cost_usd
        ELSE 0
    END AS roi_score,
    prompt_version,
    topic
FROM carousel_performance
WHERE published_at IS NOT NULL
ORDER BY roi_score DESC;
```

### Database Migration Script

```sql
-- migrations/001_monitoring_schema.sql

BEGIN;

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Create tables
-- (paste table creation SQL from above)

-- Create views
-- (paste view creation SQL from above)

-- Create triggers for auto-aggregation
CREATE OR REPLACE FUNCTION update_daily_summary()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO daily_usage_summary (
        date, provider, model,
        total_calls, successful_calls, failed_calls,
        total_prompt_tokens, total_completion_tokens, total_tokens,
        total_cost_usd
    )
    VALUES (
        DATE(NEW.timestamp), NEW.provider, NEW.model,
        1, CASE WHEN NEW.success THEN 1 ELSE 0 END, CASE WHEN NEW.success THEN 0 ELSE 1 END,
        NEW.prompt_tokens, NEW.completion_tokens, NEW.total_tokens,
        NEW.cost_usd
    )
    ON CONFLICT (date, provider, model) DO UPDATE SET
        total_calls = daily_usage_summary.total_calls + 1,
        successful_calls = daily_usage_summary.successful_calls + CASE WHEN NEW.success THEN 1 ELSE 0 END,
        failed_calls = daily_usage_summary.failed_calls + CASE WHEN NEW.success THEN 0 ELSE 1 END,
        total_prompt_tokens = daily_usage_summary.total_prompt_tokens + NEW.prompt_tokens,
        total_completion_tokens = daily_usage_summary.total_completion_tokens + NEW.completion_tokens,
        total_tokens = daily_usage_summary.total_tokens + NEW.total_tokens,
        total_cost_usd = daily_usage_summary.total_cost_usd + NEW.cost_usd,
        last_updated = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_daily_summary
    AFTER INSERT ON api_calls
    FOR EACH ROW
    EXECUTE FUNCTION update_daily_summary();

COMMIT;
```

---

## API Client Integration

### Groq Client Enhancement

```python
# src/api_clients/groq_client.py

import structlog
from typing import Optional, Dict, Any
from datetime import datetime
import uuid

logger = structlog.get_logger()

class GroqClient:
    """Enhanced Groq client with comprehensive token tracking"""

    def __init__(self, api_key: str, db_connection=None):
        self.client = Groq(api_key=api_key)
        self.db = db_connection
        self.provider = "groq"

    def generate_text(
        self,
        prompt: str,
        model: str = "llama-3.3-70b-versatile",
        temperature: float = 0.7,
        max_tokens: int = 500,
        correlation_id: Optional[str] = None,
        operation: str = "fact_generation"
    ) -> tuple[str, Dict[str, Any]]:
        """
        Generate text with comprehensive token tracking

        Returns:
            tuple: (generated_text, metrics_dict)
        """
        request_id = str(uuid.uuid4())
        start_time = datetime.utcnow()

        # Log request
        logger.info(
            "groq_request_start",
            request_id=request_id,
            correlation_id=correlation_id,
            model=model,
            prompt_length=len(prompt),
            operation=operation
        )

        try:
            # Make API call
            response = self.client.chat.completions.create(
                messages=[{"role": "user", "content": prompt}],
                model=model,
                temperature=temperature,
                max_tokens=max_tokens
            )

            # Calculate duration
            duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)

            # Extract usage
            usage = response.usage

            # Calculate cost
            cost_usd = self._calculate_cost(model, usage)

            # Build metrics
            metrics = {
                'request_id': request_id,
                'correlation_id': correlation_id,
                'provider': self.provider,
                'model': model,
                'endpoint': '/v1/chat/completions',
                'timestamp': start_time,
                'duration_ms': duration_ms,
                'prompt_tokens': usage.prompt_tokens,
                'completion_tokens': usage.completion_tokens,
                'total_tokens': usage.total_tokens,
                'cost_usd': cost_usd,
                'operation': operation,
                'success': True,
                'temperature': temperature,
                'max_tokens': max_tokens
            }

            # Store metrics
            self._store_metrics(metrics)

            # Log success
            logger.info(
                "groq_request_complete",
                **metrics
            )

            return response.choices[0].message.content, metrics

        except Exception as e:
            duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)

            # Log error
            error_metrics = {
                'request_id': request_id,
                'correlation_id': correlation_id,
                'provider': self.provider,
                'model': model,
                'timestamp': start_time,
                'duration_ms': duration_ms,
                'success': False,
                'error_message': str(e),
                'operation': operation
            }

            self._store_metrics(error_metrics)

            logger.error(
                "groq_request_failed",
                **error_metrics
            )

            raise

    def _calculate_cost(self, model: str, usage) -> float:
        """
        Calculate cost based on Groq pricing

        Groq Pricing (as of 2025):
        - llama-3.3-70b: $0.59/1M input, $0.79/1M output
        - llama-3.1-8b: $0.05/1M input, $0.08/1M output
        """
        pricing = {
            'llama-3.3-70b-versatile': {'input': 0.59, 'output': 0.79},
            'llama-3.3-70b-8192': {'input': 0.59, 'output': 0.79},
            'llama-3.1-8b-instant': {'input': 0.05, 'output': 0.08},
            'llama-3.3-8b-8192': {'input': 0.05, 'output': 0.08},
        }

        rates = pricing.get(model, {'input': 0.10, 'output': 0.20})  # Default fallback

        input_cost = (usage.prompt_tokens / 1_000_000) * rates['input']
        output_cost = (usage.completion_tokens / 1_000_000) * rates['output']

        return round(input_cost + output_cost, 6)

    def _store_metrics(self, metrics: Dict[str, Any]):
        """Store metrics to database"""
        if self.db is None:
            return

        try:
            self.db.execute("""
                INSERT INTO api_calls (
                    request_id, correlation_id, provider, model, endpoint,
                    timestamp, duration_ms, prompt_tokens, completion_tokens,
                    total_tokens, cost_usd, operation, success, error_message,
                    temperature, max_tokens
                ) VALUES (
                    %(request_id)s, %(correlation_id)s, %(provider)s, %(model)s, %(endpoint)s,
                    %(timestamp)s, %(duration_ms)s, %(prompt_tokens)s, %(completion_tokens)s,
                    %(total_tokens)s, %(cost_usd)s, %(operation)s, %(success)s, %(error_message)s,
                    %(temperature)s, %(max_tokens)s
                )
            """, metrics)
            self.db.commit()
        except Exception as e:
            logger.error("failed_to_store_metrics", error=str(e))
```

### Gemini Client Enhancement

```python
# src/api_clients/gemini_client.py

import structlog
from typing import Optional, Dict, Any
from datetime import datetime
import uuid

logger = structlog.get_logger()

class GeminiClient:
    """Enhanced Gemini client with token tracking"""

    def __init__(self, api_key: str, db_connection=None):
        import google.generativeai as genai
        genai.configure(api_key=api_key)
        self.genai = genai
        self.db = db_connection
        self.provider = "gemini"

    def generate_content(
        self,
        prompt: str,
        model_name: str = "gemini-2.5-flash",
        temperature: float = 0.7,
        max_tokens: int = 1000,
        correlation_id: Optional[str] = None,
        operation: str = "content_expansion"
    ) -> tuple[str, Dict[str, Any]]:
        """Generate content with token tracking"""

        request_id = str(uuid.uuid4())
        start_time = datetime.utcnow()

        logger.info(
            "gemini_request_start",
            request_id=request_id,
            correlation_id=correlation_id,
            model=model_name,
            operation=operation
        )

        try:
            model = self.genai.GenerativeModel(model_name)

            response = model.generate_content(
                prompt,
                generation_config={
                    'temperature': temperature,
                    'max_output_tokens': max_tokens
                }
            )

            duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)

            # Extract usage metadata
            usage = response.usage_metadata

            # Calculate cost
            cost_usd = self._calculate_cost(model_name, usage)

            metrics = {
                'request_id': request_id,
                'correlation_id': correlation_id,
                'provider': self.provider,
                'model': model_name,
                'endpoint': '/v1/models/generateContent',
                'timestamp': start_time,
                'duration_ms': duration_ms,
                'prompt_tokens': usage.prompt_token_count,
                'completion_tokens': usage.candidates_token_count,
                'total_tokens': usage.total_token_count,
                'cost_usd': cost_usd,
                'operation': operation,
                'success': True,
                'temperature': temperature,
                'max_tokens': max_tokens
            }

            self._store_metrics(metrics)

            logger.info("gemini_request_complete", **metrics)

            return response.text, metrics

        except Exception as e:
            duration_ms = int((datetime.utcnow() - start_time).total_seconds() * 1000)

            error_metrics = {
                'request_id': request_id,
                'correlation_id': correlation_id,
                'provider': self.provider,
                'model': model_name,
                'timestamp': start_time,
                'duration_ms': duration_ms,
                'success': False,
                'error_message': str(e),
                'operation': operation
            }

            self._store_metrics(error_metrics)
            logger.error("gemini_request_failed", **error_metrics)
            raise

    def _calculate_cost(self, model: str, usage) -> float:
        """
        Calculate Gemini API cost

        Gemini Pricing (2025):
        - gemini-2.5-flash: $0.075/1M input, $0.30/1M output
        - gemini-2.5-pro: $1.25/1M input, $5.00/1M output
        """
        pricing = {
            'gemini-2.5-flash': {'input': 0.075, 'output': 0.30},
            'gemini-2.5-pro': {'input': 1.25, 'output': 5.00},
        }

        rates = pricing.get(model, {'input': 0.10, 'output': 0.40})

        input_cost = (usage.prompt_token_count / 1_000_000) * rates['input']
        output_cost = (usage.candidates_token_count / 1_000_000) * rates['output']

        return round(input_cost + output_cost, 6)

    def _store_metrics(self, metrics: Dict[str, Any]):
        """Store metrics to database (same as Groq)"""
        if self.db is None:
            return

        try:
            self.db.execute("""
                INSERT INTO api_calls (
                    request_id, correlation_id, provider, model, endpoint,
                    timestamp, duration_ms, prompt_tokens, completion_tokens,
                    total_tokens, cost_usd, operation, success, error_message,
                    temperature, max_tokens
                ) VALUES (
                    %(request_id)s, %(correlation_id)s, %(provider)s, %(model)s, %(endpoint)s,
                    %(timestamp)s, %(duration_ms)s, %(prompt_tokens)s, %(completion_tokens)s,
                    %(total_tokens)s, %(cost_usd)s, %(operation)s, %(success)s, %(error_message)s,
                    %(temperature)s, %(max_tokens)s
                )
            """, metrics)
            self.db.commit()
        except Exception as e:
            logger.error("failed_to_store_metrics", error=str(e))
```

### Carousel Script Integration

```python
# scripts/composite.py - Enhanced with tracking

import uuid
from src.api_clients.groq_client import GroqClient
from src.api_clients.gemini_client import GeminiClient
import psycopg2

def generate_carousel(topic: str):
    """Generate carousel with full performance tracking"""

    # Generate correlation ID for linking all API calls
    carousel_id = str(uuid.uuid4())
    start_time = time.time()

    # Connect to database
    db = psycopg2.connect(
        host=os.getenv('POSTGRES_HOST'),
        database=os.getenv('POSTGRES_DB'),
        user=os.getenv('POSTGRES_USER'),
        password=os.getenv('POSTGRES_PASSWORD')
    )

    # Initialize clients with DB connection
    groq = GroqClient(api_key=os.getenv('GROQ_API_KEY'), db_connection=db)
    gemini = GeminiClient(api_key=os.getenv('GEMINI_API_KEY'), db_connection=db)

    # Step 1: Generate fact with Groq
    groq_start = time.time()
    fact, groq_metrics = groq.generate_text(
        prompt=f"Generate an interesting fact about: {topic}",
        correlation_id=carousel_id,
        operation="fact_generation"
    )
    groq_time = time.time() - groq_start

    # Step 2: Expand content with Gemini
    gemini_start = time.time()
    content, gemini_metrics = gemini.generate_content(
        prompt=f"Expand this fact into engaging content: {fact}",
        correlation_id=carousel_id,
        operation="content_expansion"
    )
    gemini_time = time.time() - gemini_start

    # Step 3: Render carousel (your existing rendering code)
    render_start = time.time()
    # ... your rendering code ...
    render_time = time.time() - render_start

    # Step 4: Store carousel performance
    total_time = time.time() - start_time
    total_cost = groq_metrics['cost_usd'] + gemini_metrics['cost_usd']

    cursor = db.cursor()
    cursor.execute("""
        INSERT INTO carousel_performance (
            carousel_id, generated_at,
            total_time_seconds, groq_time_seconds, gemini_time_seconds, rendering_time_seconds,
            groq_tokens, gemini_tokens, total_cost_usd,
            topic, prompt_version
        ) VALUES (
            %s, NOW(),
            %s, %s, %s, %s,
            %s, %s, %s,
            %s, %s
        )
    """, (
        carousel_id, total_time, groq_time, gemini_time, render_time,
        groq_metrics['total_tokens'], gemini_metrics['total_tokens'], total_cost,
        topic, 'v1.0'
    ))
    db.commit()

    print(f"""
    ✅ Carousel Generated!

    📊 Performance Metrics:
       - Total Time: {total_time:.2f}s
       - Groq Time: {groq_time:.2f}s ({groq_metrics['total_tokens']} tokens)
       - Gemini Time: {gemini_time:.2f}s ({gemini_metrics['total_tokens']} tokens)
       - Render Time: {render_time:.2f}s

    💰 Cost: ${total_cost:.4f}
    🆔 Carousel ID: {carousel_id}
    """)

    db.close()
    return carousel_id
```

---

## Frontend Dashboard Design

### Architecture: Home Assistant-Style Dashboard

**Technology Stack:**
- **Frontend**: React + TypeScript + Tailwind CSS
- **Charting**: Recharts or Chart.js
- **Real-time**: WebSocket connection to backend
- **Backend API**: FastAPI (Python)
- **Database**: PostgreSQL (existing)

### Dashboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│  NEXUS Token Monitoring Dashboard                    🔄 Live│
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐       │
│  │ Total Tokens │  │ Daily Cost   │  │ API Calls    │       │
│  │  245.3K      │  │  $2.47       │  │  1,247       │       │
│  │  ↑ 12%      │  │  ↓ 5%       │  │  ↑ 8%       │       │
│  └──────────────┘  └──────────────┘  └──────────────┘       │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Token Usage Over Time (24h)                            ││
│  │  [Line chart: Groq vs Gemini vs Claude]                ││
│  │                                                         ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌────────────────────────┐  ┌────────────────────────────┐ │
│  │  Cost by Provider      │  │  Tokens by Operation       │ │
│  │  [Pie chart]           │  │  [Bar chart]               │ │
│  │                        │  │                            │ │
│  └────────────────────────┘  └────────────────────────────┘ │
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Recent API Calls                              [Filter] ││
│  │  ┌───────────────────────────────────────────────────┐ ││
│  │  │ Time   │ Provider │ Operation    │ Tokens │ Cost │ ││
│  │  │ 10:23  │ Groq     │ Fact Gen     │ 234    │$0.01│ ││
│  │  │ 10:22  │ Gemini   │ Content Exp  │ 1,234  │$0.04│ ││
│  │  └───────────────────────────────────────────────────┘ ││
│  └─────────────────────────────────────────────────────────┘│
│                                                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Budget Alert                                    ⚠️      ││
│  │  Daily budget: 80% used ($4.00 / $5.00)                ││
│  │  [Progress bar]                                         ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

### Component Structure

```typescript
// frontend/src/types.ts

export interface APICallMetrics {
  id: number;
  requestId: string;
  correlationId?: string;
  provider: 'groq' | 'gemini' | 'claude';
  model: string;
  timestamp: string;
  durationMs: number;
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
  costUsd: number;
  operation: string;
  success: boolean;
}

export interface DailySummary {
  date: string;
  provider: string;
  model: string;
  totalCalls: number;
  totalTokens: number;
  totalCost: number;
  avgTokensPerCall: number;
}

export interface DashboardStats {
  totalTokensToday: number;
  totalCostToday: number;
  totalCallsToday: number;
  tokensTrend: number; // percentage change
  costTrend: number;
  callsTrend: number;
}
```

```typescript
// frontend/src/components/Dashboard.tsx

import React, { useEffect, useState } from 'react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend } from 'recharts';
import { MetricCard } from './MetricCard';
import { RecentCallsTable } from './RecentCallsTable';
import { BudgetAlert } from './BudgetAlert';

export const Dashboard: React.FC = () => {
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [recentCalls, setRecentCalls] = useState<APICallMetrics[]>([]);
  const [hourlyData, setHourlyData] = useState([]);

  useEffect(() => {
    // Fetch initial data
    fetchDashboardData();

    // Setup WebSocket for real-time updates
    const ws = new WebSocket('ws://localhost:8000/ws/metrics');

    ws.onmessage = (event) => {
      const newMetric = JSON.parse(event.data);
      setRecentCalls(prev => [newMetric, ...prev].slice(0, 20));
      updateStats(newMetric);
    };

    return () => ws.close();
  }, []);

  const fetchDashboardData = async () => {
    const response = await fetch('/api/dashboard/stats');
    const data = await response.json();
    setStats(data.stats);
    setRecentCalls(data.recentCalls);
    setHourlyData(data.hourlyData);
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white p-6">
      <header className="mb-8">
        <h1 className="text-3xl font-bold">Nexus Token Monitoring</h1>
        <p className="text-gray-400">Real-time AI API usage analytics</p>
      </header>

      {/* Stats Cards */}
      <div className="grid grid-cols-3 gap-6 mb-8">
        <MetricCard
          title="Total Tokens"
          value={stats?.totalTokensToday.toLocaleString()}
          trend={stats?.tokensTrend}
          icon="📊"
        />
        <MetricCard
          title="Daily Cost"
          value={`$${stats?.totalCostToday.toFixed(2)}`}
          trend={stats?.costTrend}
          icon="💰"
        />
        <MetricCard
          title="API Calls"
          value={stats?.totalCallsToday.toLocaleString()}
          trend={stats?.callsTrend}
          icon="🔄"
        />
      </div>

      {/* Usage Chart */}
      <div className="bg-gray-800 rounded-lg p-6 mb-8">
        <h2 className="text-xl font-semibold mb-4">Token Usage Over Time (24h)</h2>
        <LineChart width={1000} height={300} data={hourlyData}>
          <CartesianGrid strokeDasharray="3 3" stroke="#444" />
          <XAxis dataKey="hour" stroke="#888" />
          <YAxis stroke="#888" />
          <Tooltip
            contentStyle={{ backgroundColor: '#1f2937', border: 'none' }}
          />
          <Legend />
          <Line type="monotone" dataKey="groq_tokens" stroke="#8b5cf6" name="Groq" />
          <Line type="monotone" dataKey="gemini_tokens" stroke="#10b981" name="Gemini" />
          <Line type="monotone" dataKey="claude_tokens" stroke="#3b82f6" name="Claude" />
        </LineChart>
      </div>

      {/* Budget Alert */}
      <BudgetAlert
        current={stats?.totalCostToday || 0}
        limit={5.00}
        threshold={0.8}
      />

      {/* Recent Calls Table */}
      <RecentCallsTable calls={recentCalls} />
    </div>
  );
};
```

```typescript
// frontend/src/components/MetricCard.tsx

interface MetricCardProps {
  title: string;
  value: string | number;
  trend?: number;
  icon: string;
}

export const MetricCard: React.FC<MetricCardProps> = ({ title, value, trend, icon }) => {
  const trendColor = trend && trend > 0 ? 'text-green-500' : 'text-red-500';
  const trendIcon = trend && trend > 0 ? '↑' : '↓';

  return (
    <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
      <div className="flex items-center justify-between mb-2">
        <span className="text-gray-400 text-sm">{title}</span>
        <span className="text-2xl">{icon}</span>
      </div>
      <div className="text-3xl font-bold mb-1">{value}</div>
      {trend !== undefined && (
        <div className={`text-sm ${trendColor}`}>
          {trendIcon} {Math.abs(trend)}% from yesterday
        </div>
      )}
    </div>
  );
};
```

### Backend API (FastAPI)

```python
# src/api/monitoring_api.py

from fastapi import FastAPI, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from typing import List
import asyncio
import psycopg2
from datetime import datetime, timedelta

app = FastAPI(title="Nexus Monitoring API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Database connection pool
def get_db():
    return psycopg2.connect(
        host=os.getenv('POSTGRES_HOST'),
        database=os.getenv('POSTGRES_DB'),
        user=os.getenv('POSTGRES_USER'),
        password=os.getenv('POSTGRES_PASSWORD')
    )

@app.get("/api/dashboard/stats")
async def get_dashboard_stats():
    """Get current dashboard statistics"""
    db = get_db()
    cursor = db.cursor()

    # Today's stats
    cursor.execute("""
        SELECT
            SUM(total_tokens) as total_tokens,
            SUM(cost_usd) as total_cost,
            COUNT(*) as total_calls
        FROM api_calls
        WHERE timestamp >= CURRENT_DATE
    """)
    today = cursor.fetchone()

    # Yesterday's stats for trend
    cursor.execute("""
        SELECT
            SUM(total_tokens) as total_tokens,
            SUM(cost_usd) as total_cost,
            COUNT(*) as total_calls
        FROM api_calls
        WHERE timestamp >= CURRENT_DATE - INTERVAL '1 day'
          AND timestamp < CURRENT_DATE
    """)
    yesterday = cursor.fetchone()

    # Calculate trends
    stats = {
        'totalTokensToday': today[0] or 0,
        'totalCostToday': float(today[1] or 0),
        'totalCallsToday': today[2] or 0,
        'tokensTrend': calculate_trend(today[0], yesterday[0]),
        'costTrend': calculate_trend(today[1], yesterday[1]),
        'callsTrend': calculate_trend(today[2], yesterday[2])
    }

    # Recent calls
    cursor.execute("""
        SELECT
            id, request_id, correlation_id, provider, model,
            timestamp, duration_ms, prompt_tokens, completion_tokens,
            total_tokens, cost_usd, operation, success
        FROM api_calls
        ORDER BY timestamp DESC
        LIMIT 20
    """)
    recent_calls = [
        {
            'id': row[0],
            'requestId': row[1],
            'correlationId': row[2],
            'provider': row[3],
            'model': row[4],
            'timestamp': row[5].isoformat(),
            'durationMs': row[6],
            'promptTokens': row[7],
            'completionTokens': row[8],
            'totalTokens': row[9],
            'costUsd': float(row[10]),
            'operation': row[11],
            'success': row[12]
        }
        for row in cursor.fetchall()
    ]

    # Hourly data for chart
    cursor.execute("""
        SELECT
            DATE_TRUNC('hour', timestamp) as hour,
            provider,
            SUM(total_tokens) as tokens
        FROM api_calls
        WHERE timestamp >= NOW() - INTERVAL '24 hours'
        GROUP BY hour, provider
        ORDER BY hour
    """)

    hourly_data = {}
    for row in cursor.fetchall():
        hour_str = row[0].strftime('%H:%M')
        if hour_str not in hourly_data:
            hourly_data[hour_str] = {'hour': hour_str}
        hourly_data[hour_str][f"{row[1]}_tokens"] = row[2]

    db.close()

    return {
        'stats': stats,
        'recentCalls': recent_calls,
        'hourlyData': list(hourly_data.values())
    }

def calculate_trend(current, previous):
    """Calculate percentage change"""
    if previous is None or previous == 0:
        return 0
    return round(((current - previous) / previous) * 100, 1)

@app.websocket("/ws/metrics")
async def websocket_metrics(websocket: WebSocket):
    """WebSocket endpoint for real-time metrics"""
    await websocket.accept()

    db = get_db()
    cursor = db.cursor()

    # Get last timestamp
    cursor.execute("SELECT MAX(timestamp) FROM api_calls")
    last_timestamp = cursor.fetchone()[0]

    try:
        while True:
            # Check for new metrics every 2 seconds
            await asyncio.sleep(2)

            cursor.execute("""
                SELECT
                    id, request_id, provider, model, timestamp,
                    total_tokens, cost_usd, operation
                FROM api_calls
                WHERE timestamp > %s
                ORDER BY timestamp DESC
            """, (last_timestamp,))

            new_rows = cursor.fetchall()

            for row in new_rows:
                await websocket.send_json({
                    'id': row[0],
                    'requestId': row[1],
                    'provider': row[2],
                    'model': row[3],
                    'timestamp': row[4].isoformat(),
                    'totalTokens': row[5],
                    'costUsd': float(row[6]),
                    'operation': row[7]
                })
                last_timestamp = row[4]

    except Exception as e:
        print(f"WebSocket error: {e}")
    finally:
        db.close()

@app.get("/api/analytics/cost-by-operation")
async def cost_by_operation():
    """Get cost breakdown by operation"""
    db = get_db()
    cursor = db.cursor()

    cursor.execute("""
        SELECT
            operation,
            COUNT(*) as calls,
            SUM(total_tokens) as total_tokens,
            SUM(cost_usd) as total_cost,
            AVG(cost_usd) as avg_cost
        FROM api_calls
        WHERE timestamp >= NOW() - INTERVAL '30 days'
        GROUP BY operation
        ORDER BY total_cost DESC
    """)

    data = [
        {
            'operation': row[0],
            'calls': row[1],
            'totalTokens': row[2],
            'totalCost': float(row[3]),
            'avgCost': float(row[4])
        }
        for row in cursor.fetchall()
    ]

    db.close()
    return data

@app.get("/api/analytics/carousel-performance")
async def carousel_performance(limit: int = 50):
    """Get carousel performance metrics"""
    db = get_db()
    cursor = db.cursor()

    cursor.execute("""
        SELECT
            carousel_id,
            generated_at,
            total_time_seconds,
            total_cost_usd,
            likes,
            comments,
            shares,
            saves,
            (likes + comments*2 + shares*3 + saves*4) as engagement_score
        FROM carousel_performance
        ORDER BY generated_at DESC
        LIMIT %s
    """, (limit,))

    data = [
        {
            'carouselId': row[0],
            'generatedAt': row[1].isoformat(),
            'totalTime': float(row[2]) if row[2] else 0,
            'totalCost': float(row[3]) if row[3] else 0,
            'likes': row[4] or 0,
            'comments': row[5] or 0,
            'shares': row[6] or 0,
            'saves': row[7] or 0,
            'engagementScore': row[8] or 0
        }
        for row in cursor.fetchall()
    ]

    db.close()
    return data

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

---

## Analytics & Reporting

### Pre-built SQL Reports

#### Daily Cost Report

```sql
-- reports/daily_cost_report.sql

WITH daily_stats AS (
    SELECT
        DATE(timestamp) as date,
        provider,
        COUNT(*) as total_calls,
        SUM(total_tokens) as total_tokens,
        SUM(cost_usd) as total_cost,
        AVG(duration_ms) as avg_duration,
        SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as success_rate
    FROM api_calls
    WHERE timestamp >= CURRENT_DATE - INTERVAL '30 days'
    GROUP BY DATE(timestamp), provider
)
SELECT
    date,
    provider,
    total_calls,
    total_tokens,
    ROUND(total_cost::numeric, 4) as total_cost_usd,
    ROUND((total_cost / NULLIF(total_calls, 0))::numeric, 6) as avg_cost_per_call,
    ROUND(avg_duration::numeric, 0) as avg_duration_ms,
    ROUND(success_rate::numeric, 2) as success_rate_pct
FROM daily_stats
ORDER BY date DESC, total_cost DESC;
```

#### Token Efficiency Analysis

```sql
-- reports/token_efficiency.sql

SELECT
    operation,
    provider,
    model,
    COUNT(*) as calls,
    AVG(total_tokens) as avg_tokens,
    AVG(prompt_tokens) as avg_prompt_tokens,
    AVG(completion_tokens) as avg_completion_tokens,
    AVG(completion_tokens::FLOAT / NULLIF(prompt_tokens, 0)) as expansion_ratio,
    AVG(duration_ms) as avg_duration_ms,
    AVG(total_tokens::FLOAT / NULLIF(duration_ms, 0) * 1000) as tokens_per_second
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '7 days'
  AND success = TRUE
GROUP BY operation, provider, model
ORDER BY avg_tokens DESC;
```

#### Cost Trending

```sql
-- reports/cost_trending.sql

WITH weekly_costs AS (
    SELECT
        DATE_TRUNC('week', timestamp) as week,
        provider,
        SUM(cost_usd) as weekly_cost
    FROM api_calls
    WHERE timestamp >= NOW() - INTERVAL '12 weeks'
    GROUP BY week, provider
),
costs_with_lag AS (
    SELECT
        week,
        provider,
        weekly_cost,
        LAG(weekly_cost) OVER (PARTITION BY provider ORDER BY week) as prev_week_cost
    FROM weekly_costs
)
SELECT
    week,
    provider,
    ROUND(weekly_cost::numeric, 2) as weekly_cost_usd,
    ROUND(prev_week_cost::numeric, 2) as prev_week_cost_usd,
    ROUND(((weekly_cost - prev_week_cost) / NULLIF(prev_week_cost, 0) * 100)::numeric, 1) as growth_pct
FROM costs_with_lag
ORDER BY week DESC, provider;
```

### Automated Reporting Script

```python
# scripts/generate_reports.py

import psycopg2
from datetime import datetime
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

def generate_weekly_report():
    """Generate comprehensive weekly report"""

    db = psycopg2.connect(...)

    # Fetch data
    df = pd.read_sql("""
        SELECT
            DATE(timestamp) as date,
            provider,
            operation,
            total_tokens,
            cost_usd
        FROM api_calls
        WHERE timestamp >= NOW() - INTERVAL '7 days'
    """, db)

    # Create visualizations
    fig, axes = plt.subplots(2, 2, figsize=(15, 10))

    # 1. Daily cost by provider
    daily_cost = df.groupby(['date', 'provider'])['cost_usd'].sum().unstack()
    daily_cost.plot(kind='bar', stacked=True, ax=axes[0, 0])
    axes[0, 0].set_title('Daily Cost by Provider')
    axes[0, 0].set_ylabel('Cost (USD)')

    # 2. Token usage distribution
    df.boxplot(column='total_tokens', by='provider', ax=axes[0, 1])
    axes[0, 1].set_title('Token Distribution by Provider')

    # 3. Operation breakdown
    operation_cost = df.groupby('operation')['cost_usd'].sum()
    operation_cost.plot(kind='pie', ax=axes[1, 0], autopct='%1.1f%%')
    axes[1, 0].set_title('Cost by Operation')

    # 4. Daily token trends
    daily_tokens = df.groupby(['date', 'provider'])['total_tokens'].sum().unstack()
    daily_tokens.plot(ax=axes[1, 1])
    axes[1, 1].set_title('Daily Token Usage Trend')
    axes[1, 1].set_ylabel('Tokens')

    plt.tight_layout()
    plt.savefig(f'/tmp/weekly_report_{datetime.now():%Y%m%d}.png')

    # Generate summary stats
    summary = {
        'total_cost': df['cost_usd'].sum(),
        'total_tokens': df['total_tokens'].sum(),
        'total_calls': len(df),
        'avg_cost_per_call': df['cost_usd'].mean(),
        'cost_by_provider': df.groupby('provider')['cost_usd'].sum().to_dict()
    }

    return summary

if __name__ == '__main__':
    summary = generate_weekly_report()
    print("Weekly Report Generated:")
    print(f"Total Cost: ${summary['total_cost']:.2f}")
    print(f"Total Tokens: {summary['total_tokens']:,}")
    print(f"Total Calls: {summary['total_calls']:,}")
```

---

## Cost Tracking

### Real-Time Cost Calculator

```python
# src/monitoring/cost_calculator.py

from typing import Dict
from datetime import datetime

class CostCalculator:
    """Real-time cost calculation and budget management"""

    # Pricing tables (update regularly)
    PRICING = {
        'groq': {
            'llama-3.3-70b-versatile': {'input': 0.59, 'output': 0.79},
            'llama-3.1-8b-instant': {'input': 0.05, 'output': 0.08}
        },
        'gemini': {
            'gemini-2.5-flash': {'input': 0.075, 'output': 0.30},
            'gemini-2.5-pro': {'input': 1.25, 'output': 5.00}
        },
        'claude': {
            'claude-sonnet-4-5': {'input': 3.00, 'output': 15.00},
            'claude-haiku-4': {'input': 0.25, 'output': 1.25}
        }
    }

    def calculate_cost(self, provider: str, model: str, prompt_tokens: int, completion_tokens: int) -> float:
        """Calculate cost for API call"""
        try:
            rates = self.PRICING[provider][model]
            input_cost = (prompt_tokens / 1_000_000) * rates['input']
            output_cost = (completion_tokens / 1_000_000) * rates['output']
            return round(input_cost + output_cost, 6)
        except KeyError:
            # Fallback to default rates
            return (prompt_tokens + completion_tokens) / 1_000_000 * 0.10

    def check_budget(self, db_connection, budget_type: str = 'daily') -> Dict:
        """Check current spend against budget"""
        cursor = db_connection.cursor()

        if budget_type == 'daily':
            cursor.execute("""
                SELECT
                    COALESCE(SUM(cost_usd), 0) as current_spend
                FROM api_calls
                WHERE timestamp >= CURRENT_DATE
            """)

        current_spend = cursor.fetchone()[0]

        # Get budget from config
        cursor.execute("""
            SELECT budget_usd, warning_threshold_pct
            FROM cost_budgets
            WHERE period_type = %s
              AND CURRENT_DATE BETWEEN start_date AND end_date
            ORDER BY id DESC
            LIMIT 1
        """, (budget_type,))

        budget_row = cursor.fetchone()
        if not budget_row:
            return {'status': 'no_budget', 'current_spend': float(current_spend)}

        budget_usd, warning_threshold = budget_row
        usage_pct = (current_spend / budget_usd) * 100

        status = 'ok'
        if usage_pct >= 100:
            status = 'exceeded'
        elif usage_pct >= warning_threshold:
            status = 'warning'

        return {
            'status': status,
            'current_spend': float(current_spend),
            'budget': float(budget_usd),
            'usage_pct': round(usage_pct, 1),
            'remaining': float(budget_usd - current_spend)
        }

    def forecast_spend(self, db_connection, days_ahead: int = 7) -> float:
        """Forecast spending based on recent trends"""
        cursor = db_connection.cursor()

        cursor.execute("""
            SELECT AVG(daily_cost) as avg_daily_cost
            FROM (
                SELECT DATE(timestamp) as date, SUM(cost_usd) as daily_cost
                FROM api_calls
                WHERE timestamp >= CURRENT_DATE - INTERVAL '7 days'
                GROUP BY DATE(timestamp)
            ) daily
        """)

        avg_daily = cursor.fetchone()[0] or 0
        return float(avg_daily * days_ahead)
```

---

## Alerting & Notifications

### Telegram Alert System

```python
# src/monitoring/alerts.py

import requests
from typing import Dict, Any
import structlog

logger = structlog.get_logger()

class AlertManager:
    """Manage alerts for token usage and costs"""

    def __init__(self, telegram_token: str, telegram_chat_id: str):
        self.telegram_token = telegram_token
        self.telegram_chat_id = telegram_chat_id

    def send_telegram(self, message: str):
        """Send alert via Telegram"""
        url = f"https://api.telegram.org/bot{self.telegram_token}/sendMessage"

        payload = {
            'chat_id': self.telegram_chat_id,
            'text': message,
            'parse_mode': 'Markdown'
        }

        try:
            response = requests.post(url, json=payload, timeout=10)
            response.raise_for_status()
            logger.info("telegram_alert_sent", message_length=len(message))
        except Exception as e:
            logger.error("telegram_alert_failed", error=str(e))

    def check_and_alert_budget(self, budget_status: Dict[str, Any]):
        """Send alert if budget threshold exceeded"""
        if budget_status['status'] == 'warning':
            message = f"""
⚠️ *Budget Warning*

Daily spending has reached *{budget_status['usage_pct']}%* of budget.

- Current: ${budget_status['current_spend']:.2f}
- Budget: ${budget_status['budget']:.2f}
- Remaining: ${budget_status['remaining']:.2f}

Monitor usage at: http://your-dashboard-url
            """
            self.send_telegram(message)

        elif budget_status['status'] == 'exceeded':
            message = f"""
🚨 *BUDGET EXCEEDED*

Daily budget has been exceeded!

- Current: ${budget_status['current_spend']:.2f}
- Budget: ${budget_status['budget']:.2f}
- Overspend: ${abs(budget_status['remaining']):.2f}

Immediate action required.
            """
            self.send_telegram(message)

    def alert_high_cost_call(self, metrics: Dict[str, Any], threshold: float = 0.50):
        """Alert on unusually expensive API call"""
        if metrics['cost_usd'] >= threshold:
            message = f"""
💰 *High Cost API Call*

An API call exceeded cost threshold:

- Provider: {metrics['provider']}
- Model: {metrics['model']}
- Operation: {metrics['operation']}
- Tokens: {metrics['total_tokens']:,}
- Cost: ${metrics['cost_usd']:.4f}
- Duration: {metrics['duration_ms']}ms

Request ID: `{metrics['request_id']}`
            """
            self.send_telegram(message)

    def daily_summary_report(self, summary: Dict[str, Any]):
        """Send daily summary report"""
        message = f"""
📊 *Daily Token Usage Summary*
{summary['date']}

💰 *Costs:*
- Total: ${summary['total_cost']:.2f}
- Groq: ${summary['groq_cost']:.2f}
- Gemini: ${summary['gemini_cost']:.2f}

📈 *Tokens:*
- Total: {summary['total_tokens']:,}
- Avg per call: {summary['avg_tokens_per_call']:,.0f}

🔄 *API Calls:*
- Total: {summary['total_calls']:,}
- Success rate: {summary['success_rate']:.1f}%

View details: http://your-dashboard-url
        """
        self.send_telegram(message)
```

### Alert Integration in API Clients

```python
# In api_clients/groq_client.py

from src.monitoring.alerts import AlertManager

class GroqClient:
    def __init__(self, api_key: str, db_connection=None, alert_manager: AlertManager = None):
        self.client = Groq(api_key=api_key)
        self.db = db_connection
        self.alert_manager = alert_manager

    def generate_text(self, ...):
        # ... existing code ...

        # After storing metrics
        if self.alert_manager:
            self.alert_manager.alert_high_cost_call(metrics, threshold=0.10)
```

---

## Best Practices

### 1. Token Optimization

**Strategies:**
- Use smaller models for simple tasks (llama-3.1-8b vs llama-3.3-70b)
- Implement prompt caching for repeated patterns
- Set appropriate `max_tokens` limits
- Use streaming for long responses (pay as you go)

**Example:**
```python
# Bad: Always use largest model
response = groq.generate_text(prompt, model="llama-3.3-70b")

# Good: Choose model based on complexity
model = "llama-3.3-70b" if is_complex_task(prompt) else "llama-3.1-8b"
response = groq.generate_text(prompt, model=model)
```

### 2. Cost Management

**Daily Budgets:**
```sql
INSERT INTO cost_budgets (
    period_type, start_date, end_date,
    budget_usd, warning_threshold_pct
) VALUES (
    'daily', CURRENT_DATE, CURRENT_DATE + INTERVAL '1 day',
    5.00, 80
);
```

**Implement Circuit Breakers:**
```python
def safe_api_call(client, prompt, **kwargs):
    """API call with budget check"""
    budget_status = cost_calculator.check_budget(db)

    if budget_status['status'] == 'exceeded':
        raise BudgetExceededException(
            f"Daily budget exceeded: ${budget_status['current_spend']}"
        )

    return client.generate_text(prompt, **kwargs)
```

### 3. Monitoring Hygiene

**Best Practices:**
- Log every API call, even failures
- Use correlation IDs to link related calls
- Store raw responses for debugging (optional)
- Implement retry logic with exponential backoff
- Set up daily summary reports

### 4. Data Retention

```sql
-- Archive old data
CREATE TABLE api_calls_archive (LIKE api_calls INCLUDING ALL);

-- Monthly archival job
INSERT INTO api_calls_archive
SELECT * FROM api_calls
WHERE timestamp < NOW() - INTERVAL '90 days';

DELETE FROM api_calls
WHERE timestamp < NOW() - INTERVAL '90 days';

-- Vacuum to reclaim space
VACUUM ANALYZE api_calls;
```

### 5. Security

**Protect Sensitive Data:**
- Never log full API keys
- Redact user prompts if they contain PII
- Use encrypted connections (SSL/TLS)
- Implement access controls on monitoring dashboard

```python
def sanitize_prompt(prompt: str) -> str:
    """Remove sensitive data from logs"""
    # Remove emails
    prompt = re.sub(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b', '[EMAIL]', prompt)
    # Remove phone numbers
    prompt = re.sub(r'\b\d{3}[-.]?\d{3}[-.]?\d{4}\b', '[PHONE]', prompt)
    return prompt
```

---

## Implementation Checklist

### Phase 1: Foundation (Week 1)
- [ ] Create database schema (run migration script)
- [ ] Enhance Groq client with token tracking
- [ ] Enhance Gemini client with token tracking
- [ ] Implement structured logging
- [ ] Test token tracking in development

### Phase 2: Analytics (Week 2)
- [ ] Create SQL views for reporting
- [ ] Build FastAPI monitoring backend
- [ ] Set up cost budgets
- [ ] Implement alert system
- [ ] Test with production data

### Phase 3: Dashboard (Week 3)
- [ ] Build React frontend
- [ ] Implement real-time WebSocket updates
- [ ] Create visualization charts
- [ ] Deploy to production
- [ ] User acceptance testing

### Phase 4: Optimization (Week 4)
- [ ] Analyze token usage patterns
- [ ] Optimize prompts based on data
- [ ] Fine-tune cost budgets
- [ ] Set up automated reports
- [ ] Document learnings

---

## Quick Start Commands

```bash
# 1. Create database schema
psql -U nexus -d nexus -f migrations/001_monitoring_schema.sql

# 2. Install dependencies
pip install fastapi uvicorn psycopg2-binary structlog

# 3. Start monitoring API
cd src/api
python monitoring_api.py

# 4. Start frontend (if using React)
cd frontend
npm install
npm start

# 5. View dashboard
open http://localhost:3000
```

---

## Conclusion

This comprehensive guide provides multiple approaches to token monitoring, from simple logging to enterprise-grade observability. Start with the minimal approach and gradually implement more features as needed.

**Key Takeaways:**
- Always track tokens at the response level for accuracy
- Store metrics in PostgreSQL for long-term analysis
- Implement budget alerts to prevent overspending
- Build dashboards for real-time visibility
- Optimize prompts based on data

**Next Steps:**
1. Choose your implementation approach
2. Set up the database schema
3. Enhance API clients with tracking
4. Build the monitoring dashboard
5. Iterate based on insights

---

**Document Version:** 1.0
**Last Updated:** 2025-11-18
**Maintainer:** Nexus Team
**License:** MIT
