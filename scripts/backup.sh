#!/bin/bash

# Somleng CPaaS Backup Script
# Backs up databases, configurations, and logs to S3-compatible storage

set -euo pipefail

# Configuration
BACKUP_DIR="/backup"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="somleng_backup_${TIMESTAMP}"

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

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

backup_databases() {
    log_info "Backing up databases..."
    
    # Backup PostgreSQL
    log_info "Backing up PostgreSQL database..."
    pg_dump -h db -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" > "${BACKUP_DIR}/${BACKUP_NAME}/somleng_db.sql"
    
    # Backup Kamailio database
    log_info "Backing up Kamailio database..."
    pg_dump -h db -U kamailio -d kamailio > "${BACKUP_DIR}/${BACKUP_NAME}/kamailio_db.sql"
    
    # Backup Redis
    log_info "Backing up Redis data..."
    redis-cli -h redis --rdb "${BACKUP_DIR}/${BACKUP_NAME}/redis_dump.rdb"
    
    log_success "Database backups completed"
}

backup_configurations() {
    log_info "Backing up configurations..."
    
    # Create config backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/configs"
    
    # Backup environment file
    cp /app/.env "${BACKUP_DIR}/${BACKUP_NAME}/configs/" 2>/dev/null || log_warning ".env file not found"
    
    # Backup Kamailio config
    cp -r /etc/kamailio "${BACKUP_DIR}/${BACKUP_NAME}/configs/" 2>/dev/null || log_warning "Kamailio config not found"
    
    # Backup NGINX config
    cp -r /etc/nginx "${BACKUP_DIR}/${BACKUP_NAME}/configs/" 2>/dev/null || log_warning "NGINX config not found"
    
    # Backup SSL certificates
    cp -r /etc/nginx/ssl "${BACKUP_DIR}/${BACKUP_NAME}/configs/" 2>/dev/null || log_warning "SSL certificates not found"
    
    # Backup monitoring configs
    cp -r /etc/prometheus "${BACKUP_DIR}/${BACKUP_NAME}/configs/" 2>/dev/null || log_warning "Prometheus config not found"
    cp -r /etc/grafana "${BACKUP_DIR}/${BACKUP_NAME}/configs/" 2>/dev/null || log_warning "Grafana config not found"
    
    log_success "Configuration backups completed"
}

backup_logs() {
    log_info "Backing up logs..."
    
    # Create logs backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/logs"
    
    # Backup application logs
    cp -r /app/log "${BACKUP_DIR}/${BACKUP_NAME}/logs/somleng" 2>/dev/null || log_warning "Somleng logs not found"
    
    # Backup FreeSWITCH logs
    cp -r /usr/local/freeswitch/log "${BACKUP_DIR}/${BACKUP_NAME}/logs/freeswitch" 2>/dev/null || log_warning "FreeSWITCH logs not found"
    
    # Backup Kamailio logs
    cp -r /var/log/kamailio "${BACKUP_DIR}/${BACKUP_NAME}/logs/kamailio" 2>/dev/null || log_warning "Kamailio logs not found"
    
    # Backup NGINX logs
    cp -r /var/log/nginx "${BACKUP_DIR}/${BACKUP_NAME}/logs/nginx" 2>/dev/null || log_warning "NGINX logs not found"
    
    log_success "Log backups completed"
}

backup_recordings() {
    log_info "Backing up call recordings..."
    
    # Create recordings backup directory
    mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}/recordings"
    
    # Backup FreeSWITCH recordings
    cp -r /usr/local/freeswitch/recordings "${BACKUP_DIR}/${BACKUP_NAME}/recordings/freeswitch" 2>/dev/null || log_warning "FreeSWITCH recordings not found"
    
    # Backup RTPEngine recordings
    cp -r /var/lib/rtpengine "${BACKUP_DIR}/${BACKUP_NAME}/recordings/rtpengine" 2>/dev/null || log_warning "RTPEngine recordings not found"
    
    log_success "Recording backups completed"
}

compress_backup() {
    log_info "Compressing backup..."
    
    cd "${BACKUP_DIR}"
    tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
    rm -rf "${BACKUP_NAME}"
    
    # Get backup size
    BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
    log_success "Backup compressed: ${BACKUP_NAME}.tar.gz (${BACKUP_SIZE})"
}

upload_to_s3() {
    if [ -n "${BACKUP_S3_BUCKET:-}" ] && [ -n "${BACKUP_S3_ACCESS_KEY:-}" ] && [ -n "${BACKUP_S3_SECRET_KEY:-}" ]; then
        log_info "Uploading backup to S3..."
        
        # Configure AWS CLI
        aws configure set aws_access_key_id "${BACKUP_S3_ACCESS_KEY}"
        aws configure set aws_secret_access_key "${BACKUP_S3_SECRET_KEY}"
        aws configure set default.region "${BACKUP_S3_REGION:-us-east-1}"
        
        # Upload backup
        aws s3 cp "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" "s3://${BACKUP_S3_BUCKET}/somleng-backups/${BACKUP_NAME}.tar.gz"
        
        log_success "Backup uploaded to S3"
        
        # Clean up old backups (keep last 30 days)
        log_info "Cleaning up old backups..."
        aws s3 ls "s3://${BACKUP_S3_BUCKET}/somleng-backups/" | while read -r line; do
            backup_date=$(echo "$line" | awk '{print $1}')
            backup_file=$(echo "$line" | awk '{print $4}')
            
            if [ -n "$backup_date" ] && [ -n "$backup_file" ]; then
                backup_timestamp=$(date -d "$backup_date" +%s)
                current_timestamp=$(date +%s)
                age_days=$(( (current_timestamp - backup_timestamp) / 86400 ))
                
                if [ "$age_days" -gt 30 ]; then
                    log_info "Deleting old backup: $backup_file"
                    aws s3 rm "s3://${BACKUP_S3_BUCKET}/somleng-backups/$backup_file"
                fi
            fi
        done
        
        # Remove local backup after successful upload
        rm -f "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
        log_info "Local backup removed after successful upload"
    else
        log_warning "S3 configuration not found. Backup stored locally only."
    fi
}

cleanup_local_backups() {
    log_info "Cleaning up old local backups..."
    
    # Keep only last 7 local backups
    cd "${BACKUP_DIR}"
    ls -t somleng_backup_*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
    
    log_success "Local backup cleanup completed"
}

generate_backup_report() {
    log_info "Generating backup report..."
    
    REPORT_FILE="${BACKUP_DIR}/backup_report_${TIMESTAMP}.txt"
    
    cat > "$REPORT_FILE" << EOF
Somleng CPaaS Backup Report
===========================
Backup Name: ${BACKUP_NAME}
Timestamp: $(date)
Backup Size: $(du -h "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz" 2>/dev/null | cut -f1 || echo "N/A")

Components Backed Up:
- PostgreSQL databases (somleng, kamailio)
- Redis data
- Configuration files
- Application logs
- Call recordings
- SSL certificates

Backup Location:
- Local: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz
- S3: ${BACKUP_S3_BUCKET:-"Not configured"}/somleng-backups/${BACKUP_NAME}.tar.gz

Status: SUCCESS
EOF

    log_success "Backup report generated: $REPORT_FILE"
}

# Main backup function
main() {
    log_info "Starting Somleng CPaaS backup..."
    
    backup_databases
    backup_configurations
    backup_logs
    backup_recordings
    compress_backup
    upload_to_s3
    cleanup_local_backups
    generate_backup_report
    
    log_success "Backup completed successfully!"
}

# Handle script arguments
case "${1:-backup}" in
    "backup")
        main
        ;;
    "restore")
        if [ -z "${2:-}" ]; then
            log_error "Please specify backup file to restore"
            exit 1
        fi
        log_info "Restoring from backup: $2"
        # Restore logic would go here
        log_warning "Restore functionality not implemented yet"
        ;;
    "list")
        log_info "Available backups:"
        ls -la "${BACKUP_DIR}"/somleng_backup_*.tar.gz 2>/dev/null || log_info "No local backups found"
        
        if [ -n "${BACKUP_S3_BUCKET:-}" ]; then
            log_info "S3 backups:"
            aws s3 ls "s3://${BACKUP_S3_BUCKET}/somleng-backups/" 2>/dev/null || log_info "No S3 backups found"
        fi
        ;;
    *)
        echo "Usage: $0 {backup|restore|list}"
        echo "  backup           - Create a new backup"
        echo "  restore <file>   - Restore from backup file"
        echo "  list             - List available backups"
        exit 1
        ;;
esac