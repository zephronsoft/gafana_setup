#!/bin/bash

# ==============================================
# Facebook/Meta SSL Certificate Manager
# Dynamic Certificate Creation & Management
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
SSL_DIR="$SCRIPT_DIR/ssl"
CERTS_DIR="$SSL_DIR/certs"
PRIVATE_DIR="$SSL_DIR/private"
CONFIG_DIR="$SSL_DIR/config"
BACKUP_DIR="$SSL_DIR/backups"

# Certificate configuration
CERT_DAYS=365
CERT_COUNTRY="US"
CERT_STATE="CA"
CERT_CITY="Menlo Park"
CERT_ORG="Facebook"
CERT_OU="Platform Reliability"
CERT_EMAIL="platform-reliability@facebook.com"

# Domain configuration
PRIMARY_DOMAIN="monitoring.facebook.com"
DOMAINS=(
    "monitoring.facebook.com"
    "grafana.facebook.com"
    "prometheus.facebook.com"
    "alertmanager.facebook.com"
    "loki.facebook.com"
    "jaeger.facebook.com"
    "mailhog.facebook.com"
    "localhost"
    "127.0.0.1"
)

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
    echo "     Facebook/Meta SSL Certificate Manager"
    echo "=================================================="
    echo -e "${NC}"
}

create_directories() {
    print_info "Creating SSL directory structure..."
    
    local dirs=("$SSL_DIR" "$CERTS_DIR" "$PRIVATE_DIR" "$CONFIG_DIR" "$BACKUP_DIR")
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    
    # Set secure permissions for private directory
    chmod 700 "$PRIVATE_DIR"
    
    print_success "SSL directories created"
}

check_existing_certificates() {
    print_info "Checking for existing certificates..."
    
    local cert_file="$CERTS_DIR/monitoring.crt"
    local key_file="$PRIVATE_DIR/monitoring.key"
    
    if [[ -f "$cert_file" && -f "$key_file" ]]; then
        print_info "Found existing certificates, validating..."
        
        # Check if certificate is valid and not expired
        if openssl x509 -in "$cert_file" -noout -checkend 86400 2>/dev/null; then
            print_success "Existing certificates are valid"
            return 0
        else
            print_warning "Existing certificates are expired or invalid"
            backup_certificates
            return 1
        fi
    else
        print_info "No existing certificates found"
        return 1
    fi
}

backup_certificates() {
    print_info "Backing up existing certificates..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_path="$BACKUP_DIR/backup_$timestamp"
    
    mkdir -p "$backup_path"
    
    if [[ -f "$CERTS_DIR/monitoring.crt" ]]; then
        cp "$CERTS_DIR/monitoring.crt" "$backup_path/"
        print_success "Certificate backed up"
    fi
    
    if [[ -f "$PRIVATE_DIR/monitoring.key" ]]; then
        cp "$PRIVATE_DIR/monitoring.key" "$backup_path/"
        print_success "Private key backed up"
    fi
    
    if [[ -d "$CERTS_DIR" ]]; then
        cp -r "$CERTS_DIR"/* "$backup_path/" 2>/dev/null || true
    fi
}

generate_openssl_config() {
    print_info "Generating OpenSSL configuration..."
    
    local config_file="$CONFIG_DIR/openssl.cnf"
    
    cat > "$config_file" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=$CERT_COUNTRY
ST=$CERT_STATE
L=$CERT_CITY
O=$CERT_ORG
OU=$CERT_OU
CN=$PRIMARY_DOMAIN
emailAddress=$CERT_EMAIL

[v3_req]
basicConstraints = CA:FALSE
keyUsage = keyEncipherment, dataEncipherment, digitalSignature
subjectAltName = @alt_names

[v3_ca]
subjectKeyIdentifier=hash
authorityKeyIdentifier=keyid:always,issuer
basicConstraints = critical,CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[alt_names]
EOF

    # Add all domains to SAN
    local i=1
    for domain in "${DOMAINS[@]}"; do
        if [[ $domain =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "IP.$i = $domain" >> "$config_file"
        else
            echo "DNS.$i = $domain" >> "$config_file"
        fi
        ((i++))
    done
    
    print_success "OpenSSL configuration generated"
}

generate_ca_certificate() {
    print_info "Generating Certificate Authority (CA)..."
    
    local ca_key="$PRIVATE_DIR/ca.key"
    local ca_cert="$CERTS_DIR/ca.crt"
    local config_file="$CONFIG_DIR/openssl.cnf"
    
    # Generate CA private key
    openssl genrsa -out "$ca_key" 4096
    chmod 600 "$ca_key"
    
    # Generate CA certificate
    openssl req -new -x509 -days $((CERT_DAYS * 3)) -key "$ca_key" -out "$ca_cert" \
        -config "$config_file" -extensions v3_ca \
        -subj "/C=$CERT_COUNTRY/ST=$CERT_STATE/L=$CERT_CITY/O=$CERT_ORG/OU=$CERT_OU/CN=Facebook Monitoring CA/emailAddress=$CERT_EMAIL"
    
    chmod 644 "$ca_cert"
    
    print_success "CA certificate generated"
}

generate_server_certificate() {
    print_info "Generating server certificate..."
    
    local server_key="$PRIVATE_DIR/monitoring.key"
    local server_csr="$CONFIG_DIR/monitoring.csr"
    local server_cert="$CERTS_DIR/monitoring.crt"
    local ca_key="$PRIVATE_DIR/ca.key"
    local ca_cert="$CERTS_DIR/ca.crt"
    local config_file="$CONFIG_DIR/openssl.cnf"
    
    # Generate server private key
    openssl genrsa -out "$server_key" 2048
    chmod 600 "$server_key"
    
    # Generate certificate signing request
    openssl req -new -key "$server_key" -out "$server_csr" \
        -config "$config_file" -extensions v3_req
    
    # Generate server certificate signed by CA
    openssl x509 -req -in "$server_csr" -CA "$ca_cert" -CAkey "$ca_key" \
        -CAcreateserial -out "$server_cert" -days "$CERT_DAYS" \
        -extensions v3_req -extfile "$config_file"
    
    chmod 644 "$server_cert"
    
    # Clean up CSR
    rm -f "$server_csr"
    
    print_success "Server certificate generated"
}

create_certificate_bundle() {
    print_info "Creating certificate bundles..."
    
    local ca_cert="$CERTS_DIR/ca.crt"
    local server_cert="$CERTS_DIR/monitoring.crt"
    local bundle_cert="$CERTS_DIR/monitoring-bundle.crt"
    
    # Create certificate bundle (cert + CA)
    cat "$server_cert" "$ca_cert" > "$bundle_cert"
    chmod 644 "$bundle_cert"
    
    # Create full chain bundle
    local fullchain_cert="$CERTS_DIR/monitoring-fullchain.crt"
    cp "$server_cert" "$fullchain_cert"
    
    print_success "Certificate bundles created"
}

create_dhparam() {
    print_info "Generating Diffie-Hellman parameters..."
    
    local dhparam_file="$CERTS_DIR/dhparam.pem"
    
    if [[ ! -f "$dhparam_file" ]]; then
        openssl dhparam -out "$dhparam_file" 2048
        chmod 644 "$dhparam_file"
        print_success "DH parameters generated"
    else
        print_success "DH parameters already exist"
    fi
}

validate_certificates() {
    print_info "Validating generated certificates..."
    
    local server_cert="$CERTS_DIR/monitoring.crt"
    local server_key="$PRIVATE_DIR/monitoring.key"
    local ca_cert="$CERTS_DIR/ca.crt"
    
    # Validate certificate and key match
    local cert_modulus=$(openssl x509 -noout -modulus -in "$server_cert" | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$server_key" | openssl md5)
    
    if [[ "$cert_modulus" == "$key_modulus" ]]; then
        print_success "Certificate and key match"
    else
        print_error "Certificate and key do not match!"
        return 1
    fi
    
    # Validate certificate against CA
    if openssl verify -CAfile "$ca_cert" "$server_cert" &>/dev/null; then
        print_success "Certificate verification successful"
    else
        print_warning "Certificate verification failed (self-signed)"
    fi
    
    # Check certificate expiration
    local expiry_date=$(openssl x509 -enddate -noout -in "$server_cert" | cut -d= -f2)
    print_success "Certificate expires: $expiry_date"
}

show_certificate_info() {
    print_info "Certificate Information:"
    echo ""
    
    local server_cert="$CERTS_DIR/monitoring.crt"
    
    if [[ -f "$server_cert" ]]; then
        echo -e "${GREEN}Main Certificate:${NC}"
        openssl x509 -in "$server_cert" -text -noout | grep -E "(Subject:|Not Before|Not After|DNS:|IP Address:)"
        echo ""
        
        echo -e "${GREEN}Available Certificate Files:${NC}"
        ls -la "$CERTS_DIR"/*.crt 2>/dev/null || echo "No certificates found"
        echo ""
        
        echo -e "${GREEN}Available Private Keys:${NC}"
        ls -la "$PRIVATE_DIR"/*.key 2>/dev/null || echo "No private keys found"
        echo ""
    else
        print_warning "No certificates generated yet"
    fi
}

check_certificate_expiry() {
    local warn_days=${1:-30}
    local server_cert="$CERTS_DIR/monitoring.crt"
    
    if [[ ! -f "$server_cert" ]]; then
        print_error "Certificate not found"
        return 1
    fi
    
    local warn_seconds=$((warn_days * 24 * 60 * 60))
    
    if openssl x509 -checkend "$warn_seconds" -noout -in "$server_cert"; then
        print_success "Certificate is valid for more than $warn_days days"
        return 0
    else
        print_warning "Certificate expires within $warn_days days"
        return 1
    fi
}

main() {
    case "${1:-generate}" in
        generate)
            print_header
            create_directories
            
            if [[ "${2}" != "--force" ]] && check_existing_certificates; then
                print_info "Valid certificates already exist. Use --force to regenerate."
                show_certificate_info
                exit 0
            fi
            
            generate_openssl_config
            generate_ca_certificate
            generate_server_certificate
            create_certificate_bundle
            create_dhparam
            validate_certificates
            
            print_success "SSL certificates generated successfully!"
            show_certificate_info
            
            echo -e "${YELLOW}Next Steps:${NC}"
            echo "1. Restart your services to use the new certificates"
            echo "2. Import CA certificate to browser for trusted access"
            ;;
        
        check)
            local warn_days=${2:-30}
            check_certificate_expiry "$warn_days"
            ;;
        
        info)
            show_certificate_info
            ;;
        
        renew)
            if ! check_certificate_expiry 30; then
                "$0" generate --force
            else
                print_info "Certificates are still valid"
            fi
            ;;
        
        help)
            echo "Usage: $0 [COMMAND] [OPTIONS]"
            echo ""
            echo "Commands:"
            echo "  generate [--force]    Generate new certificates"
            echo "  check [days]          Check certificate expiry (default: 30 days)"
            echo "  info                  Show certificate information"
            echo "  renew                 Renew certificates if needed"
            echo "  help                  Show this help message"
            ;;
        
        *)
            print_error "Unknown command: $1"
            "$0" help
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@" 