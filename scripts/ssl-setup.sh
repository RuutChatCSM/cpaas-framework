#!/bin/bash

# SSL Certificate Setup Script for Somleng CPaaS
# Supports both Let's Encrypt and self-signed certificates

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_DIR/nginx/ssl"
ENV_FILE="$PROJECT_DIR/.env"

# Source environment variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    log_error ".env file not found. Please run deployment script first."
    exit 1
fi

setup_letsencrypt() {
    log_info "Setting up Let's Encrypt SSL certificates..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        log_info "Installing certbot..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y certbot python3-certbot-nginx
        elif command -v yum &> /dev/null; then
            yum install -y certbot python3-certbot-nginx
        else
            log_error "Package manager not supported. Please install certbot manually."
            exit 1
        fi
    fi
    
    # Stop nginx temporarily
    log_info "Stopping nginx temporarily..."
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" stop nginx
    
    # Generate certificates
    log_info "Generating Let's Encrypt certificates for ${SOMLENG_DOMAIN}..."
    certbot certonly --standalone \
        --email "${LETSENCRYPT_EMAIL}" \
        --agree-tos \
        --no-eff-email \
        --domains "${SOMLENG_DOMAIN}" \
        --domains "monitoring.${SOMLENG_DOMAIN}" \
        --domains "logs.${SOMLENG_DOMAIN}" \
        --domains "metrics.${SOMLENG_DOMAIN}"
    
    # Copy certificates to nginx directory
    log_info "Copying certificates to nginx directory..."
    mkdir -p "$SSL_DIR"
    cp "/etc/letsencrypt/live/${SOMLENG_DOMAIN}/fullchain.pem" "$SSL_DIR/"
    cp "/etc/letsencrypt/live/${SOMLENG_DOMAIN}/privkey.pem" "$SSL_DIR/"
    
    # Generate DH parameters if not exists
    if [ ! -f "$SSL_DIR/dhparam.pem" ]; then
        log_info "Generating DH parameters..."
        openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    fi
    
    # Set proper permissions
    chmod 644 "$SSL_DIR/fullchain.pem"
    chmod 600 "$SSL_DIR/privkey.pem"
    chmod 644 "$SSL_DIR/dhparam.pem"
    
    # Start nginx
    log_info "Starting nginx..."
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" start nginx
    
    # Setup auto-renewal
    setup_auto_renewal
    
    log_success "Let's Encrypt certificates installed successfully!"
}

setup_self_signed() {
    log_info "Setting up self-signed SSL certificates..."
    
    mkdir -p "$SSL_DIR"
    
    # Generate private key
    log_info "Generating private key..."
    openssl genrsa -out "$SSL_DIR/privkey.pem" 2048
    
    # Generate certificate signing request
    log_info "Generating certificate signing request..."
    openssl req -new -key "$SSL_DIR/privkey.pem" -out "$SSL_DIR/cert.csr" -subj "/C=US/ST=State/L=City/O=Organization/CN=${SOMLENG_DOMAIN}"
    
    # Generate self-signed certificate
    log_info "Generating self-signed certificate..."
    openssl x509 -req -days 365 -in "$SSL_DIR/cert.csr" -signkey "$SSL_DIR/privkey.pem" -out "$SSL_DIR/fullchain.pem"
    
    # Generate DH parameters
    log_info "Generating DH parameters..."
    openssl dhparam -out "$SSL_DIR/dhparam.pem" 2048
    
    # Set proper permissions
    chmod 644 "$SSL_DIR/fullchain.pem"
    chmod 600 "$SSL_DIR/privkey.pem"
    chmod 644 "$SSL_DIR/dhparam.pem"
    
    # Clean up
    rm -f "$SSL_DIR/cert.csr"
    
    log_success "Self-signed certificates generated successfully!"
    log_warning "Self-signed certificates are not trusted by browsers. Use Let's Encrypt for production."
}

setup_auto_renewal() {
    log_info "Setting up automatic certificate renewal..."
    
    # Create renewal script
    cat > "/usr/local/bin/renew-somleng-certs.sh" << 'EOF'
#!/bin/bash
# Somleng CPaaS Certificate Renewal Script

PROJECT_DIR="/path/to/somleng-cpaas-deploy"  # Update this path
SSL_DIR="$PROJECT_DIR/nginx/ssl"

# Renew certificates
certbot renew --quiet

# Copy renewed certificates
if [ -f "/etc/letsencrypt/live/DOMAIN/fullchain.pem" ]; then
    cp "/etc/letsencrypt/live/DOMAIN/fullchain.pem" "$SSL_DIR/"
    cp "/etc/letsencrypt/live/DOMAIN/privkey.pem" "$SSL_DIR/"
    
    # Reload nginx
    docker-compose -f "$PROJECT_DIR/docker-compose.yml" exec nginx nginx -s reload
fi
EOF
    
    # Update script with actual values
    sed -i "s|/path/to/somleng-cpaas-deploy|$PROJECT_DIR|g" "/usr/local/bin/renew-somleng-certs.sh"
    sed -i "s|DOMAIN|$SOMLENG_DOMAIN|g" "/usr/local/bin/renew-somleng-certs.sh"
    
    # Make script executable
    chmod +x "/usr/local/bin/renew-somleng-certs.sh"
    
    # Add to crontab
    (crontab -l 2>/dev/null; echo "0 3 * * * /usr/local/bin/renew-somleng-certs.sh") | crontab -
    
    log_success "Auto-renewal configured. Certificates will be renewed daily at 3 AM."
}

verify_certificates() {
    log_info "Verifying SSL certificates..."
    
    if [ ! -f "$SSL_DIR/fullchain.pem" ] || [ ! -f "$SSL_DIR/privkey.pem" ]; then
        log_error "SSL certificates not found!"
        return 1
    fi
    
    # Check certificate validity
    if openssl x509 -in "$SSL_DIR/fullchain.pem" -text -noout > /dev/null 2>&1; then
        log_success "Certificate is valid"
        
        # Show certificate details
        log_info "Certificate details:"
        openssl x509 -in "$SSL_DIR/fullchain.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:)"
        
        # Check expiration
        expiry_date=$(openssl x509 -in "$SSL_DIR/fullchain.pem" -enddate -noout | cut -d= -f2)
        expiry_timestamp=$(date -d "$expiry_date" +%s)
        current_timestamp=$(date +%s)
        days_until_expiry=$(( (expiry_timestamp - current_timestamp) / 86400 ))
        
        if [ $days_until_expiry -lt 30 ]; then
            log_warning "Certificate expires in $days_until_expiry days"
        else
            log_success "Certificate expires in $days_until_expiry days"
        fi
    else
        log_error "Certificate is invalid!"
        return 1
    fi
    
    # Test HTTPS connection
    log_info "Testing HTTPS connection..."
    if curl -k -s "https://localhost" > /dev/null 2>&1; then
        log_success "HTTPS connection successful"
    else
        log_warning "HTTPS connection failed (this may be normal if nginx is not running)"
    fi
}

show_certificate_info() {
    log_info "SSL Certificate Information:"
    echo
    
    if [ -f "$SSL_DIR/fullchain.pem" ]; then
        echo "Certificate file: $SSL_DIR/fullchain.pem"
        echo "Private key file: $SSL_DIR/privkey.pem"
        echo "DH parameters file: $SSL_DIR/dhparam.pem"
        echo
        
        # Certificate details
        openssl x509 -in "$SSL_DIR/fullchain.pem" -text -noout | grep -E "(Subject:|Issuer:|Not Before:|Not After:|DNS:)"
    else
        log_error "No certificates found!"
    fi
}

# Main function
main() {
    case "${1:-help}" in
        "letsencrypt")
            setup_letsencrypt
            verify_certificates
            ;;
        "self-signed")
            setup_self_signed
            verify_certificates
            ;;
        "verify")
            verify_certificates
            ;;
        "info")
            show_certificate_info
            ;;
        "renew")
            if [ -f "/usr/local/bin/renew-somleng-certs.sh" ]; then
                log_info "Running certificate renewal..."
                /usr/local/bin/renew-somleng-certs.sh
            else
                log_error "Auto-renewal not configured. Run 'letsencrypt' setup first."
            fi
            ;;
        *)
            echo "Usage: $0 {letsencrypt|self-signed|verify|info|renew}"
            echo
            echo "Commands:"
            echo "  letsencrypt  - Setup Let's Encrypt certificates (recommended for production)"
            echo "  self-signed  - Generate self-signed certificates (for testing)"
            echo "  verify       - Verify existing certificates"
            echo "  info         - Show certificate information"
            echo "  renew        - Manually renew Let's Encrypt certificates"
            echo
            echo "Examples:"
            echo "  $0 letsencrypt    # Setup Let's Encrypt for production"
            echo "  $0 self-signed    # Generate self-signed certs for testing"
            echo "  $0 verify         # Check certificate validity"
            exit 1
            ;;
    esac
}

main "$@"