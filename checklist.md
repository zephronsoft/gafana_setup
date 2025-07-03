Here's a comprehensive checklist of what you **MUST** update before deploying to production:

## 🔐 **Critical Security Updates**

### **1. Environment Variables (.env file)**
```bash
# Copy and update the environment file
cp environment.example .env
```

**Required changes in `.env`:**
```bash
# CRITICAL: Change default passwords
ADMIN_USER=your-admin-username
ADMIN_PASSWORD=your-very-strong-password-here

# Database security
POSTGRES_PASSWORD=your-strong-db-password-here
GRAFANA_SECRET_KEY=your-32-character-secret-key-here

# SMTP credentials for production
SMTP_PASSWORD=your-smtp-password

# External service keys
SLACK_API_URL=https://hooks.slack.com/services/YOUR/REAL/WEBHOOK
PAGERDUTY_INTEGRATION_KEY=your-real-pagerduty-key
ACME_EMAIL=your-real-email@facebook.com

# Production domains
GRAFANA_DOMAIN=grafana.your-domain.com
PROMETHEUS_DOMAIN=prometheus.your-domain.com
ALERTMANAGER_DOMAIN=alertmanager.your-domain.com
```

### **2. SSL/TLS Certificates**
```bash
# Replace self-signed certificates with real ones
mkdir -p ssl/
# Copy your real SSL certificates
cp your-domain.crt ssl/server.crt
cp your-domain.key ssl/server.key
```

### **3. AlertManager Configuration**
**Update `alertmanager/config.yml`:**
Read file: alertmanager/config.yml

**Update AlertManager for production SMTP:**
```yaml
global:
  # Production SMTP (Postfix)
  smtp_smarthost: 'postfix:587'
  smtp_from: 'noreply-monitoring@your-domain.com'
  smtp_auth_username: 'monitoring@your-domain.com'
  smtp_auth_password: '${SMTP_PASSWORD}'
  smtp_require_tls: true
  
  # Update Slack webhook
  slack_api_url: 'YOUR_REAL_SLACK_WEBHOOK_URL'
```

**Update email addresses in receivers section:**
- Replace `oncall-sre@facebook.com` with your real email
- Replace `platform-team@facebook.com` with your real email
- Replace `database-oncall@facebook.com` with your real email
- Replace `monitoring-info@facebook.com` with your real email

## 🏗️ **Infrastructure Configuration**

### **4. Resource Limits for Production**
**Update `docker-compose.yml`** to increase resource limits:

```yaml
# Update resource limits for production
prometheus:
  deploy:
    resources:
      limits:
        memory: 8G
        cpus: '4'
      reservations:
        memory: 4G
        cpus: '2'

grafana:
  deploy:
    resources:
      limits:
        memory: 2G
        cpus: '2'
      reservations:
        memory: 1G
        cpus: '1'
```

### **5. Network Security**
**Update `docker-compose.yml`** to remove exposed ports:
```yaml
# REMOVE these port mappings for production (use reverse proxy instead)
# ports:
#   - "3000:3000"  # Grafana
#   - "9090:9090"  # Prometheus
#   - "9093:9093"  # AlertManager
```

### **6. Data Retention & Storage**
**Update `prometheus/prometheus.yml`:**
```yaml
# Increase retention for production
global:
  external_labels:
    monitor: 'your-company-production'
    datacenter: 'your-datacenter'
    environment: 'production'
    team: 'your-team'

# Update remote storage URLs
remote_write:
  - url: "https://your-long-term-storage.com/api/v1/write"

remote_read:
  - url: "https://your-long-term-storage.com/api/v1/read"
```

## 🎯 **Alert Rules Customization**

### **7. Update Alert Thresholds**
**Edit `prometheus/alert.rules`** - Adjust thresholds for production:

```yaml
# Example: Update CPU threshold for production
- alert: HighCPUUsage
  expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80  # Changed from 85
  for: 10m  # Changed from 5m
```

### **8. Update Runbook URLs**
Replace all `https://wiki.facebook.com/runbooks/` URLs with your actual runbook URLs.

## 🔄 **Backup Configuration**

### **9. Setup Automated Backups**
**Create backup script:**
```bash
#!/bin/bash
# Create production backup script
./deploy.sh backup
aws s3 cp backups/ s3://your-backup-bucket/ --recursive
```

## 🌐 **External Dependencies**

### **10. External Service Integration**
- **Slack**: Replace webhook URLs with production channels
- **PagerDuty**: Update integration keys
- **SMTP**: Configure production email relay
- **DNS**: Update domain names to production domains

## 📊 **Monitoring Endpoints**

### **11. Update Scrape Targets**
**Edit `prometheus/prometheus.yml`** to include your production services:
```yaml
scrape_configs:
  - job_name: 'your-production-services'
    static_configs:
      - targets: 
        - 'prod-service-1:8080'
        - 'prod-service-2:8080'
```

## 🚀 **Production Deployment Command**

**After updating all configurations:**

```bash
# 1. Validate environment
cat .env  # Verify all secrets are set

# 2. Deploy with production profile
docker-compose --profile production up -d

# 3. Verify services
docker-compose ps
curl -f http://localhost:3000/api/health
curl -f http://localhost:9090/-/healthy
curl -f http://localhost:9093/-/healthy

# 4. Test alerting
# Trigger a test alert and verify emails/Slack notifications
```

## ⚠️ **Critical Security Checklist**

- [ ] Changed all default passwords
- [ ] Updated SSL certificates
- [ ] Updated email addresses to real ones
- [ ] Updated Slack webhooks to production channels
- [ ] Updated PagerDuty keys
- [ ] Removed debug/development settings
- [ ] Enabled authentication on all services
- [ ] Updated domain names
- [ ] Configured firewall rules
- [ ] Set up proper backup procedures
- [ ] Updated resource limits for production load
- [ ] Tested alert delivery end-to-end

**Never deploy without completing this checklist!** Would you like me to help you update any specific configuration files?