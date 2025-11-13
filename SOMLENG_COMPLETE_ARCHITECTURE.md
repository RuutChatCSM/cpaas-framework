# Complete Somleng Production Architecture

## Overview

This deployment implements the **complete official Somleng architecture** as designed by the Somleng project team. It combines:

1. **Somleng Core** - The CPaaS platform with Twilio-compatible API
2. **SomlengSWITCH** - The complete telephony engine with all microservices

## Architecture Components

### 🏗️ Infrastructure Layer
- **PostgreSQL** - Primary database (Somleng data + OpenSIPS routing tables)
- **Redis** - Cache, sessions, and job queue
- **NGINX** - Reverse proxy and load balancer

### 🌐 Somleng Core (CPaaS Platform)
- **somleng_web** - Rails application providing Twilio-compatible REST API
- **somleng_sidekiq** - Background job processing (webhooks, billing, etc.)

### 📞 SomlengSWITCH (Telephony Engine)

#### SIP Gateways (OpenSIPS-based)
- **public_gateway** - Carrier connections with IP authentication
- **client_gateway** - Customer connections with SIP registration
- **gateway_bootstrap** - Database initialization service

#### Media Processing
- **media_proxy** - Custom RTPEngine wrapper for NAT traversal and media bridging
- **freeswitch1/2** - Media servers (horizontally scalable cluster)

#### TwiML Engine
- **somleng_switch_app** - Ruby/Adhearsion app that processes TwiML and controls FreeSWITCH

#### Supporting Microservices
- **somleng_services** - Load balancer management (updates routing tables)
- **freeswitch1/2_event_logger** - Event logging sidecars
- **public/client_gateway_scheduler** - OpenSIPS maintenance schedulers

#### Messaging
- **sms_gateway** - SMS delivery via SMPP/HTTP to carriers

## Data Flow

### Inbound Call Flow
```
Carrier/Customer → OpenSIPS Gateway → FreeSWITCH → SomlengSWITCH App → Somleng Core API
                                    ↓
                               Media Proxy (for NAT traversal)
```

### API Call Flow
```
Customer API → Somleng Web → SomlengSWITCH App → FreeSWITCH → OpenSIPS → Carrier
```

### Service Discovery Flow
```
FreeSWITCH instances register → Services microservice → Updates OpenSIPS routing tables
```

## Network Architecture

### Service IP Assignments
- **172.20.0.10** - Public Gateway (OpenSIPS)
- **172.20.0.11** - Client Gateway (OpenSIPS)  
- **172.20.0.12** - Media Proxy
- **172.20.0.20** - FreeSWITCH 1
- **172.20.0.21** - FreeSWITCH 2
- **172.20.0.30** - SomlengSWITCH App

### Port Mappings
- **5060** - Public Gateway SIP (carriers)
- **5070** - Client Gateway SIP (customers)
- **5062/5064** - FreeSWITCH SIP ports
- **8021/8022** - FreeSWITCH Event Socket
- **8080** - SomlengSWITCH App API
- **3000** - Somleng Web API
- **2223** - Media Proxy control
- **16384-49151** - RTP media ports

## Production Features

### High Availability
- **Multiple FreeSWITCH instances** for horizontal scaling
- **Automatic load balancing** via OpenSIPS
- **Service discovery** via Services microservice
- **Health checks** for all components

### NAT Traversal
- **Media Proxy** handles complex NAT scenarios
- **Symmetric RTP latching** for carrier interconnection
- **STUN/TURN-like capabilities** built into Media Proxy

### Monitoring & Observability
- **FreeSWITCH Event Loggers** for call event tracking
- **Redis-based** event aggregation
- **Health check endpoints** on all services
- **Structured logging** throughout

### Scalability
- **Horizontal FreeSWITCH scaling** - add more instances
- **OpenSIPS load balancing** - distributes calls automatically
- **Background job processing** - async webhook delivery
- **Database clustering ready** - PostgreSQL primary/replica

## Key Differences from Generic Telecom Stack

### ❌ What's NOT Used (Unlike Generic Deployments)
- **Kamailio** - Somleng uses OpenSIPS with custom routing logic
- **Generic RTPEngine** - Uses custom Media Proxy wrapper
- **Asterisk** - Uses FreeSWITCH with Somleng-specific modules
- **Generic SIP routing** - Uses dynamic routing via Services microservice

### ✅ What Makes This Somleng-Specific
- **TwiML processing engine** - Ruby/Adhearsion based
- **Dynamic load balancer updates** - Services microservice
- **Integrated CPaaS platform** - Not just a telecom switch
- **Twilio API compatibility** - Drop-in replacement
- **Multi-tenant architecture** - Account isolation built-in

## Deployment Advantages

### For Heavy Production Use
1. **True horizontal scaling** - Add FreeSWITCH instances automatically
2. **Carrier-grade NAT handling** - Media Proxy solves complex scenarios
3. **Zero-downtime scaling** - Services component updates routing tables
4. **Production monitoring** - Event loggers and health checks
5. **API-driven configuration** - No manual SIP config needed

### Development to Production Path
1. **Start with this complete stack** for development
2. **Scale horizontally** by adding more FreeSWITCH containers
3. **Deploy to Kubernetes** using same container images
4. **Use official Terraform** for AWS ECS deployment

## Configuration Requirements

### Minimum Required
```bash
PUBLIC_IP=your.public.ip
POSTGRES_PASSWORD=secure_password
SECRET_KEY_BASE=rails_secret_key
FS_EVENT_SOCKET_PASSWORD=freeswitch_password
```

### Production Scaling
```bash
# Add more FreeSWITCH instances
docker-compose -f docker-compose-somleng-complete.yml up --scale freeswitch=4

# Services microservice automatically updates load balancing
```

## Next Steps

1. **Deploy this complete stack** for proper Somleng experience
2. **Configure carriers** to connect to Public Gateway (port 5060)
3. **Set up customer accounts** via Somleng dashboard
4. **Test API calls** using Twilio SDK pointing to your instance
5. **Scale FreeSWITCH** instances based on concurrent call volume
6. **Monitor via logs** and implement additional observability as needed

This architecture provides the **real production-grade Somleng experience** rather than a frankenstack of incompatible components.