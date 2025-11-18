# Nexus Token Monitoring Dashboard - Implementation Guide

**Version:** 1.0
**Platform:** React + TypeScript + FastAPI
**Style:** Home Assistant-inspired Dark Theme

---

## Table of Contents

1. [Project Structure](#project-structure)
2. [Frontend Setup](#frontend-setup)
3. [Backend API Implementation](#backend-api-implementation)
4. [Docker Deployment](#docker-deployment)
5. [Configuration](#configuration)
6. [Development Workflow](#development-workflow)

---

## Project Structure

```
nexus/
├── frontend/                     # React dashboard
│   ├── public/
│   │   └── index.html
│   ├── src/
│   │   ├── components/
│   │   │   ├── Dashboard.tsx           # Main dashboard
│   │   │   ├── MetricCard.tsx          # Stats card component
│   │   │   ├── RecentCallsTable.tsx    # API calls table
│   │   │   ├── BudgetAlert.tsx         # Budget warnings
│   │   │   ├── TokenChart.tsx          # Token usage charts
│   │   │   ├── CostChart.tsx           # Cost analytics
│   │   │   └── ProviderStats.tsx       # Per-provider metrics
│   │   ├── hooks/
│   │   │   ├── useWebSocket.ts         # Real-time updates
│   │   │   └── useDashboardData.ts     # Data fetching
│   │   ├── types/
│   │   │   └── index.ts                # TypeScript types
│   │   ├── utils/
│   │   │   └── formatters.ts           # Number/date formatting
│   │   ├── App.tsx
│   │   ├── index.tsx
│   │   └── index.css
│   ├── package.json
│   ├── tsconfig.json
│   └── tailwind.config.js
│
├── src/
│   ├── api/
│   │   ├── monitoring_api.py           # FastAPI backend
│   │   └── __init__.py
│   ├── monitoring/
│   │   ├── cost_calculator.py          # Cost tracking
│   │   ├── alerts.py                   # Alert system
│   │   └── __init__.py
│   └── ...
│
├── infra/
│   └── docker-compose.yml              # Updated with dashboard services
│
└── docs/
    └── monitoring/
        ├── TOKEN_MONITORING_GUIDE.md   # ✅ Created
        └── DASHBOARD_IMPLEMENTATION.md # ✅ This file
```

---

## Frontend Setup

### package.json

```json
{
  "name": "nexus-monitoring-dashboard",
  "version": "1.0.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.20.0",
    "recharts": "^2.10.0",
    "axios": "^1.6.0",
    "@tanstack/react-query": "^5.12.0",
    "date-fns": "^3.0.0",
    "lucide-react": "^0.300.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@types/node": "^20.10.0",
    "typescript": "^5.3.0",
    "vite": "^5.0.0",
    "@vitejs/plugin-react": "^4.2.0",
    "tailwindcss": "^3.4.0",
    "autoprefixer": "^10.4.0",
    "postcss": "^8.4.0"
  },
  "scripts": {
    "dev": "vite",
    "build": "tsc && vite build",
    "preview": "vite preview",
    "type-check": "tsc --noEmit"
  }
}
```

### vite.config.ts

```typescript
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 3000,
    proxy: {
      '/api': {
        target: 'http://localhost:8000',
        changeOrigin: true
      },
      '/ws': {
        target: 'ws://localhost:8000',
        ws: true
      }
    }
  }
});
```

### tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["ES2020", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "skipLibCheck": true,
    "moduleResolution": "bundler",
    "allowImportingTsExtensions": true,
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx",
    "strict": true,
    "noUnusedLocals": true,
    "noUnusedParameters": true,
    "noFallthroughCasesInSwitch": true
  },
  "include": ["src"],
  "references": [{ "path": "./tsconfig.node.json" }]
}
```

### tailwind.config.js

```javascript
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        // Home Assistant dark theme
        'ha-dark': '#111111',
        'ha-card': '#1c1c1c',
        'ha-border': '#2c2c2c',
        'ha-accent': '#03a9f4',
        'ha-success': '#4caf50',
        'ha-warning': '#ff9800',
        'ha-error': '#f44336',
      }
    },
  },
  plugins: [],
}
```

### index.css

```css
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  body {
    @apply bg-ha-dark text-gray-100 font-sans antialiased;
  }

  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track {
    @apply bg-ha-dark;
  }

  ::-webkit-scrollbar-thumb {
    @apply bg-ha-border rounded hover:bg-gray-600;
  }
}

@layer components {
  .card {
    @apply bg-ha-card rounded-lg border border-ha-border p-6 shadow-lg;
  }

  .card-header {
    @apply text-lg font-semibold text-gray-200 mb-4;
  }

  .stat-value {
    @apply text-3xl font-bold text-white;
  }

  .stat-label {
    @apply text-sm text-gray-400 uppercase tracking-wide;
  }

  .trend-up {
    @apply text-ha-success;
  }

  .trend-down {
    @apply text-ha-error;
  }

  .btn-primary {
    @apply bg-ha-accent text-white px-4 py-2 rounded hover:bg-blue-600 transition;
  }
}
```

---

## Core Components

### src/types/index.ts

```typescript
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
  errorMessage?: string;
}

export interface DashboardStats {
  totalTokensToday: number;
  totalCostToday: number;
  totalCallsToday: number;
  tokensTrend: number;
  costTrend: number;
  callsTrend: number;
}

export interface HourlyData {
  hour: string;
  groq_tokens?: number;
  gemini_tokens?: number;
  claude_tokens?: number;
}

export interface BudgetStatus {
  status: 'ok' | 'warning' | 'exceeded' | 'no_budget';
  currentSpend: number;
  budget: number;
  usagePct: number;
  remaining: number;
}

export interface ProviderStats {
  provider: string;
  totalCalls: number;
  totalTokens: number;
  totalCost: number;
  avgCostPerCall: number;
  successRate: number;
}
```

### src/hooks/useWebSocket.ts

```typescript
import { useEffect, useState, useCallback, useRef } from 'react';

export function useWebSocket<T>(url: string) {
  const [data, setData] = useState<T | null>(null);
  const [isConnected, setIsConnected] = useState(false);
  const ws = useRef<WebSocket | null>(null);

  const connect = useCallback(() => {
    try {
      ws.current = new WebSocket(url);

      ws.current.onopen = () => {
        console.log('WebSocket connected');
        setIsConnected(true);
      };

      ws.current.onmessage = (event) => {
        const parsed = JSON.parse(event.data);
        setData(parsed);
      };

      ws.current.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

      ws.current.onclose = () => {
        console.log('WebSocket disconnected');
        setIsConnected(false);
        // Reconnect after 5 seconds
        setTimeout(connect, 5000);
      };
    } catch (error) {
      console.error('Failed to connect WebSocket:', error);
    }
  }, [url]);

  useEffect(() => {
    connect();

    return () => {
      if (ws.current) {
        ws.current.close();
      }
    };
  }, [connect]);

  return { data, isConnected };
}
```

### src/hooks/useDashboardData.ts

```typescript
import { useQuery } from '@tanstack/react-query';
import axios from 'axios';
import { DashboardStats, APICallMetrics, HourlyData } from '../types';

interface DashboardData {
  stats: DashboardStats;
  recentCalls: APICallMetrics[];
  hourlyData: HourlyData[];
}

export function useDashboardData() {
  return useQuery<DashboardData>({
    queryKey: ['dashboard'],
    queryFn: async () => {
      const { data } = await axios.get('/api/dashboard/stats');
      return data;
    },
    refetchInterval: 30000, // Refresh every 30 seconds
  });
}

export function useBudgetStatus() {
  return useQuery({
    queryKey: ['budget'],
    queryFn: async () => {
      const { data } = await axios.get('/api/budget/status');
      return data;
    },
    refetchInterval: 60000, // Refresh every minute
  });
}

export function useProviderStats() {
  return useQuery({
    queryKey: ['provider-stats'],
    queryFn: async () => {
      const { data } = await axios.get('/api/analytics/provider-stats');
      return data;
    },
    refetchInterval: 60000,
  });
}
```

### src/components/MetricCard.tsx

```typescript
import React from 'react';
import { TrendingUp, TrendingDown, Minus } from 'lucide-react';

interface MetricCardProps {
  title: string;
  value: string | number;
  trend?: number;
  icon: React.ReactNode;
  subtitle?: string;
}

export const MetricCard: React.FC<MetricCardProps> = ({
  title,
  value,
  trend,
  icon,
  subtitle
}) => {
  const getTrendIcon = () => {
    if (trend === undefined || trend === 0) {
      return <Minus className="w-4 h-4" />;
    }
    return trend > 0 ? (
      <TrendingUp className="w-4 h-4" />
    ) : (
      <TrendingDown className="w-4 h-4" />
    );
  };

  const getTrendColor = () => {
    if (trend === undefined || trend === 0) return 'text-gray-400';
    return trend > 0 ? 'trend-up' : 'trend-down';
  };

  return (
    <div className="card hover:border-ha-accent transition-colors">
      <div className="flex items-start justify-between mb-3">
        <div className="stat-label">{title}</div>
        <div className="text-2xl">{icon}</div>
      </div>

      <div className="stat-value mb-2">{value}</div>

      <div className="flex items-center justify-between">
        {trend !== undefined && (
          <div className={`flex items-center gap-1 text-sm ${getTrendColor()}`}>
            {getTrendIcon()}
            <span>{Math.abs(trend).toFixed(1)}%</span>
          </div>
        )}
        {subtitle && <div className="text-xs text-gray-500">{subtitle}</div>}
      </div>
    </div>
  );
};
```

### src/components/TokenChart.tsx

```typescript
import React from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer
} from 'recharts';
import { HourlyData } from '../types';

interface TokenChartProps {
  data: HourlyData[];
}

export const TokenChart: React.FC<TokenChartProps> = ({ data }) => {
  return (
    <div className="card">
      <h2 className="card-header">Token Usage Over Time (24h)</h2>

      <ResponsiveContainer width="100%" height={300}>
        <LineChart data={data}>
          <CartesianGrid strokeDasharray="3 3" stroke="#2c2c2c" />
          <XAxis
            dataKey="hour"
            stroke="#888"
            style={{ fontSize: '12px' }}
          />
          <YAxis
            stroke="#888"
            style={{ fontSize: '12px' }}
            tickFormatter={(value) => value.toLocaleString()}
          />
          <Tooltip
            contentStyle={{
              backgroundColor: '#1c1c1c',
              border: '1px solid #2c2c2c',
              borderRadius: '8px'
            }}
            labelStyle={{ color: '#fff' }}
          />
          <Legend />
          <Line
            type="monotone"
            dataKey="groq_tokens"
            stroke="#8b5cf6"
            name="Groq"
            strokeWidth={2}
            dot={{ r: 3 }}
            activeDot={{ r: 5 }}
          />
          <Line
            type="monotone"
            dataKey="gemini_tokens"
            stroke="#10b981"
            name="Gemini"
            strokeWidth={2}
            dot={{ r: 3 }}
            activeDot={{ r: 5 }}
          />
          <Line
            type="monotone"
            dataKey="claude_tokens"
            stroke="#3b82f6"
            name="Claude"
            strokeWidth={2}
            dot={{ r: 3 }}
            activeDot={{ r: 5 }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
};
```

### src/components/RecentCallsTable.tsx

```typescript
import React from 'react';
import { formatDistanceToNow } from 'date-fns';
import { CheckCircle, XCircle, ExternalLink } from 'lucide-react';
import { APICallMetrics } from '../types';

interface RecentCallsTableProps {
  calls: APICallMetrics[];
}

export const RecentCallsTable: React.FC<RecentCallsTableProps> = ({ calls }) => {
  const getProviderColor = (provider: string) => {
    const colors = {
      groq: 'text-purple-400',
      gemini: 'text-green-400',
      claude: 'text-blue-400'
    };
    return colors[provider as keyof typeof colors] || 'text-gray-400';
  };

  return (
    <div className="card">
      <div className="flex items-center justify-between mb-4">
        <h2 className="card-header mb-0">Recent API Calls</h2>
        <div className="text-sm text-gray-400">
          Last 20 calls
        </div>
      </div>

      <div className="overflow-x-auto">
        <table className="w-full text-sm">
          <thead>
            <tr className="border-b border-ha-border text-left">
              <th className="py-3 px-4 font-medium text-gray-400">Time</th>
              <th className="py-3 px-4 font-medium text-gray-400">Provider</th>
              <th className="py-3 px-4 font-medium text-gray-400">Model</th>
              <th className="py-3 px-4 font-medium text-gray-400">Operation</th>
              <th className="py-3 px-4 font-medium text-gray-400 text-right">Tokens</th>
              <th className="py-3 px-4 font-medium text-gray-400 text-right">Cost</th>
              <th className="py-3 px-4 font-medium text-gray-400 text-right">Duration</th>
              <th className="py-3 px-4 font-medium text-gray-400 text-center">Status</th>
            </tr>
          </thead>
          <tbody>
            {calls.map((call) => (
              <tr
                key={call.id}
                className="border-b border-ha-border hover:bg-ha-border/50 transition"
              >
                <td className="py-3 px-4 text-gray-400">
                  {formatDistanceToNow(new Date(call.timestamp), { addSuffix: true })}
                </td>
                <td className="py-3 px-4">
                  <span className={`font-medium ${getProviderColor(call.provider)}`}>
                    {call.provider}
                  </span>
                </td>
                <td className="py-3 px-4 text-gray-300 font-mono text-xs">
                  {call.model}
                </td>
                <td className="py-3 px-4 text-gray-300">
                  {call.operation.replace(/_/g, ' ')}
                </td>
                <td className="py-3 px-4 text-right font-mono">
                  {call.totalTokens.toLocaleString()}
                </td>
                <td className="py-3 px-4 text-right font-mono">
                  ${call.costUsd.toFixed(4)}
                </td>
                <td className="py-3 px-4 text-right text-gray-400">
                  {call.durationMs}ms
                </td>
                <td className="py-3 px-4 text-center">
                  {call.success ? (
                    <CheckCircle className="w-5 h-5 text-ha-success inline" />
                  ) : (
                    <XCircle className="w-5 h-5 text-ha-error inline" />
                  )}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};
```

### src/components/BudgetAlert.tsx

```typescript
import React from 'react';
import { AlertTriangle, CheckCircle, XCircle } from 'lucide-react';
import { BudgetStatus } from '../types';

interface BudgetAlertProps {
  budget: BudgetStatus;
}

export const BudgetAlert: React.FC<BudgetAlertProps> = ({ budget }) => {
  if (budget.status === 'no_budget') {
    return null;
  }

  const getStatusConfig = () => {
    switch (budget.status) {
      case 'exceeded':
        return {
          icon: <XCircle className="w-6 h-6" />,
          color: 'border-ha-error bg-ha-error/10',
          textColor: 'text-ha-error',
          title: '🚨 Budget Exceeded',
          barColor: 'bg-ha-error'
        };
      case 'warning':
        return {
          icon: <AlertTriangle className="w-6 h-6" />,
          color: 'border-ha-warning bg-ha-warning/10',
          textColor: 'text-ha-warning',
          title: '⚠️ Budget Warning',
          barColor: 'bg-ha-warning'
        };
      default:
        return {
          icon: <CheckCircle className="w-6 h-6" />,
          color: 'border-ha-success bg-ha-success/10',
          textColor: 'text-ha-success',
          title: '✅ Budget on Track',
          barColor: 'bg-ha-success'
        };
    }
  };

  const config = getStatusConfig();
  const progressWidth = Math.min(budget.usagePct, 100);

  return (
    <div className={`card ${config.color} border-2 mb-8`}>
      <div className="flex items-center gap-3 mb-4">
        <div className={config.textColor}>{config.icon}</div>
        <h2 className={`text-xl font-bold ${config.textColor}`}>
          {config.title}
        </h2>
      </div>

      <div className="grid grid-cols-3 gap-4 mb-4">
        <div>
          <div className="text-sm text-gray-400 mb-1">Current Spend</div>
          <div className="text-2xl font-bold">${budget.currentSpend.toFixed(2)}</div>
        </div>
        <div>
          <div className="text-sm text-gray-400 mb-1">Daily Budget</div>
          <div className="text-2xl font-bold">${budget.budget.toFixed(2)}</div>
        </div>
        <div>
          <div className="text-sm text-gray-400 mb-1">Remaining</div>
          <div className={`text-2xl font-bold ${budget.remaining < 0 ? 'text-ha-error' : ''}`}>
            ${Math.abs(budget.remaining).toFixed(2)}
          </div>
        </div>
      </div>

      <div className="mb-2">
        <div className="flex justify-between text-sm text-gray-400 mb-1">
          <span>Usage</span>
          <span>{budget.usagePct.toFixed(1)}%</span>
        </div>
        <div className="w-full bg-gray-700 rounded-full h-3 overflow-hidden">
          <div
            className={`h-full ${config.barColor} transition-all duration-500`}
            style={{ width: `${progressWidth}%` }}
          />
        </div>
      </div>
    </div>
  );
};
```

### src/components/Dashboard.tsx

```typescript
import React from 'react';
import { DollarSign, Zap, Activity } from 'lucide-react';
import { MetricCard } from './MetricCard';
import { TokenChart } from './TokenChart';
import { RecentCallsTable } from './RecentCallsTable';
import { BudgetAlert } from './BudgetAlert';
import { useDashboardData, useBudgetStatus } from '../hooks/useDashboardData';
import { useWebSocket } from '../hooks/useWebSocket';
import { APICallMetrics } from '../types';

export const Dashboard: React.FC = () => {
  const { data, isLoading, error } = useDashboardData();
  const { data: budgetData } = useBudgetStatus();
  const { data: newCall, isConnected } = useWebSocket<APICallMetrics>(
    `ws://${window.location.host}/ws/metrics`
  );

  // Merge new WebSocket data with existing recent calls
  const [recentCalls, setRecentCalls] = React.useState<APICallMetrics[]>([]);

  React.useEffect(() => {
    if (data?.recentCalls) {
      setRecentCalls(data.recentCalls);
    }
  }, [data]);

  React.useEffect(() => {
    if (newCall) {
      setRecentCalls((prev) => [newCall, ...prev].slice(0, 20));
    }
  }, [newCall]);

  if (isLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-xl">Loading dashboard...</div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-xl text-ha-error">Error loading dashboard</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen p-6">
      {/* Header */}
      <header className="mb-8">
        <div className="flex items-center justify-between">
          <div>
            <h1 className="text-4xl font-bold mb-2">Nexus Token Monitoring</h1>
            <p className="text-gray-400">Real-time AI API usage analytics</p>
          </div>
          <div className="flex items-center gap-2">
            <div className={`w-3 h-3 rounded-full ${isConnected ? 'bg-ha-success' : 'bg-ha-error'}`} />
            <span className="text-sm text-gray-400">
              {isConnected ? 'Live' : 'Disconnected'}
            </span>
          </div>
        </div>
      </header>

      {/* Budget Alert */}
      {budgetData && <BudgetAlert budget={budgetData} />}

      {/* Stats Grid */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
        <MetricCard
          title="Total Tokens Today"
          value={data?.stats.totalTokensToday.toLocaleString() || '0'}
          trend={data?.stats.tokensTrend}
          icon={<Zap />}
          subtitle="vs yesterday"
        />
        <MetricCard
          title="Daily Cost"
          value={`$${data?.stats.totalCostToday.toFixed(2) || '0.00'}`}
          trend={data?.stats.costTrend}
          icon={<DollarSign />}
          subtitle="vs yesterday"
        />
        <MetricCard
          title="API Calls"
          value={data?.stats.totalCallsToday.toLocaleString() || '0'}
          trend={data?.stats.callsTrend}
          icon={<Activity />}
          subtitle="vs yesterday"
        />
      </div>

      {/* Charts */}
      <div className="mb-8">
        <TokenChart data={data?.hourlyData || []} />
      </div>

      {/* Recent Calls */}
      <RecentCallsTable calls={recentCalls} />
    </div>
  );
};
```

### src/App.tsx

```typescript
import React from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { Dashboard } from './components/Dashboard';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      refetchOnWindowFocus: false,
      retry: 1,
    },
  },
});

function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <Dashboard />
    </QueryClientProvider>
  );
}

export default App;
```

---

## Backend API Implementation

### Enhanced monitoring_api.py

See the complete implementation in the TOKEN_MONITORING_GUIDE.md under "Frontend Dashboard Design > Backend API (FastAPI)".

Additional endpoints to add:

```python
@app.get("/api/budget/status")
async def get_budget_status():
    """Get current budget status"""
    db = get_db()
    calculator = CostCalculator()
    status = calculator.check_budget(db, 'daily')
    db.close()
    return status

@app.get("/api/analytics/provider-stats")
async def get_provider_stats():
    """Get stats by provider"""
    db = get_db()
    cursor = db.cursor()

    cursor.execute("""
        SELECT
            provider,
            COUNT(*) as total_calls,
            SUM(total_tokens) as total_tokens,
            SUM(cost_usd) as total_cost,
            AVG(cost_usd) as avg_cost_per_call,
            SUM(CASE WHEN success THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100 as success_rate
        FROM api_calls
        WHERE timestamp >= NOW() - INTERVAL '7 days'
        GROUP BY provider
    """)

    stats = [
        {
            'provider': row[0],
            'totalCalls': row[1],
            'totalTokens': row[2],
            'totalCost': float(row[3]),
            'avgCostPerCall': float(row[4]),
            'successRate': float(row[5])
        }
        for row in cursor.fetchall()
    ]

    db.close()
    return stats
```

---

## Docker Deployment

### Updated docker-compose.yml

Add the following services to your existing `infra/docker-compose.yml`:

```yaml
  # Token Monitoring API
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
      - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
      - TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
    depends_on:
      - nexus-postgres
    networks:
      - nexus-network
    volumes:
      - ../src:/app/src:ro
    command: uvicorn src.api.monitoring_api:app --host 0.0.0.0 --port 8000 --reload

  # Monitoring Dashboard Frontend
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

### Dockerfile.monitoring-api

Create `infra/Dockerfile.monitoring-api`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy source code
COPY src/ ./src/

# Expose port
EXPOSE 8000

# Run API
CMD ["uvicorn", "src.api.monitoring_api:app", "--host", "0.0.0.0", "--port", "8000"]
```

### frontend/Dockerfile

```dockerfile
# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Install dependencies
COPY package.json package-lock.json ./
RUN npm ci

# Copy source and build
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine

# Copy built files
COPY --from=build /app/dist /usr/share/nginx/html

# Copy nginx config
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

### frontend/nginx.conf

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Frontend routes
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Proxy API requests
    location /api {
        proxy_pass http://nexus-monitoring-api:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }

    # WebSocket proxy
    location /ws {
        proxy_pass http://nexus-monitoring-api:8000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "Upgrade";
        proxy_set_header Host $host;
    }

    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;
}
```

---

## Quick Start

### 1. Install Frontend Dependencies

```bash
cd frontend
npm install
```

### 2. Start Development Server

```bash
# Terminal 1: Start backend API
cd src/api
python monitoring_api.py

# Terminal 2: Start frontend
cd frontend
npm run dev
```

### 3. Production Deployment

```bash
# Build and start all services
cd infra
docker-compose up -d nexus-monitoring-api nexus-dashboard

# View logs
docker-compose logs -f nexus-monitoring-api
docker-compose logs -f nexus-dashboard
```

### 4. Access Dashboard

- **Dashboard:** http://localhost:3000
- **API Docs:** http://localhost:8000/docs
- **Health Check:** http://localhost:8000/health

---

## Configuration

### Environment Variables

Add to `infra/.env`:

```bash
# Monitoring API
MONITORING_API_PORT=8000

# Dashboard
DASHBOARD_PORT=3000

# Alerts
TELEGRAM_BOT_TOKEN=your_bot_token
TELEGRAM_CHAT_ID=your_chat_id

# Budget (optional)
DAILY_BUDGET_USD=5.00
BUDGET_WARNING_THRESHOLD=80
```

---

## Development Workflow

### Local Development

```bash
# Watch mode for both frontend and backend
npm run dev          # Frontend with hot reload
uvicorn ... --reload # Backend with auto-reload
```

### Testing

```bash
# Frontend tests
npm test

# Backend tests
pytest src/api/tests/

# Type checking
npm run type-check
```

### Building for Production

```bash
# Frontend build
npm run build

# Check build size
npm run preview
```

---

## Monitoring the Monitor

The dashboard itself should be monitored:

```yaml
# Add to docker-compose.yml healthchecks
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
```

---

## Troubleshooting

### WebSocket not connecting

```typescript
// Check WebSocket URL matches your deployment
const wsUrl = import.meta.env.DEV
  ? 'ws://localhost:8000/ws/metrics'
  : `ws://${window.location.host}/ws/metrics`;
```

### CORS issues

```python
# In monitoring_api.py
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # Development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Database connection errors

```bash
# Check PostgreSQL is accessible
docker exec -it nexus-postgres psql -U nexus -d nexus

# Verify tables exist
\dt

# Check recent data
SELECT COUNT(*) FROM api_calls WHERE timestamp >= CURRENT_DATE;
```

---

## Next Steps

1. ✅ Set up database schema
2. ✅ Deploy monitoring API
3. ✅ Build and deploy dashboard
4. Customize charts and metrics
5. Add authentication (optional)
6. Configure alerts
7. Set up automated reports

---

**Implementation Status:** Ready to Deploy
**Estimated Setup Time:** 2-4 hours
**Maintenance:** Low (automated)
