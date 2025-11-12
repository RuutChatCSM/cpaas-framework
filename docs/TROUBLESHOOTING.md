# Somleng CPaaS Troubleshooting Guide

This guide helps you diagnose and resolve common issues with your Somleng CPaaS deployment.

## Quick Diagnostics

### Run Health Check
```bash
./scripts/health-check.sh
```

### Check Service Status
```bash
./scripts/deploy.sh status
```

### View Logs
```bash
# All services
./scripts/deploy.sh logs

# Specific service
docker-compose logs -f service_name
```

## Common Issues and Solutions

### 1. Services Won't Start

#### Symptoms
- Containers exit immediately
- Health checks fail
- Services show as "unhealthy"

#### Diagnosis
```bash
# Check container status
docker ps -a

# Check specific container logs
docker-compose logs container_name

# Check system resources
df -h
free -h
```

#### Solutions

**Insufficient Disk Space**
```bash
# Clean up Docker
docker system prune -a

# Clean up logs
sudo journalctl --vacuum-time=7d

# Check and clean application logs
find /var/log -name "*.log" -size +100M -delete
```

**Memory Issues**
```bash
# Check memory usage
docker stats

# Restart services with memory limits
docker-compose down
docker-compose up -d
```

**Permission Issues**
```bash
# Fix file permissions
sudo chown -R $USER:$USER /path/to/somleng-cpaas-deploy
chmod +x scripts/*.sh
```

### 2. Database Connection Issues

#### Symptoms
- "Connection refused" errors
- Web interface won't load
- API returns database errors

#### Diagnosis
```bash
# Check PostgreSQL status
docker-compose exec db pg_isready -U somleng

# Check database logs
docker-compose logs db

# Test database connection
docker-compose exec db psql -U somleng -d somleng_production -c "SELECT 1;"
```

#### Solutions

**Database Not Ready**
```bash
# Wait for database to initialize
sleep 30

# Check initialization logs
docker-compose logs db | grep "database system is ready"

# Restart database service
docker-compose restart db
```

**Connection Pool Exhausted**
```bash
# Check active connections
docker-compose exec db psql -U somleng -c "SELECT count(*) FROM pg_stat_activity;"

# Restart web services
docker-compose restart web sidekiq
```

**Database Corruption**
```bash
# Restore from backup
./scripts/backup.sh restore latest_backup.tar.gz

# Or reinitialize (WARNING: Data loss)
docker-compose down
docker volume rm somleng-cpaas-deploy_postgres_data
docker-compose up -d db
```

### 3. SIP/Voice Call Issues

#### Symptoms
- Calls fail to connect
- No audio in calls
- Registration failures
- One-way audio

#### Diagnosis
```bash
# Check Kamailio status
docker-compose exec kamailio kamctl monitor

# Check FreeSWITCH status
docker-compose exec freeswitch1 fs_cli -x "status"

# Check SIP registrations
docker-compose exec kamailio kamctl ul show

# Test SIP connectivity
nmap -sU -p 5060 your-domain.com
```

#### Solutions

**NAT/Firewall Issues**
```bash
# Check firewall rules
sudo ufw status

# Open required ports
sudo ufw allow 5060/udp
sudo ufw allow 5060/tcp
sudo ufw allow 5061/tcp
sudo ufw allow 16384:32768/udp

# Update external IP in .env
EXT_RTP_IP=YOUR_PUBLIC_IP
EXT_SIP_IP=YOUR_PUBLIC_IP
```

**RTP Issues**
```bash
# Check RTPEngine status
docker-compose logs rtpengine

# Restart RTPEngine
docker-compose restart rtpengine

# Check RTP port range
netstat -un | grep :16384
```

**FreeSWITCH Configuration**
```bash
# Check FreeSWITCH logs
docker-compose logs freeswitch1

# Restart FreeSWITCH
docker-compose restart freeswitch1 freeswitch2

# Check FreeSWITCH CLI
docker-compose exec freeswitch1 fs_cli
```

### 4. SSL/TLS Certificate Issues

#### Symptoms
- Browser security warnings
- API calls fail with SSL errors
- Certificate expired warnings

#### Diagnosis
```bash
# Check certificate status
./scripts/ssl-setup.sh info

# Test SSL connection
openssl s_client -connect your-domain.com:443

# Check certificate expiration
openssl x509 -enddate -noout -in nginx/ssl/fullchain.pem
```

#### Solutions

**Expired Certificates**
```bash
# Renew Let's Encrypt certificates
./scripts/ssl-setup.sh renew

# Or regenerate self-signed certificates
./scripts/ssl-setup.sh self-signed
```

**Certificate Path Issues**
```bash
# Check certificate files exist
ls -la nginx/ssl/

# Fix permissions
chmod 644 nginx/ssl/*.pem
chmod 600 nginx/ssl/*.key

# Restart NGINX
docker-compose restart nginx
```

### 5. API Authentication Issues

#### Symptoms
- 401 Unauthorized errors
- Invalid credentials messages
- API calls rejected

#### Diagnosis
```bash
# Test API endpoint
curl -k https://your-domain.com/health

# Test with credentials
curl -u "account_sid:auth_token" https://your-domain.com/api/2010-04-01/Accounts/ACxxxx.json

# Check web logs
docker-compose logs web
```

#### Solutions

**Invalid Credentials**
```bash
# Check admin user exists
docker-compose exec web rails console
# In Rails console:
User.find_by(email: 'admin@yourdomain.com')

# Create admin user if missing
User.create!(email: 'admin@yourdomain.com', password: 'your_password', admin: true)
```

**Session Issues**
```bash
# Clear Redis cache
docker-compose exec redis redis-cli FLUSHALL

# Restart web services
docker-compose restart web sidekiq
```

### 6. SMS Delivery Issues

#### Symptoms
- SMS messages not delivered
- SMS gateway errors
- Provider connection failures

#### Diagnosis
```bash
# Check SMS gateway logs
docker-compose logs sms_gateway

# Test SMS API
curl -X POST https://your-domain.com/api/2010-04-01/Accounts/ACxxxx/Messages.json \
  -u "account_sid:auth_token" \
  -d "To=+1234567890" \
  -d "From=+0987654321" \
  -d "Body=Test message"
```

#### Solutions

**SMPP Configuration**
```bash
# Update SMPP settings in .env
SMPP_HOST=your-smpp-provider.com
SMPP_PORT=2775
SMPP_USERNAME=your_username
SMPP_PASSWORD=your_password

# Restart SMS gateway
docker-compose restart sms_gateway
```

**Provider Issues**
```bash
# Check provider connectivity
telnet your-smpp-provider.com 2775

# Switch to HTTP provider if available
SMS_GATEWAY_MODE=http
```

### 7. Monitoring Issues

#### Symptoms
- Grafana dashboards empty
- Prometheus not collecting metrics
- Elasticsearch not receiving logs

#### Diagnosis
```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check Grafana datasources
curl -u admin:password http://localhost:3001/api/datasources

# Check Elasticsearch health
curl http://localhost:9200/_cluster/health
```

#### Solutions

**Prometheus Issues**
```bash
# Check Prometheus configuration
docker-compose exec prometheus cat /etc/prometheus/prometheus.yml

# Restart Prometheus
docker-compose restart prometheus

# Check metrics endpoints
curl http://localhost:9090/metrics
```

**Grafana Issues**
```bash
# Reset Grafana admin password
docker-compose exec grafana grafana-cli admin reset-admin-password newpassword

# Restart Grafana
docker-compose restart grafana
```

**ELK Stack Issues**
```bash
# Check Elasticsearch status
docker-compose exec elasticsearch curl -X GET "localhost:9200/_cluster/health?pretty"

# Restart ELK stack
docker-compose restart elasticsearch logstash kibana
```

### 8. Performance Issues

#### Symptoms
- Slow API responses
- High CPU/memory usage
- Call quality issues
- Timeouts

#### Diagnosis
```bash
# Check system resources
htop
iotop
nethogs

# Check container resources
docker stats

# Check database performance
docker-compose exec db psql -U somleng -c "SELECT * FROM pg_stat_activity;"
```

#### Solutions

**Database Optimization**
```bash
# Analyze slow queries
docker-compose exec db psql -U somleng -c "SELECT query, mean_time, calls FROM pg_stat_statements ORDER BY mean_time DESC LIMIT 10;"

# Vacuum database
docker-compose exec db psql -U somleng -c "VACUUM ANALYZE;"

# Update database statistics
docker-compose exec db psql -U somleng -c "ANALYZE;"
```

**Memory Optimization**
```bash
# Increase container memory limits in docker-compose.yml
deploy:
  resources:
    limits:
      memory: 2G

# Restart services
docker-compose down && docker-compose up -d
```

**Network Optimization**
```bash
# Check network latency
ping your-domain.com

# Check bandwidth usage
iftop

# Optimize RTP settings
# Update FreeSWITCH configuration for your network
```

## Advanced Troubleshooting

### Debug Mode

Enable debug logging:
```bash
# Update .env file
LOG_LEVEL=debug
RAILS_LOG_LEVEL=debug

# Restart services
docker-compose restart web sidekiq
```

### Container Shell Access

Access container shells for debugging:
```bash
# Web container
docker-compose exec web bash

# Database container
docker-compose exec db bash

# FreeSWITCH container
docker-compose exec freeswitch1 bash

# Kamailio container
docker-compose exec kamailio sh
```

### Network Debugging

```bash
# Check container networking
docker network ls
docker network inspect somleng-cpaas-deploy_somleng_network

# Test inter-container connectivity
docker-compose exec web ping db
docker-compose exec kamailio ping freeswitch1

# Check DNS resolution
docker-compose exec web nslookup db
```

### Log Analysis

```bash
# Search for errors in all logs
docker-compose logs | grep -i error

# Monitor logs in real-time
docker-compose logs -f | grep -i "error\|warning\|fail"

# Export logs for analysis
docker-compose logs > somleng_logs_$(date +%Y%m%d_%H%M%S).txt
```

## Getting Help

### Log Collection

Before seeking help, collect relevant information:

```bash
# System information
uname -a > debug_info.txt
docker --version >> debug_info.txt
docker-compose --version >> debug_info.txt

# Service status
docker ps -a >> debug_info.txt

# Recent logs
docker-compose logs --tail=100 >> debug_info.txt

# Configuration (remove sensitive data)
cat .env | sed 's/PASSWORD=.*/PASSWORD=***REDACTED***/' >> debug_info.txt
```

### Support Channels

1. **GitHub Issues**: Report bugs and feature requests
2. **Community Forum**: Ask questions and share experiences
3. **Documentation**: Check official Somleng documentation
4. **Professional Support**: Consider commercial support for production deployments

### Emergency Procedures

**Complete System Recovery**
```bash
# Stop all services
docker-compose down

# Restore from backup
./scripts/backup.sh restore latest_backup.tar.gz

# Start services
docker-compose up -d

# Verify functionality
./scripts/health-check.sh
```

**Rollback Deployment**
```bash
# If you have a previous working version
git checkout previous_working_commit

# Rebuild and restart
docker-compose down
docker-compose build --no-cache
docker-compose up -d
```

Remember to always backup your data before making significant changes, and test solutions in a development environment when possible.