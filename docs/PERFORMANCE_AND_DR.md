# Performance & Disaster Recovery Guide

## Overview

This guide covers performance benchmarking, optimization strategies, and comprehensive disaster recovery planning for the Cardano RWA platform.

## Part 1: Performance Optimization

### 1.1 Baseline Metrics

Define performance targets in `performance/baselines.json`:

```json
{
  "api_latency": {
    "p50_ms": 100,
    "p95_ms": 500,
    "p99_ms": 1000,
    "max_ms": 2000
  },
  "throughput": {
    "requests_per_second": 1000,
    "concurrent_users": 100,
    "error_rate_percent": 0.5
  },
  "database": {
    "query_p95_ms": 50,
    "connection_pool_utilization_percent": 70
  },
  "blockchain": {
    "tx_submission_ms": 500,
    "block_confirmation_seconds": 10
  },
  "resources": {
    "memory_limit_mb": 4096,
    "cpu_cores": 4
  }
}
```

### 1.2 Performance Regression Testing

Create `tests/performance/performance-regression.k6.js`:

```javascript
import http from 'k6/http';
import { check, sleep, group } from 'k6';
import { Trend, Rate, Counter, Gauge } from 'k6/metrics';

// Custom metrics
const apiLatency = new Trend('api_latency_ms', { unit: 'ms' });
const dbLatency = new Trend('db_latency_ms');
const throughput = new Counter('throughput');
const errorRate = new Rate('errors');
const concurrentUsers = new Gauge('concurrent_users');

// Performance thresholds
export const options = {
  vus: 50,
  duration: '5m',
  thresholds: {
    'api_latency_ms': ['p95<500', 'p99<1000'],
    'db_latency_ms': ['p95<50'],
    'errors': ['rate<0.005'],  // < 0.5% error rate
  },
};

export default function () {
  concurrentUsers.set(__VU);

  group('API Performance', () => {
    // Test asset listing
    const listResponse = http.get('http://localhost:5000/api/v1/assets');
    
    check(listResponse, {
      'list status 200': (r) => r.status === 200,
      'list latency < 500ms': (r) => r.timings.duration < 500,
    });

    apiLatency.add(listResponse.timings.duration);
    errorRate.add(listResponse.status !== 200);
    throughput.add(1);

    sleep(1);

    // Test asset creation
    const createResponse = http.post(
      'http://localhost:5000/api/v1/assets',
      JSON.stringify({
        name: 'Performance Test Asset',
        value: 1000000,
      }),
      { headers: { 'Content-Type': 'application/json' } }
    );

    check(createResponse, {
      'create status 201': (r) => r.status === 201,
      'create latency < 1000ms': (r) => r.timings.duration < 1000,
    });

    apiLatency.add(createResponse.timings.duration);
    errorRate.add(createResponse.status !== 201);
    throughput.add(1);

    sleep(1);
  });
}
```

### 1.3 Database Query Optimization

Create `performance/query-analysis.sql`:

```sql
-- Identify slow queries
SELECT 
  query,
  calls,
  mean_exec_time as avg_ms,
  max_exec_time as max_ms,
  total_exec_time as total_ms
FROM pg_stat_statements
WHERE mean_exec_time > 50
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Check index usage
SELECT 
  schemaname,
  tablename,
  indexname,
  idx_scan,
  idx_tup_read,
  idx_tup_fetch
FROM pg_stat_user_indexes
ORDER BY idx_scan DESC;

-- Connection pool analysis
SELECT 
  state,
  count(*) as connection_count
FROM pg_stat_activity
GROUP BY state;

-- Query plan analysis
EXPLAIN ANALYZE
SELECT a.id, a.name, a.value, c.status
FROM assets a
LEFT JOIN compliance_records c ON a.id = c.asset_id
WHERE a.created_at > NOW() - INTERVAL '30 days'
ORDER BY a.created_at DESC
LIMIT 100;
```

### 1.4 Caching Strategy

Create `Infrastructure/CacheService.cs`:

```csharp
using StackExchange.Redis;
using System.Text.Json;

public class CacheService
{
    private readonly IConnectionMultiplexer _redis;
    private readonly ILogger<CacheService> _logger;
    private readonly TimeSpan _defaultExpiration = TimeSpan.FromMinutes(10);

    public CacheService(IConnectionMultiplexer redis, ILogger<CacheService> logger)
    {
        _redis = redis;
        _logger = logger;
    }

    public async Task<T?> GetAsync<T>(string key)
    {
        try
        {
            var db = _redis.GetDatabase();
            var value = await db.StringGetAsync(key);

            if (value.IsNull)
            {
                _logger.LogDebug($"Cache miss: {key}");
                return default;
            }

            _logger.LogDebug($"Cache hit: {key}");
            return JsonSerializer.Deserialize<T>(value.ToString());
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Cache read error");
            return default;  // Graceful fallback
        }
    }

    public async Task SetAsync<T>(string key, T value, TimeSpan? expiration = null)
    {
        try
        {
            var db = _redis.GetDatabase();
            var json = JsonSerializer.Serialize(value);
            await db.StringSetAsync(
                key,
                json,
                expiration ?? _defaultExpiration);

            _logger.LogDebug($"Cache set: {key}");
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Cache write error");
            // Don't throw - cache is optional
        }
    }

    public async Task InvalidateAsync(string pattern)
    {
        try
        {
            var server = _redis.GetServer(_redis.GetEndPoints().First());
            var keys = server.Keys(pattern: $"*{pattern}*");
            
            if (keys.Count() > 0)
            {
                await _redis.GetDatabase().KeyDeleteAsync(keys.ToArray());
                _logger.LogInformation($"Invalidated {keys.Count()} cache entries");
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Cache invalidation error");
        }
    }
}
```

### 1.5 CDN Configuration (CloudFront)

```hcl
# terraform/modules/cdn/main.tf
resource "aws_cloudfront_distribution" "main" {
  origin {
    domain_name = aws_s3_bucket.assets.bucket_regional_domain_name
    origin_id   = "s3-assets"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.main.cloudfront_access_identity_path
    }
  }

  enabled = true

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-assets"

    # Aggressive caching for static assets
    cache_policy_id = aws_cloudfront_cache_policy.static.id
    compress        = true

    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache policy for static assets (max 1 year)
  viewer_restriction {
    restriction_type = "none"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # Custom cache behavior for HTML (cache for 1 hour)
  ordered_cache_behavior {
    path_pattern     = "*.html"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "s3-assets"

    cache_policy_id = data.aws_cloudfront_cache_policy.html.id

    viewer_protocol_policy = "redirect-to-https"
  }

  tags = {
    Name = "${var.environment}-cdn"
  }
}
```

## Part 2: Disaster Recovery

### 2.1 Disaster Recovery Plan (DRP)

Create `docs/DISASTER_RECOVERY_PLAN.md`:

```markdown
# Disaster Recovery Plan

## RTO and RPO Targets

| Scenario | RTO | RPO | Priority |
|----------|-----|-----|----------|
| Database failure | 15 min | 5 min | Critical |
| K8s cluster failure | 30 min | 10 min | Critical |
| API service degradation | 5 min | 1 min | High |
| Blockchain node failure | 10 min | 5 min | High |
| IPFS node failure | 60 min | 30 min | Medium |
| Workstation compromise | 4 hours | 1 hour | Medium |

## Backup Strategy

### Database Backups
- **Frequency:** Hourly continuous replication
- **Retention:** 30 days
- **Location:** S3 with cross-region replication
- **Test:** Weekly restore to test environment

### Configuration Backups
- **Frequency:** On every change (Git-based)
- **Location:** GitHub + Vault
- **Retention:** Indefinite

### Blockchain State
- **Frequency:** Daily snapshots
- **Location:** IPFS + S3
- **Retention:** 90 days

## Failover Procedures

### Database Failover
1. Detect primary failure (5 min)
2. Promote hot-standby to primary (2 min)
3. Update connection strings (1 min)
4. Verify data consistency (2 min)
5. Alert on-call team (1 min)
**Total RTO: 11 minutes**

### Kubernetes Cluster Failover
1. Detect cluster failure (2 min)
2. Spin up new cluster from IaC (20 min)
3. Deploy applications via ArgoCD (5 min)
4. Health checks (2 min)
5. DNS cutover (1 min)
**Total RTO: 30 minutes**

## Restoration Procedures

### From Database Snapshot
\`\`\`bash
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier cardano-rwa-restored \
  --db-snapshot-identifier rds:cardano-rwa-2025-01-15-03-00 \
  --db-instance-class db.t3.large

# Verify
psql -h restored-instance.amazonaws.com -U postgres -d cardano_rwa -c "SELECT COUNT(*) FROM assets;"
\`\`\`

### From Kubernetes Backup
\`\`\`bash
velero restore create --from-backup cardano-rwa-2025-01-15-03-00
velero restore describe cardano-rwa-2025-01-15-03-00
\`\`\`

## Communication Plan

- **Executive notification:** < 15 min
- **Customer notification:** < 30 min
- **Status page update:** < 5 min
- **Incident channel:** Slack #incidents
- **Post-incident review:** Within 24 hours
```

### 2.2 Backup Automation

Create `.github/workflows/backups.yml`:

```yaml
name: Backup

on:
  schedule:
    - cron: '0 * * * *'  # Hourly

jobs:
  database-backup:
    runs-on: ubuntu-latest
    steps:
      - name: Backup RDS
        run: |
          aws rds create-db-snapshot \
            --db-instance-identifier cardano-rwa-prod \
            --db-snapshot-identifier cardano-rwa-$(date +%Y%m%d-%H%M%S)

      - name: Backup to S3
        run: |
          aws s3 cp s3://cardano-rwa-backups/ \
                    s3://cardano-rwa-backups-archive/ \
                    --recursive \
                    --exclude "*" \
                    --include "rds-*.snapshot"

  k8s-backup:
    runs-on: ubuntu-latest
    steps:
      - name: Install Velero
        run: |
          wget https://github.com/vmware-tanzu/velero/releases/download/v1.11.0/velero-v1.11.0-linux-amd64.tar.gz
          tar -xzf velero-v1.11.0-linux-amd64.tar.gz

      - name: Create Backup
        run: |
          velero backup create cardano-rwa-$(date +%Y%m%d-%H%M%S) \
            --include-namespaces cardano-rwa \
            --wait

      - name: Verify Backup
        run: velero backup logs cardano-rwa-$(date +%Y%m%d-%H%M%S)
```

### 2.3 Disaster Recovery Testing

Create `tests/dr/dr-test.sh`:

```bash
#!/bin/bash

echo "🔄 Starting DR Test..."

# 1. Create database snapshot
echo "1️⃣ Creating database snapshot..."
SNAPSHOT_ID="dr-test-$(date +%s)"
aws rds create-db-snapshot \
  --db-instance-identifier cardano-rwa-prod \
  --db-snapshot-identifier "$SNAPSHOT_ID"

# Wait for snapshot
aws rds wait db-snapshot-available \
  --db-snapshot-identifier "$SNAPSHOT_ID"

# 2. Restore to test instance
echo "2️⃣ Restoring to test instance..."
TEST_INSTANCE="cardano-rwa-dr-test"

aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier "$TEST_INSTANCE" \
  --db-snapshot-identifier "$SNAPSHOT_ID" \
  --db-instance-class t3.medium

aws rds wait db-instance-available \
  --db-instance-identifier "$TEST_INSTANCE"

# 3. Run integration tests against restored DB
echo "3️⃣ Running integration tests..."
TEST_DB_ENDPOINT=$(aws rds describe-db-instances \
  --db-instance-identifier "$TEST_INSTANCE" \
  --query 'DBInstances[0].Endpoint.Address' \
  --output text)

PGPASSWORD=postgres psql -h "$TEST_DB_ENDPOINT" -U postgres -d cardano_rwa -c \
  "SELECT COUNT(*) as asset_count FROM assets;" || exit 1

# 4. Verify data consistency
echo "4️⃣ Verifying data consistency..."
PROD_COUNT=$(PGPASSWORD=postgres psql -h prod.amazonaws.com -U postgres -d cardano_rwa -t -c \
  "SELECT COUNT(*) FROM assets;")

TEST_COUNT=$(PGPASSWORD=postgres psql -h "$TEST_DB_ENDPOINT" -U postgres -d cardano_rwa -t -c \
  "SELECT COUNT(*) FROM assets;")

if [ "$PROD_COUNT" -eq "$TEST_COUNT" ]; then
  echo "✅ Data consistency verified ($PROD_COUNT assets)"
else
  echo "❌ Data mismatch! Prod: $PROD_COUNT, Test: $TEST_COUNT"
  exit 1
fi

# 5. Cleanup
echo "5️⃣ Cleaning up test resources..."
aws rds delete-db-instance \
  --db-instance-identifier "$TEST_INSTANCE" \
  --skip-final-snapshot

aws rds delete-db-snapshot \
  --db-snapshot-identifier "$SNAPSHOT_ID"

echo "✨ DR Test completed successfully!"
```

## Part 3: Observability for Performance

### 3.1 SLO/SLI Dashboard

Create Grafana dashboard JSON at `k8s/grafana/slo-dashboard.json`:

```json
{
  "dashboard": {
    "title": "SLO/SLI Tracking",
    "panels": [
      {
        "title": "API Availability SLI",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~'2..'}[5m])) / sum(rate(http_requests_total[5m])) * 100"
          }
        ],
        "threshold": 99.9,
        "thresholdStyle": "critical"
      },
      {
        "title": "Mint TX Latency p95",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(mint_duration_seconds_bucket[5m]))"
          }
        ],
        "threshold": 2,
        "unit": "seconds"
      },
      {
        "title": "Database Query Latency p99",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, rate(db_query_duration_seconds_bucket[5m]))"
          }
        ],
        "threshold": 0.05,
        "unit": "seconds"
      }
    ]
  }
}
```

### 3.2 Alert Rules

Create `k8s/prometheus/slo-alerts.yml`:

```yaml
groups:
  - name: slo_alerts
    rules:
      - alert: APIAvailabilityBelowSLO
        expr: |
          sum(rate(http_requests_total{status=~'2..'}[5m])) / 
          sum(rate(http_requests_total[5m])) < 0.999
        for: 5m
        annotations:
          summary: "API availability below SLO (99.9%)"

      - alert: MintLatencyAboveSLO
        expr: |
          histogram_quantile(0.95, rate(mint_duration_seconds_bucket[5m])) > 2
        for: 10m
        annotations:
          summary: "Mint latency p95 above SLO (> 2s)"

      - alert: DatabaseLatencyAboveSLO
        expr: |
          histogram_quantile(0.99, rate(db_query_duration_seconds_bucket[5m])) > 0.05
        for: 10m
        annotations:
          summary: "Database latency p99 above SLO (> 50ms)"
```

## Success Criteria (for Gap #5 & #9 closure)

✅ Performance baselines established  
✅ Regression tests in CI/CD  
✅ Database query optimization completed  
✅ Caching layer deployed  
✅ CDN configured for static assets  
✅ RTO/RPO targets defined for all scenarios  
✅ Backup automation running hourly  
✅ DR test executed monthly  
✅ SLO/SLI metrics visible in Grafana  
✅ Runbooks documented for all failure scenarios  
✅ < 5% deviation from baseline performance  
✅ 99.9% availability achieved in production  
✅ Team trained on incident response  
