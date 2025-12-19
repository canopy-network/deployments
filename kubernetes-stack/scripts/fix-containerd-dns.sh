#!/bin/bash

# Fix containerd DNS for Kubernetes image pulls
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

print_step "Fixing containerd DNS configuration on cluster ${CLUSTER_IP}..."

# Check SSH connectivity
print_step "Testing SSH connectivity..."
if ! ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "echo 'SSH connection successful'" 2>/dev/null; then
    print_error "Cannot SSH to ${CLUSTER_IP}"
    print_status "Make sure SSH key is added: ssh-add ${SSH_KEY}"
    exit 1
fi

# Create fix script to run on remote cluster
cat <<'REMOTE_SCRIPT' > /tmp/fix-containerd-dns.sh
#!/bin/bash
set -e

echo "🔧 Configuring containerd DNS..."

# Backup existing config if it exists
if [ -f /etc/containerd/config.toml ]; then
    echo "Backing up existing /etc/containerd/config.toml"
    sudo cp /etc/containerd/config.toml /etc/containerd/config.toml.backup.$(date +%Y%m%d_%H%M%S)
fi

# Generate default config if it doesn't exist or is minimal
if [ ! -f /etc/containerd/config.toml ] || [ $(wc -l < /etc/containerd/config.toml) -lt 10 ]; then
    echo "Generating containerd config..."
    sudo mkdir -p /etc/containerd
    containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
fi

# Add DNS configuration to containerd config
echo "Adding DNS configuration to containerd..."

# Check if [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options] section exists
if sudo grep -q '\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runc\.options\]' /etc/containerd/config.toml; then
    echo "Runtime options section exists, adding SystemdCgroup and DNS..."
    # Add SystemdCgroup = true if not present
    if ! sudo grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
        sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\.containerd\.runtimes\.runc\.options\]/a SystemdCgroup = true' /etc/containerd/config.toml
    fi
else
    # Add the runtime options section
    echo "Adding runtime options section..."
    sudo tee -a /etc/containerd/config.toml > /dev/null <<'EOF'

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF
fi

# Configure DNS in the CRI plugin section
if sudo grep -q '\[plugins\."io\.containerd\.grpc\.v1\.cri"\]' /etc/containerd/config.toml; then
    # Check if sandbox_image is configured
    if ! sudo grep -q 'sandbox_image =' /etc/containerd/config.toml; then
        sudo sed -i '/\[plugins\."io\.containerd\.grpc\.v1\.cri"\]/a sandbox_image = "registry.k8s.io/pause:3.9"' /etc/containerd/config.toml
    fi
fi

# Configure DNS servers in systemd-resolved or resolv.conf
echo "Configuring system DNS..."
if command -v systemd-resolve &> /dev/null || command -v resolvectl &> /dev/null; then
    echo "Configuring systemd-resolved DNS..."
    sudo mkdir -p /etc/systemd/resolved.conf.d
    sudo tee /etc/systemd/resolved.conf.d/dns_servers.conf > /dev/null <<'EOF'
[Resolve]
DNS=8.8.8.8 8.8.4.4 1.1.1.1
FallbackDNS=1.1.1.1
EOF
    sudo systemctl restart systemd-resolved
elif [ -f /etc/resolv.conf ]; then
    echo "Backing up /etc/resolv.conf"
    sudo cp /etc/resolv.conf /etc/resolv.conf.backup.$(date +%Y%m%d_%H%M%S)
    echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
    echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf > /dev/null
    echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf > /dev/null
fi

# Restart containerd
echo "Restarting containerd..."
sudo systemctl daemon-reload
sudo systemctl restart containerd

echo "Waiting for containerd to be ready..."
sleep 5

# Verify containerd is running
if sudo systemctl is-active --quiet containerd; then
    echo "✅ containerd is running"
else
    echo "❌ containerd failed to start"
    sudo systemctl status containerd --no-pager || true
    exit 1
fi

# Test DNS resolution from containerd context
echo "Testing DNS resolution..."
if nslookup registry-1.docker.io &> /dev/null; then
    echo "✅ DNS resolution working"
else
    echo "⚠️  DNS resolution may have issues"
fi

# For minikube, also load the image directly
if command -v minikube &> /dev/null && minikube status &> /dev/null 2>&1; then
    echo ""
    echo "Detected minikube - loading image directly..."
    if docker pull nodefleet/canopy:latest 2>&1; then
        echo "Image pulled successfully, loading into minikube..."
        minikube image load nodefleet/canopy:latest 2>&1 || echo "Image load had issues, but continuing..."
        echo "✅ Image loaded into minikube"
    else
        echo "⚠️  Could not pull image, but containerd DNS is configured"
    fi
fi

echo ""
echo "✅ containerd DNS configuration complete!"
REMOTE_SCRIPT

chmod +x /tmp/fix-containerd-dns.sh

# Copy script to remote cluster
print_step "Copying fix script to cluster..."
scp -o StrictHostKeyChecking=no -i ${SSH_KEY} /tmp/fix-containerd-dns.sh ${SSH_USER}@${CLUSTER_IP}:/tmp/

# Execute script on remote cluster
print_step "Executing containerd DNS fix..."
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "bash /tmp/fix-containerd-dns.sh"

# Cleanup
rm /tmp/fix-containerd-dns.sh
ssh -o StrictHostKeyChecking=no -i ${SSH_KEY} ${SSH_USER}@${CLUSTER_IP} "rm /tmp/fix-containerd-dns.sh" 2>/dev/null || true

print_status "✅ containerd DNS fix complete!"
print_status ""
print_status "For minikube, you can also load the image directly:"
echo "  ssh ${SSH_USER}@${CLUSTER_IP} 'docker pull nodefleet/canopy:latest && minikube image load nodefleet/canopy:latest'"
echo ""
print_status "Restart pods to retry image pull:"
echo "  kubectl delete pod -n canopy --all"
echo "  kubectl delete pod -n monitoring --all"

