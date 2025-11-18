# Nexus Token Monitoring - Quick Start Guide

Get your monitoring system up and running in 30 minutes!

---

## Prerequisites

- ✅ PostgreSQL running (nexus-postgres container)
- ✅ Python 3.11+
- ✅ Node.js 20+ (for dashboard)
- ✅ Docker & Docker Compose

---

## Step 1: Database Setup (5 minutes)

### Apply the monitoring schema

```bash
# Connect to PostgreSQL
docker exec -i nexus-postgres psql -U nexus -d nexus < migrations/001_monitoring_schema.sql

# Verify tables created
docker exec -it nexus-postgres psql -U nexus -d nexus -c "\dt"
```

Expected output:
```
                List of relations
 Schema |         Name          | Type  | Owner
--------+-----------------------+-------+-------
 public | alert_history         | table | nexus
 public | api_calls             | table | nexus
 public | carousel_performance  | table | nexus
 public | cost_budgets          | table | nexus
 public | daily_usage_summary   | table | nexus
```

### Verify views and triggers

```bash
# Check views
docker exec -it nexus-postgres psql -U nexus -d nexus -c "\dv"

# Check triggers
docker exec -it nexus-postgres psql -U nexus -d nexus -c "
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_schema = 'public';
"
```

---

## Step 2: Backend Dependencies (3 minutes)

### Install Python packages

```bash
# Add to requirements.txt (if not already present)
cat >> requirements.txt <<EOF
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
psycopg2-binary>=2.9.9
structlog>=23.2.0
python-multipart>=0.0.6
websockets>=12.0
EOF

# Install
pip install -r requirements.txt
```

### Create monitoring package

```bash
# Create directories
mkdir -p src/monitoring
mkdir -p src/api

# Create __init__.py files
touch src/monitoring/__init__.py
touch src/api/__init__.py
```

---

## Step 3: Enhanced API Clients (10 minutes)

### Update Groq Client

Create `src/api_clients/groq_client_enhanced.py`:

```python
# See TOKEN_MONITORING_GUIDE.md section "API Client Integration"
# Copy the enhanced GroqClient implementation
```

Or update your existing `src/api_clients/groq_client.py` with token tracking.

**Key additions:**
- Import `structlog`
- Add `db_connection` parameter
- Return tuple `(text, metrics)`
- Call `_store_metrics()` after each request

### Update Gemini Client

Similar updates to `src/api_clients/gemini_client.py`

---

## Step 4: Start Monitoring API (5 minutes)

### Create the API

Copy from `TOKEN_MONITORING_GUIDE.md`:

```bash
# Create monitoring API
cat > src/api/monitoring_api.py <<'EOF'
# (Copy the FastAPI implementation from the guide)
EOF
```

### Start the API

```bash
# Development mode
cd src/api
uvicorn monitoring_api:app --reload --host 0.0.0.0 --port 8000

# Or via Docker (recommended)
docker-compose up -d nexus-monitoring-api
```

### Test the API

```bash
# Health check
curl http://localhost:8000/health

# Get dashboard stats
curl http://localhost:8000/api/dashboard/stats

# API docs
open http://localhost:8000/docs
```

---

## Step 5: Frontend Dashboard (10 minutes)

### Initialize React project

```bash
# Create frontend directory
mkdir -p frontend
cd frontend

# Initialize with Vite
npm create vite@latest . -- --template react-ts

# Install dependencies
npm install recharts axios @tanstack/react-query date-fns lucide-react

# Install Tailwind
npm install -D tailwindcss postcss autoprefixer
npx tailwindcss init -p
```

### Copy dashboard components

```bash
# Create component directories
mkdir -p src/components src/hooks src/types src/utils

# Copy files from DASHBOARD_IMPLEMENTATION.md
# - src/components/Dashboard.tsx
# - src/components/MetricCard.tsx
# - src/components/TokenChart.tsx
# - src/components/RecentCallsTable.tsx
# - src/components/BudgetAlert.tsx
# - src/hooks/useWebSocket.ts
# - src/hooks/useDashboardData.ts
# - src/types/index.ts
# - tailwind.config.js
# - vite.config.ts
```

### Start the dashboard

```bash
# Development server
npm run dev

# Opens at http://localhost:3000
```

---

## Step 6: Test End-to-End (5 minutes)

### Generate test data

```python
# Create test_monitoring.py
import os
from src.api_clients.groq_client import GroqClient
import psycopg2

# Connect to DB
db = psycopg2.connect(
    host='localhost',
    port=5432,
    database='nexus',
    user='nexus',
    password=os.getenv('POSTGRES_PASSWORD')
)

# Initialize client
groq = GroqClient(
    api_key=os.getenv('GROQ_API_KEY'),
    db_connection=db
)

# Make a test call
text, metrics = groq.generate_text(
    prompt="Say hello in 5 words",
    correlation_id="test-123",
    operation="test"
)

print(f"Response: {text}")
print(f"Tokens: {metrics['total_tokens']}")
print(f"Cost: ${metrics['cost_usd']}")

db.close()
```

Run it:

```bash
python test_monitoring.py
```

### Check the dashboard

1. Open http://localhost:3000
2. You should see:
   - Updated token count
   - Cost metrics
   - New entry in "Recent API Calls" table
   - Chart updated (if within 24h window)

### Verify database

```bash
docker exec -it nexus-postgres psql -U nexus -d nexus -c "
SELECT
    timestamp,
    provider,
    operation,
    total_tokens,
    cost_usd
FROM api_calls
ORDER BY timestamp DESC
LIMIT 5;
"
```

---

## Step 7: Production Deployment (5 minutes)

### Update docker-compose.yml

Add to `infra/docker-compose.yml`:

```yaml
  nexus-monitoring-api:
    build:
      context: ..
      dockerfile: infra/Dockerfile.monitoring-api
    container_name: nexus-monitoring-api
    restart: unless-stopped
    ports:
      - "8000:8000"
    environment:
      - POSTGRES_HOST=nexus-postgres
      - POSTGRES_DB=${POSTGRES_DB}
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    depends_on:
      - nexus-postgres
    networks:
      - nexus-network
    volumes:
      - ../src:/app/src:ro

  nexus-dashboard:
    build:
      context: ../frontend
      dockerfile: Dockerfile
    container_name: nexus-dashboard
    restart: unless-stopped
    ports:
      - "3000:80"
    depends_on:
      - nexus-monitoring-api
    networks:
      - nexus-network
```

### Create Dockerfiles

```bash
# Backend Dockerfile
cat > infra/Dockerfile.monitoring-api <<'EOF'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ./src/
EXPOSE 8000
CMD ["uvicorn", "src.api.monitoring_api:app", "--host", "0.0.0.0", "--port", "8000"]
EOF

# Frontend Dockerfile (see DASHBOARD_IMPLEMENTATION.md)
```

### Deploy

```bash
cd infra
docker-compose up -d nexus-monitoring-api nexus-dashboard

# Check logs
docker-compose logs -f nexus-monitoring-api
docker-compose logs -f nexus-dashboard
```

### Access production dashboard

- Dashboard: http://100.122.207.23:3000
- API: http://100.122.207.23:8000
- API Docs: http://100.122.207.23:8000/docs

---

## Configuration

### Set budgets

```sql
-- Daily budget
INSERT INTO cost_budgets (
    period_type, start_date, end_date,
    budget_usd, warning_threshold_pct,
    created_by
) VALUES (
    'daily', CURRENT_DATE, CURRENT_DATE + INTERVAL '365 days',
    5.00, 80, 'admin'
);

-- Monthly budget
INSERT INTO cost_budgets (
    period_type, start_date, end_date,
    budget_usd, warning_threshold_pct,
    created_by
) VALUES (
    'monthly',
    DATE_TRUNC('month', CURRENT_DATE)::DATE,
    (DATE_TRUNC('month', CURRENT_DATE) + INTERVAL '12 months')::DATE,
    150.00, 85, 'admin'
);
```

### Configure alerts (optional)

Add to `infra/.env`:

```bash
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
```

---

## Verification Checklist

- [ ] Database tables created
- [ ] Views and triggers working
- [ ] Monitoring API responding
- [ ] Dashboard accessible
- [ ] Test API call logged
- [ ] Dashboard shows real-time data
- [ ] WebSocket connection active (green dot)
- [ ] Budget alerts configured
- [ ] Docker containers running

---

## Common Issues

### Issue: Database connection refused

**Solution:**
```bash
# Check PostgreSQL is running
docker ps | grep postgres

# Check connection from host
docker exec -it nexus-postgres psql -U nexus -d nexus -c "SELECT 1;"
```

### Issue: API returns 500 error

**Solution:**
```bash
# Check API logs
docker logs nexus-monitoring-api

# Common cause: missing environment variables
docker exec nexus-monitoring-api env | grep POSTGRES
```

### Issue: Dashboard shows "Loading..." forever

**Solution:**
```bash
# Check API is accessible from frontend
curl http://localhost:8000/api/dashboard/stats

# Check CORS settings in monitoring_api.py
# Should allow origin from frontend
```

### Issue: WebSocket not connecting

**Solution:**
```bash
# Check WebSocket endpoint
wscat -c ws://localhost:8000/ws/metrics

# Verify nginx config has WebSocket proxy settings
```

---

## Next Steps

### 1. Integrate with carousel generation

Update `scripts/composite.py` to use enhanced clients:

```python
from src.api_clients.groq_client import GroqClient

# Pass correlation_id for linking
carousel_id = str(uuid.uuid4())
fact, metrics = groq.generate_text(
    prompt=prompt,
    correlation_id=carousel_id,
    operation="fact_generation"
)
```

### 2. Set up daily reports

Create cron job:

```bash
# Add to crontab
0 9 * * * python /home/didac/nexus/scripts/daily_report.py
```

### 3. Configure Telegram alerts

```python
# In src/monitoring/alerts.py
alert_manager = AlertManager(
    telegram_token=os.getenv('TELEGRAM_BOT_TOKEN'),
    telegram_chat_id=os.getenv('TELEGRAM_CHAT_ID')
)

# Check budget daily
budget_status = cost_calculator.check_budget(db, 'daily')
alert_manager.check_and_alert_budget(budget_status)
```

### 4. Optimize costs

Use dashboard insights to:
- Identify expensive operations
- Compare model costs
- Find prompt inefficiencies
- Set tighter budgets

---

## Maintenance

### Daily

- Check dashboard for anomalies
- Review budget status

### Weekly

- Generate usage report
- Review carousel performance
- Adjust budgets if needed

### Monthly

- Archive old data (>90 days)
- Update pricing tables
- Review ROI metrics

---

## Support

### Documentation

- [TOKEN_MONITORING_GUIDE.md](./TOKEN_MONITORING_GUIDE.md) - Complete guide
- [DASHBOARD_IMPLEMENTATION.md](./DASHBOARD_IMPLEMENTATION.md) - Frontend details

### Troubleshooting

```bash
# Check all services
docker-compose ps

# View logs
docker-compose logs -f

# Database queries
docker exec -it nexus-postgres psql -U nexus -d nexus

# API health
curl http://localhost:8000/health
```

---

## Success Metrics

After setup, you should have:

✅ **Real-time visibility** into token usage
✅ **Cost tracking** across all AI providers
✅ **Budget alerts** before overspending
✅ **Performance metrics** for optimization
✅ **ROI analysis** for content
✅ **Historical data** for forecasting

---

**Estimated Setup Time:** 30-45 minutes
**Difficulty:** Intermediate
**Maintenance:** Low (mostly automated)

Good luck! 🚀
