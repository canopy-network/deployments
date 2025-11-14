#!/bin/bash

# Auto-generate Services After Scaling Script
set -e

echo "🔄 Auto-generating services for current canopy replicas..."

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Check if canopy namespace exists
if ! kubectl get namespace canopy &> /dev/null; then
    print_error "Canopy namespace does not exist"
    exit 1
fi

# Check if StatefulSet exists
if ! kubectl get statefulset canopy-node -n canopy &> /dev/null; then
    print_error "Canopy StatefulSet does not exist"
    exit 1
fi

# Get current number of replicas
REPLICAS=$(kubectl get statefulset canopy-node -n canopy -o jsonpath='{.spec.replicas}')
print_status "Current StatefulSet replicas: $REPLICAS"

# Apply the auto-scale job
print_status "Deploying service generator job..."
kubectl apply -f auto-scale-services.yaml

# Wait for job to complete
print_status "Waiting for service generation to complete..."
kubectl wait --for=condition=complete job/canopy-service-generator -n canopy --timeout=120s

# Show job logs
print_status "Service generation job logs:"
kubectl logs job/canopy-service-generator -n canopy

# Clean up the job
print_status "Cleaning up service generator job..."
kubectl delete job canopy-service-generator -n canopy

print_status "✅ Auto-generation completed!"

echo ""
print_status "Current services:"
kubectl get svc -l app=canopy-node -n canopy

echo ""
print_status "You can now access any node service:"
for i in $(seq 1 $REPLICAS); do
    echo "  Node $i: http://node$i.canopy.svc.cluster.local:50002"
done 