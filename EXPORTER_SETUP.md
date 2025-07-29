# Manual Exporter Configuration Guide

This guide explains how to add exporter URLs manually to your Prometheus configuration.

## Table of Contents
1. [Basic Exporter Configuration](#basic-exporter-configuration)
2. [Multiple Exporters](#multiple-exporters)
3. [External Exporters](#external-exporters)
4. [File-based Service Discovery](#file-based-service-discovery)
5. [DNS-based Service Discovery](#dns-based-service-discovery)
6. [Custom Metrics Path](#custom-metrics-path)
7. [Authentication and Security](#authentication-and-security)
8. [Relabeling and Filtering](#relabeling-and-filtering)
9. [Common Exporter Ports](#common-exporter-ports)
10. [Troubleshooting](#troubleshooting)

## Basic Exporter Configuration

### Single Exporter
```yaml
- job_name: 'my-exporter'
  scrape_interval: 30s
  scrape_timeout: 10s
  static_configs:
    - targets: ['192.168.1.100:9100']  # Replace with your exporter IP:port
      labels:
        instance: 'my-server-01'
        environment: 'production'
```

### Multiple Exporters in Same Job
```yaml
- job_name: 'multiple-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  static_configs:
    - targets: 
      - '192.168.1.101:9100'  # First exporter
      - '192.168.1.102:9100'  # Second exporter
      - '192.168.1.103:9100'  # Third exporter
      labels:
        environment: 'production'
        datacenter: 'east-1'
```

## Multiple Exporters

### Different Types of Exporters
```yaml
- job_name: 'mixed-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  static_configs:
    - targets: 
      - '192.168.1.100:9100'  # Node exporter
      - '192.168.1.100:8080'  # cAdvisor
      - '192.168.1.100:9187'  # PostgreSQL exporter
      - '192.168.1.100:9121'  # Redis exporter
    labels:
      instance: 'server-01'
      environment: 'production'
```

### Separate Jobs for Different Exporters
```yaml
# Node exporters
- job_name: 'node-exporters'
  scrape_interval: 30s
  static_configs:
    - targets: 
      - '192.168.1.100:9100'
      - '192.168.1.101:9100'
      - '192.168.1.102:9100'
    labels:
      job: 'node-exporter'
      environment: 'production'

# Database exporters
- job_name: 'database-exporters'
  scrape_interval: 30s
  static_configs:
    - targets: 
      - '192.168.1.100:9187'  # PostgreSQL
      - '192.168.1.101:9121'  # Redis
    labels:
      job: 'database-exporter'
      environment: 'production'
```

## External Exporters

### HTTPS Exporters
```yaml
- job_name: 'external-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  scheme: https  # Use HTTPS for external exporters
  tls_config:
    insecure_skip_verify: true  # Only for testing
  static_configs:
    - targets: 
      - 'external-server.com:9100'
    labels:
      instance: 'external-server'
      environment: 'external'
```

### Exporters with Authentication
```yaml
- job_name: 'auth-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  basic_auth:
    username: 'prometheus'
    password: 'your-password'
  static_configs:
    - targets: 
      - 'secure-server.com:9100'
    labels:
      instance: 'secure-exporter'
      environment: 'production'
```

## File-based Service Discovery

### Create exporters.yml file
```yaml
# prometheus/exporters.yml
- targets:
  - '192.168.1.100:9100'
  - '192.168.1.101:9100'
  - '192.168.1.102:9100'
  labels:
    job: 'node-exporter'
    environment: 'production'
    datacenter: 'east-1'

- targets:
  - '192.168.1.100:9187'
  - '192.168.1.101:9187'
  labels:
    job: 'postgres-exporter'
    environment: 'production'
```

### Configure Prometheus to use file
```yaml
- job_name: 'file-sd-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  file_sd_configs:
    - files:
      - 'exporters.yml'
      refresh_interval: 5m
```

## DNS-based Service Discovery

### DNS SRV Records
```yaml
- job_name: 'dns-sd-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  dns_sd_configs:
    - names: ['exporters.local']  # DNS name that resolves to exporter IPs
      port: 9100
      refresh_interval: 30s
```

## Custom Metrics Path

### Custom Endpoint
```yaml
- job_name: 'custom-metrics-path'
  scrape_interval: 30s
  scrape_timeout: 10s
  metrics_path: /custom/metrics  # Custom metrics endpoint
  static_configs:
    - targets: 
      - '192.168.1.100:8080'
    labels:
      instance: 'custom-app-01'
      service: 'custom-application'
```

### Query Parameters
```yaml
- job_name: 'exporters-with-params'
  scrape_interval: 30s
  scrape_timeout: 10s
  metrics_path: /metrics
  params:
    debug: ['true']
    format: ['prometheus']
  static_configs:
    - targets: 
      - '192.168.1.100:8080'
    labels:
      instance: 'debug-enabled-exporter'
```

## Authentication and Security

### Basic Authentication
```yaml
- job_name: 'auth-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  basic_auth:
    username: 'prometheus'
    password: 'your-secure-password'
  static_configs:
    - targets: 
      - '192.168.1.100:9100'
    labels:
      instance: 'auth-enabled-exporter'
```

### TLS Configuration
```yaml
- job_name: 'tls-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  scheme: https
  tls_config:
    ca_file: '/path/to/ca.crt'
    cert_file: '/path/to/client.crt'
    key_file: '/path/to/client.key'
    server_name: 'exporter.example.com'
  static_configs:
    - targets: 
      - 'secure-exporter.com:9100'
    labels:
      instance: 'tls-enabled-exporter'
```

## Relabeling and Filtering

### Custom Relabeling
```yaml
- job_name: 'custom-relabel-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  static_configs:
    - targets: 
      - '192.168.1.100:9100'
      - '192.168.1.101:9100'
      - '192.168.1.102:9100'
  relabel_configs:
    - source_labels: [__address__]
      target_label: instance
      regex: '([^:]+):.*'
      replacement: '${1}'
    - source_labels: [__address__]
      target_label: datacenter
      regex: '192\.168\.1\.(100|101)'
      replacement: 'east-1'
    - source_labels: [__address__]
      target_label: datacenter
      regex: '192\.168\.1\.102'
      replacement: 'west-1'
```

### Metric Filtering
```yaml
- job_name: 'filtered-exporters'
  scrape_interval: 30s
  scrape_timeout: 10s
  static_configs:
    - targets: 
      - '192.168.1.100:9100'
  metric_relabel_configs:
    # Only keep metrics that start with 'node_'
    - source_labels: [__name__]
      regex: 'node_.*'
      action: keep
    # Drop specific metrics
    - source_labels: [__name__]
      regex: 'node_cpu_seconds_total'
      action: drop
```

## Common Exporter Ports

| Exporter | Default Port | Description |
|----------|--------------|-------------|
| node_exporter | 9100 | System metrics |
| cadvisor | 8080 | Container metrics |
| postgres_exporter | 9187 | PostgreSQL metrics |
| redis_exporter | 9121 | Redis metrics |
| mysql_exporter | 9104 | MySQL metrics |
| mongodb_exporter | 9216 | MongoDB metrics |
| elasticsearch_exporter | 9114 | Elasticsearch metrics |
| nginx_exporter | 9113 | Nginx metrics |
| apache_exporter | 9117 | Apache metrics |
| haproxy_exporter | 9101 | HAProxy metrics |
| blackbox_exporter | 9115 | Endpoint monitoring |
| pushgateway | 9091 | Batch job metrics |

## Troubleshooting

### Check if Exporter is Accessible
```bash
# Test HTTP connectivity
curl http://192.168.1.100:9100/metrics

# Test HTTPS connectivity
curl -k https://192.168.1.100:9100/metrics

# Check if port is open
telnet 192.168.1.100 9100
```

### Verify Prometheus Configuration
```bash
# Check Prometheus configuration syntax
prometheus --config.file=prometheus.yml --check-config

# Reload Prometheus configuration
curl -X POST http://localhost:9090/-/reload
```

### Common Issues

1. **Connection Refused**
   - Check if exporter is running
   - Verify port number
   - Check firewall settings

2. **Authentication Failed**
   - Verify username/password
   - Check if exporter requires authentication
   - Ensure credentials are correct

3. **SSL/TLS Issues**
   - Check certificate validity
   - Verify CA certificate
   - Use `insecure_skip_verify: true` for testing

4. **No Metrics**
   - Check metrics path
   - Verify exporter is exposing metrics
   - Check exporter logs

### Debugging Commands

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets

# Check specific target
curl "http://localhost:9090/api/v1/targets?job=my-exporter"

# Check Prometheus logs
docker logs prometheus

# Test exporter directly
curl http://exporter-ip:port/metrics
```

## Best Practices

1. **Use Labels**: Always add meaningful labels to your exporters
2. **Separate Jobs**: Use different job names for different types of exporters
3. **File Discovery**: Use file-based discovery for dynamic environments
4. **Security**: Use authentication and TLS for production environments
5. **Monitoring**: Monitor your exporters themselves
6. **Documentation**: Document your exporter configurations
7. **Testing**: Test configurations before deploying to production

## Example Complete Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  # Internal exporters
  - job_name: 'internal-exporters'
    scrape_interval: 30s
    static_configs:
      - targets: 
        - '192.168.1.100:9100'  # Node exporter
        - '192.168.1.100:8080'  # cAdvisor
        - '192.168.1.100:9187'  # PostgreSQL
        - '192.168.1.100:9121'  # Redis
      labels:
        environment: 'production'
        datacenter: 'east-1'

  # External exporters with authentication
  - job_name: 'external-exporters'
    scrape_interval: 30s
    scheme: https
    basic_auth:
      username: 'prometheus'
      password: 'secure-password'
    tls_config:
      insecure_skip_verify: true
    static_configs:
      - targets: 
        - 'external-server.com:9100'
      labels:
        environment: 'external'
        datacenter: 'cloud'

  # File-based discovery
  - job_name: 'file-sd-exporters'
    scrape_interval: 30s
    file_sd_configs:
      - files:
        - 'exporters.yml'
        refresh_interval: 5m
``` 




######################################################################################################################################333
I'll help you add exporter URLs manually to the Prometheus configuration. Let me first check the current Prometheus configuration to understand the structure.

Read file: prometheus/prometheus.yml
Now I'll show you how to add exporter URLs manually to the Prometheus configuration. I'll create an updated version that demonstrates different ways to add exporters:

Now let me create a simple example file for file-based service discovery:

Now let me create a comprehensive guide for adding exporter URLs manually:

Perfect! I've created a comprehensive setup for adding exporter URLs manually to Prometheus. Here's a summary of what I've provided:

## Summary of Changes

### 1. **Updated Prometheus Configuration** (`prometheus/prometheus.yml`)
- Added 12 different examples of manual exporter configurations
- Included examples for single exporters, multiple exporters, external exporters, file-based discovery, DNS discovery, custom metrics paths, authentication, relabeling, and filtering

### 2. **File-based Service Discovery** (`prometheus/exporters.yml`)
- Created an example file for dynamic exporter management
- Shows how to organize exporters by environment, service type, and datacenter

### 3. **Comprehensive Guide** (`EXPORTER_SETUP.md`)
- Complete documentation with examples for all scenarios
- Troubleshooting section with common issues and solutions
- Best practices and security considerations

## Key Ways to Add Exporters Manually:

### 1. **Basic Static Configuration**
```yaml
- job_name: 'my-exporter'
  static_configs:
    - targets: ['192.168.1.100:9100']
      labels:
        instance: 'my-server-01'
        environment: 'production'
```

### 2. **Multiple Exporters**
```yaml
- job_name: 'multiple-exporters'
  static_configs:
    - targets: 
      - '192.168.1.101:9100'
      - '192.168.1.102:9100'
      - '192.168.1.103:9100'
```

### 3. **File-based Discovery**
```yaml
- job_name: 'file-sd-exporters'
  file_sd_configs:
    - files: ['exporters.yml']
      refresh_interval: 5m
```

### 4. **External Exporters with Authentication**
```yaml
- job_name: 'external-exporters'
  scheme: https
  basic_auth:
    username: 'prometheus'
    password: 'your-password'
  static_configs:
    - targets: ['external-server.com:9100']
```

## Common Exporter Ports:
- **Node Exporter**: 9100
- **cAdvisor**: 8080
- **PostgreSQL Exporter**: 9187
- **Redis Exporter**: 9121
- **MySQL Exporter**: 9104
- **Blackbox Exporter**: 9115

## To Use This Setup:

1. **Copy the environment file**: `cp environment.example .env`
2. **Configure your settings** in `.env`
3. **Add your exporter URLs** to `prometheus/prometheus.yml`
4. **Deploy**: `./deploy.sh dev` (development) or `./deploy.sh prod` (production)

The configuration is now SSL-free with enhanced SMTP support (MailHog for development, external SMTP for production) and comprehensive manual exporter configuration examples!