#!/bin/bash

# Canopy Kubernetes Stack Deployment Script
set -e

echo "🚀 Deploying Canopy Kubernetes Stack..."

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

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Connected to Kubernetes cluster: $(kubectl config current-context)"

# Create namespaces
print_status "Creating namespaces..."
kubectl apply -f ../canopy/canopy-namespace.yaml
kubectl apply -f ../monitoring/monitoring-namespace.yaml
print_status "Namespaces created successfully"

# Create storage
print_status "Creating persistent volume claims..."
kubectl apply -f ../canopy/canopy-pvcs.yaml
kubectl apply -f ../monitoring/monitoring-pvcs.yaml
print_status "PVCs created successfully"

# Create ConfigMaps
print_status "Creating ConfigMaps..."
kubectl apply -f ../monitoring/prometheus-config.yaml
kubectl apply -f ../monitoring/loki-config.yaml
kubectl apply -f ../monitoring/blackbox-config.yaml
kubectl apply -f ../monitoring/grafana-datasources.yaml
kubectl apply -f ../monitoring/grafana-dashboards.yaml
kubectl apply -f ../monitoring/grafana-alerting.yaml
kubectl apply -f ../monitoring/haproxy-config.yaml
kubectl apply -f ../canopy/canopy-configmaps.yaml
print_status "ConfigMaps created successfully"

# Verify canopy ConfigMaps are created
print_status "Verifying canopy ConfigMaps..."
kubectl get configmap canopy-genesis -n canopy
kubectl get configmap all-node-configs -n canopy
print_status "Canopy ConfigMaps verified successfully"

# Deploy monitoring stack
print_status "Deploying monitoring stack..."
kubectl apply -f ../monitoring/node-monitoring.yaml
kubectl apply -f ../monitoring/monitoring-stack.yaml
kubectl apply -f ../monitoring/haproxy.yaml
kubectl apply -f ../monitoring/monitoring-services.yaml
print_status "Monitoring stack deployed successfully"

# Deploy Canopy nodes
print_status "Deploying Canopy nodes..."
kubectl apply -f ../canopy/canopy-nodes.yaml
print_status "Canopy nodes deployed successfully"

# Wait for pods to be ready
print_status "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=haproxy -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=canopy-node -n canopy --timeout=600s

print_status "All pods are ready!"

# Display status
echo ""
print_status "Deployment completed successfully!"
echo ""
print_status "Current status:"
echo "=================="

echo ""
print_status "Canopy namespace:"
kubectl get pods -n canopy

echo ""
print_status "Monitoring namespace:"
kubectl get pods -n monitoring

echo ""
print_status "Services:"
kubectl get svc -n canopy
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
print_status "To check logs:"
echo "kubectl logs -f canopy-node-0 -n canopy"
echo "kubectl logs -f deployment/grafana -n monitoring"
echo "kubectl logs -f deployment/prometheus -n monitoring"

echo ""
print_status "To scale Canopy nodes:"
echo "kubectl scale statefulset canopy-node --replicas=5 -n canopy"

echo ""
print_status "To clean up and redeploy:"
echo "./scripts/cleanup-monitoring.sh && ./scripts/deploy.sh" 