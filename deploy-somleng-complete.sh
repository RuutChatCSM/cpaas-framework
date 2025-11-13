#!/bin/bash

# =============================================================================
# Complete Somleng Infrastructure Deployment Script
# =============================================================================

set -e

echo "🚀 Starting Complete Somleng Infrastructure Deployment"
echo "======================================================="

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

# Check if required files exist
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    if [ ! -f "docker-compose.yml" ]; then
        print_error "docker-compose.yml not found!"
        exit 1
    fi
    
    if [ ! -f ".env.example" ]; then
        print_error ".env.example not found!"
        exit 1
    fi
    
    if [ ! -d "/tmp/somleng-switch" ]; then
        print_status "Cloning SomlengSWITCH repository..."
        cd /tmp && git clone https://github.com/somleng/somleng-switch.git --depth 1
    fi
    
    print_success "Prerequisites check completed"
}

# Validate environment configuration
validate_config() {
    print_status "Validating configuration..."
    
    if ! grep -q "PUBLIC_IP=YOUR_PUBLIC_IP_HERE" .env; then
        print_success "Configuration appears to be customized"
    else
        print_error "Please configure .env with your actual values!"
        print_warning "At minimum, set: PUBLIC_IP, POSTGRES_PASSWORD, SECRET_KEY_BASE"
        exit 1
    fi
}

# Build and start infrastructure
deploy_infrastructure() {
    print_status "Building and starting Somleng infrastructure..."
    
    # Environment file should already exist as .env
    if [ ! -f ".env" ]; then
        print_error ".env file not found! Please copy .env.example to .env and configure it."
        exit 1
    fi
    
    # Stop any existing containers
    print_status "Stopping existing containers..."
    docker-compose down --remove-orphans 2>/dev/null || true
    
    # Build images
    print_status "Building custom images..."
    docker-compose build --parallel
    
    # Start infrastructure services first
    print_status "Starting infrastructure services..."
    docker-compose up -d db redis
    
    # Wait for database
    print_status "Waiting for database to be ready..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if docker-compose exec -T db pg_isready -U postgres > /dev/null 2>&1; then
            break
        fi
        sleep 2
        ((timeout--))
    done
    
    if [ $timeout -eq 0 ]; then
        print_error "Database failed to start within timeout"
        exit 1
    fi
    
    print_success "Database is ready"
    
    # Initialize databases
    print_status "Initializing OpenSIPS databases..."
    docker-compose up gateway_bootstrap
    docker-compose rm -f gateway_bootstrap
    
    # Start core Somleng services
    print_status "Starting Somleng Core services..."
    docker-compose up -d somleng_web somleng_sidekiq
    
    # Start SomlengSWITCH infrastructure
    print_status "Starting SomlengSWITCH infrastructure..."
    
    # Start media proxy
    docker-compose up -d media_proxy
    
    # Start gateways
    docker-compose up -d public_gateway client_gateway
    
    # Start FreeSWITCH cluster
    docker-compose up -d freeswitch1 freeswitch2
    
    # Start TwiML engine
    docker-compose up -d somleng_switch_app
    
    # Start supporting services
    docker-compose up -d \
        freeswitch1_event_logger \
        freeswitch2_event_logger \
        somleng_services \
        public_gateway_scheduler \
        client_gateway_scheduler \
        sms_gateway \
        nginx
    
    print_success "All services started"
}

# Health check
health_check() {
    print_status "Performing health checks..."
    
    services=(
        "somleng_postgres:5432"
        "somleng_redis:6379"
        "somleng_web:3000"
        "somleng_switch_app:8080"
        "somleng_public_gateway:5060"
        "somleng_client_gateway:5060"
        "somleng_media_proxy:2223"
        "somleng_freeswitch1:5222"
        "somleng_freeswitch2:5222"
    )
    
    for service in "${services[@]}"; do
        container=$(echo $service | cut -d: -f1)
        port=$(echo $service | cut -d: -f2)
        
        print_status "Checking $container:$port..."
        
        timeout=30
        while [ $timeout -gt 0 ]; do
            if docker-compose exec -T $container nc -z localhost $port > /dev/null 2>&1; then
                print_success "$container:$port is healthy"
                break
            fi
            sleep 2
            ((timeout--))
        done
        
        if [ $timeout -eq 0 ]; then
            print_warning "$container:$port health check timed out"
        fi
    done
}

# Display status
show_status() {
    print_status "Deployment Status:"
    echo "=================="
    docker-compose ps
    
    echo ""
    print_status "Service URLs:"
    echo "============="
    echo "Somleng Web Interface: http://localhost:3000"
    echo "SomlengSWITCH API:     http://localhost:8080"
    echo "NGINX:                 http://localhost:80"
    
    echo ""
    print_status "SIP Endpoints:"
    echo "=============="
    echo "Public Gateway (Carriers):  sip://localhost:5060"
    echo "Client Gateway (Customers): sip://localhost:5070"
    
    echo ""
    print_status "FreeSWITCH Instances:"
    echo "===================="
    echo "FreeSWITCH 1: localhost:5062 (Event Socket: 8021)"
    echo "FreeSWITCH 2: localhost:5064 (Event Socket: 8022)"
    
    echo ""
    print_status "Next Steps:"
    echo "==========="
    echo "1. Configure your SIP carriers to connect to localhost:5060"
    echo "2. Set up customer SIP accounts via Somleng dashboard"
    echo "3. Test API functionality with: curl http://localhost:3000/health"
    echo "4. Monitor logs with: docker-compose logs -f"
}

# Main execution
main() {
    check_prerequisites
    validate_config
    deploy_infrastructure
    health_check
    show_status
    
    print_success "🎉 Complete Somleng Infrastructure deployment completed!"
    print_status "Check logs with: docker-compose logs -f"
}

# Handle script arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "stop")
        print_status "Stopping Somleng infrastructure..."
        docker-compose down
        print_success "Infrastructure stopped"
        ;;
    "restart")
        print_status "Restarting Somleng infrastructure..."
        docker-compose restart
        print_success "Infrastructure restarted"
        ;;
    "status")
        show_status
        ;;
    "logs")
        docker-compose logs -f "${2:-}"
        ;;
    *)
        echo "Usage: $0 {deploy|stop|restart|status|logs [service]}"
        echo ""
        echo "Commands:"
        echo "  deploy   - Deploy complete infrastructure"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  status   - Show deployment status"
        echo "  logs     - Show logs (optionally for specific service)"
        exit 1
        ;;
esac