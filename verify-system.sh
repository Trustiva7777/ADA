#!/bin/bash
# Cardano RWA Startup Verification Script
# Comprehensive health checks for all services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Functions
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}\n"
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# ============================================================================
# SYSTEM CHECKS
# ============================================================================

print_header "System Requirements"

# Docker
if command_exists docker; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
    check_pass "Docker installed: $DOCKER_VERSION"
else
    check_fail "Docker not found"
fi

# Docker Compose
if command_exists docker-compose; then
    COMPOSE_VERSION=$(docker-compose --version | cut -d' ' -f3)
    check_pass "Docker Compose installed: $COMPOSE_VERSION"
else
    check_fail "Docker Compose not found"
fi

# Node.js
if command_exists node; then
    NODE_VERSION=$(node --version)
    check_pass "Node.js installed: $NODE_VERSION"
else
    check_warn "Node.js not found (optional for container usage)"
fi

# .NET
if command_exists dotnet; then
    DOTNET_VERSION=$(dotnet --version)
    check_pass ".NET SDK installed: $DOTNET_VERSION"
else
    check_warn ".NET SDK not found (optional for container usage)"
fi

# pnpm
if command_exists pnpm; then
    PNPM_VERSION=$(pnpm --version)
    check_pass "pnpm installed: $PNPM_VERSION"
else
    check_warn "pnpm not found (optional for container usage)"
fi

# ============================================================================
# ENVIRONMENT CHECK
# ============================================================================

print_header "Environment Configuration"

if [ -f ".env" ]; then
    check_pass ".env file exists"
    
    # Check for critical variables
    if grep -q "^NETWORK=" .env; then
        NETWORK=$(grep "^NETWORK=" .env | cut -d'=' -f2)
        check_pass "NETWORK configured: $NETWORK"
    else
        check_fail "NETWORK not configured in .env"
    fi
    
    if grep -q "BLOCKFROST_API_KEY=" .env; then
        API_KEY=$(grep "BLOCKFROST_API_KEY=" .env | cut -d'=' -f2 | head -c 10)
        if [ -n "$API_KEY" ]; then
            check_pass "BLOCKFROST_API_KEY configured"
        else
            check_warn "BLOCKFROST_API_KEY is empty (using local Ogmios/Kupo)"
        fi
    else
        check_warn "BLOCKFROST_API_KEY not in .env"
    fi
else
    check_fail ".env file not found - run: cp .env.example .env"
fi

# ============================================================================
# DOCKER SERVICES CHECK
# ============================================================================

print_header "Docker Services Status"

# Check if docker daemon is running
if ! docker ps >/dev/null 2>&1; then
    check_fail "Docker daemon not running"
    echo "Please start Docker first"
    exit 1
fi

# Get list of running containers
RUNNING=$(docker-compose ps -q 2>/dev/null | wc -l)

if [ "$RUNNING" -gt 0 ]; then
    check_pass "Docker Compose services running: $RUNNING containers"
else
    check_warn "No Docker Compose services running"
    echo "  Start services with: docker-compose up -d"
fi

# Check individual services
echo ""
echo "Service Health Checks:"

# Cardano Node
if docker ps | grep -q "cardano-node"; then
    if docker exec cardano-node ls /ipc/node.socket >/dev/null 2>&1; then
        check_pass "Cardano Node: Running and healthy"
    else
        check_fail "Cardano Node: Not responding"
    fi
else
    check_warn "Cardano Node: Not running"
fi

# Ogmios
if docker ps | grep -q "ogmios"; then
    if curl -s http://localhost:1337/health | grep -q "ok"; then
        check_pass "Ogmios: Running and healthy"
    else
        check_fail "Ogmios: Port 1337 not responding"
    fi
else
    check_warn "Ogmios: Not running"
fi

# Kupo
if docker ps | grep -q "kupo"; then
    if curl -s http://localhost:1442 >/dev/null 2>&1; then
        check_pass "Kupo: Running and healthy"
    else
        check_fail "Kupo: Port 1442 not responding"
    fi
else
    check_warn "Kupo: Not running"
fi

# Submit API
if docker ps | grep -q "submit-api"; then
    if curl -s http://localhost:8090/health >/dev/null 2>&1; then
        check_pass "Submit API: Running and healthy"
    else
        check_fail "Submit API: Port 8090 not responding"
    fi
else
    check_warn "Submit API: Not running"
fi

# Backend API
if docker ps | grep -q "backend"; then
    if curl -s http://localhost:8080/health >/dev/null 2>&1; then
        check_pass "Backend API: Running and healthy"
    else
        check_fail "Backend API: Port 8080 not responding"
    fi
else
    check_warn "Backend API: Not running"
fi

# Frontend
if docker ps | grep -q "frontend"; then
    if curl -s http://localhost:8081 >/dev/null 2>&1; then
        check_pass "Frontend: Running and healthy"
    else
        check_fail "Frontend: Port 8081 not responding"
    fi
else
    check_warn "Frontend: Not running"
fi

# Prometheus
if docker ps | grep -q "prometheus"; then
    if curl -s http://localhost:9090/-/healthy >/dev/null 2>&1; then
        check_pass "Prometheus: Running and healthy"
    else
        check_warn "Prometheus: Port 9090 not responding"
    fi
else
    check_warn "Prometheus: Not running"
fi

# Grafana
if docker ps | grep -q "grafana"; then
    if curl -s http://localhost:3000/api/health >/dev/null 2>&1; then
        check_pass "Grafana: Running and healthy"
    else
        check_warn "Grafana: Port 3000 not responding"
    fi
else
    check_warn "Grafana: Not running"
fi

# ============================================================================
# NETWORK CONNECTIVITY
# ============================================================================

print_header "Network Connectivity"

# Check Cardano Network
if [ -f ".env" ]; then
    NETWORK=$(grep "^NETWORK=" .env | cut -d'=' -f2 || echo "preview")
    
    case "$NETWORK" in
        mainnet)
            CHECK_URL="https://explorer.cardano.org/"
            ;;
        preprod)
            CHECK_URL="https://preprod.cexplorer.io/"
            ;;
        preview)
            CHECK_URL="https://preview.cexplorer.io/"
            ;;
        *)
            CHECK_URL=""
            ;;
    esac
    
    if [ -n "$CHECK_URL" ]; then
        if curl -s -m 5 "$CHECK_URL" >/dev/null 2>&1; then
            check_pass "Cardano network ($NETWORK) reachable"
        else
            check_fail "Cannot reach Cardano network ($NETWORK)"
        fi
    fi
fi

# Check IPFS
if curl -s -m 5 "https://ipfs.io/ipfs/QmbFMke1KXqnYyBHWAVLccqstdNKDh7bRfNYrQXm5fgfC2" >/dev/null 2>&1; then
    check_pass "IPFS gateway reachable"
else
    check_warn "IPFS gateway not reachable (will use local IPFS if configured)"
fi

# ============================================================================
# FILE STRUCTURE
# ============================================================================

print_header "Project Structure"

REQUIRED_DIRS=(
    "cardano-rwa-qh/docs"
    "cardano-rwa-qh/src"
    "SampleApp/BackEnd"
    "SampleApp/FrontEnd"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        check_pass "Directory exists: $dir"
    else
        check_fail "Directory missing: $dir"
    fi
done

REQUIRED_FILES=(
    "cardano-rwa-qh/docker-compose.yml"
    "docker-compose.yml"
    "docker-compose.override.yml"
    "readme.md"
    ".env.example"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        check_pass "File exists: $file"
    else
        check_fail "File missing: $file"
    fi
done

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Health Check Summary"

TOTAL=$((PASSED + FAILED + WARNINGS))

echo -e "Total Checks: ${BLUE}$TOTAL${NC}"
echo -e "Passed:       ${GREEN}$PASSED${NC}"
echo -e "Failed:       ${RED}$FAILED${NC}"
echo -e "Warnings:     ${YELLOW}$WARNINGS${NC}"

echo ""

if [ $FAILED -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}✓ All systems operational!${NC}"
        echo ""
        echo "Next steps:"
        echo "  1. Visit Frontend: http://localhost:8081"
        echo "  2. Visit Backend:  http://localhost:8080/swagger"
        echo "  3. Monitor via Grafana: http://localhost:3000 (admin/admin)"
    else
        echo -e "${YELLOW}⚠ System mostly operational with warnings${NC}"
    fi
else
    echo -e "${RED}✗ System has errors that need fixing${NC}"
    echo ""
    echo "Common fixes:"
    echo "  1. Start services:      docker-compose up -d"
    echo "  2. Check logs:          docker-compose logs -f"
    echo "  3. Review docs:         cat TROUBLESHOOTING.md"
fi

exit $FAILED
