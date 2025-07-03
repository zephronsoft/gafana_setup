#!/bin/bash

# ==============================================
# Facebook/Meta SSL Certificate Renewal Script
# Automatic Certificate Renewal for Cron
# ==============================================

# Configuration
SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
LOG_FILE="$SCRIPT_DIR/ssl-renew.log"
SSL_MANAGER="$SCRIPT_DIR/ssl-manager.sh"
DOCKER_COMPOSE="$SCRIPT_DIR/docker-compose.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_success() {
    log "✓ $1"
}

log_warning() {
    log "⚠ $1"
}

log_error() {
    log "✗ $1"
}

log_info() {
    log "ℹ $1"
}

# Main renewal process
main() {
    log_info "Starting SSL certificate renewal check..."
    
    # Check if SSL manager exists
    if [ ! -f "$SSL_MANAGER" ]; then
        log_error "SSL manager script not found: $SSL_MANAGER"
        exit 1
    fi
    
    # Make SSL manager executable
    chmod +x "$SSL_MANAGER"
    
    # Check if certificates expire within 30 days
    if "$SSL_MANAGER" check 30 >> "$LOG_FILE" 2>&1; then
        log_info "Certificates are valid for more than 30 days"
        exit 0
    else
        log_warning "Certificates expire within 30 days, renewing..."
        
        # Backup existing certificates
        BACKUP_DIR="$SCRIPT_DIR/ssl/backups/auto_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        if [ -f "$SCRIPT_DIR/ssl/certs/monitoring.crt" ]; then
            cp "$SCRIPT_DIR/ssl/certs/monitoring.crt" "$BACKUP_DIR/"
            log_info "Backed up existing certificate"
        fi
        
        if [ -f "$SCRIPT_DIR/ssl/private/monitoring.key" ]; then
            cp "$SCRIPT_DIR/ssl/private/monitoring.key" "$BACKUP_DIR/"
            log_info "Backed up existing private key"
        fi
        
        # Generate new certificates
        if "$SSL_MANAGER" generate --force >> "$LOG_FILE" 2>&1; then
            log_success "New certificates generated successfully"
            
            # Restart services to use new certificates
            if [ -f "$DOCKER_COMPOSE" ]; then
                log_info "Restarting services to use new certificates..."
                
                # Check if docker-compose is available
                if command -v docker-compose &> /dev/null; then
                    if docker-compose -f "$DOCKER_COMPOSE" restart traefik >> "$LOG_FILE" 2>&1; then
                        log_success "Traefik restarted successfully"
                    else
                        log_warning "Failed to restart Traefik"
                    fi
                    
                    # Wait a bit before restarting other services
                    sleep 10
                    
                    # Restart other services that might need new certificates
                    SERVICES_TO_RESTART=("grafana" "prometheus" "alertmanager")
                    for service in "${SERVICES_TO_RESTART[@]}"; do
                        if docker-compose -f "$DOCKER_COMPOSE" restart "$service" >> "$LOG_FILE" 2>&1; then
                            log_success "Restarted $service successfully"
                        else
                            log_warning "Failed to restart $service"
                        fi
                    done
                else
                    log_warning "docker-compose not found, cannot restart services"
                fi
            else
                log_warning "Docker Compose file not found, cannot restart services"
            fi
            
            # Verify new certificates
            if "$SSL_MANAGER" check 1 >> "$LOG_FILE" 2>&1; then
                log_success "New certificates verified successfully"
                
                # Send notification (optional)
                send_notification "SSL Certificate Renewal" "SSL certificates have been renewed successfully on $(hostname)"
                
            else
                log_error "New certificate verification failed"
                exit 1
            fi
        else
            log_error "Certificate generation failed"
            exit 1
        fi
    fi
    
    log_info "SSL certificate renewal check completed"
}

# Send notification function (can be customized)
send_notification() {
    local title="$1"
    local message="$2"
    
    # Try to send notification via mail if available
    if command -v mail &> /dev/null; then
        echo "$message" | mail -s "$title" "${NOTIFICATION_EMAIL:-admin@facebook.com}" 2>/dev/null
    fi
    
    # Log notification
    log_info "Notification: $title - $message"
}

# Cleanup old log files (keep last 30 days)
cleanup_logs() {
    find "$SCRIPT_DIR" -name "ssl-renew.log.*" -type f -mtime +30 -delete 2>/dev/null
}

# Rotate log file if it's too large (>10MB)
rotate_logs() {
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt 10485760 ]; then
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d_%H%M%S)"
        touch "$LOG_FILE"
        log_info "Log file rotated"
    fi
}

# Error handling
trap 'log_error "Script interrupted"; exit 1' INT TERM

# Main execution
rotate_logs
cleanup_logs
main "$@" 