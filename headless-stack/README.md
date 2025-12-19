# Canopy Headless Monitoring Stack

This directory contains the configuration and deployment scripts for a headless Canopy monitoring stack that uses Prometheus federation to send metrics to a central Prometheus instance.

## Overview

The headless monitoring stack includes:
- Canopy nodes (node1 and node2)
- Prometheus (configured for federation)
- Loki (log aggregation)
- Node Exporter (host metrics)
- cAdvisor (container metrics)
- Blackbox Exporter (endpoint monitoring)

**Note**: This configuration does NOT include:
- Grafana (UI removed for headless operation)
- Traefik (load balancer removed)
- Web interfaces (all UI components removed)

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Canopy Node   │    │   Canopy Node   │    │  Central        │
│   (Prometheus   │    │   (Prometheus   │    │  Prometheus     │
│   Federation)   │    │   Federation)   │    │  (Collector)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
                    ┌─────────────┴─────────────┐
                    │      Federation           │
                    │      Endpoints            │
                    └───────────────────────────┘
```

## Files

- `docker-compose.yaml` - Headless Docker Compose configuration
- `monitoring/prometheus/prometheus.headless.yml` - Prometheus configuration for federation
- `canopy-headless-deploy.yml` - Ansible playbook for deployment
- `inventory.yml` - Example Ansible inventory
- `headless.env.j2` - Environment template
- `prometheus.headless.yml.j2` - Prometheus configuration template
- `canopy-monitoring.service.j2` - Systemd service template

## Deployment

### Prerequisites

1. Ansible installed on your control machine
2. SSH access to target nodes
3. Central Prometheus instance running

### Quick Start

1. **Update inventory**:
   ```bash
   # Edit inventory.yml with your node details
   vim inventory.yml
   ```

2. **Deploy to nodes**:
   ```bash
   # Deploy to all nodes
   ansible-playbook -i inventory.yml canopy-headless-deploy.yml

   # Deploy to specific node
   ansible-playbook -i inventory.yml canopy-headless-deploy.yml --limit canopy-node-1
   ```

3. **Verify deployment**:
   ```bash
   # Check Prometheus federation endpoint
   curl http://NODE_IP:9090/federate?match[]={job=~"canopy.*"}
   ```

### Ansible Command Examples

#### Basic Deployment
```bash
# Deploy to all nodes in inventory
ansible-playbook -i inventory.yml canopy-headless-deploy.yml

# Deploy with verbose output
ansible-playbook -i inventory.yml canopy-headless-deploy.yml -v

# Deploy with extra verbose output (debugging)
ansible-playbook -i inventory.yml canopy-headless-deploy.yml -vvv
```

#### Targeted Deployment
```bash
# Deploy to specific node
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --limit canopy-node-1

# Deploy to multiple specific nodes
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --limit "canopy-node-1,canopy-node-2"

# Deploy to nodes matching a pattern
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --limit "canopy-node*"
```

#### Dry Run and Testing
```bash
# Check what would be changed (dry run)
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --check

# Dry run with verbose output
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --check -v

# Test connectivity to nodes
ansible -i inventory.yml all -m ping
```

#### Custom Variables
```bash
# Override variables at runtime
ansible-playbook -i inventory.yml canopy-headless-deploy.yml \
  -e "canopy_user=ubuntu" \
  -e "canopy_home=/opt/canopy" \
  -e "central_prometheus_url=http://prometheus.example.com:9090"

# Use external variables file
ansible-playbook -i inventory.yml canopy-headless-deploy.yml \
  -e "@custom-vars.yml"
```

#### Troubleshooting Commands
```bash
# Check Ansible connectivity
ansible -i inventory.yml all -m ping -v

# List all hosts in inventory
ansible -i inventory.yml all --list-hosts

# Test specific task
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --tags "docker-install"

# Run only specific tasks
ansible-playbook -i inventory.yml canopy-headless-deploy.yml --tags "setup,deploy"
```

#### Advanced Examples
```bash
# Deploy with custom SSH key
ansible-playbook -i inventory.yml canopy-headless-deploy.yml \
  --private-key ~/.ssh/custom_key

# Deploy with custom user
ansible-playbook -i inventory.yml canopy-headless-deploy.yml \
  -u custom_user

# Deploy with sudo privileges
ansible-playbook -i inventory.yml canopy-headless-deploy.yml \
  --become --become-user root

# Deploy with parallel execution (5 nodes at once)
ansible-playbook -i inventory.yml canopy-headless-deploy.yml \
  --forks 5
```

### Manual Deployment

If you prefer manual deployment:

1. **Copy files to node**:
   ```bash
   scp -r headless-stack/ user@node:/home/user/canopy/
   ```

2. **Create environment file**:
   ```bash
   # On the node
   cd /home/user/canopy/headless-stack
   cp headless.env.j2 .env
   # Edit .env with your configuration
   ```

3. **Start services**:
   ```bash
   docker-compose -f docker-compose.yaml up -d
   ```

## Central Prometheus Configuration

Add this to your central Prometheus configuration:

```yaml
scrape_configs:
  - job_name: 'federate-canopy-node-1'
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~"canopy.*"}'
        - '{job=~"node-exporter"}'
        - '{job=~"cadvisor"}'
    static_configs:
      - targets: ['NODE1_IP:9090']

  - job_name: 'federate-canopy-node-2'
    honor_labels: true
    metrics_path: '/federate'
    params:
      'match[]':
        - '{job=~"canopy.*"}'
        - '{job=~"node-exporter"}'
        - '{job=~"cadvisor"}'
    static_configs:
      - targets: ['NODE2_IP:9090']
```

## Federation Endpoints

Each node exposes a federation endpoint at:
- `http://NODE_IP:9090/federate`

Available metrics:
- `{job=~"canopy.*"}` - Canopy node metrics
- `{job=~"node-exporter"}` - Host metrics
- `{job=~"cadvisor"}` - Container metrics
- `{job=~"blackbox"}` - Endpoint monitoring
- `{job=~"loki"}` - Loki metrics

## Monitoring

### Service Status
```bash
# Check service status
systemctl status canopy-headless-monitoring

# View logs
journalctl -u canopy-headless-monitoring -f

# Check containers
docker-compose -f docker-compose.yaml ps
```

### Metrics Verification
```bash
# Check Prometheus targets
curl http://NODE_IP:9090/api/v1/targets

# Check federation endpoint
curl http://NODE_IP:9090/federate?match[]={job=~"canopy.*"}
```

## Configuration

### Environment Variables

- `NODE_NAME` - Node identifier
- `CENTRAL_PROMETHEUS_URL` - Central Prometheus URL
- `PROMETHEUS_RETENTION_DAYS` - Local retention period
- `LOKI_RETENTION_HOURS` - Log retention period

### Resource Limits

- Node containers: 4GB RAM, 2 CPU cores
- Prometheus: 2GB RAM, 1 CPU core
- Other services: Minimal resources

## Troubleshooting

### Common Issues

1. **Federation not working**:
   - Check firewall rules (port 9090)
   - Verify network connectivity
   - Check Prometheus logs

2. **Services not starting**:
   - Check Docker service status
   - Verify disk space
   - Check resource limits

3. **Metrics missing**:
   - Verify Canopy nodes are running
   - Check Prometheus targets
   - Review scrape intervals

### Logs

```bash
# Prometheus logs
docker logs prometheus

# Canopy node logs
docker logs node1
docker logs node2

# System service logs
journalctl -u canopy-headless-monitoring -f
```

## Security Considerations

1. **Network Security**:
   - Restrict access to federation endpoints
   - Use VPN for inter-node communication
   - Implement proper firewall rules

2. **Authentication**:
   - Consider adding authentication to federation endpoints
   - Use TLS for metric transmission
   - Implement proper access controls

3. **Data Protection**:
   - Encrypt sensitive configuration
   - Implement proper backup strategies
   - Monitor access logs

## Performance Tuning

1. **Prometheus**:
   - Adjust scrape intervals based on load
   - Tune retention periods
   - Monitor memory usage

2. **Loki**:
   - Configure appropriate retention
   - Tune chunk sizes
   - Monitor storage usage

3. **System Resources**:
   - Monitor CPU and memory usage
   - Adjust container limits as needed
   - Consider SSD storage for better performance 