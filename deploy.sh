#!/bin/bash

# ==============================================
# Facebook/Meta Monitoring Stack Deployment
# No SSL - Internal SMTP Setup
# ==============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if .env file exists
if [ ! -f .env ]; then
    print_error ".env file not found. Please copy environment.example to .env and configure it."
    exit 1
fi

# Load environment variables
source .env

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to check required environment variables
check_env_vars() {
    local missing_vars=()
    
    # Generate secret key if not set
    if [ -z "$GRAFANA_SECRET_KEY" ]; then
        print_warning "GRAFANA_SECRET_KEY not set, generating one..."
        SECRET_KEY=$(openssl rand -hex 32)
        echo "GRAFANA_SECRET_KEY=$SECRET_KEY" >> .env
        print_success "Generated GRAFANA_SECRET_KEY"
        # Reload environment variables
        source .env
    fi
    
    # Required variables for both modes
    if [ -z "$ADMIN_PASSWORD" ]; then
        missing_vars+=("ADMIN_PASSWORD")
    fi
    
    if [ -z "$POSTGRES_PASSWORD" ]; then
        missing_vars+=("POSTGRES_PASSWORD")
    fi
    
    # Check SMTP variables for both modes (make them optional for development)
    if [ "$1" = "production" ]; then
        if [ -z "$SMTP_USER" ]; then
            missing_vars+=("SMTP_USER")
        fi
        
        if [ -z "$SMTP_PASSWORD" ]; then
            missing_vars+=("SMTP_PASSWORD")
        fi
        
        if [ -z "$SMTP_FROM" ]; then
            missing_vars+=("SMTP_FROM")
        fi
    else
        # For development, set default SMTP values if not provided
        if [ -z "$SMTP_USER" ]; then
            print_warning "SMTP_USER not set, using default for development..."
            echo "SMTP_USER=monitoring@monitoring.local" >> .env
        fi
        
        if [ -z "$SMTP_PASSWORD" ]; then
            print_warning "SMTP_PASSWORD not set, using default for development..."
            echo "SMTP_PASSWORD=dev-password" >> .env
        fi
        
        if [ -z "$SMTP_FROM" ]; then
            print_warning "SMTP_FROM not set, using default for development..."
            echo "SMTP_FROM=noreply@monitoring.local" >> .env
        fi
    fi
    
    if [ ${#missing_vars[@]} -ne 0 ]; then
        print_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi
    
    print_success "Environment variables validated"
}

# Function to create required directories
create_directories() {
    print_status "Creating required directories..."
    
    mkdir -p mailhog
    mkdir -p grafana/dashboards
    mkdir -p grafana/provisioning/dashboards
    mkdir -p grafana/provisioning/datasources
    
    print_success "Directories created"
}



# Function to deploy development stack
deploy_development() {
    print_status "Deploying development stack with MailHog SMTP..."
    
    docker-compose up -d
    
    print_success "Development stack deployed successfully!"
    print_status "Services available at:"
    echo "  - Grafana: http://localhost:3000"
    echo "  - Prometheus: http://localhost:9090"
    echo "  - AlertManager: http://localhost:9093"
    echo "  - Loki: http://localhost:3100"
    echo "  - Jaeger: http://localhost:16686"
    echo "  - MailHog (SMTP): http://localhost:8025"
    echo "  - cAdvisor: http://localhost:8080"
    echo "  - Node Exporter: http://localhost:9100"
    echo "  - Pushgateway: http://localhost:9091"
    echo "  - Blackbox: http://localhost:9115"
    echo "  - Redis: localhost:6379"
    
    print_status "Default credentials:"
    echo "  - Grafana Admin: $ADMIN_USER / $ADMIN_PASSWORD"
    echo "  - MailHog: No authentication required"
    echo "  - SMTP (MailHog): localhost:1025"
}

# Function to deploy production stack
deploy_production() {
    print_status "Deploying production stack with internal Postfix SMTP..."
    
    docker-compose -f docker-compose.production.yml up -d
    
    print_success "Production stack deployed successfully!"
    print_status "Services available at:"
    echo "  - Grafana: http://$GRAFANA_DOMAIN:3000"
    echo "  - Prometheus: http://prometheus.$GRAFANA_DOMAIN:9090"
    echo "  - AlertManager: http://alertmanager.$GRAFANA_DOMAIN:9093"
    echo "  - Loki: http://loki.$GRAFANA_DOMAIN:3100"
    echo "  - Jaeger: http://jaeger.$GRAFANA_DOMAIN:16686"
    echo "  - Postfix SMTP: localhost:587"
    echo "  - cAdvisor: http://localhost:8080"
    echo "  - Node Exporter: http://localhost:9100"
    echo "  - Pushgateway: http://localhost:9091"
    echo "  - Blackbox: http://localhost:9115"
    echo "  - Redis: localhost:6379"
    
    print_status "Default credentials:"
    echo "  - Grafana Admin: $ADMIN_USER / $ADMIN_PASSWORD"
    echo "  - SMTP (Postfix): $SMTP_USER / $SMTP_PASSWORD"
    echo "  - SMTP Server: postfix:587"
}

# Function to stop stack
stop_stack() {
    print_status "Stopping monitoring stack..."
    
    if [ "$1" = "production" ]; then
        docker-compose -f docker-compose.production.yml down
    else
        docker-compose down
    fi
    
    print_success "Stack stopped"
}

# Function to show logs
show_logs() {
    print_status "Showing logs for $1 stack..."
    
    if [ "$1" = "production" ]; then
        docker-compose -f docker-compose.production.yml logs -f
    else
        docker-compose logs -f
    fi
}

# Function to show status
show_status() {
    print_status "Checking service status..."
    
    if [ "$1" = "production" ]; then
        docker-compose -f docker-compose.production.yml ps
    else
        docker-compose ps
    fi
}

# Function to backup data
backup_data() {
    print_status "Creating backup..."
    
    BACKUP_DIR="backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$BACKUP_DIR"
    
    # Backup volumes
    docker run --rm -v grafana_setup_grafana_data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar czf /backup/grafana_data.tar.gz -C /data .
    docker run --rm -v grafana_setup_prometheus_data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar czf /backup/prometheus_data.tar.gz -C /data .
    docker run --rm -v grafana_setup_alertmanager_data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar czf /backup/alertmanager_data.tar.gz -C /data .
    docker run --rm -v grafana_setup_loki_data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar czf /backup/loki_data.tar.gz -C /data .
    docker run --rm -v grafana_setup_postgres_data:/data -v "$(pwd)/$BACKUP_DIR:/backup" alpine tar czf /backup/postgres_data.tar.gz -C /data .
    
    print_success "Backup created in $BACKUP_DIR/"
}

# Function to restore data
restore_data() {
    if [ -z "$1" ]; then
        print_error "Please specify backup directory"
        exit 1
    fi
    
    print_status "Restoring from backup: $1"
    
    if [ ! -d "$1" ]; then
        print_error "Backup directory $1 not found"
        exit 1
    fi
    
    # Stop stack first
    stop_stack "$2"
    
    # Restore volumes
    docker run --rm -v grafana_setup_grafana_data:/data -v "$(pwd)/$1:/backup" alpine sh -c "rm -rf /data/* && tar xzf /backup/grafana_data.tar.gz -C /data"
    docker run --rm -v grafana_setup_prometheus_data:/data -v "$(pwd)/$1:/backup" alpine sh -c "rm -rf /data/* && tar xzf /backup/prometheus_data.tar.gz -C /data"
    docker run --rm -v grafana_setup_alertmanager_data:/data -v "$(pwd)/$1:/backup" alpine sh -c "rm -rf /data/* && tar xzf /backup/alertmanager_data.tar.gz -C /data"
    docker run --rm -v grafana_setup_loki_data:/data -v "$(pwd)/$1:/backup" alpine sh -c "rm -rf /data/* && tar xzf /backup/loki_data.tar.gz -C /data"
    docker run --rm -v grafana_setup_postgres_data:/data -v "$(pwd)/$1:/backup" alpine sh -c "rm -rf /data/* && tar xzf /backup/postgres_data.tar.gz -C /data"
    
    print_success "Data restored from $1"
}

# Function to test SMTP
test_smtp() {
    print_status "Testing SMTP configuration..."
    
    if [ "$1" = "production" ]; then
        print_status "Testing production Postfix SMTP..."
        # Test Postfix SMTP
        if command -v telnet > /dev/null 2>&1; then
            echo "QUIT" | telnet localhost 587
            print_success "Postfix SMTP port 587 is accessible"
        else
            print_warning "telnet not available, cannot test SMTP connectivity"
        fi
    else
        print_status "Testing development MailHog SMTP..."
        # Test MailHog SMTP
        if command -v curl > /dev/null 2>&1; then
            if curl -s http://localhost:8025 > /dev/null; then
                print_success "MailHog web interface is accessible at http://localhost:8025"
            else
                print_warning "MailHog web interface not accessible"
            fi
        fi
    fi
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  dev                    Deploy development stack with MailHog SMTP"
    echo "  prod                   Deploy production stack with internal Postfix SMTP"
    echo "  stop [dev|prod]        Stop the stack"
    echo "  logs [dev|prod]        Show logs"
    echo "  status [dev|prod]      Show service status"
    echo "  backup                 Create backup of all data"
    echo "  restore <backup_dir>   Restore from backup"
    echo "  test-smtp [dev|prod]   Test SMTP configuration"
    echo "  help                   Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 dev                 Deploy development stack"
    echo "  $0 prod                Deploy production stack"
    echo "  $0 stop dev            Stop development stack"
    echo "  $0 logs prod           Show production logs"
    echo "  $0 backup              Create backup"
    echo "  $0 restore backup_20231201_120000"
    echo "  $0 test-smtp dev       Test MailHog SMTP"
    echo "  $0 test-smtp prod      Test Postfix SMTP"
    echo ""
    echo "SMTP Configuration:"
    echo "  Development: MailHog (localhost:1025, web UI: localhost:8025)"
    echo "  Production:  Postfix (localhost:587, internal SMTP server)"
}

# Main script logic
case "$1" in
    "dev")
        check_docker
        check_env_vars "development"
        create_directories
        deploy_development
        ;;
    "prod")
        check_docker
        check_env_vars "production"
        create_directories
        deploy_production
        ;;
    "stop")
        stop_stack "$2"
        ;;
    "logs")
        show_logs "$2"
        ;;
    "status")
        show_status "$2"
        ;;
    "backup")
        backup_data
        ;;
    "restore")
        restore_data "$2" "$3"
        ;;
    "test-smtp")
        test_smtp "$2"
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac 