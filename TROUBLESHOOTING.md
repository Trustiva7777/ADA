# 🔧 Troubleshooting Guide

Common issues and solutions for the Cardano RWA Platform.

## Docker & Infrastructure Issues

### Services Won't Start

**Problem**: Docker containers fail to start

**Solutions**:

1. Check Docker daemon is running
   ```bash
   docker ps
   docker-compose --version
   ```

2. Clear and rebuild
   ```bash
   docker-compose down -v  # Remove volumes
   docker-compose up --build -d
   ```

3. Check logs
   ```bash
   docker-compose logs -f cardano-node
   docker-compose logs -f ogmios
   ```

### Port Already in Use

**Problem**: `Address already in use` error

**Solutions**:

```bash
# Find what's using the port
lsof -i :1337        # Ogmios
lsof -i :1442        # Kupo
lsof -i :8080        # Backend
lsof -i :8081        # Frontend

# Kill the process
kill -9 <PID>

# Or change the port in docker-compose.yml
```

### Health Checks Failing

**Problem**: Container restarts continuously

**Solutions**:

1. Check service logs
   ```bash
   docker-compose logs cardano-node
   ```

2. Increase startup time
   ```yaml
   healthcheck:
     start_period: 60s  # Increase from 30s
   ```

3. Verify dependencies started first
   ```bash
   docker-compose up cardano-node
   # Wait for health check to pass
   docker-compose up
   ```

## Cardano Infrastructure Issues

### Node Won't Sync

**Problem**: Cardano node stays at low block height

**Solutions**:

1. Check network configuration
   ```bash
   # Verify correct network (preview, preprod, mainnet)
   grep NETWORK .env
   ```

2. Increase resources
   ```yaml
   deploy:
     resources:
       limits:
         memory: 6G  # Increase from 4G
   ```

3. Reset database
   ```bash
   docker-compose down -v
   docker volume rm cardano-rwa_node-db
   docker-compose up -d
   ```

### Ogmios Connection Errors

**Problem**: `Connection refused` when querying Ogmios

**Solutions**:

1. Verify Ogmios is healthy
   ```bash
   curl http://localhost:1337/health
   ```

2. Check network connectivity
   ```bash
   docker-compose exec ogmios wget -O- http://localhost:1337/health
   ```

3. Rebuild Ogmios connection
   ```bash
   docker-compose restart ogmios
   ```

### Kupo UTxO Errors

**Problem**: Kupo returns empty results

**Solutions**:

1. Wait for Kupo to sync
   ```bash
   docker-compose logs kupo | grep "tip"
   # Wait for tip to catch up with cardano-node
   ```

2. Verify match patterns
   ```bash
   # Default pattern matches everything
   # Adjust in docker-compose.yml if needed
   ```

3. Clear and resync
   ```bash
   docker-compose down -v
   docker volume rm cardano-rwa_kupo-db
   docker-compose up -d kupo
   ```

## TypeScript/Node.js Issues

### pnpm not found

**Problem**: `pnpm: command not found`

**Solutions**:

```bash
# Install pnpm globally
npm install -g pnpm

# Or use with npm
npx pnpm --version
```

### Module not found errors

**Problem**: `Cannot find module 'xxx'`

**Solutions**:

```bash
# Reinstall dependencies
rm -rf node_modules pnpm-lock.yaml
pnpm install

# Or update
pnpm update
```

### TypeScript compilation errors

**Problem**: Strict type checking fails

**Solutions**:

```bash
# Type check before running
pnpm run type-check

# Fix common issues
pnpm run type-check --noEmit

# Use any as last resort (not recommended)
// @ts-ignore
```

## .NET Issues

### Build Failures

**Problem**: `dotnet build` fails

**Solutions**:

```bash
# Clean and rebuild
dotnet clean
dotnet restore
dotnet build

# Check .NET version
dotnet --version  # Should be 9.0+
```

### Port 8080/8081 in use

**Problem**: Frontend/Backend won't start

**Solutions**:

```bash
# Use different ports
dotnet run --urls "http://localhost:9000"

# Or kill existing process
lsof -i :8080
kill -9 <PID>
```

### NuGet package errors

**Problem**: Package restore fails

**Solutions**:

```bash
# Clear NuGet cache
dotnet nuget locals all --clear

# Restore packages
dotnet restore --no-cache

# Check network
dotnet nuget verify
```

## Compliance & Policy Issues

### Policy Lock Calculation

**Problem**: Slot calculation incorrect

**Solutions**:

1. Use provided task
   ```bash
   # VS Code Task: "Policy: plan lock slot (.NET)"
   ```

2. Manual calculation
   ```typescript
   // 1 slot = 1 second on Cardano
   // 45 days = 3,888,000 seconds
   const lockSlot = currentSlot + (45 * 24 * 60 * 60);
   ```

### Allowlist Validation

**Problem**: Allowlist rejected with error

**Solutions**:

1. Check format
   ```bash
   # CSV: address,name,status
   # JSON: { "allowlist": [{ "address": "...", "verified": true }] }
   ```

2. Validate addresses
   ```bash
   # Each address must be valid Cardano address
   # Starting with addr_... for mainnet
   # Starting with addr_test... for testnet
   ```

3. Check encoding
   ```bash
   # File must be UTF-8 encoded
   file -i allowlist.csv
   ```

### Evidence Bundle Issues

**Problem**: IPFS pin fails

**Solutions**:

1. Check IPFS connectivity
   ```bash
   curl https://ipfs.io/ipfs/QmXxxx
   ```

2. Verify manifest hash
   ```bash
   sha256sum docs/evidence-bundle.json
   # Compare with sha256-manifest.json
   ```

3. Manual pin
   ```bash
   curl -X POST https://api.pinata.cloud/pinning/pinFileToIPFS \
     -H "pinata_api_key: YOUR_KEY" \
     -F "file=@evidence-bundle.json"
   ```

## Distribution Issues

### Payout Calculation Errors

**Problem**: Payout amounts incorrect

**Solutions**:

1. Verify CSV format
   ```
   wallet_address,tokens_held,pro_rata_share,payout_amount_usd
   addr_...,1000,0.05,500
   ```

2. Check decimal handling
   ```bash
   # Default is 2 decimals for USD
   # Adjust TOKEN_DECIMALS in .env if needed
   ```

3. Recalculate manually
   ```bash
   # Pro-rata = holder_balance / total_supply
   # Payout USD = pro_rata * total_usd_per_distribution
   ```

### Transaction Submission Fails

**Problem**: `submitTx` returns error

**Solutions**:

1. Check UTxO availability
   ```bash
   # Verify funding address has sufficient funds
   curl "http://localhost:1442?address=addr_..."
   ```

2. Verify fee calculation
   ```bash
   # Fee = inputs - outputs
   # Must leave minimum UTxO (2 ADA)
   ```

3. Check for double spending
   ```bash
   # Each input can only be spent once
   # Remove duplicates from inputs
   ```

## Monitoring Issues

### Prometheus Not Collecting Metrics

**Problem**: Prometheus shows no data

**Solutions**:

1. Verify configuration
   ```bash
   docker exec prometheus cat /etc/prometheus/prometheus.yml
   ```

2. Check targets
   ```
   http://localhost:9090/targets
   ```

3. Restart Prometheus
   ```bash
   docker-compose restart prometheus
   ```

### Grafana Dashboard Empty

**Problem**: Grafana shows no graphs

**Solutions**:

1. Add Prometheus data source
   ```
   Configuration → Data Sources → Add Prometheus
   URL: http://prometheus:9090
   ```

2. Import dashboard
   ```
   + → Import → Paste dashboard JSON ID
   ```

3. Check permissions
   ```bash
   docker-compose logs grafana | grep error
   ```

## Environment Issues

### Missing Environment Variables

**Problem**: `.env` file not found or incomplete

**Solutions**:

1. Create from template
   ```bash
   cd cardano-rwa-qh
   cp .env.example .env
   ```

2. Update with your values
   ```bash
   nano .env
   ```

3. Verify critical variables
   ```bash
   echo $BLOCKFROST_API_KEY
   echo $NETWORK
   ```

### Wrong Network Selected

**Problem**: Operations fail with network mismatch

**Solutions**:

```bash
# Check current network
grep "^NETWORK=" .env

# Switch networks
sed -i 's/NETWORK=.*/NETWORK=preprod/' .env

# Verify
source .env
echo $NETWORK
```

## Performance Issues

### Slow Queries

**Problem**: API requests timeout

**Solutions**:

1. Increase timeouts in `.env`
   ```bash
   DB_TIMEOUT=60000  # 60 seconds
   ```

2. Check resource usage
   ```bash
   docker stats
   ```

3. Optimize queries
   ```bash
   # Use Kupo with specific patterns
   # Instead of --match ".*" (matches everything)
   --match ".*.$ASSET_ID"  # Match specific policy
   ```

### High Memory Usage

**Problem**: Docker container crashes with OOM

**Solutions**:

1. Increase resource limits
   ```yaml
   deploy:
     resources:
       limits:
         memory: 6G
   ```

2. Reduce retention period
   ```bash
   # For Prometheus
   --storage.tsdb.retention.time=24h  # Down from 200h
   ```

3. Clear old data
   ```bash
   docker-compose down -v  # Remove all volumes
   ```

## Log Issues

### Too Much Logging

**Problem**: Logs are huge and hard to read

**Solutions**:

1. Reduce log level
   ```bash
   LOG_LEVEL=warn
   ```

2. Limit log rotation
   ```yaml
   logging:
     options:
       max-size: "5m"  # Reduce from 10m
       max-file: "2"   # Reduce from 3
   ```

3. View specific logs
   ```bash
   docker-compose logs --tail 100 cardano-node
   docker-compose logs --since 10m backend
   ```

## Getting Help

### Debug Information to Collect

When reporting issues, include:

```bash
# System info
uname -a
docker --version
docker-compose --version
dotnet --version
node --version

# Environment
echo $NETWORK
echo $BLOCKFROST_API_KEY | head -c 10
echo ...

# Logs
docker-compose logs > logs.txt

# Status
docker ps -a
docker-compose ps
```

### Where to Get Help

- **Documentation**: Check `cardano-rwa-qh/docs/`
- **GitHub Issues**: Search for similar problems
- **GitHub Discussions**: Ask community
- **Security Issues**: Email security@trustiva.io
- **General Help**: Email dev@trustiva.io

### Creating a Good Issue

1. Search existing issues first
2. Include minimal reproducible example
3. Provide debug information above
4. Describe expected vs actual behavior
5. Mention your environment

---

**Last Updated**: January 2024

