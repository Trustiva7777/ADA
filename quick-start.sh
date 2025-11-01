#!/bin/bash

# UNYKORN 7777 - Quick Start Script
# This script sets up the entire development environment

set -e

echo "╔══════════════════════════════════════════════════════════╗"
echo "║     UNYKORN 7777 - Complete Stack Setup & Startup       ║"
echo "║              October 31, 2025                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}[1/5]${NC} Checking prerequisites..."

if ! command -v node &> /dev/null; then
    echo -e "${RED}✗ Node.js is not installed${NC}"
    exit 1
fi

if ! command -v pnpm &> /dev/null; then
    echo -e "${YELLOW}! pnpm not found, installing...${NC}"
    npm install -g pnpm
fi

if ! command -v dotnet &> /dev/null; then
    echo -e "${RED}✗ .NET SDK is not installed${NC}"
    exit 1
fi

if ! command -v docker &> /dev/null; then
    echo -e "${RED}✗ Docker is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites installed${NC}"
echo ""

# Setup Backend
echo -e "${BLUE}[2/5]${NC} Setting up Backend (.NET)..."

cd /workspaces/dotnet-codespaces/SampleApp/BackEnd

if [ ! -f "appsettings.Development.json" ]; then
    echo "Creating appsettings.Development.json..."
    cat > appsettings.Development.json << 'EOF'
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft": "Warning"
    }
  },
  "ConnectionStrings": {
    "DefaultConnection": "Server=localhost;Port=5432;Database=unykorn_rwa;User Id=postgres;Password=postgres;"
  },
  "Redis": {
    "Host": "localhost",
    "Port": 6379
  },
  "Web3": {
    "ProviderUrl": "http://localhost:8545",
    "ChainId": 11155111
  }
}
EOF
    echo -e "${GREEN}✓ Backend configuration created${NC}"
fi

echo "Building backend..."
dotnet build -c Debug > /dev/null 2>&1
echo -e "${GREEN}✓ Backend ready${NC}"
echo ""

# Setup Frontend
echo -e "${BLUE}[3/5]${NC} Setting up Frontend (Next.js 15)..."

cd /workspaces/dotnet-codespaces/frontend

if [ ! -f ".env.local" ]; then
    echo "Creating .env.local..."
    cat > .env.local << 'EOF'
NEXT_PUBLIC_API_URL=http://localhost:5000/api
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=test_project_id
NODE_ENV=development
EOF
    echo -e "${GREEN}✓ Frontend environment created${NC}"
fi

if [ ! -d "node_modules" ]; then
    echo "Installing dependencies (this may take 2-3 minutes)..."
    pnpm install > /dev/null 2>&1
    echo -e "${GREEN}✓ Frontend dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Frontend dependencies already installed${NC}"
fi

echo ""

# Setup Docker services
echo -e "${BLUE}[4/5]${NC} Starting Docker services..."

cd /workspaces/dotnet-codespaces

if ! docker ps | grep -q postgres; then
    echo "Starting PostgreSQL and Redis..."
    docker-compose up -d postgres redis > /dev/null 2>&1
    echo "Waiting for services to be ready..."
    sleep 5
    echo -e "${GREEN}✓ Docker services started${NC}"
else
    echo -e "${GREEN}✓ Services already running${NC}"
fi

echo ""

# Display startup commands
echo -e "${BLUE}[5/5]${NC} Setup Complete! 🎉"
echo ""
echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Next: Start the development stack${NC}"
echo -e "${YELLOW}================================${NC}"
echo ""
echo "1️⃣  Backend (.NET):"
echo -e "   ${BLUE}cd /workspaces/dotnet-codespaces/SampleApp/BackEnd${NC}"
echo -e "   ${BLUE}dotnet run${NC}"
echo -e "   ▶ Runs on http://localhost:5000${NC}"
echo ""
echo "2️⃣  Frontend (Next.js):"
echo -e "   ${BLUE}cd /workspaces/dotnet-codespaces/frontend${NC}"
echo -e "   ${BLUE}pnpm dev${NC}"
echo -e "   ▶ Runs on http://localhost:3000${NC}"
echo ""
echo "3️⃣  Database (PostgreSQL):"
echo -e "   Already running via Docker"
echo -e "   ▶ postgres://postgres:postgres@localhost:5432/unykorn_rwa${NC}"
echo ""
echo "4️⃣  Cache (Redis):"
echo -e "   Already running via Docker"
echo -e "   ▶ redis://localhost:6379${NC}"
echo ""
echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Docker Compose Services${NC}"
echo -e "${YELLOW}================================${NC}"
echo ""
echo "View running services:"
echo -e "   ${BLUE}docker-compose ps${NC}"
echo ""
echo "View logs:"
echo -e "   ${BLUE}docker-compose logs -f${NC}"
echo ""
echo "Stop services:"
echo -e "   ${BLUE}docker-compose down${NC}"
echo ""
echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}Helpful Commands${NC}"
echo -e "${YELLOW}================================${NC}"
echo ""
echo "Frontend linting:"
echo -e "   ${BLUE}pnpm lint${NC}"
echo ""
echo "Frontend building:"
echo -e "   ${BLUE}pnpm build${NC}"
echo ""
echo "Backend tests:"
echo -e "   ${BLUE}dotnet test${NC}"
echo ""
echo "Database access:"
echo -e "   ${BLUE}psql -U postgres -h localhost -d unykorn_rwa${NC}"
echo ""
echo -e "${YELLOW}================================${NC}"
echo -e "${YELLOW}📚 Documentation${NC}"
echo -e "${YELLOW}================================${NC}"
echo ""
echo "Frontend Setup Guide:"
echo -e "   ${BLUE}/frontend/FRONTEND_SETUP_GUIDE.md${NC}"
echo ""
echo "Implementation Roadmap:"
echo -e "   ${BLUE}/IMPLEMENTATION_ROADMAP.md${NC}"
echo ""
echo "Full Infrastructure Outline:"
echo -e "   ${BLUE}/UNYKORN_7777_FULL_INFRASTRUCTURE_OUTLINE.md${NC}"
echo ""
echo -e "${GREEN}✓ Setup complete! Ready to code! 🚀${NC}"
echo ""
