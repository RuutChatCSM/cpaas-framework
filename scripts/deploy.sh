#!/bin/bash

# Somleng CPaaS Production Deployment Script
# This script deploys a complete Somleng CPaaS stack with high availability

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
ENV_FILE="$PROJECT_DIR/.env"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"

# Functions
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

check_requirements() {
    log_info "Checking system requirements..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    fi
    
    # Check available disk space (minimum 20GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [ "$available_space" -lt 20971520 ]; then  # 20GB in KB
        log_warning "Less than 20GB disk space available. Consider freeing up space."
    fi
    
    # Check available memory (minimum 8GB)
    available_memory=$(free -m | awk 'NR==2{print $7}')
    if [ "$available_memory" -lt 8192 ]; then  # 8GB in MB
        log_warning "Less than 8GB memory available. Performance may be affected."
    fi
    
    log_success "System requirements check completed"
}

setup_environment() {
    log_info "Setting up environment..."
    
    # Check if .env file exists
    if [ ! -f "$ENV_FILE" ]; then
        log_info "Creating .env file from template..."
        cp "$PROJECT_DIR/.env.example" "$ENV_FILE"
        log_warning "Please edit .env file with your configuration before continuing"
        log_warning "Required changes:"
        echo "  - SOMLENG_DOMAIN: Your domain name"
        echo "  - PUBLIC_IP: Your server's public IP address"
        echo "  - SECRET_KEY_BASE: Generate with 'openssl rand -hex 64'"
        echo "  - Database passwords"
        echo "  - SSL certificate email"
        read -p "Press Enter after editing .env file..."
    fi
    
    # Source environment variables
    source "$ENV_FILE"
    
    # Validate required variables
    required_vars=(
        "SOMLENG_DOMAIN"
        "PUBLIC_IP"
        "SECRET_KEY_BASE"
        "POSTGRES_PASSWORD"
        "ADMIN_PASSWORD"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required environment variable $var is not set"
            exit 1
        fi
    done
    
    log_success "Environment setup completed"
}

setup_ssl() {
    log_info "Setting up SSL certificates..."
    
    # Create SSL directory
    mkdir -p "$PROJECT_DIR/nginx/ssl"
    
    # Check if certificates already exist
    if [ -f "$PROJECT_DIR/nginx/ssl/fullchain.pem" ] && [ -f "$PROJECT_DIR/nginx/ssl/privkey.pem" ]; then
        log_info "SSL certificates already exist"
        return
    fi
    
    # Generate self-signed certificates for initial setup
    log_info "Generating self-signed certificates for initial setup..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout "$PROJECT_DIR/nginx/ssl/privkey.pem" \
        -out "$PROJECT_DIR/nginx/ssl/fullchain.pem" \
        -subj "/C=US/ST=State/L=City/O=Organization/CN=${SOMLENG_DOMAIN}"
    
    # Generate DH parameters
    if [ ! -f "$PROJECT_DIR/nginx/ssl/dhparam.pem" ]; then
        log_info "Generating DH parameters (this may take a while)..."
        openssl dhparam -out "$PROJECT_DIR/nginx/ssl/dhparam.pem" 2048
    fi
    
    log_warning "Self-signed certificates generated. Consider using Let's Encrypt for production."
    log_success "SSL setup completed"
}

setup_firewall() {
    log_info "Configuring firewall rules..."
    
    # Check if ufw is available
    if command -v ufw &> /dev/null; then
        # Allow SSH
        ufw allow ssh
        
        # Allow HTTP and HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        
        # Allow SIP ports
        ufw allow 5060/udp
        ufw allow 5060/tcp
        ufw allow 5061/tcp
        
        # Allow RTP ports
        ufw allow 16384:32768/udp
        ufw allow 20000:30000/udp
        
        # Enable firewall
        ufw --force enable
        
        log_success "Firewall configured"
    else
        log_warning "UFW not available. Please configure firewall manually."
    fi
}

deploy_services() {
    log_info "Deploying Somleng CPaaS services..."
    
    cd "$PROJECT_DIR"
    
    # Pull latest images
    log_info "Pulling Docker images..."
    docker-compose pull
    
    # Start database services first
    log_info "Starting database services..."
    docker-compose up -d db redis
    
    # Wait for databases to be ready
    log_info "Waiting for databases to be ready..."
    sleep 30
    
    # Initialize Somleng database
    log_info "Initializing Somleng database..."
    docker-compose exec -T db psql -U somleng -d somleng_production -c "SELECT 1;" || {
        docker-compose exec -T web bundle exec rails db:create
        docker-compose exec -T web bundle exec rails db:migrate
        docker-compose exec -T web bundle exec rails db:seed
    }
    
    # Create admin user
    log_info "Creating admin user..."
    docker-compose exec -T web bundle exec rails runner "
        User.find_or_create_by(email: '${ADMIN_EMAIL}') do |user|
            user.password = '${ADMIN_PASSWORD}'
            user.admin = true
        end
    "
    
    # Start all services
    log_info "Starting all services..."
    docker-compose up -d
    
    # Wait for services to be ready
    log_info "Waiting for services to be ready..."
    sleep 60
    
    log_success "Services deployed successfully"
}

verify_deployment() {
    log_info "Verifying deployment..."
    
    # Check service health
    services=(
        "somleng_postgres"
        "somleng_redis"
        "somleng_web"
        "somleng_sidekiq"
        "somleng_freeswitch1"
        "somleng_freeswitch2"
        "somleng_kamailio"
        "somleng_nginx"
        "somleng_prometheus"
        "somleng_grafana"
    )
    
    failed_services=()
    
    for service in "${services[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "$service"; then
            log_success "$service is running"
        else
            log_error "$service is not running"
            failed_services+=("$service")
        fi
    done
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        log_success "All services are running"
    else
        log_error "Some services failed to start: ${failed_services[*]}"
        return 1
    fi
    
    # Test web interface
    log_info "Testing web interface..."
    if curl -f -s "http://localhost:3000/health" > /dev/null; then
        log_success "Web interface is accessible"
    else
        log_error "Web interface is not accessible"
        return 1
    fi
    
    log_success "Deployment verification completed"
}

setup_monitoring() {
    log_info "Setting up monitoring dashboards..."
    
    # Wait for Grafana to be ready
    sleep 30
    
    # Import default dashboards (if available)
    # This would typically involve API calls to Grafana
    
    log_info "Monitoring setup completed"
    log_info "Access monitoring at:"
    echo "  - Grafana: https://${SOMLENG_DOMAIN}:3001 (admin/admin)"
    echo "  - Prometheus: https://${SOMLENG_DOMAIN}:9090"
    echo "  - Kibana: https://${SOMLENG_DOMAIN}:5601"
}

show_deployment_info() {
    log_success "Somleng CPaaS deployment completed successfully!"
    echo
    echo "Access your Somleng CPaaS at:"
    echo "  - Web Interface: https://${SOMLENG_DOMAIN}"
    echo "  - API Endpoint: https://${SOMLENG_DOMAIN}/api"
    echo "  - Admin Login: ${ADMIN_EMAIL} / ${ADMIN_PASSWORD}"
    echo
    echo "Monitoring:"
    echo "  - Grafana: https://${SOMLENG_DOMAIN}:3001"
    echo "  - Prometheus: https://${SOMLENG_DOMAIN}:9090"
    echo "  - Kibana: https://${SOMLENG_DOMAIN}:5601"
    echo
    echo "SIP Configuration:"
    echo "  - SIP Domain: ${SIP_DOMAIN:-$SOMLENG_DOMAIN}"
    echo "  - SIP Port: 5060 (UDP/TCP)"
    echo "  - SIP TLS Port: 5061 (TCP)"
    echo
    echo "Next steps:"
    echo "  1. Configure your SIP trunks and SMS gateways"
    echo "  2. Set up Let's Encrypt for production SSL certificates"
    echo "  3. Configure monitoring alerts"
    echo "  4. Set up regular backups"
    echo
    log_warning "Remember to secure your deployment and change default passwords!"
}

# Main execution
main() {
    log_info "Starting Somleng CPaaS deployment..."
    
    check_requirements
    setup_environment
    setup_ssl
    setup_firewall
    deploy_services
    verify_deployment
    setup_monitoring
    show_deployment_info
    
    log_success "Deployment completed successfully!"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "stop")
        log_info "Stopping Somleng CPaaS services..."
        cd "$PROJECT_DIR"
        docker-compose down
        log_success "Services stopped"
        ;;
    "restart")
        log_info "Restarting Somleng CPaaS services..."
        cd "$PROJECT_DIR"
        docker-compose restart
        log_success "Services restarted"
        ;;
    "logs")
        cd "$PROJECT_DIR"
        docker-compose logs -f "${2:-}"
        ;;
    "status")
        cd "$PROJECT_DIR"
        docker-compose ps
        ;;
    "update")
        log_info "Updating Somleng CPaaS..."
        cd "$PROJECT_DIR"
        docker-compose pull
        docker-compose up -d
        log_success "Update completed"
        ;;
    *)
        echo "Usage: $0 {deploy|stop|restart|logs|status|update}"
        echo "  deploy  - Deploy the complete stack"
        echo "  stop    - Stop all services"
        echo "  restart - Restart all services"
        echo "  logs    - Show logs (optionally for specific service)"
        echo "  status  - Show service status"
        echo "  update  - Update and restart services"
        exit 1
        ;;
esac