# Somleng CPaaS Architecture Overview

This document provides a comprehensive overview of the Somleng CPaaS architecture, components, and data flow.

## High-Level Architecture

```
                                    Internet
                                       |
                               [Load Balancer/CDN]
                                       |
                                   [Firewall]
                                       |
                               [NGINX Reverse Proxy]
                               (SSL Termination)
                                       |
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
   [Web Interface]              [API Gateway]                [Monitoring]
   (Dashboard/Admin)            (REST API)                   (Grafana/Kibana)
        │                              │                              │
        └──────────────┬───────────────┼───────────────┬──────────────┘
                       │               │               │
                  [Somleng Core]  [Authentication]  [Metrics/Logs]
                  (Rails App)     (JWT/Session)     (Prometheus/ELK)
                       │               │               │
        ┌──────────────┼───────────────┼───────────────┼──────────────┐
        │              │               │               │              │
   [Database]     [Message Queue]  [Cache]      [File Storage]   [Backup]
   (PostgreSQL)   (Sidekiq/Redis)  (Redis)      (Local/S3)       (S3)
        │              │               │               │              │
        └──────────────┼───────────────┼───────────────┼──────────────┘
                       │               │               │
                  [SIP Router]    [Media Servers]  [SMS Gateway]
                  (Kamailio)      (FreeSWITCH)    (SMPP/HTTP)
                       │               │               │
                  [RTPEngine]     [Call Recording]  [SMS Providers]
                  (NAT/SBC)       (Audio Files)    (Carriers)
                       │               │               │
                       └───────────────┼───────────────┘
                                       │
                               [Telecom Carriers]
                               (SIP Trunks/SMS)
```

## Component Architecture

### 1. Frontend Layer

#### NGINX Reverse Proxy
- **Purpose**: SSL termination, load balancing, static file serving
- **Features**:
  - HTTP/2 support
  - Rate limiting
  - Security headers
  - Gzip compression
  - WebSocket support for real-time features

#### Web Interface
- **Technology**: Ruby on Rails
- **Features**:
  - Admin dashboard
  - Account management
  - Call/SMS logs
  - Real-time monitoring
  - Multi-tenant interface

### 2. Application Layer

#### Somleng Core (Rails Application)
- **Purpose**: Main application logic and API
- **Components**:
  - REST API (Twilio-compatible)
  - Account management
  - Call routing logic
  - Billing and usage tracking
  - Webhook handling
  - Multi-tenancy support

#### Background Processing
- **Technology**: Sidekiq with Redis
- **Functions**:
  - Async webhook delivery
  - Call detail record processing
  - Billing calculations
  - SMS delivery
  - Report generation

### 3. Data Layer

#### PostgreSQL Database
- **Purpose**: Primary data storage
- **Schema**:
  - Accounts and subaccounts
  - Phone numbers
  - Call detail records (CDRs)
  - SMS messages
  - Recordings metadata
  - Billing information

#### Redis Cache
- **Purpose**: Caching and session storage
- **Uses**:
  - Session management
  - API rate limiting
  - Real-time data
  - Background job queue
  - Temporary data storage

### 4. Communication Layer

#### Kamailio SIP Router
- **Purpose**: SIP signaling and routing
- **Features**:
  - Load balancing across FreeSWITCH nodes
  - NAT traversal
  - SIP authentication
  - Registration handling
  - Call routing
  - Security (flood protection, rate limiting)

#### FreeSWITCH Media Servers
- **Purpose**: Media processing and call control
- **Features**:
  - RTP handling
  - IVR processing
  - Call recording
  - Conference bridging
  - TTS/STT
  - Codec transcoding

#### RTPEngine
- **Purpose**: RTP proxy and NAT traversal
- **Features**:
  - Media anchoring
  - NAT traversal
  - RTP recording
  - Bandwidth management
  - Security (SRTP)

#### SMS Gateway
- **Purpose**: SMS message delivery
- **Protocols**:
  - SMPP
  - HTTP APIs
  - SIP MESSAGE
  - GSM modems

### 5. Monitoring and Observability

#### Prometheus
- **Purpose**: Metrics collection and alerting
- **Metrics**:
  - System metrics (CPU, memory, disk)
  - Application metrics (API calls, response times)
  - Call metrics (volume, quality, duration)
  - SIP metrics (registrations, responses)

#### Grafana
- **Purpose**: Metrics visualization and dashboards
- **Dashboards**:
  - System overview
  - Call quality metrics
  - API performance
  - Business metrics
  - Alert management

#### ELK Stack (Elasticsearch, Logstash, Kibana)
- **Purpose**: Log aggregation and analysis
- **Components**:
  - Elasticsearch: Log storage and search
  - Logstash: Log processing and parsing
  - Kibana: Log visualization and analysis

## Data Flow

### 1. Outbound Call Flow

```
API Request → Somleng Core → Database (CDR) → Kamailio → FreeSWITCH → Carrier
     ↓              ↓              ↓            ↓           ↓          ↓
Webhook ← Background Job ← Status Update ← SIP Events ← Media ← Call Progress
```

1. **API Request**: Client makes REST API call to initiate call
2. **Somleng Core**: Validates request, creates CDR, queues call
3. **Database**: Stores call record and routing information
4. **Kamailio**: Routes SIP INVITE to appropriate FreeSWITCH node
5. **FreeSWITCH**: Processes call, handles media, executes TwiML
6. **Carrier**: Terminates call to destination
7. **Status Updates**: Call progress events flow back through the stack
8. **Webhooks**: Status callbacks sent to client application

### 2. Inbound Call Flow

```
Carrier → Kamailio → FreeSWITCH → TwiML Fetch → Somleng Core → Webhook → Client App
   ↓         ↓          ↓             ↓            ↓           ↓         ↓
Database ← CDR ← Media Processing ← Call Control ← Routing ← Response ← TwiML
```

1. **Carrier**: Sends INVITE to Kamailio
2. **Kamailio**: Routes to FreeSWITCH based on DID
3. **FreeSWITCH**: Accepts call, fetches TwiML from Somleng
4. **Somleng Core**: Looks up phone number, sends webhook to client
5. **Client App**: Returns TwiML instructions
6. **FreeSWITCH**: Executes TwiML (play, record, dial, etc.)
7. **Database**: Stores CDR and call details

### 3. SMS Flow

```
API Request → Somleng Core → SMS Gateway → SMPP/HTTP → SMS Provider → Delivery
     ↓              ↓             ↓           ↓            ↓           ↓
Database ← Background Job ← Queue ← Status Updates ← Delivery Receipt ← End User
```

1. **API Request**: Client sends SMS via REST API
2. **Somleng Core**: Validates and queues message
3. **Background Job**: Processes SMS queue
4. **SMS Gateway**: Sends via SMPP or HTTP to provider
5. **SMS Provider**: Delivers to end user
6. **Delivery Receipt**: Status updates flow back
7. **Webhook**: Delivery status sent to client

## Security Architecture

### 1. Network Security

```
Internet → WAF/DDoS Protection → Firewall → Load Balancer → Internal Network
```

- **Firewall**: Only required ports open (80, 443, 5060, 5061, RTP range)
- **Rate Limiting**: API and SIP request rate limiting
- **DDoS Protection**: Network-level protection
- **VPN Access**: Administrative access via VPN

### 2. Application Security

- **Authentication**: JWT tokens, API keys, SIP authentication
- **Authorization**: Role-based access control (RBAC)
- **Encryption**: TLS/SSL for all web traffic, SIP-TLS for signaling
- **Input Validation**: All API inputs validated and sanitized
- **SQL Injection Protection**: Parameterized queries, ORM protection

### 3. Data Security

- **Encryption at Rest**: Database encryption, encrypted backups
- **Encryption in Transit**: TLS for all communications
- **Key Management**: Secure key storage and rotation
- **Data Retention**: Configurable data retention policies
- **Audit Logging**: All access and changes logged

## Scalability Architecture

### 1. Horizontal Scaling

#### Application Tier
- Multiple Somleng web instances behind load balancer
- Stateless application design
- Session storage in Redis cluster

#### Media Tier
- Multiple FreeSWITCH nodes
- Kamailio load balancing
- RTPEngine clustering

#### Database Tier
- PostgreSQL read replicas
- Connection pooling
- Database sharding (if needed)

### 2. Vertical Scaling

- CPU: Scale based on concurrent calls
- Memory: Scale based on call volume and caching needs
- Storage: Scale based on recordings and logs
- Network: Scale based on RTP bandwidth requirements

### 3. Auto-Scaling

```yaml
# Example Kubernetes HPA configuration
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: somleng-web-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: somleng-web
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
```

## High Availability Architecture

### 1. Service Redundancy

- **Load Balancers**: Multiple load balancer instances
- **Application Servers**: Multiple Somleng instances
- **Media Servers**: Multiple FreeSWITCH nodes
- **Databases**: Master-slave replication
- **Monitoring**: Redundant monitoring systems

### 2. Failover Mechanisms

- **Health Checks**: Continuous health monitoring
- **Automatic Failover**: Automatic service failover
- **Circuit Breakers**: Prevent cascade failures
- **Graceful Degradation**: Maintain core functionality during outages

### 3. Disaster Recovery

- **Backup Strategy**: Regular automated backups
- **Geographic Distribution**: Multi-region deployment
- **Recovery Procedures**: Documented recovery processes
- **RTO/RPO Targets**: Recovery time and point objectives

## Performance Optimization

### 1. Database Optimization

- **Indexing**: Optimized database indexes
- **Query Optimization**: Efficient SQL queries
- **Connection Pooling**: Database connection management
- **Caching**: Redis caching layer

### 2. Application Optimization

- **Code Optimization**: Efficient algorithms and data structures
- **Caching**: Application-level caching
- **Async Processing**: Background job processing
- **CDN**: Content delivery network for static assets

### 3. Network Optimization

- **Compression**: Gzip compression for web traffic
- **Keep-Alive**: HTTP connection reuse
- **RTP Optimization**: Efficient RTP handling
- **QoS**: Quality of Service configuration

## Deployment Architecture

### 1. Container Architecture

```
Docker Host
├── somleng-web (Rails app)
├── somleng-sidekiq (Background jobs)
├── postgres (Database)
├── redis (Cache/Queue)
├── kamailio (SIP router)
├── freeswitch1 (Media server)
├── freeswitch2 (Media server)
├── rtpengine (RTP proxy)
├── nginx (Reverse proxy)
├── prometheus (Metrics)
├── grafana (Dashboards)
├── elasticsearch (Logs)
├── logstash (Log processing)
└── kibana (Log visualization)
```

### 2. Network Architecture

```
External Network (Internet)
├── Public IP: 203.0.113.1
├── Ports: 80, 443, 5060, 5061, 16384-32768
└── Docker Bridge Network: 172.20.0.0/16
    ├── nginx: 172.20.0.2
    ├── somleng-web: 172.20.0.3
    ├── kamailio: 172.20.0.5
    ├── freeswitch1: 172.20.0.10
    ├── freeswitch2: 172.20.0.11
    └── rtpengine: host network mode
```

### 3. Storage Architecture

```
Host Storage
├── /var/lib/docker/volumes/
│   ├── postgres_data (Database files)
│   ├── redis_data (Cache data)
│   ├── somleng_uploads (File uploads)
│   ├── freeswitch_recordings (Call recordings)
│   ├── nginx_logs (Access logs)
│   └── backup_data (Backup files)
└── External Storage (S3)
    ├── Backups
    ├── Call recordings
    └── Log archives
```

This architecture provides a robust, scalable, and maintainable CPaaS platform that can handle high-volume communications while maintaining reliability and performance.