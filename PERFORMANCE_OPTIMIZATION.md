# ⚡ Performance Optimization Guide

Strategies and configurations for optimizing Cardano RWA platform performance.

## System-Level Optimization

### Memory Optimization

```bash
# Check current memory usage
docker stats

# Expected Memory Usage:
# - Cardano Node: 2-4 GB
# - Ogmios: 512 MB - 1 GB
# - Kupo: 1-2 GB
# - Backend: 256-512 MB
# - Frontend: 128-256 MB
```

**Recommendations:**

1. **Increase Cardano Node Memory** (high sync load)
   ```yaml
   cardano-node:
     deploy:
       resources:
         limits:
           memory: 6G  # From 4G
   ```

2. **Enable JVM Memory Tuning** (if applicable)
   ```bash
   export JVM_OPTS="-Xms1G -Xmx2G"
   ```

### CPU Optimization

```bash
# Monitor CPU usage per container
docker stats --no-stream

# Identify high CPU usage
# If node > 2 cores: check sync progress
# If backend > 0.5 cores: profile endpoints
# If kupo > 1 core: optimize queries
```

**Recommendations:**

1. **Allocate more CPU cores**
   ```yaml
   cardano-node:
     deploy:
       resources:
         limits:
           cpus: '4.0'  # From 2.0
   ```

2. **Enable CPU pinning** (for dedicated servers)
   ```yaml
   cardano-node:
     cpuset: '0-3'  # Pin to cores 0-3
   ```

### Disk I/O Optimization

```bash
# Monitor disk I/O
iostat -x 1 5

# Check disk usage
docker volume ls
du -sh /var/lib/docker/volumes/*/

# Expected Disk Usage:
# - Node DB: 15-30 GB
# - Kupo DB: 5-10 GB
# - Prometheus: 10-20 GB
```

**Recommendations:**

1. **Use SSD storage** (not HDD)
   ```bash
   # Check disk type
   lsblk -d -o name,rota
   # rota=0 is SSD, rota=1 is HDD
   ```

2. **Enable filesystem optimizations**
   ```bash
   # Mount with noatime to reduce I/O
   mount -o noatime /data
   ```

3. **Increase read-ahead** for sequential reads
   ```bash
   blockdev --setra 4096 /dev/sda
   ```

## Database Performance

### Kupo UTxO Index Optimization

**Current Configuration (cardano-rwa-qh/docker-compose.yml):**
```yaml
kupo:
  command: [
    "--node-socket", "/ipc/node.socket",
    "--host", "0.0.0.0",
    "--port", "1442",
    "--match", ".*",           # Matches everything
    "--since", "origin"
  ]
```

**Optimization: Match Specific Policies**

Instead of matching all assets (`.*`), match only your assets:

```yaml
kupo:
  command: [
    "--match", ".$POLICY_ID",  # Match specific policy
    # OR
    "--match", ".(POLICY_1|POLICY_2)",  # Multiple policies
  ]
```

**Benefits:**
- 50-80% faster sync
- 60-70% lower disk usage
- Lower memory consumption

### Prometheus Retention Optimization

**Current:** 200 hours of data

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=200h'
```

**For Production:** Reduce to 30 days, archive old metrics

```yaml
prometheus:
  command:
    - '--storage.tsdb.retention.time=720h'  # 30 days
    - '--storage.tsdb.max-block-duration=24h'
```

## Query Optimization

### Cardano Node Query Performance

**Problem:** Slow queries to blockchain

**Solutions:**

1. **Use local Ogmios instead of Blockfrost**
   - Local: <100ms latency
   - Blockfrost: >500ms latency

2. **Batch queries**
   ```typescript
   // ❌ Bad: Individual queries
   for (const address of addresses) {
     const utxos = await getUtxos(address);
   }
   
   // ✅ Good: Batch queries
   const allUtxos = await getUtxosBatch(addresses);
   ```

3. **Cache frequently accessed data**
   ```typescript
   // Add Redis caching layer
   const utxos = await redis.get(address) 
     || await getUtxos(address);
   ```

### API Response Optimization

**Identify slow endpoints:**

```bash
# Enable timing headers
curl -i http://localhost:8080/api/endpoint
# Look for X-Response-Time header

# Check backend logs for slow queries
docker logs backend | grep "duration:"
```

**Optimization techniques:**

1. **Add pagination**
   ```typescript
   GET /api/holders?page=1&pageSize=100
   ```

2. **Compress responses**
   ```typescript
   app.use(compression());  // Gzip compression
   ```

3. **Enable caching headers**
   ```typescript
   res.set('Cache-Control', 'public, max-age=300');  // 5 minutes
   ```

## Network Optimization

### Bandwidth Optimization

```bash
# Monitor network traffic
nethogs

# Target metrics:
# - Download: < 50 Mbps average
# - Upload: < 10 Mbps average
```

**Optimizations:**

1. **Enable request compression**
   ```yaml
   # In backend API
   app.use(compression());
   ```

2. **Reduce logging verbosity**
   ```bash
   LOG_LEVEL=warn  # Instead of debug
   ```

3. **Implement connection pooling**
   ```typescript
   const pool = new ConnectionPool({ max: 100 });
   ```

### Latency Optimization

```bash
# Measure latency to Cardano network
ping -c 10 <cardano-relay>

# Target: < 50ms latency
```

**Optimizations:**

1. **Use local Cardano infrastructure**
   - Reduces network hops
   - Eliminates external API latency

2. **Deploy closer to network**
   - Use CDN for static assets
   - Regional API endpoints

## Application-Level Optimization

### .NET Backend

**Enable production optimizations:**

```csharp
// Program.cs
if (app.Environment.IsProduction())
{
    app.UseResponseCompression();
    app.UseResponseCaching();
}

// Connection pooling
services.AddPooledDbConnection();

// Caching
services.AddMemoryCache();
services.AddStackExchangeRedisCache();
```

**Configuration:**

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "pooling=true;max pool size=100;"
  }
}
```

### Frontend (Blazor)

**Performance optimizations:**

```csharp
// Enable pre-rendering
@attribute [StreamRendering(true)]

// Lazy load components
<Suspense>
    <ChildContent>
        <HeavyComponent />
    </ChildContent>
    <FallbackContent>
        <div>Loading...</div>
    </FallbackContent>
</Suspense>

// Enable output caching
@attribute [OutputCache(Duration = 60)]
```

## Monitoring & Metrics

### Key Performance Indicators (KPIs)

Monitor these metrics in Grafana:

| Metric | Alert Threshold | Target |
|--------|-----------------|--------|
| API p99 latency | > 500ms | < 100ms |
| Error rate | > 1% | < 0.1% |
| Disk usage | > 80% | < 70% |
| Memory usage | > 85% | < 75% |
| CPU usage | > 80% | < 60% |
| Transaction throughput | < 50 tx/s | > 100 tx/s |

### Prometheus Queries

```promql
# API Response Time (p99)
histogram_quantile(0.99, api_request_duration_seconds_bucket)

# Error Rate
rate(api_errors_total[5m])

# Memory Usage
container_memory_usage_bytes / 1024 / 1024

# CPU Usage
rate(container_cpu_usage_seconds_total[5m]) * 100

# Disk I/O
rate(container_io_read_bytes_recursive[5m]) / 1024 / 1024
```

## Load Testing

### Baseline Establishment

Run load tests before and after optimizations:

```bash
# Generate load test script
./create_load_test_script

# Run load test
artillery run load-test.yml --target http://localhost:8080
```

### Expected Results (Baseline)

```
- Requests: 1000 req/s
- Success: > 95%
- p99 latency: < 200ms
- Error rate: < 1%
```

## Scaling Strategies

### Horizontal Scaling

**When single instance isn't enough:**

1. **Load Balancer Setup**
   ```yaml
   nginx:
     image: nginx:alpine
     ports:
       - "8080:8080"
     volumes:
       - ./nginx.conf:/etc/nginx/nginx.conf
   ```

2. **Multiple Backend Instances**
   ```yaml
   backend:
     deploy:
       replicas: 3
   ```

3. **Database Replication**
   ```yaml
   postgres-primary:
     environment:
       REPLICATION_MODE: master
   postgres-replica:
     environment:
       REPLICATION_MODE: slave
   ```

### Vertical Scaling

**Increase resources on existing instance:**

```bash
# Upgrade server specs
# - RAM: 32 GB → 64 GB
# - CPU: 8 cores → 16 cores
# - Disk: 500 GB SSD → 1 TB NVMe
```

## Benchmarking

### Cardano Node Sync Performance

```bash
# Check sync progress
docker logs cardano-node | grep "Syncing"

# Expected sync time:
# - From genesis: 24-48 hours
# - Recent snapshot: 2-4 hours
```

### Transaction Processing

```bash
# Create and time a transaction
time ./scripts/mint-token.sh \
  --ticker QH-R1 \
  --amount 1000000 \
  --decimals 2

# Expected: < 30 seconds end-to-end
```

## Troubleshooting Performance Issues

### Slow Node Sync

```bash
# Increase peers
docker exec cardano-node \
  cardano-cli query ledger-state

# Check network connectivity
docker exec cardano-node \
  netstat -an | grep ESTABLISHED | wc -l
```

### High Memory Usage

```bash
# Find memory leak
docker exec backend dotnet-stack trace
docker exec backend dotnet-dump collect

# Analyze dump
dotnet-dump analyze core.dmp
```

### High CPU Usage

```bash
# Profile CPU hotspots
docker exec backend dotnet-trace collect

# Analyze profiling data
dotnet-trace convert trace.nettrace
```

## Performance Tuning Checklist

- [ ] Disk: Using SSD (not HDD)
- [ ] Memory: 32GB+ for production
- [ ] CPU: 8+ cores for production
- [ ] Network: < 50ms latency to Cardano network
- [ ] Kupo: Matching specific policies (not all)
- [ ] Prometheus: Retention optimized (30-90 days)
- [ ] Backend: Output caching enabled
- [ ] Frontend: Lazy loading enabled
- [ ] Logs: Info level for production
- [ ] Monitoring: All KPIs tracked
- [ ] Load testing: Baseline established
- [ ] CDN: Static assets cached

---

**Last Updated**: January 2024  
**Next Review**: Quarterly or after major changes

