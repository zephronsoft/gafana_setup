# Internal SMTP Setup Guide

This guide explains the internal SMTP configuration for the monitoring stack.

## Overview

The monitoring stack uses internal SMTP servers for both development and production environments:

- **Development**: MailHog (for testing and development)
- **Production**: Postfix (internal SMTP server)

## Development Environment (MailHog)

### What is MailHog?
MailHog is a development SMTP server that captures all emails sent by your application and displays them in a web interface. It's perfect for development and testing.

### Configuration
```yaml
# Grafana SMTP Configuration (Development)
GF_SMTP_ENABLED=true
GF_SMTP_HOST=mailhog:1025
GF_SMTP_USER=
GF_SMTP_PASSWORD=
GF_SMTP_FROM_ADDRESS=noreply-monitoring@localhost
GF_SMTP_SKIP_VERIFY=true
```

### Access Points
- **SMTP Server**: `localhost:1025`
- **Web Interface**: `http://localhost:8025`
- **No Authentication Required**

### Benefits
- No external dependencies
- Web interface to view sent emails
- Perfect for development and testing
- No risk of sending emails to real addresses

## Production Environment (Postfix)

### What is Postfix?
Postfix is a full-featured mail transfer agent (MTA) that can send emails to external recipients. It's configured as an internal SMTP server.

### Configuration
```yaml
# Grafana SMTP Configuration (Production)
GF_SMTP_ENABLED=true
GF_SMTP_HOST=postfix:587
GF_SMTP_USER=monitoring@localhost
GF_SMTP_PASSWORD=your-smtp-password
GF_SMTP_FROM_ADDRESS=noreply-monitoring@localhost
GF_SMTP_SKIP_VERIFY=true
GF_SMTP_STARTTLS_POLICY=MandatoryStartTLS
```

### Access Points
- **SMTP Server**: `localhost:587`
- **Internal Network**: `postfix:587`

### Benefits
- Full SMTP functionality
- Can send emails to external recipients
- Internal server (no external dependencies)
- Configurable authentication

## Environment Variables

### Required SMTP Variables
```bash
# SMTP Configuration
MAIL_DOMAIN=localhost
SMTP_USER=monitoring@localhost
SMTP_PASSWORD=your-smtp-password
SMTP_FROM=noreply-monitoring@localhost
SMTP_HOST=postfix:587
SMTP_PORT=587
```

### Setting Up Environment
1. Copy the example environment file:
   ```bash
   cp environment.example .env
   ```

2. Configure SMTP variables in `.env`:
   ```bash
   # For development (MailHog)
   SMTP_USER=monitoring@localhost
   SMTP_PASSWORD=your-smtp-password
   SMTP_FROM=noreply-monitoring@localhost
   
   # For production (Postfix)
   SMTP_USER=monitoring@localhost
   SMTP_PASSWORD=your-secure-password
   SMTP_FROM=noreply-monitoring@localhost
   ```

## Deployment

### Development Deployment
```bash
# Deploy with MailHog SMTP
./deploy.sh dev
```

### Production Deployment
```bash
# Deploy with Postfix SMTP
./deploy.sh prod
```

## Testing SMTP

### Test Development SMTP
```bash
# Test MailHog
./deploy.sh test-smtp dev

# Access MailHog web interface
open http://localhost:8025
```

### Test Production SMTP
```bash
# Test Postfix
./deploy.sh test-smtp prod

# Test SMTP connectivity
telnet localhost 587
```

## Email Configuration in Grafana

### Development (MailHog)
1. Go to Grafana: `http://localhost:3000`
2. Navigate to **Configuration** → **Notification channels**
3. Add a new notification channel
4. Configure SMTP settings:
   - **Host**: `mailhog:1025`
   - **User**: (leave empty)
   - **Password**: (leave empty)
   - **From Address**: `noreply-monitoring@localhost`

### Production (Postfix)
1. Go to Grafana: `http://your-domain:3000`
2. Navigate to **Configuration** → **Notification channels**
3. Add a new notification channel
4. Configure SMTP settings:
   - **Host**: `postfix:587`
   - **User**: `monitoring@localhost`
   - **Password**: `your-smtp-password`
   - **From Address**: `noreply-monitoring@localhost`

## Troubleshooting

### MailHog Issues
```bash
# Check if MailHog is running
docker ps | grep mailhog

# Check MailHog logs
docker logs mailhog

# Access MailHog web interface
curl http://localhost:8025
```

### Postfix Issues
```bash
# Check if Postfix is running
docker ps | grep postfix

# Check Postfix logs
docker logs postfix

# Test SMTP connectivity
telnet localhost 587
```

### Common Issues

1. **Connection Refused**
   - Check if SMTP container is running
   - Verify port configuration
   - Check network connectivity

2. **Authentication Failed**
   - Verify SMTP credentials
   - Check user/password configuration
   - Ensure Postfix is properly configured

3. **Emails Not Sending**
   - Check Grafana SMTP configuration
   - Verify SMTP server is accessible
   - Check logs for error messages

## Security Considerations

### Development (MailHog)
- No authentication required
- Only accessible locally
- Emails are captured, not sent externally
- Safe for development environments

### Production (Postfix)
- Configure strong passwords
- Use internal network only
- Consider firewall rules
- Monitor SMTP logs for security

## Advanced Configuration

### Custom Postfix Configuration
Edit `postfix/main.cf` for custom Postfix settings:
```bash
# Example custom settings
myhostname = monitoring.localhost
mydomain = localhost
myorigin = $mydomain
inet_interfaces = all
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain
```

### Custom MailHog Configuration
MailHog configuration is handled through environment variables in `docker-compose.yml`:
```yaml
environment:
  - MH_STORAGE=maildir
  - MH_MAILDIR_PATH=/maildir
```

## Monitoring SMTP

### Check SMTP Health
```bash
# Development
curl http://localhost:8025/api/v2/messages

# Production
telnet localhost 587
```

### View SMTP Logs
```bash
# Development
docker logs mailhog

# Production
docker logs postfix
```

## Best Practices

1. **Use MailHog for Development**
   - Prevents accidental emails to real addresses
   - Provides web interface for email testing
   - No external dependencies

2. **Use Postfix for Production**
   - Full SMTP functionality
   - Can send to external recipients
   - Internal server control

3. **Secure Configuration**
   - Use strong passwords for production
   - Limit network access
   - Monitor SMTP logs

4. **Testing**
   - Always test SMTP configuration
   - Verify email delivery
   - Check notification channels in Grafana

## Migration from External SMTP

If you're migrating from external SMTP to internal SMTP:

1. **Update Environment Variables**
   ```bash
   # Remove external SMTP variables
   # PRODUCTION_SMTP_HOST=smtp.gmail.com
   # PRODUCTION_SMTP_USER=your-email@gmail.com
   # PRODUCTION_SMTP_PASSWORD=your-app-password
   
   # Add internal SMTP variables
   SMTP_USER=monitoring@localhost
   SMTP_PASSWORD=your-secure-password
   SMTP_FROM=noreply-monitoring@localhost
   ```

2. **Update Grafana Configuration**
   - Change SMTP host from external to internal
   - Update credentials
   - Test notification channels

3. **Verify Configuration**
   ```bash
   ./deploy.sh test-smtp prod
   ```

## Support

For issues with SMTP configuration:

1. Check container logs
2. Verify network connectivity
3. Test SMTP manually
4. Review configuration files
5. Check Grafana notification channels 