#!/bin/bash

# Debug Configuration Script
set -e

echo "🔍 Debugging Canopy Configuration Issues..."

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

print_status "Step 1: Applying updated configuration..."
kubectl apply -f canopy-configmaps.yaml

print_status "Step 2: Restarting pods to pick up new configuration..."
kubectl delete pod -l app=canopy-node -n canopy

print_status "Step 3: Waiting for pods to restart..."
sleep 10

print_status "Step 4: Checking init container logs..."
for i in 0 1 2; do
    POD_NAME="canopy-node-$i"
    echo ""
    echo "=== Init container logs for $POD_NAME ==="
    if kubectl get pod $POD_NAME -n canopy &> /dev/null; then
        kubectl logs $POD_NAME -n canopy -c setup-config 2>/dev/null || echo "Could not get logs for $POD_NAME"
    else
        echo "Pod $POD_NAME not found or not ready yet"
    fi
done

echo ""
print_status "Step 5: Checking actual configuration values..."
for i in 0 1 2; do
    POD_NAME="canopy-node-$i"
    NODE_NUM=$((i + 1))
    echo ""
    echo "=== Configuration for Node $NODE_NUM ($POD_NAME) ==="
    
    if kubectl get pod $POD_NAME -n canopy &> /dev/null; then
        POD_STATUS=$(kubectl get pod $POD_NAME -n canopy -o jsonpath='{.status.phase}')
        echo "Pod status: $POD_STATUS"
        
        if [ "$POD_STATUS" = "Running" ]; then
            echo "rpcURL:"
            kubectl exec $POD_NAME -n canopy -- grep -o '"rpcURL": "[^"]*"' /root/.canopy/config.json 2>/dev/null || echo "  Not found"
            
            echo "adminRPCURL:"
            kubectl exec $POD_NAME -n canopy -- grep -o '"adminRPCURL": "[^"]*"' /root/.canopy/config.json 2>/dev/null || echo "  Not found"
            
            echo "externalAddress:"
            kubectl exec $POD_NAME -n canopy -- grep -o '"externalAddress": "[^"]*"' /root/.canopy/config.json 2>/dev/null || echo "  Not found"
            
            echo "networkID:"
            kubectl exec $POD_NAME -n canopy -- grep -o '"networkID": [0-9]*' /root/.canopy/config.json 2>/dev/null || echo "  Not found"
        else
            echo "Pod not running, cannot check configuration"
        fi
    else
        echo "Pod $POD_NAME not found"
    fi
done

echo ""
print_status "Debug completed. Check the init container logs above for any issues with variable assignment or replacement." 