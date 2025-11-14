#!/bin/bash

# Setup Storage Class for Vanilla Kubernetes Production Environment
set -e

echo "🗄️  Setting up vanilla Kubernetes storage with manual PVs..."

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

# Get node names
print_status "Detecting cluster nodes..."
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
NODE_ARRAY=($NODES)
FIRST_NODE=${NODE_ARRAY[0]}

print_status "Available nodes: $NODES"
print_status "Using node '$FIRST_NODE' for storage"

# Update the storage-class.yaml with the correct node name
print_status "Updating storage class configuration with node name..."
sed -i "s/- node1  # Replace with your actual node name/- $FIRST_NODE/g" kubernetes-stack/storage-class.yaml

# Create directories on the node (this requires SSH access or running on the node)
print_status "Creating storage directories..."
print_warning "You need to create the following directories on node '$FIRST_NODE':"
echo ""
echo "sudo mkdir -p /data/canopy/node0"
echo "sudo mkdir -p /data/canopy/node1" 
echo "sudo mkdir -p /data/canopy/node2"
echo "sudo mkdir -p /data/monitoring/prometheus"
echo "sudo mkdir -p /data/monitoring/grafana"
echo "sudo mkdir -p /data/monitoring/loki"
echo ""
echo "sudo chmod 755 /data/canopy/node*"
echo "sudo chmod 755 /data/monitoring/*"
echo ""

# Ask if directories are created
read -p "Have you created the directories on node '$FIRST_NODE'? (y/N): " dirs_created

if [[ ! $dirs_created =~ ^[Yy]$ ]]; then
    print_error "Please create the directories first, then run this script again."
    exit 1
fi

# Apply the storage class and PVs
print_status "Applying storage class and persistent volumes..."
kubectl apply -f kubernetes-stack/storage-class.yaml

# Verify storage class
print_status "Verifying storage class..."
kubectl get storageclass standard

# Verify PVs
print_status "Verifying persistent volumes..."
kubectl get pv

print_status "✅ Vanilla Kubernetes storage setup completed!"

echo ""
print_status "Storage setup summary:"
echo "  - Storage class: standard (kubernetes.io/no-provisioner)"
echo "  - PVs created for canopy nodes (100Gi each)"
echo "  - PVs created for monitoring components"
echo "  - Storage location: /data/ on node '$FIRST_NODE'"

echo ""
print_status "Your PVCs should now bind successfully!"
echo ""
print_status "To deploy your stack:"
echo "./helm-deploy.sh"
echo ""
print_status "To check PVC status:"
echo "kubectl get pvc -A" 