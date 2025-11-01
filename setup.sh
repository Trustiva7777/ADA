#!/bin/bash
# Onboarding script for Cardano RWA local development
set -e

# 1. Copy .env template if not present
echo "[Onboarding] Checking for .env file..."
if [ ! -f .env ]; then
  cp .env.example .env 2>/dev/null || cp ../.env.example .env 2>/dev/null || cp .env .env 2>/dev/null || echo "POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=sampledb" > .env
  echo "[Onboarding] .env file created. Please review and update secrets as needed."
else
  echo "[Onboarding] .env file already exists."
fi

# 2. Build and start all services
echo "[Onboarding] Building and starting Docker Compose stack..."
docker compose up --build -d

echo "[Onboarding] All services started."
echo "- Backend:     http://localhost:8080"
echo "- Frontend:    http://localhost:8081"
echo "- Postgres:    localhost:5432 (user: postgres, pass: postgres)"
echo "- IPFS:        http://localhost:5001 (API), http://localhost:8080 (Gateway)"
echo "- Cardano node: see cardano-rwa-qh/docker-compose.yml for details"
echo "- Prometheus:  http://localhost:9090"
echo "- Grafana:     http://localhost:3000 (default: admin/admin)"

echo "[Onboarding] Done! See README for more info."
