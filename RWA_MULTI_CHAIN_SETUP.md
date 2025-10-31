# RWA Multi-Chain Build & Run Guide

## Overview

This workspace supports building and running multiple RWA chains (Cardano, Midnight, and more) in a unified Docker Compose environment.

## Quick Start

### Build All Chains (Docker)
```bash
docker compose -f docker-compose.all-chains.yml build
```

### Run All Chains (Docker)
```bash
docker compose -f docker-compose.all-chains.yml up --build -d
```

### Stop All Chains
```bash
docker compose -f docker-compose.all-chains.yml down
```

### View Logs
```bash
docker compose -f docker-compose.all-chains.yml logs -f
```

## Available Services

### Cardano Chain
- **Cardano Node**: `localhost:3001` (P2P)
- **Ogmios**: `ws://localhost:1337` (Query API)
- **Kupo**: `http://localhost:1442` (UTxO indexer)

### .NET Applications
- **Backend API**: `http://localhost:8080`
- **Frontend (Blazor)**: `http://localhost:8081`

### Midnight Chain
- **Midnight Suite**: `localhost:3000` (Eligibility & DUST planning)

## VS Code Tasks

Use these from `Terminal → Run Task`:

- **🚀 RWA: Build all chains (Docker)** - Build all images
- **🚀 RWA: Up all chains (Docker)** - Start all services
- **🚀 RWA: Down all chains (Docker)** - Stop all services
- **🚀 RWA: Logs all chains (Docker)** - Stream logs
- **🌙 Midnight: Build** - Build Midnight suite
- **🔗 Cardano: Build MintTool** - Build Cardano minting tool

## Adding a New RWA Chain

To add support for a new blockchain (e.g., Ethereum, Polkadot):

### 1. Create Chain Directory Structure
```
rwa-suite/chains/
├── cardano/
├── ethereum/            # NEW
│   ├── Dockerfile
│   ├── package.json
│   ├── src/
│   └── README.md
└── midnight/
```

### 2. Create a Dockerfile
Example for Ethereum chain:

```dockerfile
FROM node:20-alpine

WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install --frozen-lockfile
COPY . .

EXPOSE 3001
CMD ["pnpm", "run", "start"]
```

### 3. Add Service to docker-compose.all-chains.yml
```yaml
# ============================================
# Ethereum Chain
# ============================================
ethereum-node:
  build:
    context: ./rwa-suite/chains/ethereum
    dockerfile: Dockerfile
  container_name: ethereum-node
  ports:
    - "8545:8545"  # JSON-RPC
    - "30303:30303"  # P2P
  environment:
    - NETWORK=sepolia
  volumes:
    - ethereum-db:/data
  networks:
    - rwa-network
  healthcheck:
    test: ["CMD", "curl", "-f", "http://localhost:8545 || exit 1"]
    interval: 10s
    timeout: 5s
    retries: 5

# Add volume for Ethereum
volumes:
  ethereum-db:
    driver: local
```

### 4. Update .vscode/tasks.json
Add a new task for building/running the chain:

```jsonc
{
    "label": "⛓️ Ethereum: Build",
    "type": "shell",
    "command": "docker build -t ethereum-rwa:latest ${workspaceFolder}/rwa-suite/chains/ethereum",
    "problemMatcher": []
}
```

### 5. Document the Chain
Create `rwa-suite/chains/ethereum/README.md` with:
- Chain setup instructions
- Available commands
- Configuration options
- Supported operations (mint, lock, distribute, etc.)

## Testing Multiple Chains

### Health Check
```bash
# Check all services
docker ps -a

# Check specific service health
curl http://localhost:8080/health  # Backend
curl http://localhost:8081/        # Frontend
curl http://localhost:1442/health  # Kupo
```

### Chain-Specific Commands

**Cardano:**
```bash
# Mint tool
dotnet run --project rwa-suite/chains/cardano/tools/MintTool/MintTool.csproj

# Distribution
pnpm --dir cardano-rwa-qh distribute
```

**Midnight:**
```bash
# Eligibility check
pnpm --dir apps/midnight-suite night:eligibility

# DUST model
pnpm --dir apps/midnight-suite night:dust
```

## Networking

All chains are connected via the `rwa-network` bridge network:
- Services can communicate using container names
- Example: `Backend` connects to `Ogmios` via `http://ogmios:1337`

## Extensibility

The structure is designed to be modular:
- Each chain is self-contained in its directory
- Each chain has its own Dockerfile and configuration
- Services are loosely coupled via Docker networks
- Easy to add, remove, or modify chains without affecting others

## Troubleshooting

### Service won't start
```bash
docker compose -f docker-compose.all-chains.yml logs <service-name>
```

### Port conflicts
Change port mappings in `docker-compose.all-chains.yml`

### Network issues
Check if all services are on the same network:
```bash
docker network inspect rwa-network
```

### Clean rebuild
```bash
docker compose -f docker-compose.all-chains.yml down -v
docker compose -f docker-compose.all-chains.yml up --build -d
```

## Next Steps

- Deploy to production using Kubernetes or cloud platforms
- Add monitoring (Prometheus, Grafana)
- Set up CI/CD pipelines for automated builds and deployments
- Integrate additional chains as needed
