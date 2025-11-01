# Developer Guide - Cardano RWA System

## Table of Contents

1. [Quick Start](#quick-start)
2. [Local Development Environment](#local-development-environment)
3. [Service Architecture](#service-architecture)
4. [Database Setup](#database-setup)
5. [IPFS Integration](#ipfs-integration)
6. [Cardano Blockchain](#cardano-blockchain)
7. [Monitoring & Observability](#monitoring--observability)
8. [API Documentation](#api-documentation)
9. [Common Tasks](#common-tasks)
10. [Troubleshooting](#troubleshooting)

## Quick Start

### Prerequisites

- Docker and Docker Compose
- .NET SDK 9.0+
- Git
- 8GB+ RAM
- 50GB+ disk space (for Cardano node)

### Getting Started

```bash
# 1. Clone the repository
git clone https://github.com/Trustiva7777/dotnet-codespaces.git
cd dotnet-codespaces

# 2. Run the onboarding script
./scripts/onboard.sh

# 3. Access the services
# Frontend:    http://localhost:8081
# Backend API: http://localhost:8080
# Grafana:     http://localhost:3000 (admin/admin)
```

## Local Development Environment

### Docker Compose Services

The project includes a comprehensive `docker-compose.yml` that orchestrates:

| Service | Port | Purpose |
|---------|------|---------|
| **Backend** | 8080 | .NET Core REST API |
| **Frontend** | 8081 | Blazor Server UI |
| **PostgreSQL** | 5432 | Primary database |
| **IPFS** | 5001, 8080 | Decentralized storage |
| **Cardano Node** | 3001 | Cardano blockchain |
| **Ogmios** | 1337 | Cardano query API |
| **Prometheus** | 9090 | Metrics collection |
| **Grafana** | 3000 | Metrics visualization |

### Starting Services

```bash
# Start all services in background
docker-compose up -d

# Start with logs visible
docker-compose up

# Stop all services
docker-compose down

# View service logs
docker-compose logs -f [service-name]
```

### Environment Configuration

Configuration is managed through `.env` file:

```bash
# Copy example to create your local .env
cp .env.example .env

# Edit as needed
nano .env
```

Key environment variables:

- `POSTGRES_USER` / `POSTGRES_PASSWORD` - Database credentials
- `ASPNETCORE_ENVIRONMENT` - ASP.NET Core environment (Development/Production)
- `CARDANO_NETWORK` - Cardano network (preview/preprod/mainnet)
- `IPFS_API` - IPFS API endpoint
- `CARDANO_OGMIOS` - Ogmios endpoint for Cardano queries

## Service Architecture

### Backend (.NET Core)

**Location:** `/SampleApp/BackEnd`

**Features:**
- REST API with OpenAPI/Swagger support
- PostgreSQL integration
- IPFS integration for file storage
- Cardano blockchain interaction via Ogmios
- Health checks and metrics

**Building:**
```bash
dotnet build SampleApp/BackEnd/BackEnd.csproj
```

**Running locally:**
```bash
dotnet run --project SampleApp/BackEnd/BackEnd.csproj
```

**API Documentation:**
- Swagger UI: http://localhost:8080/swagger
- OpenAPI Spec: http://localhost:8080/openapi/v1.json

### Frontend (Blazor Server)

**Location:** `/SampleApp/FrontEnd`

**Features:**
- Server-side Blazor UI
- Real-time component updates
- Bootstrap responsive design
- Integration with backend API

**Building:**
```bash
dotnet build SampleApp/FrontEnd/FrontEnd.csproj
```

**Running locally:**
```bash
dotnet run --project SampleApp/FrontEnd/FrontEnd.csproj
```

## Database Setup

### PostgreSQL

The project uses PostgreSQL 15 for primary data storage.

**Connection String:**
```
Host=localhost;Port=5432;Database=sampledb;Username=postgres;Password=postgres
```

**Creating Migrations:**
```bash
# In BackEnd directory
dotnet ef migrations add InitialCreate
dotnet ef database update
```

**Connecting to Database:**
```bash
docker-compose exec db psql -U postgres -d sampledb
```

**Backup & Restore:**
```bash
# Backup
docker-compose exec db pg_dump -U postgres sampledb > backup.sql

# Restore
docker-compose exec -T db psql -U postgres sampledb < backup.sql
```

## IPFS Integration

### Overview

IPFS (InterPlanetary File System) provides decentralized, content-addressed file storage.

**API Endpoint:** http://localhost:5001
**HTTP Gateway:** http://localhost:8080/ipfs

### Adding Files to IPFS

```bash
# Using IPFS CLI
docker-compose exec ipfs ipfs add /export/filename

# Using HTTP API
curl -X POST http://localhost:5001/api/v0/add -F file=@filename
```

### Retrieving Files

```bash
# Via gateway
curl http://localhost:8080/ipfs/QmHash

# Via API
curl http://localhost:5001/api/v0/cat?arg=QmHash
```

### Pinning Files

```bash
# Pin a file (ensure it persists)
docker-compose exec ipfs ipfs pin add QmHash
```

## Cardano Blockchain

### Overview

The project integrates with Cardano blockchain via:
- **Cardano Node** - Full node implementation
- **Ogmios** - Query API for blockchain state

**Network:** Preview testnet (default)

### Ogmios Query Examples

```bash
# Health check
curl http://localhost:1337/health

# Query chain state
curl -X POST http://localhost:1337/v1/blocks/latest \
  -H "Content-Type: application/json" \
  -d '{}'
```

### Switching Networks

Edit `.env` to change network:

```env
CARDANO_NETWORK=mainnet    # mainnet
CARDANO_NETWORK=preprod    # preprod testnet
CARDANO_NETWORK=preview    # preview testnet
```

### Backend Integration

The backend provides Cardano integration via:
- `/api/cardano/health` - Check node status
- `/api/cardano/utxos` - Query UTXOs
- `/api/cardano/submit-tx` - Submit transactions

## Monitoring & Observability

### Prometheus

**URL:** http://localhost:9090

Prometheus collects metrics from all services. Configuration in `monitoring/prometheus.yml`.

**Adding Metrics:**
1. Add scrape job to `prometheus.yml`
2. Expose metrics endpoint on service
3. Restart Prometheus

### Grafana

**URL:** http://localhost:3000
**Credentials:** admin / admin

**Creating Dashboards:**
1. Go to Grafana
2. Data Source → Add Prometheus
3. Create dashboard with Prometheus queries

**Example Queries:**
```promql
# Backend request rate
rate(http_requests_total[5m])

# Database connections
pg_stat_activity_count

# Container memory usage
container_memory_usage_bytes
```

### Health Checks

Each service exposes health endpoints:

```bash
# Backend
curl http://localhost:8080/health

# Frontend
curl http://localhost:8081/health

# Database
docker-compose exec db pg_isready

# IPFS
curl http://localhost:5001/api/v0/id

# Cardano
curl http://localhost:1337/health
```

## API Documentation

### Backend API

The backend exposes a RESTful API with comprehensive documentation.

**Base URL:** http://localhost:8080

**Authentication:** (To be implemented)

**Endpoints:**

#### Weather Forecast
```bash
GET /weatherforecast

Response:
[
  {
    "date": "2025-11-02",
    "temperatureC": 25,
    "temperatureF": 77,
    "summary": "Warm"
  }
]
```

#### Health Check
```bash
GET /health

Response:
{
  "status": "Healthy",
  "timestamp": "2025-11-01T12:00:00Z"
}
```

### OpenAPI / Swagger

Full API documentation available at:
- **Swagger UI:** http://localhost:8080/swagger
- **OpenAPI Spec:** http://localhost:8080/openapi/v1.json

## Common Tasks

### Building for Production

```bash
# Build backend
dotnet publish SampleApp/BackEnd/BackEnd.csproj -c Release

# Build frontend
dotnet publish SampleApp/FrontEnd/FrontEnd.csproj -c Release

# Build Docker images
docker-compose build --no-cache
```

### Running Tests

```bash
# Unit tests
dotnet test

# Integration tests
dotnet test --filter "Category=Integration"
```

### Debugging

**Visual Studio Code:**
1. Install C# Extension
2. Open project in VS Code
3. Select ".NET: Generate Assets for Build and Debug"
4. Set breakpoints
5. Press F5 to debug

**Docker:**
```bash
# View service logs
docker-compose logs -f [service-name]

# Execute command in container
docker-compose exec [service-name] bash

# View container processes
docker-compose top [service-name]
```

### Database Migrations

```bash
# Create new migration
dotnet ef migrations add MigrationName

# Apply migrations
dotnet ef database update

# Remove last migration
dotnet ef migrations remove

# Script migrations
dotnet ef migrations script
```

### Updating Dependencies

```bash
# Check for updates
dotnet package search [package-name]

# Update all packages
dotnet package update

# Update specific package
dotnet add package [package-name] --version [version]
```

## Troubleshooting

### Services Won't Start

```bash
# Check Docker daemon
docker ps

# Check Docker Compose version
docker-compose --version

# View startup errors
docker-compose logs -f

# Rebuild images
docker-compose build --no-cache --pull
```

### Port Already in Use

```bash
# Find process using port
lsof -i :8080

# Or with netstat
netstat -tulpn | grep :8080

# Kill process
kill -9 <PID>

# Or change port in docker-compose.yml
# ports:
#   - "8082:8080"
```

### Database Connection Issues

```bash
# Test connection
docker-compose exec db psql -U postgres -d sampledb -c "SELECT 1"

# Check environment variables
docker-compose config | grep POSTGRES

# View database logs
docker-compose logs db
```

### IPFS Issues

```bash
# Check IPFS daemon status
docker-compose exec ipfs ipfs swarm peers

# Reset IPFS data (WARNING: Deletes all data)
docker volume rm dotnet-codespaces_ipfs-data
docker-compose up -d ipfs
```

### Cardano Node Issues

```bash
# Check node sync status
docker-compose exec cardano-node sh -c "ls -lh /ipc/node.socket"

# View node logs
docker-compose logs -f cardano-node

# Reset node data (WARNING: Deletes all data)
docker volume rm dotnet-codespaces_cardano-node-db
docker-compose up -d cardano-node
```

### Memory Issues

If containers are running out of memory:

```bash
# Check container stats
docker stats

# Adjust resource limits in docker-compose.yml
# deploy:
#   resources:
#     limits:
#       memory: 2G
```

### Performance Optimization

```bash
# Enable Docker BuildKit for faster builds
export DOCKER_BUILDKIT=1

# Use compose profiles to start only needed services
docker-compose --profile dev up -d

# Limit Docker resource usage
docker-compose down
# Edit docker-compose.yml resource limits
docker-compose up -d
```

## Additional Resources

- [Cardano Documentation](https://docs.cardano.org)
- [IPFS Documentation](https://docs.ipfs.io)
- [ASP.NET Core Documentation](https://docs.microsoft.com/aspnet/core)
- [Blazor Documentation](https://docs.microsoft.com/aspnet/core/blazor)
- [Docker Documentation](https://docs.docker.com)
- [PostgreSQL Documentation](https://www.postgresql.org/docs)

## Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/Trustiva7777/dotnet-codespaces/issues
- Documentation: See `README.md`
- Cardano Developers: https://discord.gg/inputoutput

---

**Last Updated:** November 2025
**Version:** 1.0
