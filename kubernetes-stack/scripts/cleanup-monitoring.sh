#!/bin/bash

# Cleanup Monitoring Stack Script
set -e

echo "🧹 Cleaning up monitoring stack..."

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

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    print_status "Deleting $resource_type $resource_name in namespace $namespace"
    kubectl delete $resource_type $resource_name -n $namespace --ignore-not-found=true
}

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_warning "helm is not installed or not in PATH - Helm releases will not be cleaned up"
    HELM_AVAILABLE=false
else
    HELM_AVAILABLE=true
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Connected to Kubernetes cluster: $(kubectl config current-context)"

# Confirm deletion
print_warning "This will delete all monitoring resources in the monitoring namespace."
print_warning "This includes Helm releases (grafana, loki, prometheus) and traditional Kubernetes resources."
read -p "Are you sure you want to continue? (y/N): " confirm

if [[ ! $confirm =~ ^[Yy]$ ]]; then
    print_status "Cleanup cancelled."
    exit 0
fi

# Uninstall Helm releases first
if [[ "$HELM_AVAILABLE" == "true" ]]; then
    print_status "Uninstalling Helm releases..."
    
    # Check if releases exist before trying to uninstall
    if helm list -n monitoring | grep -q "grafana"; then
        print_status "Uninstalling Grafana Helm release..."
        helm uninstall grafana -n monitoring
    else
        print_status "Grafana Helm release not found"
    fi
    
    if helm list -n monitoring | grep -q "loki"; then
        print_status "Uninstalling Loki Helm release..."
        helm uninstall loki -n monitoring
    else
        print_status "Loki Helm release not found"
    fi
    
    if helm list -n monitoring | grep -q "prometheus"; then
        print_status "Uninstalling Prometheus Helm release..."
        helm uninstall prometheus -n monitoring
    else
        print_status "Prometheus Helm release not found"
    fi
    
    print_status "Helm releases uninstalled successfully"
    
    # Wait a moment for Helm to clean up resources
    print_status "Waiting for Helm cleanup to complete..."
    sleep 5
else
    print_warning "Skipping Helm uninstall (helm not available)"
fi

# Delete remaining deployments (some may have been cleaned up by Helm)
print_status "Deleting remaining deployments..."
safe_delete deployment prometheus monitoring
safe_delete deployment grafana monitoring
safe_delete deployment loki monitoring
safe_delete deployment blackbox-exporter monitoring
safe_delete deployment haproxy monitoring

# Delete Canopy resources
print_status "Deleting Canopy resources..."
safe_delete statefulset canopy-node canopy
safe_delete service canopy-node canopy
safe_delete service canopy-node-headless canopy
safe_delete service node1 canopy
safe_delete service node2 canopy
safe_delete service node3 canopy

# Delete any additional scaled node services (node4, node5, etc.)
print_status "Deleting scaled node services..."
for i in $(seq 1 15); do
    if kubectl get service node$i -n canopy &> /dev/null; then
        print_status "Deleting service node$i..."
        safe_delete service node$i canopy
    fi
done

# Clean up any generated service files
print_status "Cleaning up generated service files..."
if [ -f "../canopy-services-scaled.yaml" ]; then
    print_status "Removing generated service file: canopy-services-scaled.yaml"
    rm -f ../canopy-services-scaled.yaml
fi

# Delete services
print_status "Deleting services..."
safe_delete service prometheus monitoring
safe_delete service grafana monitoring
safe_delete service loki monitoring
safe_delete service blackbox-exporter monitoring
safe_delete service haproxy monitoring

# Delete ConfigMaps
print_status "Deleting ConfigMaps..."
safe_delete configmap prometheus-config monitoring
safe_delete configmap loki-config monitoring
safe_delete configmap blackbox-config monitoring
safe_delete configmap grafana-datasources monitoring
safe_delete configmap grafana-dashboards monitoring
safe_delete configmap grafana-alerting monitoring
safe_delete configmap grafana-provisioning monitoring
safe_delete configmap haproxy-config monitoring

# Delete Canopy ConfigMaps
print_status "Deleting Canopy ConfigMaps..."
safe_delete configmap canopy-genesis canopy
safe_delete configmap canopy-config-template canopy
safe_delete configmap node1-config canopy
safe_delete configmap node2-config canopy
safe_delete configmap all-node-configs canopy

# Delete PVCs
print_status "Deleting PVCs..."
safe_delete pvc prometheus-data monitoring
safe_delete pvc grafana-data monitoring
safe_delete pvc loki-data monitoring

# Delete Canopy PVCs (created by StatefulSet volumeClaimTemplates)
print_status "Deleting Canopy PVCs..."
for i in $(seq 0 14); do
    if kubectl get pvc canopy-data-canopy-node-$i -n canopy &> /dev/null; then
        print_status "Deleting PVC canopy-data-canopy-node-$i..."
        safe_delete pvc canopy-data-canopy-node-$i canopy
    fi
done

# Delete DaemonSets
print_status "Deleting DaemonSets..."
safe_delete daemonset node-exporter monitoring
safe_delete daemonset cadvisor monitoring

# Delete ServiceAccounts
print_status "Deleting ServiceAccounts..."
safe_delete serviceaccount prometheus monitoring
safe_delete serviceaccount grafana monitoring
safe_delete serviceaccount loki monitoring
safe_delete serviceaccount blackbox-exporter monitoring
safe_delete serviceaccount haproxy monitoring

# Delete any remaining Helm-related resources
print_status "Cleaning up any remaining Helm-related resources..."
kubectl delete all -l app.kubernetes.io/instance=grafana -n monitoring --ignore-not-found=true
kubectl delete all -l app.kubernetes.io/instance=loki -n monitoring --ignore-not-found=true
kubectl delete all -l app.kubernetes.io/instance=prometheus -n monitoring --ignore-not-found=true

# Delete namespaces (optional - uncomment if you want to delete the entire namespace)
# print_status "Deleting monitoring namespace..."
# kubectl delete namespace monitoring --ignore-not-found=true

print_status "Cleanup completed successfully!"

echo ""
print_status "Remaining resources in monitoring namespace:"
kubectl get all -n monitoring 2>/dev/null || print_status "No resources found in monitoring namespace"

echo ""
print_status "Remaining resources in canopy namespace:"
kubectl get all -n canopy 2>/dev/null || print_status "No resources found in canopy namespace"

if [[ "$HELM_AVAILABLE" == "true" ]]; then
    echo ""
    print_status "Remaining Helm releases in monitoring namespace:"
    helm list -n monitoring 2>/dev/null || print_status "No Helm releases found in monitoring namespace"
fi

echo ""
print_status "Cleaned up resources include:"
echo "  - All StatefulSets and Deployments"
echo "  - All Services (including scaled node services node1-node15)"
echo "  - All ConfigMaps"
echo "  - All PVCs (including scaled canopy-data PVCs)"
echo "  - All DaemonSets"
echo "  - All ServiceAccounts"
echo "  - Generated service files (canopy-services-scaled.yaml)"
echo "  - Helm releases (if available)"

echo ""
print_status "To redeploy the monitoring stack:"
echo "./scripts/deploy.sh"
echo ""
print_status "Or to deploy with Helm:"
echo "./scripts/helm-deploy.sh"
echo ""
print_status "To redeploy with updated scalable configuration:"
echo "./scripts/update-canopy-config.sh" 