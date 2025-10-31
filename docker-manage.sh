#!/bin/bash
# Cardano RWA Docker Management Script
# Simplified commands for common Docker operations

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

show_help() {
    cat << EOF
${BLUE}Cardano RWA Docker Management${NC}

Usage: ./docker-manage.sh <command> [options]

Commands:
    ${GREEN}up${NC}              Start all services in background
    ${GREEN}down${NC}            Stop all services
    ${GREEN}restart${NC}         Restart all services
    ${GREEN}build${NC}           Build all images
    ${GREEN}logs${NC}            Show container logs (streaming)
    ${GREEN}ps${NC}              Show running containers
    ${GREEN}clean${NC}           Remove all containers and volumes
    ${GREEN}reset${NC}           Full reset (clean + rebuild)
    ${GREEN}health${NC}          Check services health
    ${GREEN}backup${NC}          Backup database volumes
    ${GREEN}restore${NC}         Restore database volumes
    ${GREEN}verify${NC}          Run system verification
    ${GREEN}prune${NC}           Clean up unused Docker objects

Examples:
    ./docker-manage.sh up
    ./docker-manage.sh logs -f
    ./docker-manage.sh health
    ./docker-manage.sh backup
    ./docker-manage.sh clean

Options:
    -f, --follow     Follow logs (use with 'logs')
    -s, --service    Specific service (e.g., -s cardano-node)
    -h, --help       Show this help message
EOF
}

# Parse arguments
SERVICE=""
FOLLOW=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--service)
            SERVICE="$2"
            shift 2
            ;;
        -f|--follow)
            FOLLOW="-f"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            COMMAND="$1"
            shift
            ;;
    esac
done

# Commands
case "${COMMAND:-help}" in
    up)
        echo -e "${BLUE}Starting services...${NC}"
        docker-compose up -d
        echo -e "${GREEN}✓ Services started${NC}"
        echo ""
        echo "Access points:"
        echo "  Cardano Node: localhost:3001"
        echo "  Ogmios:       localhost:1337"
        echo "  Kupo:         localhost:1442"
        echo "  Backend API:  http://localhost:8080"
        echo "  Frontend:     http://localhost:8081"
        echo "  Prometheus:   http://localhost:9090"
        echo "  Grafana:      http://localhost:3000"
        ;;
    
    down)
        echo -e "${BLUE}Stopping services...${NC}"
        docker-compose down
        echo -e "${GREEN}✓ Services stopped${NC}"
        ;;
    
    restart)
        echo -e "${BLUE}Restarting services...${NC}"
        if [ -n "$SERVICE" ]; then
            docker-compose restart "$SERVICE"
            echo -e "${GREEN}✓ Service $SERVICE restarted${NC}"
        else
            docker-compose restart
            echo -e "${GREEN}✓ All services restarted${NC}"
        fi
        ;;
    
    build)
        echo -e "${BLUE}Building images...${NC}"
        docker-compose build --no-cache
        echo -e "${GREEN}✓ Build complete${NC}"
        ;;
    
    logs)
        if [ -n "$SERVICE" ]; then
            docker-compose logs $FOLLOW "$SERVICE"
        else
            docker-compose logs $FOLLOW
        fi
        ;;
    
    ps)
        docker-compose ps
        ;;
    
    health)
        echo -e "${BLUE}Checking service health...${NC}"
        echo ""
        
        # Check each service
        services=("cardano-node" "ogmios" "kupo" "submit-api")
        
        for service in "${services[@]}"; do
            if docker ps | grep -q "$service"; then
                echo -e "${GREEN}✓${NC} $service is running"
            else
                echo -e "${RED}✗${NC} $service is not running"
            fi
        done
        
        # Check ports
        echo ""
        echo "Port checks:"
        
        if curl -s http://localhost:1337/health > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Ogmios (1337) responding"
        else
            echo -e "${RED}✗${NC} Ogmios (1337) not responding"
        fi
        
        if curl -s http://localhost:1442 > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} Kupo (1442) responding"
        else
            echo -e "${RED}✗${NC} Kupo (1442) not responding"
        fi
        ;;
    
    clean)
        echo -e "${BLUE}Cleaning up...${NC}"
        read -p "This will remove all containers and volumes. Continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            echo -e "${GREEN}✓ Cleanup complete${NC}"
        else
            echo "Cleanup cancelled"
        fi
        ;;
    
    reset)
        echo -e "${BLUE}Full system reset...${NC}"
        read -p "This will reset everything. Continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down -v
            docker-compose build --no-cache
            docker-compose up -d
            echo -e "${GREEN}✓ Reset complete${NC}"
        else
            echo "Reset cancelled"
        fi
        ;;
    
    backup)
        echo -e "${BLUE}Backing up volumes...${NC}"
        BACKUP_DIR="backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        docker run --rm -v cardano-rwa_node-db:/volume -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/node-db.tar.gz -C /volume .
        docker run --rm -v cardano-rwa_kupo-db:/volume -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/kupo-db.tar.gz -C /volume .
        docker run --rm -v cardano-rwa_prometheus-data:/volume -v "$(pwd)/$BACKUP_DIR":/backup alpine tar czf /backup/prometheus-data.tar.gz -C /volume .
        
        echo -e "${GREEN}✓ Backup saved to $BACKUP_DIR${NC}"
        ls -lh "$BACKUP_DIR"
        ;;
    
    restore)
        BACKUP_DIR="${SERVICE:-.}"
        if [ ! -d "$BACKUP_DIR" ]; then
            echo -e "${RED}✗ Backup directory not found: $BACKUP_DIR${NC}"
            echo "Usage: ./docker-manage.sh restore -s <backup_dir>"
            exit 1
        fi
        
        echo -e "${BLUE}Restoring from $BACKUP_DIR...${NC}"
        read -p "This will overwrite existing volumes. Continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker-compose down
            
            docker volume rm cardano-rwa_node-db cardano-rwa_kupo-db cardano-rwa_prometheus-data 2>/dev/null || true
            docker volume create cardano-rwa_node-db
            docker volume create cardano-rwa_kupo-db
            docker volume create cardano-rwa_prometheus-data
            
            [ -f "$BACKUP_DIR/node-db.tar.gz" ] && docker run --rm -v cardano-rwa_node-db:/volume -v "$(pwd)/$BACKUP_DIR":/backup alpine tar xzf /backup/node-db.tar.gz -C /volume
            [ -f "$BACKUP_DIR/kupo-db.tar.gz" ] && docker run --rm -v cardano-rwa_kupo-db:/volume -v "$(pwd)/$BACKUP_DIR":/backup alpine tar xzf /backup/kupo-db.tar.gz -C /volume
            [ -f "$BACKUP_DIR/prometheus-data.tar.gz" ] && docker run --rm -v cardano-rwa_prometheus-data:/volume -v "$(pwd)/$BACKUP_DIR":/backup alpine tar xzf /backup/prometheus-data.tar.gz -C /volume
            
            docker-compose up -d
            echo -e "${GREEN}✓ Restore complete${NC}"
        else
            echo "Restore cancelled"
        fi
        ;;
    
    verify)
        ./verify-system.sh
        ;;
    
    prune)
        echo -e "${BLUE}Pruning Docker system...${NC}"
        read -p "This will remove unused Docker objects. Continue? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            docker system prune -f
            docker volume prune -f
            echo -e "${GREEN}✓ Prune complete${NC}"
        else
            echo "Prune cancelled"
        fi
        ;;
    
    help|--help|-h)
        show_help
        ;;
    
    *)
        echo -e "${RED}Unknown command: $COMMAND${NC}"
        show_help
        exit 1
        ;;
esac
