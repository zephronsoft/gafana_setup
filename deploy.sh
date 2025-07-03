#!/bin/bash

# ==============================================
# Facebook/Meta Monitoring Stack Deployment
# Enterprise Deployment Script
# ==============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
ENV_FILE="$SCRIPT_DIR/.env"
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
BACKUP_DIR="$SCRIPT_DIR/backups"

# Functions
print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "  Facebook/Meta Enterprise Monitoring Stack"
    echo "=================================================="
    echo -e "${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install Docker Engine >= 20.10"
        exit 1
    fi
    
    DOCKER_VERSION=$(docker version --format '{{.Server.Version}}')
    print_success "Docker version: $DOCKER_VERSION"
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        print_error "Docker Compose is not installed. Please install Docker Compose >= 2.0"
        exit 1
    fi
    
    COMPOSE_VERSION=$(docker-compose version --short)
    print_success "Docker Compose version: $COMPOSE_VERSION"
    
    # Check system resources
    TOTAL_MEM=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$TOTAL_MEM" -lt 8 ]; then
        print_warning "System has ${TOTAL_MEM}GB RAM. 8GB+ recommended for production"
    else
        print_success "System memory: ${TOTAL_MEM}GB"
    fi
    
    # Check disk space
    AVAILABLE_SPACE=$(df -BG . | tail -1 | awk '{print $4}' | sed 's/G//')
    if [ "$AVAILABLE_SPACE" -lt 100 ]; then
        print_warning "Available disk space: ${AVAILABLE_SPACE}GB. 100GB+ recommended"
    else
        print_success "Available disk space: ${AVAILABLE_SPACE}GB"
    fi
}

setup_environment() {
    print_info "Setting up environment..."
    
    if [ ! -f "$ENV_FILE" ]; then
        if [ -f "$SCRIPT_DIR/environment.example" ]; then
            cp "$SCRIPT_DIR/environment.example" "$ENV_FILE"
            print_success "Created .env file from template"
            print_warning "Please edit .env file with your configuration before proceeding"
            echo -e "${YELLOW}Required variables to configure:${NC}"
            echo "  - ADMIN_PASSWORD"
            echo "  - POSTGRES_PASSWORD" 
            echo "  - GRAFANA_SECRET_KEY"
            echo "  - SLACK_API_URL"
            echo "  - SMTP_PASSWORD"
            echo "  - PAGERDUTY_INTEGRATION_KEY"
            read -p "Press Enter after configuring .env file..."
        else
            print_error "environment.example file not found. Cannot create .env file."
            exit 1
        fi
    else
        print_success "Environment file exists"
    fi
    
    # Validate required environment variables
    source "$ENV_FILE"
    
    REQUIRED_VARS=("ADMIN_USER" "ADMIN_PASSWORD" "POSTGRES_PASSWORD" "GRAFANA_SECRET_KEY")
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    print_success "Environment variables validated"
}

create_directories() {
    print_info "Creating required directories..."
    
    DIRS=(
        "prometheus/data"
        "grafana/data"
        "alertmanager/data"
        "loki/data"
        "postgres/data"
        "ssl/certs"
        "ssl/private"
        "ssl/config"
        "ssl/backups"
        "backups"
        "logs"
        "traefik"
    )
    
    for dir in "${DIRS[@]}"; do
        mkdir -p "$SCRIPT_DIR/$dir"
        print_success "Created directory: $dir"
    done
    
    # Set proper permissions
    sudo chown -R 65534:65534 "$SCRIPT_DIR/prometheus/data" 2>/dev/null || true
    sudo chown -R 472:472 "$SCRIPT_DIR/grafana/data" 2>/dev/null || true
    sudo chown -R 65534:65534 "$SCRIPT_DIR/alertmanager/data" 2>/dev/null || true
    sudo chown -R 10001:10001 "$SCRIPT_DIR/loki/data" 2>/dev/null || true
    
    # Set SSL directory permissions
    chmod 700 "$SCRIPT_DIR/ssl/private"
    chmod 755 "$SCRIPT_DIR/ssl/certs"
    chmod 755 "$SCRIPT_DIR/ssl/config"
    chmod 755 "$SCRIPT_DIR/ssl/backups"
    
    # Create ACME JSON file for Let's Encrypt
    touch "$SCRIPT_DIR/ssl/acme.json"
    chmod 600 "$SCRIPT_DIR/ssl/acme.json"
    
    print_success "Directory permissions set"
}

generate_ssl_certificates() {
    print_info "Managing SSL certificates..."
    
    # Check if SSL manager script exists
    if [ ! -f "$SCRIPT_DIR/ssl-manager.sh" ]; then
        print_error "SSL manager script not found. Cannot generate certificates."
        exit 1
    fi
    
    # Make SSL manager executable
    chmod +x "$SCRIPT_DIR/ssl-manager.sh"
    
    # Check if certificates already exist and are valid
    if "$SCRIPT_DIR/ssl-manager.sh" check 7; then
        print_success "Valid SSL certificates found"
    else
        print_info "Generating new SSL certificates..."
        "$SCRIPT_DIR/ssl-manager.sh" generate
        print_success "SSL certificates generated successfully"
    fi
    
    # Verify certificates were created
    if [ ! -f "$SCRIPT_DIR/ssl/certs/monitoring.crt" ] || [ ! -f "$SCRIPT_DIR/ssl/private/monitoring.key" ]; then
        print_error "SSL certificate generation failed"
        exit 1
    fi
    
    print_success "SSL certificates are ready"
}

backup_existing_data() {
    if [ "$1" = "upgrade" ]; then
        print_info "Creating backup of existing data..."
        
        BACKUP_TIMESTAMP=$(date +%Y%m%d_%H%M%S)
        BACKUP_PATH="$BACKUP_DIR/backup_$BACKUP_TIMESTAMP"
        
        mkdir -p "$BACKUP_PATH"
        
        # Backup volumes if they exist
        if docker volume ls | grep -q prometheus_data; then
            docker run --rm -v prometheus_data:/data -v "$BACKUP_PATH":/backup alpine tar czf /backup/prometheus_data.tar.gz -C /data .
            print_success "Backed up Prometheus data"
        fi
        
        if docker volume ls | grep -q grafana_data; then
            docker run --rm -v grafana_data:/data -v "$BACKUP_PATH":/backup alpine tar czf /backup/grafana_data.tar.gz -C /data .
            print_success "Backed up Grafana data"
        fi
        
        print_success "Backup completed: $BACKUP_PATH"
    fi
}

deploy_stack() {
    print_info "Deploying monitoring stack..."
    
    # Pull latest images
    print_info "Pulling Docker images..."
    docker-compose -f "$COMPOSE_FILE" pull
    print_success "Images pulled successfully"
    
    # Start services
    print_info "Starting services..."
    docker-compose -f "$COMPOSE_FILE" up -d
    
    # Wait for services to be ready
    print_info "Waiting for services to be ready..."
    sleep 30
    
    # Check service health
    check_service_health
}

check_service_health() {
    print_info "Checking service health..."
    
    SERVICES=(
        "grafana:3000"
        "prometheus:9090"
        "alertmanager:9093"
        "loki:3100"
    )
    
    for service in "${SERVICES[@]}"; do
        SERVICE_NAME=$(echo "$service" | cut -d: -f1)
        SERVICE_PORT=$(echo "$service" | cut -d: -f2)
        
        if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$SERVICE_PORT" | grep -q "200\|302"; then
            print_success "$SERVICE_NAME is healthy"
        else
            print_warning "$SERVICE_NAME may not be ready yet"
        fi
    done
}

show_access_info() {
    print_info "Deployment completed successfully!"
    echo ""
    echo -e "${GREEN}Access Information:${NC}"
    echo "  Grafana:       https://localhost:3000"
    echo "  Prometheus:    https://localhost:9090"
    echo "  AlertManager:  https://localhost:9093"
    echo "  Loki:          https://localhost:3100"
    echo "  Jaeger:        https://localhost:16686"
    echo "  MailHog:       http://localhost:8025"
    echo ""
    echo -e "${GREEN}Default Credentials:${NC}"
    echo "  Username: ${ADMIN_USER:-admin}"
    echo "  Password: Check your .env file"
    echo ""
    echo -e "${GREEN}SSL Certificate Management:${NC}"
    echo "  SSL Manager:   ./ssl-manager.sh"
    echo "  Auto Renewal:  ./setup-ssl-renewal.sh"
    echo "  Certificate Status: ./ssl-manager.sh info"
    echo ""
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Login to Grafana and explore dashboards"
    echo "  2. Configure alerting channels in AlertManager"
    echo "  3. Review and customize alert rules"
    echo "  4. Set up automatic SSL renewal: ./setup-ssl-renewal.sh setup"
    echo "  5. Import CA certificate to browser for trusted access"
    echo ""
    echo -e "${YELLOW}SSL Certificate Notes:${NC}"
    echo "  - Self-signed certificates generated automatically"
    echo "  - CA certificate: ssl/certs/ca.crt"
    echo "  - Import CA certificate to browser to avoid security warnings"
    echo "  - For production, replace with proper SSL certificates"
    echo ""
}

show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  deploy     Deploy the monitoring stack (default)"
    echo "  upgrade    Upgrade existing deployment with backup"
    echo "  stop       Stop all services"
    echo "  restart    Restart all services"
    echo "  status     Show service status"
    echo "  logs       Show service logs"
    echo "  backup     Create manual backup"
    echo "  help       Show this help message"
    echo ""
}

# Main execution
case "${1:-deploy}" in
    deploy)
        print_header
        check_prerequisites
        setup_environment
        create_directories
        generate_ssl_certificates
        deploy_stack
        show_access_info
        ;;
    upgrade)
        print_header
        check_prerequisites
        backup_existing_data upgrade
        deploy_stack
        show_access_info
        ;;
    stop)
        print_info "Stopping monitoring stack..."
        docker-compose -f "$COMPOSE_FILE" down
        print_success "Services stopped"
        ;;
    restart)
        print_info "Restarting monitoring stack..."
        docker-compose -f "$COMPOSE_FILE" restart
        print_success "Services restarted"
        ;;
    status)
        print_info "Service status:"
        docker-compose -f "$COMPOSE_FILE" ps
        ;;
    logs)
        SERVICE=${2:-}
        if [ -n "$SERVICE" ]; then
            docker-compose -f "$COMPOSE_FILE" logs -f "$SERVICE"
        else
            docker-compose -f "$COMPOSE_FILE" logs -f
        fi
        ;;
    backup)
        backup_existing_data upgrade
        ;;
    help)
        show_usage
        ;;
    *)
        print_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac 