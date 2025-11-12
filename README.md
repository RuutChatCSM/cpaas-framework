# Somleng CPaaS Production Deployment

A complete, production-ready Communications Platform as a Service (CPaaS) deployment using Somleng with Kamailio, FreeSWITCH, and comprehensive monitoring.

## 🚀 Features

- **Complete CPaaS Stack**: Voice calls, SMS, IVR, and programmable communications
- **High Availability**: Multiple FreeSWITCH nodes with Kamailio load balancing
- **SBC Functionality**: NAT traversal, RTP anchoring, and SIP security
- **Twilio-Compatible API**: Drop-in replacement for Twilio with same REST API
- **Multi-Tenant**: Support for multiple accounts and subaccounts
- **Comprehensive Monitoring**: Prometheus, Grafana, and ELK stack
- **Production Security**: SSL/TLS, rate limiting, and security headers
- **Automated Backups**: Database, configuration, and log backups to S3
- **Scalable Architecture**: Horizontal scaling support

## 📋 Prerequisites

### System Requirements

- **OS**: Ubuntu 20.04+ / Debian 11+ / CentOS 8+
- **CPU**: 8+ cores (recommended for high volume)
- **RAM**: 16GB+ (minimum 8GB)
- **Storage**: 100GB+ SSD
- **Network**: Public IP address with ports 80, 443, 5060, 5061, 16384-32768 open

### Software Requirements

- Docker 20.10+
- Docker Compose 2.0+
- Domain name with DNS pointing to your server
- Email address for SSL certificates

## 🏗️ Architecture

```
                    Internet
                       |
                   [Load Balancer]
                       |
                   [NGINX Proxy]
                   (SSL Termination)
                       |
        ┌──────────────┼──────────────┐
        │              │              │
   [Somleng API]  [Monitoring]   [Kamailio SIP Router]
   (Multi-tenant)  (Grafana/ELK)      |
        │              │         [RTPEngine]
        │              │              |
   [PostgreSQL]   [Prometheus]   ┌────┴────┐
   [Redis]        [Elasticsearch] │         │
   [Sidekiq]                 [FreeSWITCH] [FreeSWITCH]
                             (Node 1)    (Node 2)
                                 │         │
                            [SIP Trunks/Carriers]
```

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Clone the repository
git clone <repository-url>
cd somleng-cpaas-deploy

# Copy environment template
cp .env.example .env

# Edit configuration (see Configuration section)
nano .env
```

### 2. Configure Environment

Edit `.env` file with your settings:

```bash
# Domain and network
SOMLENG_DOMAIN=yourdomain.com
PUBLIC_IP=YOUR_PUBLIC_IP_ADDRESS

# Generate secret key
SECRET_KEY_BASE=$(openssl rand -hex 64)

# Set strong passwords
POSTGRES_PASSWORD=your_secure_db_password
ADMIN_PASSWORD=your_admin_password
GRAFANA_ADMIN_PASSWORD=your_grafana_password
ELASTIC_PASSWORD=your_elastic_password

# SSL certificate email
LETSENCRYPT_EMAIL=admin@yourdomain.com
```

### 3. Deploy

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run deployment
./scripts/deploy.sh
```

### 4. Setup SSL Certificates

```bash
# For production (Let's Encrypt)
./scripts/ssl-setup.sh letsencrypt

# For testing (self-signed)
./scripts/ssl-setup.sh self-signed
```

## 📖 Detailed Configuration

### Environment Variables

#### Core Configuration
- `SOMLENG_DOMAIN`: Your domain name
- `PUBLIC_IP`: Server's public IP address
- `SECRET_KEY_BASE`: Rails secret key (generate with `openssl rand -hex 64`)

#### Database Configuration
- `POSTGRES_PASSWORD`: PostgreSQL password
- `REDIS_MAXMEMORY`: Redis memory limit (default: 512mb)

#### SIP Configuration
- `SIP_DOMAIN`: SIP domain (usually same as SOMLENG_DOMAIN)
- `RTP_START_PORT`: RTP port range start (default: 16384)
- `RTP_END_PORT`: RTP port range end (default: 32768)

#### Monitoring Configuration
- `GRAFANA_ADMIN_PASSWORD`: Grafana admin password
- `ELASTIC_PASSWORD`: Elasticsearch password
- `PROMETHEUS_RETENTION_TIME`: Metrics retention (default: 15d)

#### Backup Configuration
- `BACKUP_S3_BUCKET`: S3 bucket for backups
- `BACKUP_S3_ACCESS_KEY`: S3 access key
- `BACKUP_S3_SECRET_KEY`: S3 secret key
- `BACKUP_S3_REGION`: S3 region

### SIP Trunk Configuration

Configure your SIP trunks in the Somleng web interface:

1. Login to `https://yourdomain.com`
2. Go to **Carriers** → **Add Carrier**
3. Configure your SIP trunk details:
   - Host: Your carrier's SIP server
   - Username/Password: SIP credentials
   - Prefix: Routing prefix (optional)

### SMS Gateway Configuration

Configure SMS providers:

1. **SMPP Provider**: Set SMPP_* variables in .env
2. **HTTP Provider**: Configure in Somleng web interface
3. **GSM Gateway**: Connect via SIP or HTTP

## 🔧 Management Commands

### Service Management

```bash
# Deploy/start all services
./scripts/deploy.sh

# Stop all services
./scripts/deploy.sh stop

# Restart services
./scripts/deploy.sh restart

# View logs
./scripts/deploy.sh logs [service_name]

# Check service status
./scripts/deploy.sh status

# Update services
./scripts/deploy.sh update
```

### SSL Certificate Management

```bash
# Setup Let's Encrypt certificates
./scripts/ssl-setup.sh letsencrypt

# Generate self-signed certificates
./scripts/ssl-setup.sh self-signed

# Verify certificates
./scripts/ssl-setup.sh verify

# Show certificate info
./scripts/ssl-setup.sh info

# Renew certificates
./scripts/ssl-setup.sh renew
```

### Backup Management

```bash
# Create backup
./scripts/backup.sh backup

# List backups
./scripts/backup.sh list

# Restore from backup
./scripts/backup.sh restore backup_file.tar.gz
```

## 📊 Monitoring and Observability

### Access Points

- **Somleng Dashboard**: `https://yourdomain.com`
- **Grafana**: `https://monitoring.yourdomain.com:3001`
- **Prometheus**: `https://metrics.yourdomain.com:9090`
- **Kibana**: `https://logs.yourdomain.com:5601`

### Default Credentials

- **Somleng**: As configured in ADMIN_EMAIL/ADMIN_PASSWORD
- **Grafana**: admin / GRAFANA_ADMIN_PASSWORD
- **Kibana**: elastic / ELASTIC_PASSWORD

### Key Metrics

- **Call Volume**: Total calls, concurrent calls, call duration
- **Call Quality**: Success rate, failure rate, latency
- **System Health**: CPU, memory, disk usage
- **SIP Metrics**: Registrations, SIP response codes
- **Database Performance**: Query time, connections

### Alerts

Pre-configured alerts for:
- Service downtime
- High resource usage
- Call failure rates
- Certificate expiration
- Database issues

## 🔒 Security

### Network Security

- Firewall configured for required ports only
- Rate limiting on API endpoints
- DDoS protection via NGINX
- SIP flood protection via Kamailio

### Application Security

- SSL/TLS encryption for all web traffic
- SIP-TLS support for secure signaling
- SRTP support for secure media
- Strong password policies
- JWT token authentication

### Data Security

- Database encryption at rest
- Secure backup encryption
- Log sanitization
- PCI DSS compliance ready

## 🔧 Troubleshooting

### Common Issues

#### Services Won't Start

```bash
# Check Docker status
docker ps -a

# Check logs
./scripts/deploy.sh logs

# Check disk space
df -h

# Check memory
free -h
```

#### SIP Registration Issues

```bash
# Check Kamailio logs
docker-compose logs kamailio

# Check FreeSWITCH logs
docker-compose logs freeswitch1

# Test SIP connectivity
nmap -sU -p 5060 yourdomain.com
```

#### Call Quality Issues

```bash
# Check RTP ports
netstat -un | grep :16384

# Check RTPEngine
docker-compose logs rtpengine

# Monitor call metrics in Grafana
```

#### Database Connection Issues

```bash
# Check PostgreSQL
docker-compose exec db psql -U somleng -d somleng_production -c "SELECT 1;"

# Check Redis
docker-compose exec redis redis-cli ping
```

### Performance Tuning

#### High Call Volume

1. **Scale FreeSWITCH nodes**:
   ```yaml
   # Add more FreeSWITCH services in docker-compose.yml
   freeswitch3:
     image: somleng/somleng-freeswitch:latest
     # ... configuration
   ```

2. **Optimize Kamailio**:
   - Increase worker processes
   - Tune memory settings
   - Configure load balancing

3. **Database optimization**:
   - Increase connection pool
   - Optimize PostgreSQL settings
   - Consider read replicas

#### Memory Optimization

```bash
# Adjust container memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G
    reservations:
      memory: 1G
```

## 🔄 Scaling

### Horizontal Scaling

1. **Add FreeSWITCH Nodes**:
   - Add new FreeSWITCH services to docker-compose.yml
   - Update Kamailio dispatcher table
   - Configure load balancing

2. **Database Scaling**:
   - Setup PostgreSQL read replicas
   - Configure connection pooling
   - Implement database sharding

3. **Redis Scaling**:
   - Setup Redis cluster
   - Configure Redis Sentinel
   - Implement session distribution

### Vertical Scaling

1. **Increase Resources**:
   - Add more CPU cores
   - Increase RAM
   - Use faster storage (NVMe SSD)

2. **Optimize Configuration**:
   - Tune database parameters
   - Adjust worker processes
   - Optimize memory allocation

## 📚 API Documentation

### Twilio-Compatible API

Somleng provides a Twilio-compatible REST API:

```bash
# Make a call
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Calls.json \
  -u "ACxxxx:auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Url=https://example.com/voice.xml"

# Send SMS
curl -X POST https://yourdomain.com/api/2010-04-01/Accounts/ACxxxx/Messages.json \
  -u "ACxxxx:auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Body=Hello from Somleng!"
```

### TwiML Support

Somleng supports TwiML for call control:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<Response>
    <Say voice="alice">Welcome to Somleng CPaaS!</Say>
    <Gather action="/handle-input" numDigits="1">
        <Say>Press 1 for sales, 2 for support</Say>
    </Gather>
</Response>
```

## 🤝 Support

### Community Support

- GitHub Issues: Report bugs and feature requests
- Documentation: Comprehensive guides and tutorials
- Community Forum: Ask questions and share experiences

### Commercial Support

For production deployments, consider:
- Professional services for setup and configuration
- 24/7 monitoring and support
- Custom development and integrations
- Training and consultation

## 📄 License

This deployment configuration is provided under the MIT License. Somleng itself is also open source under the MIT License.

## 🙏 Acknowledgments

- **Somleng Team**: For creating an excellent open-source CPaaS platform
- **FreeSWITCH Community**: For the robust media server
- **Kamailio Community**: For the powerful SIP router
- **Docker Community**: For containerization technology

---

For more information, visit the [Somleng website](https://www.somleng.org) or check the [official documentation](https://docs.somleng.org).