#!/bin/bash

# ==============================================
# Facebook/Meta SSL Certificate Renewal Setup
# Automatic Cron Job Configuration
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
RENEWAL_SCRIPT="$SCRIPT_DIR/ssl-renew.sh"

# Functions
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

print_header() {
    echo -e "${BLUE}"
    echo "=================================================="
    echo "   SSL Certificate Renewal Setup"
    echo "   Facebook/Meta Enterprise Monitoring"
    echo "=================================================="
    echo -e "${NC}"
}

check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if renewal script exists
    if [ ! -f "$RENEWAL_SCRIPT" ]; then
        print_error "SSL renewal script not found: $RENEWAL_SCRIPT"
        exit 1
    fi
    
    # Make renewal script executable
    chmod +x "$RENEWAL_SCRIPT"
    print_success "SSL renewal script is ready"
    
    # Check if cron is available
    if ! command -v crontab &> /dev/null; then
        print_error "crontab command not found. Please install cron."
        exit 1
    fi
    
    print_success "Prerequisites met"
}

show_current_cron() {
    print_info "Current cron jobs:"
    echo ""
    crontab -l 2>/dev/null || echo "No cron jobs configured"
    echo ""
}

setup_cron_job() {
    print_info "Setting up automatic SSL certificate renewal..."
    
    # Default schedule: Every Sunday at 2:00 AM
    local schedule="0 2 * * 0"
    local cron_job="$schedule $RENEWAL_SCRIPT >> $SCRIPT_DIR/ssl-renew.log 2>&1"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "$RENEWAL_SCRIPT"; then
        print_warning "SSL renewal cron job already exists"
        read -p "Do you want to update it? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Cron job setup cancelled"
            return
        fi
        
        # Remove existing cron job
        crontab -l 2>/dev/null | grep -v "$RENEWAL_SCRIPT" | crontab -
        print_info "Removed existing cron job"
    fi
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    print_success "SSL renewal cron job added"
    
    echo ""
    print_info "Cron job details:"
    echo "  Schedule: Every Sunday at 2:00 AM"
    echo "  Command: $RENEWAL_SCRIPT"
    echo "  Log file: $SCRIPT_DIR/ssl-renew.log"
    echo ""
}

setup_custom_schedule() {
    print_info "Setting up custom SSL certificate renewal schedule..."
    
    echo ""
    echo "Common cron schedule examples:"
    echo "  0 2 * * 0     - Every Sunday at 2:00 AM (recommended)"
    echo "  0 2 * * 1     - Every Monday at 2:00 AM"
    echo "  0 2 1 * *     - First day of every month at 2:00 AM"
    echo "  0 2 */7 * *   - Every 7 days at 2:00 AM"
    echo "  0 */12 * * *  - Every 12 hours"
    echo ""
    
    read -p "Enter cron schedule (or press Enter for default): " custom_schedule
    
    if [ -z "$custom_schedule" ]; then
        custom_schedule="0 2 * * 0"
    fi
    
    # Validate cron schedule (basic check)
    if ! echo "$custom_schedule" | grep -E '^[0-9*/,-]+ [0-9*/,-]+ [0-9*/,-]+ [0-9*/,-]+ [0-9*/,-]+$' > /dev/null; then
        print_error "Invalid cron schedule format"
        exit 1
    fi
    
    local cron_job="$custom_schedule $RENEWAL_SCRIPT >> $SCRIPT_DIR/ssl-renew.log 2>&1"
    
    # Remove existing cron job if exists
    if crontab -l 2>/dev/null | grep -q "$RENEWAL_SCRIPT"; then
        crontab -l 2>/dev/null | grep -v "$RENEWAL_SCRIPT" | crontab -
        print_info "Removed existing cron job"
    fi
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "$cron_job") | crontab -
    print_success "Custom SSL renewal cron job added"
    
    echo ""
    print_info "Cron job details:"
    echo "  Schedule: $custom_schedule"
    echo "  Command: $RENEWAL_SCRIPT"
    echo "  Log file: $SCRIPT_DIR/ssl-renew.log"
    echo ""
}

remove_cron_job() {
    print_info "Removing SSL certificate renewal cron job..."
    
    if crontab -l 2>/dev/null | grep -q "$RENEWAL_SCRIPT"; then
        crontab -l 2>/dev/null | grep -v "$RENEWAL_SCRIPT" | crontab -
        print_success "SSL renewal cron job removed"
    else
        print_warning "No SSL renewal cron job found"
    fi
}

test_renewal() {
    print_info "Testing SSL certificate renewal..."
    
    if [ ! -f "$RENEWAL_SCRIPT" ]; then
        print_error "SSL renewal script not found"
        exit 1
    fi
    
    # Run renewal script in test mode
    print_info "Running renewal script..."
    "$RENEWAL_SCRIPT"
    
    print_success "Test completed. Check the log file for details:"
    echo "  Log file: $SCRIPT_DIR/ssl-renew.log"
}

show_status() {
    print_info "SSL Certificate Renewal Status:"
    echo ""
    
    # Check if cron job exists
    if crontab -l 2>/dev/null | grep -q "$RENEWAL_SCRIPT"; then
        print_success "Cron job is configured"
        echo "Current cron job:"
        crontab -l 2>/dev/null | grep "$RENEWAL_SCRIPT"
        echo ""
    else
        print_warning "No cron job configured"
        echo ""
    fi
    
    # Check recent logs
    if [ -f "$SCRIPT_DIR/ssl-renew.log" ]; then
        echo "Recent log entries:"
        tail -10 "$SCRIPT_DIR/ssl-renew.log"
        echo ""
    else
        print_info "No log file found yet"
    fi
    
    # Check certificate expiry
    if [ -f "$SCRIPT_DIR/ssl-manager.sh" ]; then
        print_info "Certificate status:"
        "$SCRIPT_DIR/ssl-manager.sh" check 30
    fi
}

show_usage() {
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  setup      Set up automatic SSL renewal (default schedule)"
    echo "  custom     Set up with custom schedule"
    echo "  remove     Remove automatic SSL renewal"
    echo "  test       Test SSL renewal process"
    echo "  status     Show renewal status and recent logs"
    echo "  cron       Show current cron jobs"
    echo "  help       Show this help message"
    echo ""
}

# Main execution
case "${1:-setup}" in
    setup)
        print_header
        check_prerequisites
        setup_cron_job
        print_success "SSL certificate renewal setup completed!"
        ;;
    custom)
        print_header
        check_prerequisites
        setup_custom_schedule
        print_success "Custom SSL certificate renewal setup completed!"
        ;;
    remove)
        print_header
        remove_cron_job
        ;;
    test)
        print_header
        test_renewal
        ;;
    status)
        print_header
        show_status
        ;;
    cron)
        print_header
        show_current_cron
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