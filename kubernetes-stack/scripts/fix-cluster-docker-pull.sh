#!/bin/bash

# Quick fix for Docker pull timeout on remote K8s cluster
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

print_step "Fixing Docker pull timeout on cluster ${CLUSTER_IP}..."

# Check SSH connectivity
print_step "Testing SSH connectivity..."
if ! ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "echo 'SSH connection successful'" 2>/dev/null; then
    print_error "Cannot SSH to ${CLUSTER_IP}"
    print_status "Make sure SSH key is added: ssh-add ${SSH_KEY}"
    exit 1
fi

# Create fix script to run on remote cluster
print_step "Creating Docker daemon configuration..."

cat <<'REMOTE_SCRIPT' > /tmp/fix-docker-remote.sh
#!/bin/bash
set -e

echo "🔧 Configuring Docker daemon..."

# Backup existing daemon.json if it exists
if [ -f /etc/docker/daemon.json ]; then
    echo "Backing up existing /etc/docker/daemon.json"
    sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d_%H%M%S)
fi

# Create new daemon.json with DNS and timeout settings
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<'EOF'
{
  "dns": ["8.8.8.8", "8.8.4.4", "1.1.1.1"],
  "max-concurrent-downloads": 10,
  "max-concurrent-uploads": 5,
  "registry-mirrors": [],
  "insecure-registries": [],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF

echo "✅ Docker daemon configuration updated"

# Restart Docker
echo "Restarting Docker daemon..."
if command -v systemctl &> /dev/null; then
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "Waiting for Docker to be ready..."
    sleep 10
    sudo systemctl status docker --no-pager || true
else
    sudo service docker restart
    sleep 10
fi

# Test Docker connectivity
echo "Testing Docker connectivity..."
if docker info &> /dev/null; then
    echo "✅ Docker daemon is running"
else
    echo "❌ Docker daemon is not responding"
    exit 1
fi

# Test DNS resolution
echo "Testing DNS resolution..."
if nslookup registry-1.docker.io &> /dev/null; then
    echo "✅ DNS resolution working"
else
    echo "⚠️  DNS resolution may have issues"
fi

# Test network connectivity
echo "Testing network connectivity to Docker Hub..."
if curl -I --connect-timeout 10 --max-time 30 https://registry-1.docker.io/v2/ &> /dev/null; then
    echo "✅ Network connectivity to Docker Hub working"
else
    echo "⚠️  Cannot reach Docker Hub - check firewall/proxy settings"
fi

# Try pulling the image
echo "Attempting to pull nodefleet/canopy:latest..."
if docker pull nodefleet/canopy:latest; then
    echo "✅ Image pull successful!"
else
    echo "⚠️  Image pull failed - check Docker Hub credentials"
    echo "You may need to login: docker login -u nodefleet"
fi
REMOTE_SCRIPT

chmod +x /tmp/fix-docker-remote.sh

# Copy script to remote cluster
print_step "Copying fix script to cluster..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/fix-docker-remote.sh ${SSH_USER}@${CLUSTER_IP}:/tmp/

# Execute script on remote cluster
print_step "Executing fix script on cluster..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "bash /tmp/fix-docker-remote.sh"

# Cleanup
rm /tmp/fix-docker-remote.sh
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "rm /tmp/fix-docker-remote.sh" 2>/dev/null || true

print_status "✅ Fix script execution complete!"
print_status ""
print_status "If Docker pull still fails, try:"
echo "  1. Check if Docker Hub credentials are needed:"
echo "     ssh ${SSH_USER}@${CLUSTER_IP} 'cat ~/docker_login.txt | docker login --username nodefleet --password-stdin'"
echo ""
echo "  2. Check firewall rules:"
echo "     ssh ${SSH_USER}@${CLUSTER_IP} 'sudo ufw status'"
echo ""
echo "  3. Check network connectivity:"
echo "     ssh ${SSH_USER}@${CLUSTER_IP} 'curl -I https://registry-1.docker.io/v2/'"
echo ""
echo "  4. For minikube, use image cache instead:"
echo "     minikube cache add nodefleet/canopy:latest"

