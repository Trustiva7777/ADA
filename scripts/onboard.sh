#!/bin/bash

# Cardano RWA System - Developer Onboarding Script
# This script sets up the local development environment for the Cardano RWA project

set -e

echo "================================================"
echo "Cardano RWA System - Developer Onboarding"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}[1/5]${NC} Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    echo "  Please install Docker from https://www.docker.com/products/docker-desktop"
    exit 1
fi
echo -e "${GREEN}✓ Docker installed${NC}"

if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}✗ Docker Compose is not installed${NC}"
    echo "  Please install Docker Compose from https://docs.docker.com/compose/install/"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose installed${NC}"

if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}✗ .NET SDK is not installed${NC}"
    echo "  Please install .NET SDK from https://dotnet.microsoft.com/download"
    exit 1
fi
echo -e "${GREEN}✓ .NET SDK installed${NC}"

if ! command -v git &> /dev/null; then
    echo -e "${RED}✗ Git is not installed${NC}"
    echo "  Please install Git from https://git-scm.com/downloads"
    exit 1
fi
echo -e "${GREEN}✓ Git installed${NC}"

echo ""

# Check if .env file exists
echo -e "${BLUE}[2/5]${NC} Setting up environment variables..."

if [ ! -f ".env" ]; then
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ Created .env from .env.example${NC}"
    else
        echo -e "${YELLOW}⚠ .env.example not found, creating .env...${NC}"
        cat > .env << 'EOF'
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=sampledb
ASPNETCORE_ENVIRONMENT=Development
EOF
    fi
else
    echo -e "${GREEN}✓ .env file already exists${NC}"
fi

echo ""

# Create monitoring directories if they don't exist
echo -e "${BLUE}[3/5]${NC} Setting up monitoring infrastructure..."

mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/dashboards

echo -e "${GREEN}✓ Monitoring directories created${NC}"

echo ""

# Build Docker images
echo -e "${BLUE}[4/5]${NC} Building Docker images..."
echo "  This may take a few minutes on first run..."

docker-compose build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Docker images built successfully${NC}"
else
    echo -e "${RED}✗ Failed to build Docker images${NC}"
    exit 1
fi

echo ""

# Start services
echo -e "${BLUE}[5/5]${NC} Starting services..."

docker-compose up -d

echo ""
echo -e "${GREEN}✓ All services started successfully!${NC}"
echo ""

# Display service URLs
echo "================================================"
echo "Services are now running at:"
echo "================================================"
echo -e "${BLUE}Frontend:${NC}       http://localhost:8081"
echo -e "${BLUE}Backend (API):${NC}   http://localhost:8080"
echo -e "${BLUE}Backend (Swagger):${NC} http://localhost:8080/swagger"
echo -e "${BLUE}IPFS Gateway:${NC}    http://localhost:8080"
echo -e "${BLUE}IPFS API:${NC}        http://localhost:5001"
echo -e "${BLUE}Prometheus:${NC}      http://localhost:9090"
echo -e "${BLUE}Grafana:${NC}         http://localhost:3000 (admin/admin)"
echo -e "${BLUE}Cardano Node:${NC}    http://localhost:3001"
echo -e "${BLUE}Ogmios:${NC}          http://localhost:1337"
echo "================================================"
echo ""

# Display useful commands
echo "Useful commands:"
echo "  - Start services:     docker-compose up -d"
echo "  - Stop services:      docker-compose down"
echo "  - View logs:          docker-compose logs -f"
echo "  - View backend logs:  docker-compose logs -f backend"
echo "  - View frontend logs: docker-compose logs -f frontend"
echo ""

# Check service health
echo "Checking service health..."
sleep 3

BACKEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/healthz || echo "000")
if [ "$BACKEND_HEALTH" == "200" ] || [ "$BACKEND_HEALTH" == "404" ]; then
    echo -e "${GREEN}✓ Backend is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Backend health check returned: $BACKEND_HEALTH${NC}"
fi

FRONTEND_HEALTH=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8081 || echo "000")
if [ "$FRONTEND_HEALTH" == "200" ]; then
    echo -e "${GREEN}✓ Frontend is healthy${NC}"
else
    echo -e "${YELLOW}⚠ Frontend health check returned: $FRONTEND_HEALTH${NC}"
fi

echo ""
echo -e "${GREEN}✓ Onboarding complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Open http://localhost:8081 in your browser"
echo "  2. Check API documentation at http://localhost:8080/swagger"
echo "  3. Monitor services at http://localhost:3000 (Grafana)"
echo "  4. Review the README.md for more information"
echo ""
