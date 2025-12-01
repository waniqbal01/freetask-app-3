# Monitoring and Observability Setup for Freetask

This document provides setup instructions for integrating monitoring and observability tools into the Freetask application.

## Table of Contents

- [Sentry Integration (Error Tracking)](#sentry-integration)
- [Prometheus Integration (Metrics)](#prometheus-integration)
- [Recommended Dashboards](#recommended-dashboards)

---

## Sentry Integration (Error Tracking)

Sentry provides real-time error tracking and performance monitoring.

### Backend (NestJS) Setup

1. **Install Sentry SDK**:
```bash
cd freetask-api
npm install @sentry/node @sentry/profiling-node
```

2. **Configure Sentry** in `main.ts`:
```typescript
import * as Sentry from '@sentry/node';
import { ProfilingIntegration } from '@sentry/profiling-node';

async function bootstrap() {
  // Initialize Sentry BEFORE creating NestJS app
  if (process.env.SENTRY_DSN) {
    Sentry.init({
      dsn: process.env.SENTRY_DSN,
      environment: process.env.NODE_ENV || 'development',
      integrations: [
        new ProfilingIntegration(),
      ],
      tracesSampleRate: 1.0, // Adjust for production (0.1 = 10%)
      profilesSampleRate: 1.0,
    });
  }

  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  
  // ... rest of bootstrap code
}
```

3. **Add Sentry Error Filter** (`src/common/filters/sentry.filter.ts`):
```typescript
import { Catch, ArgumentsHost, HttpException } from '@nestjs/common';
import { BaseExceptionFilter } from '@nestjs/core';
import * as Sentry from '@sentry/node';

@Catch()
export class SentryFilter extends BaseExceptionFilter {
  catch(exception: unknown, host: ArgumentsHost) {
    // Send error to Sentry
    if (process.env.SENTRY_DSN) {
      Sentry.captureException(exception);
    }
    
    super.catch(exception, host);
  }
}
```

4. **Apply global filter** in `main.ts`:
```typescript
import { SentryFilter } from './common/filters/sentry.filter';

// In bootstrap function
app.useGlobalFilters(new SentryFilter(httpAdapter));
```

5. **Set environment variable**:
```env
SENTRY_DSN="https://your-sentry-dsn@sentry.io/project-id"
```

### Frontend (Flutter) Setup

1. **Add Sentry dependency** in `pubspec.yaml`:
```yaml
dependencies:
  sentry_flutter: ^7.0.0
```

2. **Initialize Sentry** in `main.dart`:
```dart
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://your-flutter-sentry-dsn@sentry.io/project-id';
      options.environment = 'production'; // or 'development'
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(MyApp()),
  );
}
```

3. **Wrap app with Sentry error boundary**:
```dart
runApp(
  DefaultAssetBundle(
    bundle: SentryAssetBundle(),
    child: MyApp(),
  ),
);
```

### Sentry Account Setup

1. Sign up at [sentry.io](https://sentry.io)
2. Create new project for Backend (Node.js)
3. Create new project for Frontend (Flutter)
4. Copy DSN from project settings
5. Add DSN to environment variables

---

## Prometheus Integration (Metrics)

Prometheus collects time-series metrics for monitoring application performance.

### Backend (NestJS) Setup

1. **Install Prometheus client**:
```bash
cd freetask-api
npm install prom-client
npm install @willsoto/nestjs-prometheus
```

2. **Import Prometheus Module** in `app.module.ts`:
```typescript
import { PrometheusModule } from '@willsoto/nestjs-prometheus';

@Module({
  imports: [
    PrometheusModule.register({
      path: '/metrics',
      defaultMetrics: {
        enabled: true,
      },
    }),
    // ... other imports
  ],
})
export class AppModule {}
```

3. **Custom Metrics** (optional) in a service:
```typescript
import { Injectable } from '@nestjs/common';
import { Counter, Histogram } from 'prom-client';
import { InjectMetric } from '@willsoto/nestjs-prometheus';

@Injectable()
export class JobsService {
  constructor(
    @InjectMetric('jobs_created_total')
    private readonly jobsCreatedCounter: Counter,
    
    @InjectMetric('job_creation_duration_seconds')
    private readonly jobCreationHistogram: Histogram,
  ) {}

  async createJob(dto: CreateJobDto) {
    const end = this.jobCreationHistogram.startTimer();
    
    try {
      // Create job logic
      const job = await this.prisma.job.create({ data: dto });
      
      // Increment counter
      this.jobsCreatedCounter.inc();
      
      return job;
    } finally {
      end(); // Record duration
    }
  }
}
```

4. **Register custom metrics** in module providers:
```typescript
import { makeCounterProvider, makeHistogramProvider } from '@willsoto/nestjs-prometheus';

@Module({
  providers: [
    makeCounterProvider({
      name: 'jobs_created_total',
      help: 'Total number of jobs created',
    }),
    makeHistogramProvider({
      name: 'job_creation_duration_seconds',
      help: 'Job creation duration in seconds',
    }),
  ],
})
export class JobsModule {}
```

### Prometheus Server Setup

**Docker Compose** (`prometheus.yml`):
```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'

volumes:
  prometheus_data:
```

**Prometheus Configuration** (`prometheus.yml`):
```yaml
global:
  scrape_interval: 15s # Scrape targets every 15 seconds
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'freetask-api'
    static_configs:
      - targets: ['api:4000'] # Adjust to your API host:port
    metrics_path: '/metrics'
```

**Run Prometheus**:
```bash
docker-compose -f prometheus.yml up -d
```

Access Prometheus UI at `http://localhost:9090`.

---

## Recommended Dashboards

### Key Metrics to Track

#### Application Performance
- **Request Rate**: Requests per second (RPS)
- **Response Time**: P50, P95, P99 latencies
- **Error Rate**: 4xx and 5xx errors per minute
- **Uptime**: Application availability percentage

#### Database Metrics
- **Query Duration**: Average and P95 query times
- **Connection Pool**: Active/idle connections
- **Query Count**: Queries per second
- **Slow Queries**: Queries exceeding threshold

#### Business Metrics
- **User Registrations**: New users per day
- **Jobs Created**: Total jobs created
- **Completed Jobs**: Jobs marked as completed
- **Active Chat Sessions**: Number of ongoing chats

### Sample Prometheus Queries

**Request Rate**:
```promql
rate(http_requests_total[5m])
```

**Average Response Time**:
```promql
rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m])
```

**Error Rate (4xx/5xx)**:
```promql
sum(rate(http_requests_total{status=~"4..|5.."}[5m]))
```

**Jobs Created (last hour)**:
```promql
increase(jobs_created_total[1h])
```

### Grafana Dashboards

1. **Install Grafana**:
```yaml
# Add to docker-compose.yml
grafana:
  image: grafana/grafana:latest
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
  volumes:
    - grafana_data:/var/lib/grafana
```

2. **Configure Prometheus as Data Source**:
   - Access Grafana at `http://localhost:3000`
   - Login with `admin` / `admin`
   - Add Prometheus data source: `http://prometheus:9090`

3. **Import Dashboard**:
   - Use pre-built Node.js dashboard ID: `11159`
   - Or create custom dashboard with recommended metrics

### Alerting Rules

**Configure alerts** in `prometheus-alerts.yml`:
```yaml
groups:
  - name: freetask_alerts
    rules:
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.1
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"

      - alert: SlowResponseTime
        expr: rate(http_request_duration_seconds_sum[5m]) / rate(http_request_duration_seconds_count[5m]) > 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Slow response time detected"
          description: "Average response time is {{ $value }}s"

      - alert: DatabaseConnectionPoolExhausted
        expr: database_connections_active / database_connections_max > 0.9
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Database connection pool near capacity"
```

---

## Cost Considerations

- **Sentry**: Free tier includes 5k events/month, upgrade for higher limits
- **Prometheus**: Self-hosted (free), cloud options available (Grafana Cloud, Datadog)
- **Storage**: Prometheus data grows over time, plan for disk space

---

## Next Steps

1. Set up Sentry projects and integrate DSNs
2. Deploy Prometheus alongside your application
3. Configure Grafana dashboards
4. Set up alerting (PagerDuty, Slack, Email)
5. Monitor metrics and iterate on thresholds

For production deployments, consider managed monitoring solutions like:
- **Datadog**: https://www.datadoghq.com
- **New Relic**: https://newrelic.com
- **Grafana Cloud**: https://grafana.com/products/cloud

