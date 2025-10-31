# 🚀 Quick Start Guide

Get the Cardano RWA platform running in minutes.

## Prerequisites

- **Docker & Docker Compose**: [Install](https://docs.docker.com/get-docker/)
- **Git**: For cloning the repository
- **Blockfrost API Key** (optional): [Get free key](https://blockfrost.io)
- **~30GB disk space**: For Cardano node database

## Installation (5 minutes)

### 1. Clone Repository

```bash
git clone https://github.com/Trustiva7777/ADA.git
cd ADA
```

### 2. Environment Setup

```bash
cd cardano-rwa-qh

# Copy environment template
cp .env.example .env

# Edit configuration (optional - defaults work for testnet)
nano .env
```

**Minimal configuration** (for testing):
- Keep `NETWORK=preview`
- Leave `BLOCKFROST_API_KEY` blank (uses local Ogmios/Kupo)

### 3. Start Services

```bash
cd ..  # Back to root directory

# Start all services
./docker-manage.sh up

# Or manually
docker-compose -f cardano-rwa-qh/docker-compose.yml up -d
```

### 4. Verify Installation

```bash
./verify-system.sh
```

Expected output:
```
✓ Docker installed
✓ .env file exists
✓ Cardano Node: Running and healthy
✓ Ogmios: Running and healthy
✓ Kupo: Running and healthy
✓ Backend API: Running and healthy
✓ Frontend: Running and healthy
```

## Access the Platform

Once running, visit:

| Service | URL | Purpose |
|---------|-----|---------|
| **Frontend** | http://localhost:8081 | Web interface |
| **Backend API** | http://localhost:8080 | REST API |
| **API Docs** | http://localhost:8080/swagger | OpenAPI spec |
| **Prometheus** | http://localhost:9090 | Metrics |
| **Grafana** | http://localhost:3000 | Dashboards (admin/admin) |

## Common Commands

### Check Status

```bash
./docker-manage.sh ps          # List running services
./docker-manage.sh health      # Check service health
./verify-system.sh             # Full system verification
```

### View Logs

```bash
./docker-manage.sh logs                    # All logs
./docker-manage.sh logs -f                 # Stream logs
./docker-manage.sh logs -s cardano-node    # Specific service
```

### Stop/Restart

```bash
./docker-manage.sh restart          # Restart all services
./docker-manage.sh restart -s backend   # Restart specific
./docker-manage.sh down             # Stop all services
```

### Database Operations

```bash
./docker-manage.sh backup        # Backup databases
./docker-manage.sh restore -s <backup-dir>  # Restore
./docker-manage.sh clean         # Remove all data
```

## Working with QH-R1 Token

### 1. Navigate to Platform

```bash
cd cardano-rwa-qh
```

### 2. Build Proof Manifest

```bash
# VS Code Task: "Proofs: build sha256 manifest (.NET)"
# Or via command line:
pnpm run proofs:sha256
```

Output: `docs/sha256-manifest.json`

### 3. Plan Policy Lock

```bash
# VS Code Task: "Policy: plan lock slot (.NET)"
# Calculates optimal lock time (default: current slot + 45 days)
```

Output: `reports/lock_plan.json`

### 4. Create Attestation

```bash
# VS Code Task: "Attestation: policy/lock/proofs (.NET)"
# Provide:
# - policyId: <your-policy-id>
# - network: Preprod
# - policy.json: <path-to-policy>
# - allowlist.csv: <path-to-allowlist>
```

Output: `docs/token/attestation.Preprod.json`

### 5. Mint Token

```bash
pnpm mint -- \
  --ticker "QH-R1" \
  --amount 1000000 \
  --decimals 2 \
  --name "Quebrada-Honda-I" \
  --doc "ipfs://<CID>"
```

## Development Workflow

### Backend Development

```bash
# Terminal 1: Watch backend
./scripts/dev/watch-backend.sh

# Terminal 2: Interact with API
curl http://localhost:8080/api/health
```

### Frontend Development

```bash
# Terminal 1: Watch frontend
./scripts/dev/watch-frontend.sh

# Terminal 2: Open browser
# http://localhost:8081
```

### TypeScript/Node Development

```bash
cd cardano-rwa-qh

# Install dependencies
pnpm install

# Run dev server
pnpm dev

# Build
pnpm build

# Test
pnpm test
```

## Troubleshooting

### Services Won't Start

```bash
# Check Docker is running
docker ps

# View error logs
docker-compose logs -f

# Rebuild images
./docker-manage.sh build

# Full reset
./docker-manage.sh reset
```

### Port Already in Use

```bash
# Find what's using the port
lsof -i :8080

# Kill the process
kill -9 <PID>

# Or use different port in .env
BACKEND_PORT=9000
```

### Out of Disk Space

```bash
# Check usage
docker system df

# Clean up
./docker-manage.sh prune
docker volume prune -f
```

### Cardano Node Not Syncing

```bash
# Check logs
docker logs cardano-node | tail -50

# Monitor progress
docker logs -f cardano-node | grep "Syncing"

# Expected: completes in 24-48 hours from genesis
```

## Next Steps

### For Development

1. **Read the docs**: `cardano-rwa-qh/README.md`
2. **Explore endpoints**: Visit Swagger at http://localhost:8080/swagger
3. **Check examples**: `cardano-rwa-qh/src/examples/`
4. **Join Discord**: Community support

### For Production

1. **Review**: `DEPLOYMENT_CHECKLIST.md`
2. **Security**: Read `SECURITY.md`
3. **Performance**: Review `PERFORMANCE_OPTIMIZATION.md`
4. **Compliance**: Check `cardano-rwa-qh/legal/`

## Getting Help

- **Documentation**: Check the `docs/` directory
- **GitHub Issues**: Search for solutions
- **Troubleshooting**: Read `TROUBLESHOOTING.md`
- **Security Issues**: Email security@trustiva.io
- **General Questions**: Visit GitHub Discussions

## Key Concepts

### Cardano Node
The Cardano blockchain node - maintains a full copy of the blockchain

### Ogmios
Query service for building transactions and accessing blockchain data

### Kupo
UTxO indexer - tracks all unspent transaction outputs

### QH-R1 Token
Example implementation: Quebrada Honda mining royalty token

### Evidence Bundle
IPFS-pinned documentation (legal, technical, compliance reports)

### Attestation
Cryptographic binding of token policy, evidence, and compliance rules

## Architecture Overview

```
┌─────────────────────────────────┐
│     Frontend (Blazor)           │
│    http://localhost:8081        │
└────────────┬────────────────────┘
             │
┌────────────▼────────────────────┐
│   Backend API (.NET Core)       │
│    http://localhost:8080        │
└────────────┬────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
┌───▼───────┐  ┌─────▼──────┐
│ Ogmios    │  │   Kupo     │
│ :1337     │  │   :1442    │
└───┬───────┘  └─────┬──────┘
    │                │
    └────────┬───────┘
             │
      ┌──────▼──────┐
      │ Cardano Node│
      │  :3001      │
      └─────────────┘
```

## Performance Tips

- **First sync**: 24-48 hours (downloads entire blockchain)
- **Subsequent restarts**: < 5 minutes
- **Query latency**: 50-200ms local, < 500ms remote
- **Memory usage**: 8-16GB recommended for production

## Security Reminders

- ✅ Keep `.env` out of version control
- ✅ Use strong passwords in production
- ✅ Enable firewall rules
- ✅ Keep systems updated
- ✅ Use TLS/HTTPS in production
- ✅ Never hardcode secrets

## Support

For help and support:

1. **Documentation**: https://github.com/Trustiva7777/ADA/tree/main/docs
2. **Issues**: https://github.com/Trustiva7777/ADA/issues
3. **Discussions**: https://github.com/Trustiva7777/ADA/discussions
4. **Email**: dev@trustiva.io

---

**Ready?** Start with `./docker-manage.sh up` and visit http://localhost:8081! 🎉
