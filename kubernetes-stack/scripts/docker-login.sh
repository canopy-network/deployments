#!/bin/bash

# Docker Login Script for nodefleet/canopy
set -e

echo "🐳 Docker Login for nodefleet/canopy repository..."

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

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed or not in PATH"
    exit 1
fi

print_status "Docker found: $(docker --version)"

# Function to perform Docker login
docker_login() {
    local username=$1
    local password=$2
    
    print_status "Attempting Docker login..."
    
    # Try to login to Docker Hub
    echo "$password" | docker login -u "$username" --password-stdin
    
    if [ $? -eq 0 ]; then
        print_status "Docker login successful!"
        print_status "You can now pull the nodefleet/canopy image:"
        echo "docker pull nodefleet/canopy:latest"
        
        # Test pulling the image
        print_status "Testing image pull..."
        if docker pull nodefleet/canopy:latest; then
            print_status "Image pull successful!"
        else
            print_warning "Image pull failed. The repository might be private or the image doesn't exist."
        fi
    else
        print_error "Docker login failed!"
        exit 1
    fi
}

# Check if already logged in
if docker info &>/dev/null; then
    print_status "Docker daemon is running"
    
    # Check if we can pull the image without login
    print_status "Testing if image is publicly accessible..."
    if docker pull nodefleet/canopy:latest &>/dev/null; then
        print_status "Image is publicly accessible! No login required."
        exit 0
    else
        print_status "Image requires authentication. Proceeding with login..."
    fi
else
    print_error "Docker daemon is not running. Please start Docker first."
    exit 1
fi

# Get credentials
print_status "Please provide Docker Hub credentials for nodefleet/canopy"

read -p "Enter Docker username: " docker_username
read -s -p "Enter Docker password: " docker_password
echo

if [ -z "$docker_username" ] || [ -z "$docker_password" ]; then
    print_error "Username and password are required!"
    exit 1
fi

# Perform login
docker_login "$docker_username" "$docker_password"

print_status "Docker login completed successfully!"
print_status "You can now run the Kubernetes deployment scripts." 