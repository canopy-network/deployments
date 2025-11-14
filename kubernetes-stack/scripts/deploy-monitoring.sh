#!/bin/bash

# Monitoring Stack Deployment Script
set -e

echo "🚀 Deploying Monitoring Stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Connected to Kubernetes cluster: $(kubectl config current-context)"

# Create monitoring namespace
print_status "Creating monitoring namespace..."
kubectl apply -f ../monitoring/monitoring-namespace.yaml
print_status "Monitoring namespace created successfully"

# Create monitoring storage
print_status "Creating monitoring persistent volume claims..."
kubectl apply -f ../monitoring/monitoring-pvcs.yaml
print_status "Monitoring PVCs created successfully"

# Create monitoring ConfigMaps
print_status "Creating monitoring ConfigMaps..."
kubectl apply -f ../monitoring/prometheus-config.yaml
kubectl apply -f ../monitoring/loki-config.yaml
kubectl apply -f ../monitoring/blackbox-config.yaml
kubectl apply -f ../monitoring/grafana-datasources.yaml
kubectl apply -f ../monitoring/grafana-dashboards.yaml
kubectl apply -f ../monitoring/grafana-alerting.yaml
kubectl apply -f ../monitoring/haproxy-config.yaml
print_status "Monitoring ConfigMaps created successfully"

# Deploy monitoring stack with Helm
print_status "Deploying monitoring stack with Helm..."

# Deploy Prometheus
print_status "Installing Prometheus..."
helm install prometheus ../helm-charts/prometheus \
  --namespace monitoring \
  --create-namespace

# Deploy Loki
print_status "Installing Loki..."
helm install loki ../helm-charts/loki \
  --namespace monitoring \
  --create-namespace

# Deploy Grafana
print_status "Installing Grafana..."
helm install grafana ../helm-charts/grafana \
  --namespace monitoring \
  --create-namespace

# Deploy remaining monitoring components
print_status "Deploying remaining monitoring components..."
kubectl apply -f ../monitoring/blackbox-config.yaml
kubectl apply -f ../monitoring/haproxy-config.yaml
kubectl apply -f ../monitoring/node-monitoring.yaml
kubectl apply -f ../monitoring/haproxy.yaml
kubectl apply -f ../monitoring/monitoring-services.yaml

print_status "Monitoring stack deployed successfully!"

# Wait for pods to be ready
print_status "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=haproxy -n monitoring --timeout=300s

print_status "All monitoring pods are ready!"

# Display status
echo ""
print_status "Monitoring deployment completed successfully!"
echo ""
print_status "Current monitoring status:"
echo "================================"

echo ""
print_status "Monitoring namespace:"
kubectl get pods -n monitoring

echo ""
print_status "Helm releases:"
helm list -n monitoring

echo ""
print_status "Monitoring services:"
kubectl get svc -n monitoring

echo ""
print_status "Access Information:"
echo "========================"
echo "Grafana: http://monitoring.canopy.nodefleet.net (via HAProxy)"
echo "HAProxy Stats: http://haproxy.monitoring.svc.cluster.local:8404/stats"
echo "Prometheus: Internal service at prometheus.monitoring.svc.cluster.local:9090"
echo "Loki: Internal service at loki.monitoring.svc.cluster.local:3100"

echo ""
print_warning "Note: You may need to configure your DNS or ingress to access external services"
print_warning "SSL certificates should be configured for production use"

echo ""
print_status "To check monitoring logs:"
echo "kubectl logs -f deployment/grafana -n monitoring"
echo "kubectl logs -f deployment/prometheus -n monitoring"
echo "kubectl logs -f deployment/loki -n monitoring"

echo ""
print_status "To upgrade monitoring Helm releases:"
echo "helm upgrade prometheus ../helm-charts/prometheus -n monitoring"
echo "helm upgrade grafana ../helm-charts/grafana -n monitoring"
echo "helm upgrade loki ../helm-charts/loki -n monitoring"

echo ""
print_status "To clean up monitoring:"
echo "./scripts/cleanup-monitoring.sh" 