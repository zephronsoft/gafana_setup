# Facebook/Meta Enterprise Monitoring Stack

A comprehensive, enterprise-grade monitoring solution designed for Facebook/Meta's production infrastructure. This stack provides complete observability with metrics, logs, traces, and alerting capabilities.

## 🚀 Features

### **Core Monitoring Stack**
- **Prometheus** - High-performance metrics collection and storage
- **Grafana** - Advanced visualization and dashboards with PostgreSQL backend
- **AlertManager** - Intelligent alerting with multi-channel notifications
- **Loki** - Scalable log aggregation and analysis
- **Jaeger** - Distributed tracing for microservices

### **Data Collection**
- **Node Exporter** - System metrics (CPU, memory, disk, network)
- **cAdvisor** - Container metrics and resource usage
- **Promtail** - Log collection from applications and infrastructure
- **Blackbox Exporter** - Endpoint monitoring and health checks

### **Enterprise Features**
- **High Availability** - Clustered AlertManager and data persistence
- **Security** - RBAC, audit logging, SSL/TLS encryption
- **Scalability** - Optimized for large-scale deployment
- **Multi-Channel Alerting** - Slack, PagerDuty, Email, Microsoft Teams
- **Log Aggregation** - Centralized logging with retention policies
- **Distributed Tracing** - End-to-end request tracking
- **Database Backend** - PostgreSQL for Grafana configuration storage

## 📋 Prerequisites

- Docker Engine >= 20.10
- Docker Compose >= 2.0
- 8GB+ RAM (16GB recommended for production)
- 100GB+ disk space
- SSL certificates for HTTPS endpoints

## 🛠️ Quick Start

### 1. Clone Repository
```bash
git clone https://github.com/facebook/enterprise-monitoring-stack.git
cd enterprise-monitoring-stack
```

### 2. Configure Environment
```bash
cp environment.example .env
```

Edit `.env` with your configuration:
```bash
# Admin Credentials
ADMIN_USER=admin
ADMIN_PASSWORD=your-secure-password

# Database
POSTGRES_PASSWORD=your-db-password
GRAFANA_SECRET_KEY=your-grafana-secret

# Alerting
SLACK_API_URL=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK
SMTP_PASSWORD=your-smtp-password
PAGERDUTY_INTEGRATION_KEY=your-pagerduty-key
```

### 3. Deploy Stack
```bash
# Start all services
docker-compose up -d

# Verify deployment
docker-compose ps
```

### 4. Access Services
- **Grafana**: https://localhost:3000 (admin/password)
- **Prometheus**: https://localhost:9090
- **AlertManager**: https://localhost:9093
- **Loki**: https://localhost:3100
- **Jaeger**: https://localhost:16686
- **MailHog** (Dev SMTP): http://localhost:8025

## 📊 Dashboards

### Pre-configured Dashboards
1. **Infrastructure Overview** - System health and resource utilization
2. **Container Metrics** - Docker container performance
3. **Application Performance** - Service-level monitoring
4. **Network Monitoring** - Endpoint health and SSL certificates
5. **Security Dashboard** - Authentication and access monitoring
6. **Business Metrics** - SLO/SLA tracking

## 📧 SMTP Configuration

### Built-in SMTP Servers
The monitoring stack includes two SMTP server options:

#### Development (MailHog)
- **Web Interface**: http://localhost:8025
- **SMTP Port**: 1025
- **Features**: Email capture and web-based inbox
- **Usage**: Automatically enabled in development mode
- **Perfect for**: Testing email notifications without sending real emails

#### Production (Postfix)
- **SMTP Port**: 587
- **Features**: Full-featured SMTP server with authentication
- **Usage**: Enable with `--profile production`
- **Configuration**: Edit `postfix/main.cf` and `postfix/master.cf`

### Environment-Specific Setup

#### Development Mode (Default)
```bash
# Uses MailHog for email testing
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

#### Production Mode
```bash
# Uses Postfix for real email delivery
docker-compose --profile production up -d
```

## 🔔 Alerting

### Alert Channels
- **Critical Alerts**: PagerDuty + Slack + Email
- **Warning Alerts**: Slack + Email
- **Info Alerts**: Email only
- **Environment-specific**: Separate channels for dev/staging/prod

### Alert Rules
- **Infrastructure**: CPU, memory, disk, network
- **Application**: Service availability, error rates, latency
- **Security**: Unauthorized access, suspicious activity
- **Business**: SLO violations, throughput anomalies

## 🔒 Security Features

### Authentication & Authorization
- Multi-factor authentication support
- RBAC with team-based access control
- LDAP/Active Directory integration
- Audit logging for all actions

### Network Security
- SSL/TLS encryption for all communications
- Network segmentation with Docker networks
- Firewall rules and port restrictions
- Reverse proxy with security headers

### Data Protection
- Encrypted data storage
- Secure secret management
- Regular security updates
- Backup encryption

## 🔐 SSL Certificate Management

### Dynamic Certificate Generation
The monitoring stack includes a comprehensive SSL certificate management system that automatically generates and manages SSL certificates for all services.

#### Features
- **Automatic Generation**: Creates self-signed certificates if none provided
- **Multi-Domain Support**: Supports all monitoring services with SAN (Subject Alternative Names)
- **Certificate Validation**: Checks certificate validity and expiration
- **Automatic Renewal**: Configurable automatic renewal before expiration
- **Backup System**: Automatic backup of certificates before renewal
- **Easy Integration**: Seamless integration with Traefik reverse proxy

#### SSL Manager Script
```bash
# Generate new certificates
./ssl-manager.sh generate

# Check certificate status
./ssl-manager.sh check

# Show certificate information
./ssl-manager.sh info

# Renew certificates if needed
./ssl-manager.sh renew

# Force regeneration
./ssl-manager.sh generate --force
```

#### Certificate Domains
The system generates certificates for all monitoring services:
- `monitoring.facebook.com` (main domain)
- `grafana.facebook.com`
- `prometheus.facebook.com`
- `alertmanager.facebook.com`
- `loki.facebook.com`
- `jaeger.facebook.com`
- `mailhog.facebook.com`
- `localhost` (for development)

### Automatic Certificate Renewal

#### Setup Automatic Renewal
```bash
# Setup automatic renewal with default schedule (Sundays at 2 AM)
./setup-ssl-renewal.sh setup

# Setup with custom schedule
./setup-ssl-renewal.sh custom

# Check renewal status
./setup-ssl-renewal.sh status

# Test renewal process
./setup-ssl-renewal.sh test
```

#### Renewal Process
1. **Check Expiration**: Verifies if certificates expire within 30 days
2. **Backup Current**: Creates backup of existing certificates
3. **Generate New**: Creates new certificates with updated validity
4. **Restart Services**: Automatically restarts services to use new certificates
5. **Verify**: Validates new certificates are working correctly
6. **Log**: Comprehensive logging of the renewal process

#### Monitoring Certificate Expiry
The system includes built-in monitoring of certificate expiration:
- **Prometheus Metrics**: Certificate expiry metrics
- **Grafana Dashboard**: Certificate status visualization
- **AlertManager Rules**: Alerts for certificates expiring soon
- **Automated Notifications**: Email/Slack notifications for renewals

### Using Your Own Certificates

#### Production SSL Certificates
For production environments, replace the self-signed certificates with proper SSL certificates:

```bash
# Place your certificates in the ssl directory
cp your-certificate.crt ssl/certs/monitoring.crt
cp your-private-key.key ssl/private/monitoring.key
cp your-ca-certificate.crt ssl/certs/ca.crt

# Restart services to use new certificates
docker-compose restart traefik grafana prometheus alertmanager
```

#### Let's Encrypt Integration
For automated Let's Encrypt certificates:
1. Configure your domain DNS to point to your server
2. Update `environment.example` with your domain and email
3. Enable Let's Encrypt in Traefik configuration
4. Deploy the stack - certificates will be automatically obtained

### SSL Directory Structure
```
ssl/
├── certs/                    # Certificate files
│   ├── monitoring.crt        # Main certificate
│   ├── monitoring-bundle.crt # Certificate bundle
│   ├── ca.crt               # CA certificate
│   └── dhparam.pem          # DH parameters
├── private/                  # Private keys (chmod 700)
│   ├── monitoring.key        # Main private key
│   └── ca.key               # CA private key
├── config/                   # OpenSSL configuration
│   └── openssl.cnf          # Certificate generation config
└── backups/                  # Automatic backups
    └── backup_YYYYMMDD_HHMMSS/
```

### Troubleshooting SSL Issues

#### Common Issues
- **Certificate Validation**: Check certificate validity with `openssl x509 -in ssl/certs/monitoring.crt -text -noout`
- **Permission Issues**: Ensure proper permissions on SSL directories
- **Service Restart**: Restart services after certificate changes
- **DNS Issues**: Verify domain resolution for proper SSL validation

#### Debug Commands
```bash
# Check certificate expiry
openssl x509 -in ssl/certs/monitoring.crt -noout -enddate

# Verify certificate and key match
openssl x509 -noout -modulus -in ssl/certs/monitoring.crt | openssl md5
openssl rsa -noout -modulus -in ssl/private/monitoring.key | openssl md5

# Test SSL connection
openssl s_client -connect localhost:443 -servername monitoring.facebook.com
```

## 📈 Scalability

### Horizontal Scaling
- Prometheus federation for multi-datacenter
- Grafana clustering with shared database
- AlertManager clustering with gossip protocol
- Loki distributed deployment

### Performance Optimization
- Metrics retention policies (30 days default)
- Query optimization and caching
- Resource limits and reservations
- SSD storage for time series data

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Facebook Monitoring Stack                │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Grafana   │  │ Prometheus  │  │AlertManager │         │
│  │   :3000     │  │    :9090    │  │    :9093    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│         │                │                │                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │    Loki     │  │   Jaeger    │  │   Traefik   │         │
│  │   :3100     │  │   :16686    │  │  :80/:443   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│                     Data Collection                         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │Node Exporter│  │  cAdvisor   │  │  Promtail   │         │
│  │   :9100     │  │    :8080    │  │   :9080     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Blackbox   │  │   Redis     │  │ PostgreSQL  │         │
│  │   :9115     │  │   :6379     │  │   :5432     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

## 🔧 Configuration

### Prometheus Configuration
- **Retention**: 30 days (configurable)
- **Storage**: 50GB limit (configurable)
- **Scrape Interval**: 15s (optimized for performance)
- **Remote Storage**: Configured for long-term storage

### Grafana Configuration
- **Database**: PostgreSQL backend for HA
- **Plugins**: Pre-installed enterprise plugins
- **Themes**: Dark theme as default
- **SMTP**: Configured for email notifications

### AlertManager Configuration
- **Clustering**: Multi-instance for HA
- **Routing**: Sophisticated rule-based routing
- **Inhibition**: Prevents alert storms
- **Templates**: Custom notification templates

## 📚 Documentation

### Runbooks
- [Infrastructure Alerts](docs/runbooks/infrastructure.md)
- [Application Alerts](docs/runbooks/application.md)
- [Database Alerts](docs/runbooks/database.md)
- [Security Alerts](docs/runbooks/security.md)

### Operational Guides
- [Backup and Recovery](docs/operations/backup.md)
- [Scaling Guide](docs/operations/scaling.md)
- [Troubleshooting](docs/operations/troubleshooting.md)
- [Maintenance](docs/operations/maintenance.md)

## 🔄 Backup & Recovery

### Automated Backups
- **Prometheus Data**: Daily snapshots to S3
- **Grafana Config**: Database backups
- **AlertManager State**: Configuration backups
- **Retention**: 90 days (configurable)

### Disaster Recovery
- **RTO**: 15 minutes
- **RPO**: 1 hour
- **Cross-region replication**
- **Automated failover**

## 📊 Monitoring Best Practices

### Metrics Naming
- Use consistent naming conventions
- Include units in metric names
- Add appropriate labels for filtering
- Avoid high cardinality metrics

### Alert Design
- Define clear SLIs and SLOs
- Use symptom-based alerting
- Implement proper escalation policies
- Regular alert review and tuning

### Dashboard Design
- Focus on user experience
- Use appropriate visualization types
- Include context and documentation
- Regular dashboard maintenance

## 🚀 Deployment Options

### Development Environment
```bash
# Development setup with MailHog SMTP
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d

# Or use the deployment script
./deploy.sh deploy
```

### Production Environment
```bash
# Production setup with Postfix SMTP
docker-compose --profile production up -d

# Or use the deployment script for production
./deploy.sh deploy --production
```

### Quick Testing Environment
```bash
# Minimal setup with MailHog only
docker-compose up -d mailhog grafana prometheus alertmanager
```

### Kubernetes Deployment
```bash
# Helm chart available
helm install fb-monitoring ./helm/monitoring-stack
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Internal Support**: #platform-reliability
- **Documentation**: [wiki.facebook.com/monitoring](https://wiki.facebook.com/monitoring)
- **Incidents**: Create ticket in JIRA
- **Email**: platform-reliability@facebook.com

## 🏷️ Version History

- **v3.0.0** - Enterprise-grade monitoring stack
- **v2.0.0** - Added distributed tracing and log aggregation
- **v1.0.0** - Initial release with basic monitoring

---

**Built with ❤️ by the Facebook Platform Reliability Team**
