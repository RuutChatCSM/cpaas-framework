# Somleng CPaaS Deployment Guide

This guide provides step-by-step instructions for deploying Somleng CPaaS in production environments.

## Pre-Deployment Checklist

### Infrastructure Requirements

- [ ] VPS/Server with Ubuntu 20.04+ or CentOS 8+
- [ ] Minimum 8GB RAM, 4 CPU cores, 100GB SSD storage
- [ ] Public IP address assigned
- [ ] Domain name configured with DNS A records
- [ ] Firewall configured for required ports
- [ ] SSH access to the server

### Network Configuration

Required ports to be open:

| Port Range | Protocol | Service | Description |
|------------|----------|---------|-------------|
| 22 | TCP | SSH | Server management |
| 80 | TCP | HTTP | Web traffic (redirects to HTTPS) |
| 443 | TCP | HTTPS | Secure web traffic |
| 5060 | UDP/TCP | SIP | SIP signaling |
| 5061 | TCP | SIP-TLS | Secure SIP signaling |
| 16384-32768 | UDP | RTP | Media streams (FreeSWITCH) |
| 20000-30000 | UDP | RTP | Media streams (RTPEngine) |

### DNS Configuration

Configure the following DNS records:

```
A       yourdomain.com              -> YOUR_PUBLIC_IP
A       monitoring.yourdomain.com   -> YOUR_PUBLIC_IP
A       logs.yourdomain.com         -> YOUR_PUBLIC_IP
A       metrics.yourdomain.com      -> YOUR_PUBLIC_IP
```

## Step-by-Step Deployment

### Step 1: Server Preparation

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y curl wget git ufw

# Configure firewall
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5060/udp
sudo ufw allow 5060/tcp
sudo ufw allow 5061/tcp
sudo ufw allow 16384:32768/udp
sudo ufw allow 20000:30000/udp
sudo ufw --force enable

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again to apply Docker group membership
```

### Step 2: Download and Configure

```bash
# Clone the deployment repository
git clone <repository-url> somleng-cpaas-deploy
cd somleng-cpaas-deploy

# Copy environment template
cp .env.example .env

# Generate secret key
SECRET_KEY=$(openssl rand -hex 64)

# Edit configuration file
nano .env
```

### Step 3: Environment Configuration

Update the following variables in `.env`:

```bash
# Domain and Network
SOMLENG_DOMAIN=yourdomain.com
PUBLIC_IP=YOUR_PUBLIC_IP_ADDRESS

# Security
SECRET_KEY_BASE=your_generated_secret_key_here

# Database Passwords
POSTGRES_PASSWORD=secure_postgres_password_2024
ADMIN_PASSWORD=secure_admin_password_2024

# Monitoring Passwords
GRAFANA_ADMIN_PASSWORD=secure_grafana_password_2024
ELASTIC_PASSWORD=secure_elastic_password_2024

# SSL Configuration
LETSENCRYPT_EMAIL=admin@yourdomain.com

# Backup Configuration (optional)
BACKUP_S3_BUCKET=your-backup-bucket
BACKUP_S3_ACCESS_KEY=your_s3_access_key
BACKUP_S3_SECRET_KEY=your_s3_secret_key
BACKUP_S3_REGION=us-east-1
```

### Step 4: Deploy Services

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run deployment
./scripts/deploy.sh
```

The deployment script will:
1. Check system requirements
2. Validate configuration
3. Generate SSL certificates (self-signed initially)
4. Deploy all services
5. Initialize databases
6. Create admin user
7. Verify deployment

### Step 5: Setup SSL Certificates

For production, use Let's Encrypt:

```bash
# Setup Let's Encrypt certificates
./scripts/ssl-setup.sh letsencrypt
```

For testing, self-signed certificates are already generated.

### Step 6: Verify Deployment

```bash
# Check service status
./scripts/deploy.sh status

# View logs
./scripts/deploy.sh logs

# Test web interface
curl -k https://yourdomain.com/health
```

## Post-Deployment Configuration

### 1. Access Web Interface

Navigate to `https://yourdomain.com` and login with:
- Email: Value from `ADMIN_EMAIL`
- Password: Value from `ADMIN_PASSWORD`

### 2. Configure SIP Trunks

1. Go to **Carriers** → **Add Carrier**
2. Configure your SIP trunk:
   - Name: Your carrier name
   - Host: carrier.example.com
   - Username: your_sip_username
   - Password: your_sip_password
   - Prefix: (optional routing prefix)

### 3. Configure Phone Numbers

1. Go to **Phone Numbers** → **Add Phone Number**
2. Configure your DID numbers:
   - Number: +1234567890
   - Carrier: Select configured carrier
   - Voice URL: https://yourdomain.com/voice (your TwiML endpoint)

### 4. Setup SMS Gateway

For SMPP providers, update `.env`:

```bash
SMPP_HOST=smpp.provider.com
SMPP_PORT=2775
SMPP_USERNAME=your_smpp_username
SMPP_PASSWORD=your_smpp_password
```

Then restart services:

```bash
./scripts/deploy.sh restart
```

### 5. Configure Monitoring

Access monitoring interfaces:

- **Grafana**: `https://monitoring.yourdomain.com:3001`
  - Username: admin
  - Password: Value from `GRAFANA_ADMIN_PASSWORD`

- **Kibana**: `https://logs.yourdomain.com:5601`
  - Username: elastic
  - Password: Value from `ELASTIC_PASSWORD`

- **Prometheus**: `https://metrics.yourdomain.com:9090`

## Testing Your Deployment

### 1. Test API Endpoints

```bash
# Test health endpoint
curl -k https://yourdomain.com/health

# Test API authentication (replace with your account SID and token)
curl -X GET https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx.json \
  -u "ACxxxx:your_auth_token"
```

### 2. Test SIP Registration

```bash
# Test SIP connectivity
nmap -sU -p 5060 yourdomain.com

# Check Kamailio status
docker-compose exec kamailio kamctl monitor 1
```

### 3. Make Test Call

Using the Somleng API:

```bash
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls.json \
  -u "ACxxxx:auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Url=https://example.com/voice.xml"
```

### 4. Send Test SMS

```bash
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Messages.json \
  -u "ACxxxx:auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Body=Test message from Somleng"
```

## Performance Optimization

### Database Optimization

```bash
# Connect to PostgreSQL
docker-compose exec db psql -U somleng -d somleng_production

# Check database performance
SELECT * FROM pg_stat_activity;

# Optimize queries
EXPLAIN ANALYZE SELECT * FROM calls WHERE created_at > NOW() - INTERVAL '1 day';
```

### FreeSWITCH Optimization

Edit FreeSWITCH configuration for high volume:

```xml
<!-- Increase session limits -->
<param name="max-sessions" value="10000"/>
<param name="sessions-per-second" value="100"/>

<!-- Optimize RTP -->
<param name="rtp-start-port" value="16384"/>
<param name="rtp-end-port" value="32768"/>
```

### Kamailio Optimization

Update Kamailio configuration:

```
# Increase worker processes
children=16

# Increase memory
shm_mem=512
pkg_mem=16
```

## Backup and Recovery

### Setup Automated Backups

```bash
# Configure backup in .env
BACKUP_S3_BUCKET=your-backup-bucket
BACKUP_S3_ACCESS_KEY=your_access_key
BACKUP_S3_SECRET_KEY=your_secret_key

# Test backup
./scripts/backup.sh backup

# Setup cron job for daily backups
echo "0 2 * * * /path/to/somleng-cpaas-deploy/scripts/backup.sh backup" | crontab -
```

### Recovery Procedures

```bash
# List available backups
./scripts/backup.sh list

# Restore from backup
./scripts/backup.sh restore somleng_backup_20240101_020000.tar.gz
```

## Monitoring and Alerting

### Setup Grafana Dashboards

1. Login to Grafana
2. Import pre-configured dashboards
3. Configure alert notifications
4. Setup alert rules for critical metrics

### Key Metrics to Monitor

- **System Metrics**: CPU, Memory, Disk usage
- **Call Metrics**: Call volume, success rate, duration
- **SIP Metrics**: Registrations, response codes
- **Database Metrics**: Query performance, connections
- **Network Metrics**: Bandwidth, packet loss

### Alert Configuration

Configure alerts for:
- Service downtime
- High error rates
- Resource exhaustion
- Certificate expiration
- Database issues

## Security Hardening

### System Security

```bash
# Disable root login
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config

# Setup fail2ban
sudo apt install fail2ban
sudo systemctl enable fail2ban

# Configure automatic updates
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

### Application Security

1. **Change Default Passwords**: Update all default passwords
2. **Enable 2FA**: Configure two-factor authentication
3. **Regular Updates**: Keep all components updated
4. **Access Control**: Implement proper user roles and permissions
5. **Network Security**: Use VPN for administrative access

## Troubleshooting Common Issues

### Service Won't Start

```bash
# Check Docker daemon
sudo systemctl status docker

# Check container logs
docker-compose logs service_name

# Check resource usage
docker stats

# Check disk space
df -h
```

### Database Connection Issues

```bash
# Check PostgreSQL status
docker-compose exec db pg_isready -U somleng

# Check connections
docker-compose exec db psql -U somleng -c "SELECT count(*) FROM pg_stat_activity;"

# Reset connections
docker-compose restart db
```

### SIP Issues

```bash
# Check Kamailio status
docker-compose exec kamailio kamctl monitor

# Check FreeSWITCH status
docker-compose exec freeswitch1 fs_cli -x "status"

# Check SIP registrations
docker-compose exec kamailio kamctl ul show
```

### Performance Issues

```bash
# Check system resources
htop
iotop
nethogs

# Check container resources
docker stats

# Analyze slow queries
docker-compose exec db psql -U somleng -c "SELECT * FROM pg_stat_statements ORDER BY total_time DESC LIMIT 10;"
```

## Maintenance Procedures

### Regular Maintenance Tasks

1. **Weekly**:
   - Check service status
   - Review monitoring alerts
   - Check disk space and cleanup logs
   - Verify backups

2. **Monthly**:
   - Update system packages
   - Review security logs
   - Performance analysis
   - Capacity planning

3. **Quarterly**:
   - Security audit
   - Disaster recovery testing
   - Configuration review
   - Documentation updates

### Update Procedures

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
./scripts/deploy.sh update

# Update SSL certificates
./scripts/ssl-setup.sh renew
```

## Support and Resources

### Documentation
- [Somleng Documentation](https://docs.somleng.org)
- [FreeSWITCH Documentation](https://freeswitch.org/confluence/)
- [Kamailio Documentation](https://www.kamailio.org/wiki/)

### Community Support
- GitHub Issues
- Community Forums
- Slack/Discord channels

### Professional Support
- Commercial support options
- Professional services
- Training and consultation

---

This deployment guide provides comprehensive instructions for setting up and maintaining a production Somleng CPaaS deployment. For additional support, refer to the official documentation or community resources.