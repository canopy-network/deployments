#!/bin/bash

# Start Kubernetes Cluster (Minikube)
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Configuration from agent.md
CLUSTER_IP="${1:-173.201.36.84}"
SSH_USER="${2:-ubuntu}"
SSH_KEY="${3:-~/.ssh/id_rsa}"

print_step "Starting Kubernetes cluster on ${CLUSTER_IP}..."

# Check SSH connectivity
print_step "Testing SSH connectivity..."
if ! ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "echo 'SSH connection successful'" 2>/dev/null; then
    print_error "Cannot SSH to ${CLUSTER_IP}"
    print_status "Make sure SSH key is added: ssh-add ${SSH_KEY}"
    exit 1
fi

# Create start script to run on remote cluster
cat <<'REMOTE_SCRIPT' > /tmp/start-minikube.sh
#!/bin/bash
set -e

echo "🚀 Starting Minikube cluster..."

# Check if minikube is installed
if ! command -v minikube &> /dev/null; then
    echo "❌ minikube is not installed"
    exit 1
fi

# Check current status
echo "Current minikube status:"
minikube status || true

# Use default profile
PROFILE="minikube"
echo "Using profile: ${PROFILE}"

# Start minikube
echo "Starting minikube cluster..."
if minikube start --profile=${PROFILE} 2>&1; then
    echo "✅ Minikube started successfully!"
else
    echo "⚠️  Minikube start had issues, checking status..."
    minikube status --profile=${PROFILE} || true
fi

# Wait for cluster to be ready
echo "Waiting for cluster to be ready..."
sleep 10

# Check cluster status
echo ""
echo "Cluster status:"
minikube status --profile=${PROFILE}

# Verify kubectl connectivity
echo ""
echo "Testing kubectl connectivity..."
if kubectl cluster-info &> /dev/null; then
    echo "✅ kubectl is working!"
    kubectl cluster-info
    echo ""
    echo "Node status:"
    kubectl get nodes
else
    echo "⚠️  kubectl connectivity issues - cluster may still be starting"
    echo "Wait a few minutes and check: kubectl get nodes"
fi
REMOTE_SCRIPT

chmod +x /tmp/start-minikube.sh

# Copy script to remote cluster
print_step "Copying start script to cluster..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/start-minikube.sh ${SSH_USER}@${CLUSTER_IP}:/tmp/

# Execute script on remote cluster
print_step "Starting minikube cluster..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "bash /tmp/start-minikube.sh"

# Cleanup
rm /tmp/start-minikube.sh
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "rm /tmp/start-minikube.sh" 2>/dev/null || true

print_status "✅ Cluster start script execution complete!"
print_status ""
print_status "To verify cluster status:"
echo "  ssh ${SSH_USER}@${CLUSTER_IP} 'minikube status'"
echo "  ssh ${SSH_USER}@${CLUSTER_IP} 'kubectl get nodes'"

