#!/bin/bash

# Update Canopy Configuration Script
set -e

echo "🔄 Updating Canopy Configuration for Scalability..."

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

# Check if canopy namespace exists
if ! kubectl get namespace canopy &> /dev/null; then
    print_status "Creating canopy namespace..."
    kubectl apply -f canopy-namespace.yaml
fi

# Apply updated ConfigMaps
print_status "Applying updated ConfigMaps..."
kubectl apply -f canopy-configmaps.yaml

# Wait for ConfigMaps to be ready
print_status "Waiting for ConfigMaps to be ready..."
sleep 3

# Verify ConfigMaps
print_status "Verifying ConfigMaps..."
kubectl get configmap canopy-genesis -n canopy
kubectl get configmap canopy-config-template -n canopy

# Apply updated StatefulSet and Services
print_status "Applying updated StatefulSet and Services..."
kubectl apply -f canopy-nodes.yaml

# Wait for rollout to complete
print_status "Waiting for StatefulSet rollout to complete..."
kubectl rollout status statefulset/canopy-node -n canopy --timeout=300s

print_status "Configuration update completed successfully!"

echo ""
print_status "Current status:"
kubectl get pods -n canopy
kubectl get svc -n canopy

echo ""
print_status "Test scaling with:"
echo "./scale-canopy.sh 5"
echo ""
print_status "Or use kubectl directly:"
echo "kubectl scale statefulset canopy-node --replicas=10 -n canopy"
echo ""
print_status "Then generate services for the scaled nodes:"
echo "./scale-canopy.sh 10"

echo ""
print_status "Monitor scaling progress:"
echo "kubectl get pods -n canopy -w" 