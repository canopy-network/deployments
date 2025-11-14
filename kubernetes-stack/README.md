# Canopy Kubernetes Stack

This directory contains Kubernetes manifests for deploying the Canopy blockchain network with monitoring infrastructure using both traditional YAML manifests and Helm charts.

## Architecture

The stack is organized into two namespaces:
- `canopy`: Contains the Canopy blockchain nodes
- `monitoring`: Contains the monitoring infrastructure

### Components

#### Canopy Namespace
- **StatefulSet**: `canopy-node` - Scalable Canopy blockchain nodes
- **Service**: `canopy-node` - Internal service for node communication
- **PVCs**: Persistent storage for node data

#### Monitoring Namespace
- **Prometheus**: Metrics collection and alerting (Helm chart available)
- **Grafana**: Visualization and dashboards (Helm chart available)
- **Loki**: Log aggregation (Helm chart available)
- **HAProxy**: Load balancer and reverse proxy
- **Blackbox Exporter**: External monitoring
- **Node Exporter**: Node-level metrics
- **cAdvisor**: Container metrics

## Prerequisites

1. **Kubernetes Cluster**: 1.20+ with RBAC enabled
2. **Storage Class**: `standard` for persistent volumes (default for Minikube)
3. **Load Balancer**: For external access to HAProxy
4. **SSL Certificates**: For HTTPS termination (optional)
5. **Helm**: 3.0+ (for Helm chart deployment)
6. **Docker Hub Access**: For pulling the `nodefleet/canopy` image

## Docker Authentication

The Canopy nodes use the `nodefleet/canopy` Docker image, which may be a private repository. You need to set up Docker authentication before deployment.

### Option 1: Local Docker Login
```bash
# Login to Docker Hub
./docker-login.sh

# Or manually
docker login -u your-username -p your-password
```

### Option 2: Kubernetes Docker Registry Secret
```bash
# Create Kubernetes secrets for Docker authentication
./create-docker-secret.sh
```

### Option 3: Manual Secret Creation
```bash
# Create secret manually
kubectl create secret docker-registry docker-registry-secret \
  --namespace=canopy \
  --docker-server=nodefleet/canopy \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email

kubectl create secret docker-registry docker-registry-secret \
  --namespace=monitoring \
  --docker-server=nodefleet/canopy \
  --docker-username=your-username \
  --docker-password=your-password \
  --docker-email=your-email
```

## Quick Start

### Option 1: Helm Deployment (Recommended)
Use the provided Helm deployment script for easier management:
```bash
./helm-deploy.sh
```

### Option 2: Traditional YAML Deployment
Use the provided deployment script:
```bash
./deploy.sh
```

### Option 3: Manual Deployment

1. **Set up Docker authentication** (see above)

2. **Create namespaces**:
```bash
kubectl apply -f canopy-namespace.yaml
kubectl apply -f monitoring-namespace.yaml
```

3. **Create storage**:
```bash
kubectl apply -f canopy-pvcs.yaml
kubectl apply -f monitoring-pvcs.yaml
```

4. **Create ConfigMaps**:
```bash
kubectl apply -f prometheus-config.yaml
kubectl apply -f loki-config.yaml
kubectl apply -f blackbox-config.yaml
kubectl apply -f grafana-datasources.yaml
kubectl apply -f grafana-dashboards.yaml
kubectl apply -f grafana-alerting.yaml
kubectl apply -f haproxy-config.yaml
```

5. **Deploy monitoring stack**:
```bash
kubectl apply -f node-monitoring.yaml
kubectl apply -f monitoring-stack.yaml
kubectl apply -f haproxy.yaml
kubectl apply -f monitoring-services.yaml
```

6. **Deploy Canopy nodes**:
```bash
kubectl apply -f canopy-nodes.yaml
```

### Option 4: Deploy All at Once
```bash
kubectl apply -f *.yaml
```

## File Structure

### Root Directory (YAML Manifests)
All Kubernetes manifests are organized in the root directory:

#### Namespaces
- `canopy-namespace.yaml` - Canopy application namespace
- `monitoring-namespace.yaml` - Monitoring infrastructure namespace

#### Storage
- `canopy-pvcs.yaml` - Persistent volume claims for Canopy nodes
- `monitoring-pvcs.yaml` - Persistent volume claims for monitoring components

#### Configuration
- `prometheus-config.yaml` - Prometheus configuration
- `loki-config.yaml` - Loki log aggregation configuration
- `blackbox-config.yaml` - Blackbox exporter configuration
- `grafana-datasources.yaml` - Grafana datasources configuration
- `grafana-dashboards.yaml` - Grafana dashboards configuration
- `grafana-alerting.yaml` - Grafana alerting configuration
- `haproxy-config.yaml` - HAProxy load balancer configuration

#### Deployments
- `canopy-nodes.yaml` - Canopy blockchain nodes StatefulSet and Service
- `monitoring-stack.yaml` - Prometheus, Grafana, Loki, and Blackbox deployments
- `haproxy.yaml` - HAProxy deployment and service
- `node-monitoring.yaml` - Node exporter and cAdvisor DaemonSets
- `monitoring-services.yaml` - Services for monitoring components

#### Scripts
- `docker-login.sh` - Docker Hub login script
- `create-docker-secret.sh` - Kubernetes Docker registry secret creation
- `generate-docker-config.sh` - Generate base64 Docker config
- `deploy.sh` - Traditional YAML deployment
- `helm-deploy.sh` - Helm chart deployment
- `cleanup-monitoring.sh` - Cleanup existing monitoring resources
- `fix-helm-conflict.sh` - Quick fix for Helm conflicts

#### Secrets
- `secrets/docker-registry-secret.yaml` - Docker registry authentication
- `secrets/docker-registry-secret-template.yaml` - Template for Docker secrets

### Helm Charts Directory
- `helm-charts/prometheus/` - Prometheus Helm chart
- `helm-charts/loki/` - Loki Helm chart
- `helm-charts/grafana/` - Grafana Helm chart

## Helm Charts

### Prometheus Chart
```bash
# Install
helm install prometheus ./helm-charts/prometheus -n monitoring

# Upgrade
helm upgrade prometheus ./helm-charts/prometheus -n monitoring

# Uninstall
helm uninstall prometheus -n monitoring
```

### Loki Chart
```bash
# Install
helm install loki ./helm-charts/loki -n monitoring

# Upgrade
helm upgrade loki ./helm-charts/loki -n monitoring

# Uninstall
helm uninstall loki -n monitoring
```

### Grafana Chart
```bash
# Install
helm install grafana ./helm-charts/grafana -n monitoring

# Upgrade
helm upgrade grafana ./helm-charts/grafana -n monitoring

# Uninstall
helm uninstall grafana -n monitoring
```

### Customizing Helm Charts
Each Helm chart can be customized by modifying the `values.yaml` file or by passing values on the command line:

```bash
# Example: Customize Prometheus retention
helm install prometheus ./helm-charts/prometheus \
  --namespace monitoring \
  --set server.retention.time=400h \
  --set server.resources.limits.memory=4Gi
```

## Scaling

### Canopy Nodes
The Canopy StatefulSet is designed to scale dynamically up to 15 replicas. Each node gets its own configuration and can be accessed individually.

#### Quick Scaling (Recommended)
Use the provided scaling script:
```bash
# Scale to 5 nodes
./scale-canopy.sh 5

# Scale to 10 nodes
./scale-canopy.sh 10

# Scale to 15 nodes (maximum)
./scale-canopy.sh 15
```

#### Manual Scaling
You can also scale manually using kubectl:
```bash
# Scale the StatefulSet
kubectl scale statefulset canopy-node --replicas=10 -n canopy

# Generate individual services for each node
./scale-canopy.sh 10
```

#### Scaling Features
- **Dynamic Configuration**: Each node gets its own configuration automatically based on hostname
- **Individual Services**: Each node gets a dedicated service (node1, node2, etc.)
- **Load Balancing**: The main `canopy-node` service provides load balancing across all nodes
- **Headless Service**: Direct pod access via `canopy-node-headless` service
- **Auto-Discovery**: Nodes automatically discover each other using Kubernetes DNS
- **Smart RPC Routing**: First 3 nodes use peer-to-peer RPC, additional nodes connect to node1
- **Unique Network IDs**: Each node gets a unique networkID based on its position

#### Access Patterns
After scaling, you can access nodes in multiple ways:

**Individual Node Access:**
```bash
# Access specific nodes
kubectl port-forward service/node1 50001:50002 -n canopy  # Node 1 RPC
kubectl port-forward service/node5 50005:50002 -n canopy  # Node 5 RPC
```

**Load Balanced Access:**
```bash
# Access any available node
kubectl port-forward service/canopy-node 50002:50002 -n canopy
```

**Direct Pod Access:**
```bash
# Access specific pods directly
kubectl port-forward canopy-node-0 50002:50002 -n canopy
kubectl port-forward canopy-node-4 50002:50002 -n canopy
```

### Monitoring Components
Most monitoring components are designed to run as single instances. For high availability:
- Prometheus: Consider using Prometheus Operator
- Grafana: Can be scaled horizontally with shared storage
- HAProxy: Can be scaled with multiple replicas behind a load balancer

## Configuration

### Dynamic Configuration System
The Canopy nodes use a dynamic configuration system that automatically generates node-specific configurations based on the pod's hostname. Each node receives:

- **Unique RPC URLs**: Automatically configured based on node position
- **Dynamic External Addresses**: Based on node number (e.g., `tcp://node1.test.nodefleet.net`)
- **Smart Peer Discovery**: First 3 nodes use circular peer configuration, additional nodes connect to node1
- **Unique Network IDs**: Each node gets its own networkID (1, 2, 3, etc.)

#### Configuration Logic
- **Node 1**: Uses node2 for RPC, external address `tcp://node1.test.nodefleet.net`, networkID 1
- **Node 2**: Uses node3 for RPC, external address `tcp://node2.test.nodefleet.net`, networkID 2  
- **Node 3**: Uses node1 for RPC, external address `tcp://node3.test.nodefleet.net`, networkID 3
- **Node 4+**: Uses node1 for RPC, external address `tcp://nodeN.test.nodefleet.net`, networkID N

#### Testing Dynamic Configuration
Use the provided test script to verify dynamic configuration:
```bash
./test-dynamic-config.sh
```

This will show the actual configuration values for each running node and validate they match the expected patterns.

### Environment Variables
The Canopy nodes use the following environment variables:
- `EXPLORER_BASE_PATH`: Base path for explorer (default: "/")
- `WALLET_BASE_PATH`: Base path for wallet (default: "/")
- `BUILD_PATH`: Build path (default: "cmd/cli")
- `BIN_PATH`: Binary path (default: "/usr/local/bin")
- `BRANCH`: Git branch (default: "no-sync-issue")

### Storage
Each Canopy node requires 100Gi of persistent storage. The storage class `standard` is used by default (compatible with Minikube).

### Networking
- Canopy nodes communicate on ports 50000-50003 and 9001
- HAProxy exposes ports 80, 443, and 8404 (stats)
- Monitoring services use standard ports (9090, 3000, 3100, etc.)

## Monitoring

### Access Points
- **Grafana**: `http://monitoring.canopy.nodefleet.net` (via HAProxy)
- **Prometheus**: Internal service at `prometheus.monitoring.svc.cluster.local:9090`
- **HAProxy Stats**: `http://haproxy.monitoring.svc.cluster.local:8404/stats`

### Alerts
The stack includes pre-configured alerts for:
- Disk usage above 80%
- Node availability
- Service health checks

### Dashboards
Grafana comes with pre-configured dashboards for:
- Canopy node metrics
- Infrastructure monitoring
- Container metrics

## Troubleshooting

### Docker Image Pull Issues
If you encounter image pull errors:
```bash
# Check if Docker secret exists
kubectl get secret docker-registry-secret -n canopy
kubectl get secret docker-registry-secret -n monitoring

# Recreate Docker secret if needed
./create-docker-secret.sh

# Check pod events for image pull errors
kubectl describe pod canopy-node-0 -n canopy
```

### Helm Installation Conflicts
If you encounter errors like "ConfigMap exists and cannot be imported into the current release", it means there are existing resources from previous deployments that conflict with Helm.

#### Quick Fix
```bash
# Run the quick fix script
./fix-helm-conflict.sh

# Then install Helm charts
helm install prometheus ./helm-charts/prometheus -n monitoring
helm install loki ./helm-charts/loki -n monitoring
helm install grafana ./helm-charts/grafana -n monitoring
```

#### Full Cleanup
```bash
# Run the cleanup script
./cleanup-monitoring.sh

# Then run the Helm deployment with cleanup
./helm-deploy.sh --cleanup
```

#### Manual Cleanup
```bash
# Delete conflicting resources manually
kubectl delete configmap prometheus-config -n monitoring --ignore-not-found=true
kubectl delete configmap loki-config -n monitoring --ignore-not-found=true
kubectl delete configmap grafana-datasources -n monitoring --ignore-not-found=true
kubectl delete configmap grafana-dashboards -n monitoring --ignore-not-found=true
kubectl delete configmap grafana-alerting -n monitoring --ignore-not-found=true
kubectl delete deployment prometheus grafana loki -n monitoring --ignore-not-found=true
kubectl delete service prometheus grafana loki -n monitoring --ignore-not-found=true
```

### Storage Class Issues
If you encounter storage class errors:
```bash
# Check available storage classes
kubectl get storageclass

# Update PVCs to use available storage class
# The manifests are configured for 'standard' storage class (Minikube default)
```

### Check Pod Status
```bash
kubectl get pods -n canopy
kubectl get pods -n monitoring
```

### View Logs
```bash
# Canopy node logs
kubectl logs -f canopy-node-0 -n canopy

# Monitoring logs
kubectl logs -f deployment/grafana -n monitoring
kubectl logs -f deployment/prometheus -n monitoring
```

### Check Services
```bash
kubectl get svc -n canopy
kubectl get svc -n monitoring
```

### Check Helm Releases
```bash
helm list -n monitoring
helm status prometheus -n monitoring
helm status grafana -n monitoring
helm status loki -n monitoring
```

### Persistent Volume Issues
```bash
kubectl get pvc -n canopy
kubectl get pvc -n monitoring
kubectl describe pvc <pvc-name> -n <namespace>
```

## Security Considerations

1. **Network Policies**: Consider implementing network policies to restrict pod-to-pod communication
2. **RBAC**: Ensure proper RBAC configuration for service accounts
3. **Secrets**: Store sensitive data in Kubernetes secrets
4. **SSL/TLS**: Configure proper SSL certificates for external access
5. **Authentication**: Implement proper authentication for Grafana and HAProxy
6. **Docker Credentials**: Store Docker registry credentials securely in Kubernetes secrets

## Backup and Recovery

### Data Backup
- Canopy node data is stored in persistent volumes
- Regular backups of PVC data are recommended
- Consider using Velero for cluster-wide backup

### Configuration Backup
- ConfigMaps and Secrets should be version controlled
- Consider using GitOps tools like ArgoCD or Flux
- Helm releases can be backed up using `helm get values`

## Performance Tuning

### Resource Limits
The manifests include reasonable resource limits. Adjust based on your cluster capacity:
- Canopy nodes: 4Gi memory, 2 CPU cores
- Prometheus: 2Gi memory, 1 CPU core
- Grafana: 1Gi memory, 500m CPU

### Storage Performance
- Use SSD storage for better I/O performance
- Consider using local storage for Canopy nodes
- Monitor storage metrics for bottlenecks

## Maintenance

### Updates
1. Update container images in deployments
2. Test in staging environment
3. Roll out updates using rolling updates
4. Monitor for issues during updates

### Helm Chart Updates
```bash
# Update Helm charts
helm upgrade prometheus ./helm-charts/prometheus -n monitoring
helm upgrade grafana ./helm-charts/grafana -n monitoring
helm upgrade loki ./helm-charts/loki -n monitoring
```

### Scaling Operations
1. Scale up during high load periods
2. Scale down during low usage
3. Monitor resource usage and adjust limits accordingly

## Support

For issues and questions:
1. Check the logs for error messages
2. Verify network connectivity between services
3. Ensure storage is properly configured
4. Check resource limits and requests
5. Review Helm chart values and configurations
6. Verify Docker authentication is properly configured 
