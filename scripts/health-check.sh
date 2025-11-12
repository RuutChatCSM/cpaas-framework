#!/bin/bash

# =============================================================================
# Somleng CPaaS Health Check Script
# =============================================================================
# This script performs comprehensive health checks on all Somleng components

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

# Load environment variables
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Default values
SOMLENG_DOMAIN=${SOMLENG_DOMAIN:-localhost}
POSTGRES_USER=${POSTGRES_USER:-somleng}
POSTGRES_DB=${POSTGRES_DB:-somleng_production}

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

check_docker() {
    log_info "Checking Docker..."
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        return 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker daemon is not running"
        return 1
    fi
    
    log_success "Docker is running"
    return 0
}

check_docker_compose() {
    log_info "Checking Docker Compose..."
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose is not installed"
        return 1
    fi
    
    log_success "Docker Compose is available"
    return 0
}

check_containers() {
    log_info "Checking container status..."
    
    local containers=(
        "somleng_postgres"
        "somleng_redis"
        "somleng_web"
        "somleng_sidekiq"
        "somleng_freeswitch1"
        "somleng_freeswitch2"
        "somleng_kamailio"
        "somleng_rtpengine"
        "somleng_sms_gateway"
        "somleng_coturn"
        "somleng_nginx"
        "prometheus"
        "grafana"
        "elasticsearch"
        "kibana"
        "logstash"
    )
    
    local failed_containers=()
    
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            local status=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "no-healthcheck")
            if [[ "$status" == "healthy" ]] || [[ "$status" == "no-healthcheck" ]]; then
                log_success "Container $container is running"
            else
                log_warning "Container $container is running but not healthy (status: $status)"
            fi
        else
            log_error "Container $container is not running"
            failed_containers+=("$container")
        fi
    done
    
    if [[ ${#failed_containers[@]} -gt 0 ]]; then
        log_error "Failed containers: ${failed_containers[*]}"
        return 1
    fi
    
    return 0
}

check_database() {
    log_info "Checking PostgreSQL database..."
    
    if docker exec somleng_postgres pg_isready -U "$POSTGRES_USER" -d "$POSTGRES_DB" &> /dev/null; then
        log_success "PostgreSQL is accepting connections"
        
        # Check database tables
        local table_count=$(docker exec somleng_postgres psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" -t -c "SELECT count(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
        if [[ "$table_count" -gt 0 ]]; then
            log_success "Database has $table_count tables"
        else
            log_warning "Database appears to be empty"
        fi
    else
        log_error "PostgreSQL is not accepting connections"
        return 1
    fi
    
    return 0
}

check_redis() {
    log_info "Checking Redis..."
    
    if docker exec somleng_redis redis-cli ping | grep -q "PONG"; then
        log_success "Redis is responding"
    else
        log_error "Redis is not responding"
        return 1
    fi
    
    return 0
}

check_web_api() {
    log_info "Checking Somleng Web API..."
    
    local health_url="https://$SOMLENG_DOMAIN/health"
    if curl -k -s -f "$health_url" &> /dev/null; then
        log_success "Somleng Web API is responding"
    else
        # Try HTTP if HTTPS fails
        local http_health_url="http://$SOMLENG_DOMAIN/health"
        if curl -s -f "$http_health_url" &> /dev/null; then
            log_success "Somleng Web API is responding (HTTP)"
        else
            log_error "Somleng Web API is not responding"
            return 1
        fi
    fi
    
    return 0
}

check_sip_services() {
    log_info "Checking SIP services..."
    
    # Check Kamailio
    if docker exec somleng_kamailio kamctl monitor 1 &> /dev/null; then
        log_success "Kamailio is running"
    else
        log_error "Kamailio is not responding"
        return 1
    fi
    
    # Check FreeSWITCH nodes
    for i in 1 2; do
        if docker exec "somleng_freeswitch$i" fs_cli -x "status" | grep -q "UP"; then
            log_success "FreeSWITCH node $i is running"
        else
            log_error "FreeSWITCH node $i is not responding"
            return 1
        fi
    done
    
    return 0
}

check_monitoring() {
    log_info "Checking monitoring services..."
    
    # Check Prometheus
    if curl -s -f "http://localhost:9090/-/healthy" &> /dev/null; then
        log_success "Prometheus is healthy"
    else
        log_error "Prometheus is not responding"
        return 1
    fi
    
    # Check Grafana
    if curl -s -f "http://localhost:3001/api/health" &> /dev/null; then
        log_success "Grafana is healthy"
    else
        log_error "Grafana is not responding"
        return 1
    fi
    
    # Check Elasticsearch
    if curl -s -f "http://localhost:9200/_cluster/health" &> /dev/null; then
        log_success "Elasticsearch is healthy"
    else
        log_error "Elasticsearch is not responding"
        return 1
    fi
    
    return 0
}

check_ssl_certificates() {
    log_info "Checking SSL certificates..."
    
    local cert_file="$PROJECT_DIR/nginx/ssl/fullchain.pem"
    local key_file="$PROJECT_DIR/nginx/ssl/privkey.pem"
    
    if [[ -f "$cert_file" ]] && [[ -f "$key_file" ]]; then
        # Check certificate expiration
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        if [[ $days_until_expiry -gt 30 ]]; then
            log_success "SSL certificate is valid for $days_until_expiry days"
        elif [[ $days_until_expiry -gt 0 ]]; then
            log_warning "SSL certificate expires in $days_until_expiry days"
        else
            log_error "SSL certificate has expired"
            return 1
        fi
    else
        log_warning "SSL certificates not found (using self-signed or not configured)"
    fi
    
    return 0
}

check_ports() {
    log_info "Checking port accessibility..."
    
    local ports=(
        "80:HTTP"
        "443:HTTPS"
        "5060:SIP"
        "5061:SIP-TLS"
        "3478:STUN"
        "5349:TURN-TLS"
    )
    
    for port_info in "${ports[@]}"; do
        local port=$(echo "$port_info" | cut -d: -f1)
        local service=$(echo "$port_info" | cut -d: -f2)
        
        if netstat -tuln | grep -q ":$port "; then
            log_success "Port $port ($service) is listening"
        else
            log_error "Port $port ($service) is not listening"
        fi
    done
    
    return 0
}

check_disk_space() {
    log_info "Checking disk space..."
    
    local usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    
    if [[ $usage -lt 80 ]]; then
        log_success "Disk usage is ${usage}%"
    elif [[ $usage -lt 90 ]]; then
        log_warning "Disk usage is ${usage}% (consider cleanup)"
    else
        log_error "Disk usage is ${usage}% (critical)"
        return 1
    fi
    
    return 0
}

check_memory() {
    log_info "Checking memory usage..."
    
    local mem_info=$(free | grep Mem)
    local total=$(echo "$mem_info" | awk '{print $2}')
    local used=$(echo "$mem_info" | awk '{print $3}')
    local usage=$((used * 100 / total))
    
    if [[ $usage -lt 80 ]]; then
        log_success "Memory usage is ${usage}%"
    elif [[ $usage -lt 90 ]]; then
        log_warning "Memory usage is ${usage}% (monitor closely)"
    else
        log_error "Memory usage is ${usage}% (critical)"
        return 1
    fi
    
    return 0
}

# Main execution
main() {
    echo "============================================================================="
    echo "Somleng CPaaS Health Check"
    echo "============================================================================="
    echo
    
    local checks=(
        "check_docker"
        "check_docker_compose"
        "check_containers"
        "check_database"
        "check_redis"
        "check_web_api"
        "check_sip_services"
        "check_monitoring"
        "check_ssl_certificates"
        "check_ports"
        "check_disk_space"
        "check_memory"
    )
    
    local failed_checks=()
    
    for check in "${checks[@]}"; do
        echo
        if ! $check; then
            failed_checks+=("$check")
        fi
    done
    
    echo
    echo "============================================================================="
    if [[ ${#failed_checks[@]} -eq 0 ]]; then
        log_success "All health checks passed!"
        echo "Your Somleng CPaaS deployment is healthy and ready for production."
    else
        log_error "Health check failed!"
        echo "Failed checks: ${failed_checks[*]}"
        echo "Please review the errors above and fix the issues."
        exit 1
    fi
    echo "============================================================================="
}

# Run main function
main "$@"