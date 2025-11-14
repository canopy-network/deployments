#!/bin/bash

# Docker Registry Secret Creation Script
set -e

echo "🐳 Creating Docker Registry Secret for nodefleet/canopy..."

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

# Function to create Docker registry secret
create_docker_secret() {
    local namespace=$1
    local username=$2
    local password=$3
    local email=$4
    
    print_status "Creating Docker registry secret in namespace: $namespace"
    
    # Create the secret using kubectl
    kubectl create secret docker-registry docker-registry-secret \
        --namespace=$namespace \
        --docker-server=nodefleet/canopy \
        --docker-username="$username" \
        --docker-password="$password" \
        --docker-email="$email" \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Docker registry secret created successfully in namespace: $namespace"
}

# Function to create secret from existing Docker config
create_from_docker_config() {
    local namespace=$1
    
    print_status "Creating Docker registry secret from existing Docker config in namespace: $namespace"
    
    # Create the secret from existing Docker config
    kubectl create secret generic docker-registry-secret \
        --namespace=$namespace \
        --from-file=.dockerconfigjson=$HOME/.docker/config.json \
        --type=kubernetes.io/dockerconfigjson \
        --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Docker registry secret created from config in namespace: $namespace"
}

# Check if Docker config exists
if [ -f "$HOME/.docker/config.json" ]; then
    print_status "Found existing Docker config at $HOME/.docker/config.json"
    read -p "Do you want to use existing Docker config? (y/n): " use_existing
    
    if [[ $use_existing =~ ^[Yy]$ ]]; then
        # Create secrets from existing Docker config
        create_from_docker_config "canopy"
        create_from_docker_config "monitoring"
        print_status "Docker registry secrets created from existing config!"
        exit 0
    fi
fi

# Manual input method
print_status "Please provide Docker registry credentials for nodefleet/canopy"

read -p "Enter Docker username: " docker_username
read -s -p "Enter Docker password: " docker_password
echo
read -p "Enter Docker email: " docker_email

if [ -z "$docker_username" ] || [ -z "$docker_password" ] || [ -z "$docker_email" ]; then
    print_error "All fields are required!"
    exit 1
fi

# Create secrets in both namespaces
create_docker_secret "canopy" "$docker_username" "$docker_password" "$docker_email"
create_docker_secret "monitoring" "$docker_username" "$docker_password" "$docker_email"

print_status "Docker registry secrets created successfully!"
print_status "You can now deploy the Canopy stack with private image access."

echo ""
print_status "To verify the secrets:"
echo "kubectl get secret docker-registry-secret -n canopy"
echo "kubectl get secret docker-registry-secret -n monitoring" 