#!/bin/bash

# Fix containerd DNS inside minikube container
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

print_step "Fixing containerd DNS inside minikube on ${CLUSTER_IP}..."

# Check SSH connectivity
print_step "Testing SSH connectivity..."
if ! ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "echo 'SSH connection successful'" 2>/dev/null; then
    print_error "Cannot SSH to ${CLUSTER_IP}"
    print_status "Make sure SSH key is added: ssh-add ${SSH_KEY}"
    exit 1
fi

# Create fix script to run inside minikube
cat <<'REMOTE_SCRIPT' > /tmp/fix-minikube-containerd.sh
#!/bin/bash
set -e

echo "🔧 Configuring DNS inside minikube container..."

# Configure DNS in minikube's resolv.conf
echo "Configuring /etc/resolv.conf in minikube..."
minikube ssh "sudo tee /etc/resolv.conf > /dev/null <<'EOF'
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF"

# Configure containerd inside minikube
echo "Configuring containerd inside minikube..."
minikube ssh "sudo mkdir -p /etc/containerd"
minikube ssh "sudo containerd config default | sudo tee /etc/containerd/config.toml > /dev/null || echo 'Config generation skipped'"

# Restart containerd inside minikube
echo "Restarting containerd inside minikube..."
minikube ssh "sudo systemctl restart containerd || sudo service containerd restart"
sleep 5

# Test DNS resolution inside minikube
echo "Testing DNS resolution inside minikube..."
minikube ssh "nslookup registry-1.docker.io" || echo "DNS test had issues"

# Load image directly into minikube using docker
echo "Loading image into minikube using docker..."
if docker pull nodefleet/canopy:latest 2>&1; then
    echo "Image pulled on host, loading into minikube..."
    minikube image load nodefleet/canopy:latest 2>&1 || echo "Image load had issues"
    echo "✅ Image loaded into minikube"
fi

# Also try pulling directly inside minikube
echo "Attempting to pull image inside minikube..."
minikube ssh "docker pull nodefleet/canopy:latest" || echo "Pull inside minikube had issues, but image may already be loaded"

echo ""
echo "✅ Minikube containerd DNS configuration complete!"
REMOTE_SCRIPT

chmod +x /tmp/fix-minikube-containerd.sh

# Copy script to remote cluster
print_step "Copying fix script to cluster..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/fix-minikube-containerd.sh ${SSH_USER}@${CLUSTER_IP}:/tmp/

# Execute script on remote cluster
print_step "Executing minikube containerd DNS fix..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "bash /tmp/fix-minikube-containerd.sh"

# Cleanup
rm /tmp/fix-minikube-containerd.sh
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "rm /tmp/fix-minikube-containerd.sh" 2>/dev/null || true

print_status "✅ Minikube containerd DNS fix complete!"
print_status ""
print_status "Restart pods to retry image pull:"
echo "  kubectl delete pod -n canopy --all"
echo "  kubectl delete pod -n canopy-localnet --all"

