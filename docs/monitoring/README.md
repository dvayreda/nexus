# Nexus Token & Cost Monitoring System

Complete observability for AI API usage, costs, and performance.

---

## Overview

This monitoring system provides comprehensive tracking and analytics for token usage across multiple AI providers (Groq, Gemini, Claude). It includes:

- **Real-time dashboarding** with Home Assistant-style UI
- **Cost tracking & budgets** with automated alerts
- **Performance analytics** for optimization
- **ROI analysis** for carousel content
- **Historical reporting** for trend analysis

---

## Features

### 📊 Monitoring

- Track every API call with detailed metrics
- Real-time WebSocket updates
- Provider-specific cost calculation
- Performance metrics (duration, tokens/sec)
- Success rate tracking

### 💰 Cost Management

- Daily/weekly/monthly budgets
- Budget alerts (Telegram/Email)
- Cost forecasting
- Provider comparison
- Operation-level cost breakdown

### 📈 Analytics

- Token usage trends
- Cost per operation analysis
- Carousel performance metrics
- Instagram engagement tracking
- ROI calculations

### 🎨 Dashboard

- Home Assistant-inspired dark theme
- Real-time charts (Recharts)
- Metric cards with trends
- Recent API calls table
- Budget progress bars

---

## Architecture

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│   Groq/     │────▶│  Enhanced    │────▶│ PostgreSQL  │
│   Gemini/   │     │  API Clients │     │  Database   │
│   Claude    │     └──────────────┘     └─────────────┘
└─────────────┘                                │
                                               │
                    ┌──────────────────────────┘
                    │
                    ▼
         ┌──────────────────┐         ┌──────────────┐
         │  FastAPI Backend │◀───────▶│    React     │
         │  (Monitoring API)│         │  Dashboard   │
         └──────────────────┘         └──────────────┘
                    │                        ▲
                    │                        │
                    ▼                        │
         ┌──────────────────┐                │
         │  Alert System    │                │
         │  (Telegram)      │                │
         └──────────────────┘                │
                                             │
                                    WebSocket (real-time)
```

---

## Documentation

### 📚 Comprehensive Guides

1. **[TOKEN_MONITORING_GUIDE.md](./TOKEN_MONITORING_GUIDE.md)** (30,000+ words)
   - Token monitoring approaches (response-based, tiktoken, character-based)
   - Architecture patterns (decorator, context manager, observer, streaming)
   - Implementation strategies (minimal, production, enterprise)
   - Complete database schema with triggers and views
   - Enhanced API client implementations
   - Analytics & reporting
   - Cost tracking & budgets
   - Alert system
   - Best practices

2. **[DASHBOARD_IMPLEMENTATION.md](./DASHBOARD_IMPLEMENTATION.md)**
   - React + TypeScript setup
   - Component library (MetricCard, Charts, Tables)
   - WebSocket integration
   - Tailwind CSS theming
   - Docker deployment
   - Configuration guide

3. **[QUICK_START.md](./QUICK_START.md)**
   - 30-minute setup guide
   - Step-by-step instructions
   - Verification checklist
   - Troubleshooting
   - Common issues & solutions

---

## Quick Start

### Prerequisites

- PostgreSQL (running)
- Python 3.11+
- Node.js 20+
- Docker & Docker Compose

### Installation

```bash
# 1. Apply database schema
docker exec -i nexus-postgres psql -U nexus -d nexus < migrations/001_monitoring_schema.sql

# 2. Install Python dependencies
pip install fastapi uvicorn psycopg2-binary structlog

# 3. Start monitoring API
uvicorn src.api.monitoring_api:app --reload

# 4. Install frontend dependencies
cd frontend
npm install

# 5. Start dashboard
npm run dev
```

### Access

- **Dashboard:** http://localhost:3000
- **API:** http://localhost:8000
- **API Docs:** http://localhost:8000/docs

See [QUICK_START.md](./QUICK_START.md) for detailed instructions.

---

## Database Schema

### Core Tables

- **`api_calls`** - Individual API requests with tokens, cost, duration
- **`daily_usage_summary`** - Aggregated daily metrics
- **`cost_budgets`** - Budget management and thresholds
- **`carousel_performance`** - Content generation & social metrics
- **`alert_history`** - Audit trail of alerts

### Views

- **`v_hourly_usage`** - 24-hour rolling metrics
- **`v_cost_by_operation`** - Cost breakdown by operation
- **`v_carousel_roi`** - ROI analysis for published content
- **`v_budget_status`** - Real-time budget tracking

### Triggers

- Auto-update daily summaries
- Auto-update budget spend tracking

See [migrations/001_monitoring_schema.sql](../../migrations/001_monitoring_schema.sql) for full schema.

---

## API Endpoints

### Dashboard

- `GET /api/dashboard/stats` - Main dashboard statistics
- `GET /api/budget/status` - Current budget status
- `GET /api/analytics/provider-stats` - Stats by provider

### Analytics

- `GET /api/analytics/cost-by-operation` - Cost breakdown
- `GET /api/analytics/carousel-performance` - Carousel metrics
- `GET /api/analytics/token-efficiency` - Token efficiency analysis

### Real-time

- `WS /ws/metrics` - WebSocket for live updates

See [http://localhost:8000/docs](http://localhost:8000/docs) for interactive API documentation.

---

## Usage Examples

### Track API calls

```python
from src.api_clients.groq_client import GroqClient
import psycopg2

db = psycopg2.connect(...)
groq = GroqClient(api_key="...", db_connection=db)

# Returns tuple: (text, metrics)
text, metrics = groq.generate_text(
    prompt="Generate a fun fact",
    correlation_id="carousel-123",
    operation="fact_generation"
)

print(f"Tokens: {metrics['total_tokens']}")
print(f"Cost: ${metrics['cost_usd']}")
```

### Check budget

```python
from src.monitoring.cost_calculator import CostCalculator

calculator = CostCalculator()
status = calculator.check_budget(db, 'daily')

if status['status'] == 'warning':
    print(f"⚠️ Budget at {status['usage_pct']}%")
```

### Send alerts

```python
from src.monitoring.alerts import AlertManager

alerts = AlertManager(
    telegram_token="...",
    telegram_chat_id="..."
)

alerts.check_and_alert_budget(budget_status)
```

### Query analytics

```sql
-- Today's spending by provider
SELECT provider, SUM(cost_usd) as total_cost
FROM api_calls
WHERE timestamp >= CURRENT_DATE
GROUP BY provider;

-- Top carousels by ROI
SELECT * FROM v_carousel_roi LIMIT 10;

-- Budget status
SELECT * FROM v_budget_status;
```

---

## Screenshots

### Dashboard Overview

```
┌─────────────────────────────────────────────────────────┐
│  Total Tokens     Daily Cost        API Calls           │
│  245.3K ↑12%      $2.47 ↓5%        1,247 ↑8%           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Token Usage Over Time (24h)                            │
│  [Interactive line chart with Groq/Gemini/Claude]       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  Recent API Calls                                       │
│  Time │ Provider │ Operation    │ Tokens │ Cost        │
│  10:23│ Groq     │ Fact Gen     │ 234    │ $0.01       │
│  10:22│ Gemini   │ Content Exp  │ 1,234  │ $0.04       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│  ⚠️ Budget Warning                                      │
│  Daily budget: 80% used ($4.00 / $5.00)                │
│  [████████████████░░░░░░] 80%                          │
└─────────────────────────────────────────────────────────┘
```

---

## Configuration

### Environment Variables

```bash
# Database
POSTGRES_HOST=nexus-postgres
POSTGRES_DB=nexus
POSTGRES_USER=nexus
POSTGRES_PASSWORD=your_password

# Monitoring API
MONITORING_API_PORT=8000

# Dashboard
DASHBOARD_PORT=3000

# Alerts (optional)
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id

# Budgets
DAILY_BUDGET_USD=5.00
BUDGET_WARNING_THRESHOLD=80
```

### Budgets

```sql
-- Set daily budget
INSERT INTO cost_budgets (
    period_type, start_date, end_date,
    budget_usd, warning_threshold_pct
) VALUES (
    'daily', CURRENT_DATE, CURRENT_DATE + INTERVAL '365 days',
    5.00, 80
);
```

### Pricing Tables

Update pricing in `src/monitoring/cost_calculator.py`:

```python
PRICING = {
    'groq': {
        'llama-3.3-70b-versatile': {'input': 0.59, 'output': 0.79}
    },
    'gemini': {
        'gemini-2.5-flash': {'input': 0.075, 'output': 0.30}
    }
}
```

---

## Deployment

### Docker Compose

```yaml
# Add to infra/docker-compose.yml

services:
  nexus-monitoring-api:
    build:
      context: ..
      dockerfile: infra/Dockerfile.monitoring-api
    ports:
      - "8000:8000"
    environment:
      - POSTGRES_HOST=nexus-postgres
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    depends_on:
      - nexus-postgres

  nexus-dashboard:
    build:
      context: ../frontend
    ports:
      - "3000:80"
    depends_on:
      - nexus-monitoring-api
```

### Deploy

```bash
docker-compose up -d nexus-monitoring-api nexus-dashboard
```

---

## Monitoring Approaches

### 1. Response-Based (Recommended)

Most accurate - uses provider-reported token counts.

**Pros:** Exact, includes all optimizations
**Cons:** Requires API support

### 2. Tiktoken Estimation

Pre-calculates tokens for budget checks.

**Pros:** Works offline, predictable
**Cons:** Estimation only (~5% error)

### 3. Character Approximation

Quick rough estimates (~4 chars/token).

**Pros:** Zero dependencies, very fast
**Cons:** Inaccurate (±30% error)

### 4. Hybrid (Production)

Combines all approaches for different purposes.

**Best for:** Production systems

---

## Analytics

### Key Metrics

- **Total tokens** - Track volume trends
- **Cost per call** - Identify expensive operations
- **Success rate** - Monitor API reliability
- **Tokens/second** - Performance benchmarking
- **ROI score** - Content effectiveness

### Reports

- Daily cost summary
- Weekly trend analysis
- Monthly budget review
- Carousel performance ranking
- Provider cost comparison

### SQL Queries

```sql
-- Token efficiency
SELECT operation, AVG(total_tokens) as avg_tokens
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '7 days'
GROUP BY operation;

-- Cost trending
SELECT DATE(timestamp), SUM(cost_usd)
FROM api_calls
WHERE timestamp >= NOW() - INTERVAL '30 days'
GROUP BY DATE(timestamp)
ORDER BY DATE(timestamp);
```

---

## Alerts

### Types

- **Budget warnings** - 80% threshold
- **Budget exceeded** - 100% threshold
- **High-cost calls** - Single call >$0.50
- **API failures** - Error rate >10%
- **Daily summary** - Morning digest

### Channels

- Telegram (implemented)
- Email (template provided)
- Slack (webhook ready)
- SMS (Twilio integration)

### Configuration

```python
alert_manager = AlertManager(
    telegram_token=os.getenv('TELEGRAM_BOT_TOKEN'),
    telegram_chat_id=os.getenv('TELEGRAM_CHAT_ID')
)

# Check budget
budget_status = calculator.check_budget(db, 'daily')
alert_manager.check_and_alert_budget(budget_status)

# Alert on expensive call
if metrics['cost_usd'] > 0.50:
    alert_manager.alert_high_cost_call(metrics)
```

---

## Best Practices

### 1. Token Optimization

- Use smaller models for simple tasks
- Set appropriate `max_tokens` limits
- Implement prompt caching
- Monitor token efficiency

### 2. Cost Management

- Set realistic budgets
- Monitor trends weekly
- Alert before exceeding
- Review expensive operations

### 3. Monitoring Hygiene

- Log every API call
- Use correlation IDs
- Track retry attempts
- Store error messages

### 4. Data Retention

- Archive data >90 days
- Vacuum database monthly
- Keep summaries forever
- Delete raw logs after 1 year

### 5. Security

- Never log full API keys
- Redact user PII
- Use encrypted connections
- Implement dashboard auth

---

## Performance

### Database

- Indexed for fast queries
- Auto-aggregated daily summaries
- Triggers for real-time updates
- Views for common reports

### API

- Response time <100ms
- WebSocket for real-time
- Connection pooling
- Caching for aggregates

### Dashboard

- Client-side caching
- Lazy loading charts
- Virtualized tables
- WebSocket reconnection

---

## Troubleshooting

### Common Issues

**Database connection failed**
```bash
docker ps | grep postgres
docker logs nexus-postgres
```

**API not responding**
```bash
docker logs nexus-monitoring-api
curl http://localhost:8000/health
```

**Dashboard blank**
```bash
# Check API connectivity
curl http://localhost:8000/api/dashboard/stats

# Check browser console
# Verify CORS settings
```

**WebSocket not connecting**
```bash
wscat -c ws://localhost:8000/ws/metrics
# Check nginx WebSocket proxy config
```

---

## Roadmap

### Implemented ✅

- Database schema with triggers
- Enhanced API clients
- FastAPI monitoring backend
- React dashboard
- WebSocket real-time updates
- Budget tracking
- Alert system
- Comprehensive documentation

### Planned 🚧

- [ ] Authentication (OAuth2)
- [ ] Multi-user support
- [ ] Custom alert rules
- [ ] Grafana integration
- [ ] Prometheus exporter
- [ ] Mobile app
- [ ] ML cost forecasting
- [ ] A/B test analysis

---

## Contributing

### Adding New Providers

1. Update `api_calls` constraint
2. Add pricing to `cost_calculator.py`
3. Enhance client with tracking
4. Update dashboard colors

### Adding New Metrics

1. Add column to `api_calls`
2. Update API client tracking
3. Create view if needed
4. Add to dashboard

---

## Maintenance

### Daily

- Check dashboard
- Review budget status
- Monitor alerts

### Weekly

- Generate usage report
- Review cost trends
- Update budgets

### Monthly

- Archive old data
- Update pricing
- Review ROI metrics
- Vacuum database

### Quarterly

- Security audit
- Performance review
- Feature planning

---

## Support

### Documentation

- [TOKEN_MONITORING_GUIDE.md](./TOKEN_MONITORING_GUIDE.md)
- [DASHBOARD_IMPLEMENTATION.md](./DASHBOARD_IMPLEMENTATION.md)
- [QUICK_START.md](./QUICK_START.md)

### Commands

```bash
# Health checks
docker-compose ps
curl http://localhost:8000/health

# View logs
docker-compose logs -f nexus-monitoring-api

# Database access
docker exec -it nexus-postgres psql -U nexus -d nexus

# Test API
curl http://localhost:8000/api/dashboard/stats | jq
```

---

## License

MIT License - See LICENSE file

---

## Credits

**Created:** 2025-11-18
**Authors:** Nexus Team
**Version:** 1.0.0

**Technologies:**
- FastAPI (Python backend)
- React + TypeScript (Frontend)
- PostgreSQL (Database)
- Recharts (Visualization)
- Tailwind CSS (Styling)
- Docker (Deployment)

---

## Summary

This monitoring system provides complete observability for AI API usage with:

- ✅ Real-time dashboards
- ✅ Cost tracking & budgets
- ✅ Performance analytics
- ✅ ROI analysis
- ✅ Automated alerts
- ✅ Historical reporting
- ✅ Production-ready deployment

**Total Documentation:** 50,000+ words across 3 comprehensive guides

**Setup Time:** 30-45 minutes

**Maintenance:** Low (mostly automated)

Get started with [QUICK_START.md](./QUICK_START.md)! 🚀
