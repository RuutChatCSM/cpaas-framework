#!/bin/bash

# =============================================================================
# Somleng CPaaS Security Hardening Script
# =============================================================================
# This script applies security hardening measures to the Somleng deployment

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

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

configure_firewall() {
    log_info "Configuring UFW firewall..."
    
    # Install UFW if not present
    if ! command -v ufw &> /dev/null; then
        apt-get update
        apt-get install -y ufw
    fi
    
    # Reset UFW to defaults
    ufw --force reset
    
    # Default policies
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (be careful not to lock yourself out)
    ufw allow ssh
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow SIP ports
    ufw allow 5060/udp
    ufw allow 5060/tcp
    ufw allow 5061/tcp
    
    # Allow RTP ports for FreeSWITCH
    ufw allow 16384:32768/udp
    
    # Allow STUN/TURN ports
    ufw allow 3478/udp
    ufw allow 3478/tcp
    ufw allow 5349/tcp
    ufw allow 49152:65535/udp
    
    # Allow monitoring ports (restrict to localhost if needed)
    ufw allow from 127.0.0.1 to any port 9090  # Prometheus
    ufw allow from 127.0.0.1 to any port 3001  # Grafana
    ufw allow from 127.0.0.1 to any port 5601  # Kibana
    ufw allow from 127.0.0.1 to any port 9200  # Elasticsearch
    
    # Enable UFW
    ufw --force enable
    
    log_success "Firewall configured successfully"
}

configure_fail2ban() {
    log_info "Installing and configuring Fail2Ban..."
    
    # Install Fail2Ban
    apt-get update
    apt-get install -y fail2ban
    
    # Create custom jail configuration
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban time in seconds (1 hour)
bantime = 3600

# Find time window (10 minutes)
findtime = 600

# Number of failures before ban
maxretry = 5

# Ignore local IPs
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log

[nginx-limit-req]
enabled = true
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10

[kamailio]
enabled = true
port = 5060,5061
protocol = udp
logpath = /var/log/kamailio/kamailio.log
maxretry = 10
findtime = 300
bantime = 1800

[asterisk]
enabled = true
port = 5060,5061
protocol = udp
logpath = /var/log/asterisk/messages
maxretry = 10
findtime = 300
bantime = 1800
EOF

    # Create Kamailio filter
    cat > /etc/fail2ban/filter.d/kamailio.conf << 'EOF'
[Definition]
failregex = ^.*\[.*\]: NOTICE: <HOST>.*registration attempt.*$
            ^.*\[.*\]: WARNING: <HOST>.*authentication failed.*$
            ^.*\[.*\]: NOTICE: <HOST>.*failed to authenticate.*$
ignoreregex =
EOF

    # Restart and enable Fail2Ban
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log_success "Fail2Ban configured successfully"
}

secure_ssh() {
    log_info "Hardening SSH configuration..."
    
    # Backup original SSH config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Apply SSH hardening
    cat >> /etc/ssh/sshd_config << 'EOF'

# Security hardening
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 2
LoginGraceTime 60
EOF

    # Restart SSH service
    systemctl restart sshd
    
    log_success "SSH hardened successfully"
}

configure_system_security() {
    log_info "Applying system security configurations..."
    
    # Disable unused network protocols
    cat >> /etc/modprobe.d/blacklist-rare-network.conf << 'EOF'
# Disable rare network protocols
install dccp /bin/true
install sctp /bin/true
install rds /bin/true
install tipc /bin/true
EOF

    # Set kernel parameters for security
    cat >> /etc/sysctl.d/99-security.conf << 'EOF'
# IP Spoofing protection
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.rp_filter = 1

# Ignore ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# Ignore send redirects
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# Disable source packet routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# Log Martians
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# Ignore ICMP ping requests
net.ipv4.icmp_echo_ignore_all = 1

# Ignore Directed pings
net.ipv4.icmp_echo_ignore_broadcasts = 1

# Disable IPv6 if not needed
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1

# TCP SYN flood protection
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 2048
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 5

# Increase local port range
net.ipv4.ip_local_port_range = 2000 65000

# Increase TCP max buffer size
net.core.rmem_default = 31457280
net.core.rmem_max = 67108864
net.core.wmem_default = 31457280
net.core.wmem_max = 67108864
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_window_scaling = 1
EOF

    # Apply sysctl settings
    sysctl -p /etc/sysctl.d/99-security.conf
    
    log_success "System security configured successfully"
}

secure_docker() {
    log_info "Applying Docker security configurations..."
    
    # Create Docker daemon configuration
    mkdir -p /etc/docker
    cat > /etc/docker/daemon.json << 'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "live-restore": true,
  "userland-proxy": false,
  "no-new-privileges": true,
  "seccomp-profile": "/etc/docker/seccomp.json",
  "storage-driver": "overlay2"
}
EOF

    # Download Docker seccomp profile
    curl -o /etc/docker/seccomp.json https://raw.githubusercontent.com/moby/moby/master/profiles/seccomp/default.json
    
    # Restart Docker
    systemctl restart docker
    
    log_success "Docker security configured successfully"
}

setup_log_monitoring() {
    log_info "Setting up log monitoring..."
    
    # Install logwatch
    apt-get install -y logwatch
    
    # Configure logwatch
    cat > /etc/logwatch/conf/logwatch.conf << 'EOF'
LogDir = /var/log
TmpDir = /var/cache/logwatch
MailTo = root
MailFrom = Logwatch
Print = Yes
Save = /tmp/logwatch
Range = yesterday
Detail = Med
Service = All
mailer = "/usr/sbin/sendmail -t"
EOF

    # Create daily logwatch cron job
    cat > /etc/cron.daily/00logwatch << 'EOF'
#!/bin/bash
/usr/sbin/logwatch --output mail --mailto root --detail high
EOF
    chmod +x /etc/cron.daily/00logwatch
    
    log_success "Log monitoring configured successfully"
}

setup_intrusion_detection() {
    log_info "Setting up intrusion detection..."
    
    # Install AIDE (Advanced Intrusion Detection Environment)
    apt-get install -y aide
    
    # Initialize AIDE database
    aideinit
    
    # Move database to proper location
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    
    # Create daily AIDE check
    cat > /etc/cron.daily/aide << 'EOF'
#!/bin/bash
/usr/bin/aide --check | /usr/bin/mail -s "AIDE Report $(hostname)" root
EOF
    chmod +x /etc/cron.daily/aide
    
    log_success "Intrusion detection configured successfully"
}

secure_file_permissions() {
    log_info "Securing file permissions..."
    
    # Secure sensitive files
    chmod 600 "$PROJECT_DIR/.env" 2>/dev/null || true
    chmod 600 "$PROJECT_DIR/nginx/ssl/"*.pem 2>/dev/null || true
    chmod 600 "$PROJECT_DIR/nginx/ssl/"*.key 2>/dev/null || true
    
    # Secure script files
    chmod 755 "$PROJECT_DIR/scripts/"*.sh
    
    # Secure configuration directories
    chmod -R 644 "$PROJECT_DIR/kamailio/config/"*
    chmod -R 644 "$PROJECT_DIR/monitoring/"*
    chmod -R 644 "$PROJECT_DIR/nginx/"*
    
    log_success "File permissions secured successfully"
}

setup_automatic_updates() {
    log_info "Setting up automatic security updates..."
    
    # Install unattended-upgrades
    apt-get install -y unattended-upgrades
    
    # Configure automatic updates
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Allowed-Origins {
    "${distro_id}:${distro_codename}-security";
    "${distro_id}ESMApps:${distro_codename}-apps-security";
    "${distro_id}ESM:${distro_codename}-infra-security";
};

Unattended-Upgrade::Package-Blacklist {
};

Unattended-Upgrade::DevRelease "false";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-Time "02:00";
EOF

    # Enable automatic updates
    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    log_success "Automatic updates configured successfully"
}

create_security_report() {
    log_info "Creating security report..."
    
    local report_file="/tmp/somleng_security_report.txt"
    
    cat > "$report_file" << EOF
Somleng CPaaS Security Hardening Report
Generated: $(date)
========================================

System Information:
- OS: $(lsb_release -d | cut -f2)
- Kernel: $(uname -r)
- Hostname: $(hostname)

Security Measures Applied:
✓ UFW Firewall configured
✓ Fail2Ban installed and configured
✓ SSH hardened
✓ System security parameters set
✓ Docker security configured
✓ Log monitoring setup
✓ Intrusion detection configured
✓ File permissions secured
✓ Automatic updates enabled

Firewall Status:
$(ufw status)

Fail2Ban Status:
$(fail2ban-client status)

Open Ports:
$(netstat -tuln | grep LISTEN)

Active Services:
$(systemctl list-units --type=service --state=active | grep -E "(docker|nginx|fail2ban|ufw)")

Recommendations:
1. Regularly review logs in /var/log/
2. Monitor Fail2Ban reports
3. Keep system and Docker images updated
4. Review and rotate SSL certificates
5. Implement additional monitoring as needed
6. Consider setting up VPN for administrative access
7. Regularly backup configuration and data

EOF

    echo "Security report saved to: $report_file"
    cat "$report_file"
}

# Main execution
main() {
    echo "============================================================================="
    echo "Somleng CPaaS Security Hardening"
    echo "============================================================================="
    echo
    
    # Check if running as root
    check_root
    
    local hardening_steps=(
        "configure_firewall"
        "configure_fail2ban"
        "secure_ssh"
        "configure_system_security"
        "secure_docker"
        "setup_log_monitoring"
        "setup_intrusion_detection"
        "secure_file_permissions"
        "setup_automatic_updates"
        "create_security_report"
    )
    
    local failed_steps=()
    
    for step in "${hardening_steps[@]}"; do
        echo
        if ! $step; then
            failed_steps+=("$step")
        fi
    done
    
    echo
    echo "============================================================================="
    if [[ ${#failed_steps[@]} -eq 0 ]]; then
        log_success "Security hardening completed successfully!"
        echo "Your Somleng CPaaS deployment has been hardened for production use."
        echo
        echo "IMPORTANT: Please review the security report above and:"
        echo "1. Test SSH access before closing this session"
        echo "2. Verify all services are still accessible"
        echo "3. Review firewall rules and adjust if needed"
        echo "4. Set up monitoring alerts for security events"
    else
        log_error "Some hardening steps failed!"
        echo "Failed steps: ${failed_steps[*]}"
        echo "Please review the errors above and fix the issues."
        exit 1
    fi
    echo "============================================================================="
}

# Check if we're in help mode
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [options]"
    echo
    echo "This script applies comprehensive security hardening to your Somleng CPaaS deployment."
    echo
    echo "Security measures applied:"
    echo "  - UFW firewall configuration"
    echo "  - Fail2Ban intrusion prevention"
    echo "  - SSH hardening"
    echo "  - System security parameters"
    echo "  - Docker security configuration"
    echo "  - Log monitoring setup"
    echo "  - Intrusion detection system"
    echo "  - File permission security"
    echo "  - Automatic security updates"
    echo
    echo "WARNING: This script must be run as root and will modify system configuration."
    echo "Make sure you have console access in case SSH configuration changes lock you out."
    exit 0
fi

# Run main function
main "$@"