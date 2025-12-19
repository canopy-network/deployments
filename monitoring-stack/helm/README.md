# Monitoring Stack Helm Charts

This directory contains Helm charts for deploying the monitoring stack components (Grafana, Prometheus, Loki, and Blackbox Exporter) to Kubernetes. These charts are based on the configuration from the `monitoring-stack` docker-compose setup.

## Prerequisites

- Kubernetes cluster (1.19+)
- Helm 3.x installed
- kubectl configured to access your cluster
- A namespace for monitoring (default: `monitoring`)

## Charts

- **prometheus**: Prometheus metrics collection and storage
- **grafana**: Grafana visualization and dashboards
- **loki**: Loki log aggregation
- **blackbox**: Blackbox exporter for endpoint monitoring

## Installation

### 1. Create Namespace

```bash
kubectl create namespace monitoring
```

### 2. Install Prometheus

```bash
helm install prometheus ./prometheus \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class>
```

### 3. Install Loki

```bash
helm install loki ./loki \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class>
```

### 4. Install Blackbox Exporter

```bash
helm install blackbox ./blackbox \
  --namespace monitoring
```

### 5. Install Grafana

```bash
helm install grafana ./grafana \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class> \
  --set datasources.config.datasources[0].url=http://prometheus:9090 \
  --set datasources.config.datasources[1].url=http://loki:3100
```

## Install All Components at Once

You can install all components in a single command sequence:

```bash
# Create namespace
kubectl create namespace monitoring

# Install Prometheus
helm install prometheus ./prometheus \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class>

# Install Loki
helm install loki ./loki \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class>

# Install Blackbox Exporter
helm install blackbox ./blackbox \
  --namespace monitoring

# Install Grafana
helm install grafana ./grafana \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class> \
  --set datasources.config.datasources[0].url=http://prometheus:9090 \
  --set datasources.config.datasources[1].url=http://loki:3100
```

## Configuration

### Storage Classes

Replace `<your-storage-class>` with your Kubernetes storage class name. If you're using a default storage class, you can remove the `--set server.persistentVolume.storageClass` parameter.

### Customizing Values

Each chart has a `values.yaml` file that can be customized. You can override values using:

1. **Command line flags:**
   ```bash
   helm install prometheus ./prometheus \
     --namespace monitoring \
     --set server.resources.limits.memory=4Gi
   ```

2. **Custom values file:**
   ```bash
   helm install prometheus ./prometheus \
     --namespace monitoring \
     -f custom-values.yaml
   ```

## Service URLs

After installation, services will be available at:

- **Prometheus**: `http://prometheus.monitoring.svc.cluster.local:9090`
- **Grafana**: `http://grafana.monitoring.svc.cluster.local:3000`
- **Loki**: `http://loki.monitoring.svc.cluster.local:3100`
- **Blackbox**: `http://blackbox.monitoring.svc.cluster.local:9115`

## Accessing Services

### Port Forwarding

To access services from your local machine:

```bash
# Prometheus
kubectl port-forward -n monitoring svc/prometheus 9090:9090

# Grafana
kubectl port-forward -n monitoring svc/grafana 3000:3000

# Loki
kubectl port-forward -n monitoring svc/loki 3100:3100

# Blackbox
kubectl port-forward -n monitoring svc/blackbox 9115:9115
```

### Ingress (Optional)

You can configure Ingress for external access by enabling it in the values files or using Helm overrides.

## Upgrading

To upgrade a release:

```bash
helm upgrade prometheus ./prometheus \
  --namespace monitoring \
  --set server.persistentVolume.storageClass=<your-storage-class>
```

## Uninstalling

To uninstall a release:

```bash
helm uninstall prometheus --namespace monitoring
helm uninstall loki --namespace monitoring
helm uninstall blackbox --namespace monitoring
helm uninstall grafana --namespace monitoring
```

## Configuration Details

### Prometheus

- **Image**: `prom/prometheus:v3.5.0`
- **Port**: 9090
- **Storage**: 50Gi persistent volume (configurable)
- **Scrape Configs**: Configured for cadvisor, node-exporter, traefik, blackbox, canopy nodes, and blackbox probes

### Grafana

- **Image**: `grafana/grafana:12.2.0-16557133545`
- **Port**: 3000
- **Storage**: 10Gi persistent volume (configurable)
- **Default Credentials**: admin/admin (change in production!)
- **Datasources**: Pre-configured for Prometheus and Loki
- **Dashboards**: Provisioned from ConfigMaps (add dashboard JSON files to values.yaml)

### Loki

- **Image**: `grafana/loki:3.4.4`
- **Port**: 3100 (HTTP), 9096 (gRPC)
- **Storage**: 100Gi persistent volume (configurable)
- **Auth**: Disabled (for development)
- **Storage Backend**: Filesystem

### Blackbox Exporter

- **Image**: `prom/blackbox-exporter:v0.27.0`
- **Port**: 9115
- **Modules**: Configured with http_2xx, http_200, check_block_2xx, and check_canopy_block_2xx modules

## Notes

- All charts use `runAsUser: 0` (root) to match the docker-compose configuration. For production, consider using non-root users.
- Persistent volumes are enabled by default. Ensure your cluster has a storage class configured.
- Service names match the docker-compose service names for compatibility.
- Grafana dashboards need to be added to the `values.yaml` file under `dashboards.files` section if you want to include them in the deployment.

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n monitoring
```

### View Logs

```bash
kubectl logs -n monitoring <pod-name>
```

### Describe Pod

```bash
kubectl describe pod -n monitoring <pod-name>
```

### Check Services

```bash
kubectl get svc -n monitoring
```

### Check Persistent Volumes

```bash
kubectl get pvc -n monitoring
```


