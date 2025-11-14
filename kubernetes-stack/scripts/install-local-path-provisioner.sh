#!/bin/bash

# Install Local Path Provisioner for kubeadm clusters
set -e

echo "🗄️  Installing Local Path Provisioner for kubeadm clusters..."

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

# Check if local-path-provisioner is already installed
if kubectl get deployment local-path-provisioner -n local-path-storage &> /dev/null; then
    print_warning "Local Path Provisioner already installed"
    kubectl get pods -n local-path-storage
    exit 0
fi

# Install Local Path Provisioner
print_status "Installing Local Path Provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml

# Wait for the provisioner to be ready
print_status "Waiting for Local Path Provisioner to be ready..."
kubectl wait --for=condition=available deployment/local-path-provisioner -n local-path-storage --timeout=120s

# Create the storage class
print_status "Creating storage class..."
cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: standard
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF

print_status "Local Path Provisioner installed successfully!"

# Verify installation
print_status "Verifying installation..."
kubectl get storageclass standard
kubectl get pods -n local-path-storage

echo ""
print_status "✅ Local Path Provisioner is ready!"
echo ""
print_status "Storage will be created in /opt/local-path-provisioner on each node"
print_status "You can now create PVCs that will be automatically provisioned"
echo ""
print_status "Test with a simple PVC:"
echo "kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-pvc
  namespace: default
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: standard
EOF" 