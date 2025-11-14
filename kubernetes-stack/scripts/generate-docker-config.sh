#!/bin/bash

# Generate Base64 Docker Config for Docker Hub
set -e

echo "🔐 Generating Base64 Docker Config for Docker Hub..."

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

# Get credentials
print_status "Please provide Docker Hub credentials for nodefleet/canopy"

read -p "Enter Docker Hub username: " docker_username
read -s -p "Enter Docker Hub password: " docker_password
echo

if [ -z "$docker_username" ] || [ -z "$docker_password" ]; then
    print_error "Username and password are required!"
    exit 1
fi

# Create the Docker config JSON
docker_config_json=$(cat <<EOF
{
  "auths": {
    "https://index.docker.io/v1/": {
      "username": "$docker_username",
      "password": "$docker_password",
      "email": "nodes@nodefleet.net",
      "auth": "$(echo -n "$docker_username:$docker_password" | base64)"
    }
  }
}
EOF
)

print_status "Generated Docker config JSON:"
echo "$docker_config_json"
echo ""

# Generate base64 encoded config
base64_config=$(echo -n "$docker_config_json" | base64)

print_status "Base64 encoded Docker config:"
echo "$base64_config"
echo ""

# Create the Kubernetes secret YAML
print_status "Creating Kubernetes secret YAML..."

secret_yaml=$(cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-secret
  namespace: canopy
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $base64_config
---
apiVersion: v1
kind: Secret
metadata:
  name: docker-registry-secret
  namespace: monitoring
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $base64_config
EOF
)

echo "$secret_yaml"
echo ""

# Save to file
print_status "Saving to secrets/docker-registry-secret.yaml..."
echo "$secret_yaml" > secrets/docker-registry-secret.yaml
print_status "Secret saved to secrets/docker-registry-secret.yaml"

print_status "To apply the secret:"
echo "kubectl apply -f secrets/docker-registry-secret.yaml"

echo ""
print_warning "Note: Keep your credentials secure and don't commit them to version control!"
print_warning "Consider adding secrets/docker-registry-secret.yaml to .gitignore" 