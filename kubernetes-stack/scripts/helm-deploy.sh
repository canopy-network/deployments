#!/bin/bash

# Canopy Kubernetes Stack Helm Deployment Script
set -e

echo "🚀 Deploying Canopy Kubernetes Stack with Helm..."

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

# Function to detect cluster type and recommend storage solution
detect_storage_setup() {
    print_status "🗄️  Detecting cluster storage capabilities..."
    
    # Check if we're on a cloud provider
    if kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "aws"; then
        echo "aws"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "gce"; then
        echo "gcp"
    elif kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | grep -q "azure"; then
        echo "azure"
    elif kubectl get storageclass | grep -q "local-path"; then
        echo "local-path"
    elif kubectl get storageclass | grep -q "openebs-hostpath"; then
        echo "existing"
    elif kubectl get storageclass | grep -q "minikube-hostpath"; then
        echo "minikube"
    else
        echo "vanilla"
    fi
}

# Function to create storage class and PVs for vanilla Kubernetes
setup_vanilla_storage() {
    local nodes=$1
    
    print_status "Setting up vanilla Kubernetes storage for $nodes nodes..."
    
    # Get the first node name for storage
    FIRST_NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
    print_status "Using node '$FIRST_NODE' for storage"
    
    # Check if openebs-hostpath storage class already exists
    if kubectl get storageclass openebs-hostpath &> /dev/null; then
        print_status "Local-storage StorageClass already exists. Checking if it's suitable..."
        EXISTING_PROVISIONER=$(kubectl get storageclass openebs-hostpath -o jsonpath='{.provisioner}')
        
        if [[ "$EXISTING_PROVISIONER" == "k8s.io/minikube-hostpath" ]]; then
            print_status "Found Minikube hostpath provisioner - this will work for local development"
            print_status "Skipping StorageClass creation, using existing Minikube storage"
            # For Minikube, we don't need to create manual PVs
            print_status "✅ Minikube storage setup completed!"
            return 0
        elif [[ "$EXISTING_PROVISIONER" == "kubernetes.io/no-provisioner" ]]; then
            print_status "Found no-provisioner StorageClass - perfect for manual PVs"
            # Continue with manual PV creation
        else
            print_status "Found StorageClass with provisioner: $EXISTING_PROVISIONER"
            print_status "This should work automatically, skipping manual PV creation"
            return 0
        fi
        
        # Start with empty file for PVs only
        cat > /tmp/storage-setup.yaml << EOF
# Manual PVs for existing no-provisioner StorageClass
EOF
    else
        # Create storage class and start the file
        cat > /tmp/storage-setup.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-hostpath
provisioner: kubernetes.io/no-provisioner # indicates that this StorageClass does not support automatic provisioning
volumeBindingMode: WaitForFirstConsumer
EOF
    fi

    # Generate PVs for canopy nodes
    for i in $(seq 0 $((nodes-1))); do
        cat >> /tmp/storage-setup.yaml << EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: canopy-data-canopy-node-$i
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: openebs-hostpath 
  hostPath:
    path: "/home/ubuntu/canopy_data/node$i"
#  nodeAffinity:
#    required:
#      nodeSelectorTerms:
#      - matchExpressions:
#        - key: kubernetes.io/hostname
#          operator: In
#          values:
#          - $FIRST_NODE
EOF
    done

    # Generate PVs for monitoring components
    cat >> /tmp/storage-setup.yaml << EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: prometheus-data
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: openebs-hostpath 
  local:
    path: /data/monitoring/prometheus
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $FIRST_NODE
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: grafana-data
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: openebs-hostpath 
  local:
    path: /data/monitoring/grafana
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $FIRST_NODE
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: loki-data
spec:
  capacity:
    storage: 50Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: openebs-hostpath 
  local:
    path: /data/monitoring/loki
  nodeAffinity:
    required:
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - $FIRST_NODE
EOF

    # Display directory creation instructions
    print_warning "🏗️  Manual storage setup required for vanilla Kubernetes!"
    echo ""
    echo "Please run the following commands on node '$FIRST_NODE':"
    echo ""
    echo "# Create directories for canopy nodes:"
    for i in $(seq 0 $((nodes-1))); do
        echo "sudo mkdir -p /data/canopy/node$i"
    done
    echo ""
    echo "# Create directories for monitoring:"
    echo "sudo mkdir -p /data/monitoring/prometheus"
    echo "sudo mkdir -p /data/monitoring/grafana"
    echo "sudo mkdir -p /data/monitoring/loki"
    echo ""
    echo "# Set permissions:"
    echo "sudo chmod 755 /data/canopy/node*"
    echo "sudo chmod 755 /data/monitoring/*"
    echo ""
    
    # Ask for confirmation
    read -p "Have you created the directories on node '$FIRST_NODE'? (y/N): " dirs_created
    
    if [[ ! $dirs_created =~ ^[Yy]$ ]]; then
        print_error "Please create the directories first, then run this script again."
        exit 1
    fi
    
    # Apply the storage configuration
    print_status "Applying storage class and persistent volumes..."
    kubectl apply -f /tmp/storage-setup.yaml
    
    # Clean up temporary file
    rm -f /tmp/storage-setup.yaml
    
    print_status "✅ Vanilla Kubernetes storage setup completed!"
}


# Function to install local-path-provisioner
install_local_path_provisioner() {
    print_status "Installing Local Path Provisioner..."
    
    # Check if already installed
    if kubectl get deployment local-path-provisioner -n local-path-storage &> /dev/null; then
        print_status "Local Path Provisioner already installed"
        return 0
    fi
    
    # Check if openebs-hostpath storage class already exists
    if kubectl get storageclass openebs-hostpath &> /dev/null; then
        print_status "Local-storage StorageClass already exists, skipping Local Path Provisioner installation"
        return 0
    fi
    
    # Install Local Path Provisioner
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.28/deploy/local-path-storage.yaml
    
    # Wait for it to be ready
    kubectl wait --for=condition=available deployment/local-path-provisioner -n local-path-storage --timeout=120s
    
    # Create the openebs-hostpath storage class
    cat > /tmp/storage-setup.yaml << EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-hostpath
provisioner: rancher.io/local-path
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
reclaimPolicy: Delete
EOF
    
    kubectl apply -f /tmp/storage-setup.yaml
    rm -f /tmp/storage-setup.yaml
    
    print_status "✅ Local Path Provisioner installed successfully!"
}

# Function to setup storage based on cluster type
setup_storage() {
    local nodes=$1
    local storage_type=$(detect_storage_setup)
    
    print_status "Detected storage type: $storage_type"
    
    case $storage_type in
        "local-path")
            print_status "Local Path Provisioner already available"
            ;;
        "minikube")
            print_status "Minikube detected - using existing minikube-hostpath storage"
            ;;
        "existing")
            print_status "Local-storage storage class already exists"
            ;;
        "vanilla")
            print_status "Vanilla Kubernetes detected - manual storage setup required"
            read -p "Do you want to use Local Path Provisioner (automatic) or manual PVs? (auto/manual): " storage_choice
            
            if [[ $storage_choice =~ ^[Aa] ]]; then
                install_local_path_provisioner
            else
                setup_vanilla_storage $nodes
            fi
            ;;
        *)
            print_warning "Unknown storage type, attempting Local Path Provisioner installation..."
            install_local_path_provisioner
            ;;
    esac
    
    # Verify storage class exists
    if kubectl get storageclass openebs-hostpath &> /dev/null; then
        print_status "✅ Storage class 'openebs-hostpath' is available"
        kubectl get storageclass openebs-hostpath
    elif kubectl get storageclass standard &> /dev/null; then
        print_status "✅ Storage class 'standard' (Minikube) is available"
        kubectl get storageclass standard
    else
        print_error "❌ No suitable storage class found"
        print_error "Expected 'openebs-hostpath' or 'standard' (Minikube)"
        exit 1
    fi
}

# Function to safely delete resources
safe_delete() {
    local resource_type=$1
    local resource_name=$2
    local namespace=$3
    
    print_status "Deleting $resource_type $resource_name in namespace $namespace"
    kubectl delete $resource_type $resource_name -n $namespace --ignore-not-found=true
}

# Comprehensive cleanup function
cleanup_all() {
    CLEANUP_IN_PROGRESS=true
    print_status "🧹 Running comprehensive cleanup..."
    
    # Confirm deletion
    print_warning "This will delete all monitoring and canopy resources."
    print_warning "This includes Helm releases (grafana, loki, prometheus) and traditional Kubernetes resources."
    read -p "Are you sure you want to continue? (y/N): " confirm
    
    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        print_status "Cleanup cancelled."
        exit 0
    fi
    
    # Uninstall Helm releases first
    if command -v helm &> /dev/null; then
        print_status "Uninstalling Helm releases..."
        
        # Check if releases exist before trying to uninstall
        if helm list -n monitoring | grep -q "grafana"; then
            print_status "Uninstalling Grafana Helm release..."
            helm uninstall grafana -n monitoring
        else
            print_status "Grafana Helm release not found"
        fi
        
        if helm list -n monitoring | grep -q "loki"; then
            print_status "Uninstalling Loki Helm release..."
            helm uninstall loki -n monitoring
        else
            print_status "Loki Helm release not found"
        fi
        
        if helm list -n monitoring | grep -q "prometheus"; then
            print_status "Uninstalling Prometheus Helm release..."
            helm uninstall prometheus -n monitoring
        else
            print_status "Prometheus Helm release not found"
        fi
        
        if helm list -n monitoring | grep -q "traefik"; then
            print_status "Uninstalling Traefik Helm release..."
            helm uninstall traefik -n monitoring
        else
            print_status "Traefik Helm release not found"
        fi
        
        print_status "Helm releases uninstalled successfully"
        
        # Wait a moment for Helm to clean up resources
        print_status "Waiting for Helm cleanup to complete..."
        sleep 5
    else
        print_warning "Skipping Helm uninstall (helm not available)"
    fi
    
    # Delete remaining deployments (some may have been cleaned up by Helm)
    print_status "Deleting remaining deployments..."
    safe_delete deployment prometheus monitoring
    safe_delete deployment grafana monitoring
    safe_delete deployment loki monitoring
    safe_delete deployment blackbox-exporter monitoring
    safe_delete deployment traefik monitoring
    
    # Delete Canopy resources
    print_status "Deleting Canopy resources..."
    safe_delete statefulset canopy-node canopy
    safe_delete service canopy-node canopy
    safe_delete service canopy-node-headless canopy
    safe_delete service node1 canopy
    safe_delete service node2 canopy
    safe_delete service node3 canopy
    
    # Delete any additional scaled node services (node4, node5, etc.)
    print_status "Deleting scaled node services..."
    for i in $(seq 1 99); do
        if kubectl get service node$i -n canopy &> /dev/null; then
            print_status "Deleting service node$i..."
            safe_delete service node$i canopy
        fi
    done
    
    # Clean up any generated service files
    print_status "Cleaning up generated service files..."
    if [ -f "../canopy-services-scaled.yaml" ]; then
        print_status "Removing generated service file: canopy-services-scaled.yaml"
        rm -f ../canopy-services-scaled.yaml
    fi
    
    # Delete services
    print_status "Deleting services..."
    safe_delete service prometheus monitoring
    safe_delete service grafana monitoring
    safe_delete service loki monitoring
    safe_delete service blackbox-exporter monitoring
    safe_delete service traefik monitoring
    
    # Delete ConfigMaps
    print_status "Deleting ConfigMaps..."
    safe_delete configmap prometheus-config monitoring
    safe_delete configmap loki-config monitoring
    safe_delete configmap blackbox-config monitoring
    safe_delete configmap grafana-datasources monitoring
    safe_delete configmap grafana-dashboards monitoring
    safe_delete configmap grafana-alerting monitoring
    safe_delete configmap grafana-provisioning monitoring
    
    # Delete Traefik ConfigMaps (with Helm naming pattern)
    kubectl delete configmap -l app.kubernetes.io/name=traefik -n monitoring --ignore-not-found=true
    # Also delete any standalone traefik configmaps that might exist
    safe_delete configmap traefik-config monitoring
    safe_delete configmap traefik-middlewares monitoring
    safe_delete configmap traefik-routes monitoring
    
    # Delete Canopy ConfigMaps
    print_status "Deleting Canopy ConfigMaps..."
    safe_delete configmap canopy-genesis canopy
    safe_delete configmap canopy-config-template canopy
    safe_delete configmap node1-config canopy
    safe_delete configmap node2-config canopy
    safe_delete configmap all-node-configs canopy
    
    # Delete PVCs
    print_status "Deleting PVCs..."
    safe_delete pvc prometheus-data monitoring
    safe_delete pvc grafana-data monitoring
    safe_delete pvc loki-data monitoring
    safe_delete pvc traefik-data monitoring
    
    # Delete PVs (for vanilla Kubernetes setups)
    print_status "Deleting PVs..."
    for i in $(seq 0 98); do
        if kubectl get pv canopy-data-canopy-node-$i &> /dev/null; then
            print_status "Deleting PV canopy-data-canopy-node-$i..."
            kubectl delete pv canopy-data-canopy-node-$i --ignore-not-found=true
        fi
    done
    kubectl delete pv prometheus-data grafana-data loki-data --ignore-not-found=true
    
    # Delete DaemonSets
    print_status "Deleting DaemonSets..."
    safe_delete daemonset node-exporter monitoring
    safe_delete daemonset cadvisor monitoring
    
    # Delete ServiceAccounts
    print_status "Deleting ServiceAccounts..."
    safe_delete serviceaccount prometheus monitoring
    safe_delete serviceaccount grafana monitoring
    safe_delete serviceaccount loki monitoring
    safe_delete serviceaccount blackbox-exporter monitoring
    safe_delete serviceaccount traefik monitoring
    
    # Delete any remaining Helm-related resources
    print_status "Cleaning up any remaining Helm-related resources..."
    kubectl delete all -l app.kubernetes.io/instance=grafana -n monitoring --ignore-not-found=true
    kubectl delete all -l app.kubernetes.io/instance=loki -n monitoring --ignore-not-found=true
    kubectl delete all -l app.kubernetes.io/instance=prometheus -n monitoring --ignore-not-found=true
    kubectl delete all -l app.kubernetes.io/instance=traefik -n monitoring --ignore-not-found=true
    
    print_status "Comprehensive cleanup completed successfully!"
    
    # Clean up storage class if it exists
    print_status "Cleaning up storage class..."
    #kubectl delete storageclass openebs-hostpath --ignore-not-found=true
    
    echo ""
    print_status "Remaining resources in monitoring namespace:"
    kubectl get all -n monitoring 2>/dev/null || print_status "No resources found in monitoring namespace"
    
    echo ""
    print_status "Remaining resources in canopy namespace:"
    kubectl get all -n canopy 2>/dev/null || print_status "No resources found in canopy namespace"
    
    echo ""
    print_status "Cleaned up resources include:"
    echo "  - All StatefulSets and Deployments"
    echo "  - All Services (including scaled node services node1-node15)"
    echo "  - All ConfigMaps"
    echo "  - All PVCs (including scaled canopy-data PVCs)"
    echo "  - All PVs (for vanilla Kubernetes)"
    echo "  - All DaemonSets"
    echo "  - All ServiceAccounts"
    echo "  - Generated service files (canopy-services-scaled.yaml)"
    echo "  - Helm releases"
    
    echo ""
    print_status "Proceeding with fresh deployment..."
    echo ""
    
    # Restore original files if they were modified
    restore_original_files
    
    # Reset cleanup flag
    CLEANUP_IN_PROGRESS=false
}

# Function to restore original files if they were modified
restore_original_files() {
    print_status "🔄 Restoring original configuration files..."
    
    # Restore canopy-nodes.yaml if backup exists
    if [ -f "../canopy/canopy-nodes.yaml.backup" ]; then
        print_status "Restoring ../canopy/canopy-nodes.yaml from backup..."
        mv ../canopy/canopy-nodes.yaml.backup ../canopy/canopy-nodes.yaml
    fi
    
    # Restore storage-class.yaml if it was modified
    if [ -f "../storage-class.yaml" ] && [[ -n "$WORKER_NODE" ]]; then
        print_status "Restoring storage-class.yaml to original state..."
        # Restore the original node1 value
        sed -i "s/- $WORKER_NODE/- node1  # Replace with your actual node name/g" ../storage-class.yaml
    fi
    
    # Restore image if it was modified (only if no backup exists, meaning it was modified in-place)
    if [ -f "../canopy/canopy-nodes.yaml" ] && [ ! -f "../canopy/canopy-nodes.yaml.backup" ]; then
        print_status "Restoring ../canopy/canopy-nodes.yaml image to original state..."
        # Restore to the default 'latest' tag
        sed -i "s|image: $IMAGE|image: nodefleet/canopy:latest|g" ../canopy/canopy-nodes.yaml
    fi
    
    print_status "Original files restored successfully"
}

# Parse command line arguments
REDEPLOY=false
NODES=3  # Default number of nodes
PRODUCTION=false
WORKER_NODE=""  # Default worker node (will use existing if not specified)
IMAGE="nodefleet/canopy:latest"  # Default image

while [[ $# -gt 0 ]]; do
    case $1 in
        --redeploy)
            REDEPLOY=true
            shift
            ;;
        --nodes)
            NODES="$2"
            if ! [[ "$NODES" =~ ^[0-9]+$ ]] || [ "$NODES" -lt 1 ] || [ "$NODES" -gt 99 ]; then
                print_error "Invalid number of nodes. Must be a positive integer between 1 and 99."
                exit 1
            fi
            shift 2
            ;;
        --production)
            PRODUCTION=true
            shift
            ;;
        --workernode)
            WORKER_NODE="$2"
            if [[ -z "$WORKER_NODE" ]]; then
                print_error "Worker node name cannot be empty"
                exit 1
            fi
            shift 2
            ;;
        --image)
            IMAGE="$2"
            if [[ -z "$IMAGE" ]]; then
                print_error "Image name cannot be empty"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --redeploy         Clean up all resources before deployment"
            echo "  --nodes <number>   Number of canopy nodes to deploy (1-99, default: 3)"
            echo "  --production       Enable production mode (taint tolerations, node affinity)"
            echo "  --workernode <name> Worker node name for node affinity (optional)"
            echo "  --image <name> Container image name for canopy nodes (optional)"
            echo "  -h, --help         Show this help message"
            echo ""
            echo "Storage Setup:"
            echo "  The script automatically detects your cluster type and sets up appropriate storage:"
            echo "  - AWS EKS: Uses EBS CSI driver with gp3 volumes"
            echo "  - Google GKE: Uses GCE PD CSI driver"
            echo "  - Azure AKS: Uses Azure Disk CSI driver"
            echo "  - Vanilla Kubernetes: Offers Local Path Provisioner or manual PV setup"
            echo ""
            echo "Production Mode:"
            echo "  --production flag enables:"
            echo "  - Control-plane taint tolerations"
            echo "  - Node affinity for worker nodes"
            echo "  - Pod anti-affinity for high availability"
            echo "  - Production storage class detection"
            echo ""
            echo "Examples:"
            echo "  $0 --nodes 5                    # Deploy 5 canopy nodes"
            echo "  $0 --redeploy --nodes 10        # Clean up and deploy 10 nodes"
            echo "  $0 --production --nodes 3       # Deploy 3 nodes in production mode"
            echo "  $0 --workernode worker-01       # Deploy with specific worker node affinity"
            echo "  $0 --image nodefleet/canopy:no-sync-issue  # Deploy with specific image"
            echo "  $0 --help                       # Show this help"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

print_status "Deployment configuration:"
print_status "  Nodes: $NODES"
print_status "  Redeploy: $REDEPLOY"
print_status "  Production mode: $PRODUCTION"
if [[ -n "$WORKER_NODE" ]]; then
    print_status "  Worker Node: $WORKER_NODE"
else
    print_status "  Worker Node: Using existing configuration"
fi
print_status "  Image: $IMAGE"

# Set up trap to restore files on script exit (but not during cleanup)
CLEANUP_IN_PROGRESS=false
trap 'if [[ "$CLEANUP_IN_PROGRESS" != "true" ]]; then restore_original_files; fi' EXIT

# Check for redeploy flag
if [[ "$REDEPLOY" == "true" ]]; then
    cleanup_all
fi

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    print_error "helm is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

print_status "Connected to Kubernetes cluster: $(kubectl config current-context)"

# Production-specific functions
check_production_requirements() {
    if [[ "$PRODUCTION" == "true" ]]; then
        print_status "🔍 Checking production requirements..."
        
        # Check available nodes
        TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
        READY_NODES=$(kubectl get nodes --no-headers | grep -c "Ready")
        
        print_status "Total nodes: $TOTAL_NODES, Ready nodes: $READY_NODES"
        
        if [[ $READY_NODES -lt 2 ]]; then
            print_warning "Only $READY_NODES nodes available - consider adding more nodes for production"
        fi
        
        # Check node taints
        print_status "Checking node taints..."
        kubectl get nodes -o custom-columns="NAME:.metadata.name,TAINTS:.spec.taints[*].key" | grep -v "NAME" | while read node taints; do
            if [[ -n "$taints" ]]; then
                print_warning "Node $node has taints: $taints"
            else
                print_status "Node $node has no taints"
            fi
        done
        
        # Check for control-plane taints specifically
        if kubectl get nodes -o jsonpath='{.items[*].spec.taints[?(@.key=="node-role.kubernetes.io/control-plane")]}' | grep -q "control-plane"; then
            print_warning "Control-plane nodes have taints - canopy pods will tolerate them"
        fi
    fi
}

setup_production_storage() {
    if [[ "$PRODUCTION" == "true" ]]; then
        print_status "Setting up production storage..."
        
        # Check available storage classes
        if kubectl get storageclass &> /dev/null; then
            print_status "Available storage classes:"
            kubectl get storageclass
            
            # Check for cloud provider storage
            if kubectl get storageclass standard &> /dev/null; then
                PROVISIONER=$(kubectl get storageclass standard -o jsonpath='{.provisioner}')
                if [[ "$PROVISIONER" == "k8s.io/minikube-hostpath" ]]; then
                    print_warning "Detected Minikube - this should not be used in production!"
                    print_status "Using Minikube standard storage class"
                    # Update files to use standard storage class
                    sed -i 's/storageClassName: "openebs-hostpath"/storageClassName: "standard"/g' ../canopy/canopy-nodes.yaml
                    sed -i 's/storageClassName: openebs-hostpath/storageClassName: standard/g' ../canopy/canopy-pvcs.yaml
                    sed -i 's/storageClassName: openebs-hostpath/storageClassName: standard/g' ../monitoring/monitoring-pvcs.yaml
                    sed -i 's/storageClass: "openebs-hostpath"/storageClass: "standard"/g' ../helm-charts/*/values.yaml
                elif [[ "$PROVISIONER" == "ebs.csi.aws.com" ]] || [[ "$PROVISIONER" == "pd.csi.storage.gke.io" ]] || [[ "$PROVISIONER" == "disk.csi.azure.com" ]]; then
                    print_status "Using cloud provider storage class: $PROVISIONER"
                    # Update files to use standard storage class
                    sed -i 's/storageClassName: "openebs-hostpath"/storageClassName: "standard"/g' ../canopy/canopy-nodes.yaml
                    sed -i 's/storageClassName: openebs-hostpath/storageClassName: standard/g' ../canopy/canopy-pvcs.yaml
                    sed -i 's/storageClassName: openebs-hostpath/storageClassName: standard/g' ../monitoring/monitoring-pvcs.yaml
                    sed -i 's/storageClass: "openebs-hostpath"/storageClass: "standard"/g' ../helm-charts/*/values.yaml
                fi
            fi
        fi
    fi
}

restore_storage_class_names() {
    if [[ "$PRODUCTION" == "true" ]]; then
        # Restore original storage class names in files (if they were changed)
        if kubectl get storageclass standard &> /dev/null; then
            PROVISIONER=$(kubectl get storageclass standard -o jsonpath='{.provisioner}')
            if [[ "$PROVISIONER" != "kubernetes.io/no-provisioner" ]]; then
                print_status "Restoring original storage class names in files..."
                # Restore canopy PVCs
                sed -i 's/storageClassName: standard/storageClassName: openebs-hostpath/g' ../canopy/canopy-nodes.yaml
                sed -i 's/storageClassName: standard/storageClassName: openebs-hostpath/g' ../canopy/canopy-pvcs.yaml
                sed -i 's/storageClassName: standard/storageClassName: openebs-hostpath/g' ../monitoring/monitoring-pvcs.yaml
                # Restore Helm chart values
                sed -i 's/storageClass: "standard"/storageClass: "openebs-hostpath"/g' ../helm-charts/*/values.yaml
                print_status "Original storage class names restored"
            fi
        fi
    fi
}

# Production validation and setup
check_production_requirements
setup_production_storage

# Setup storage first
setup_storage $NODES

# Update worker node affinity if specified
if [[ -n "$WORKER_NODE" ]]; then
    print_status "Updating worker node affinity to use: $WORKER_NODE"
    
    # Update storage-class.yaml with new worker node
    if [ -f "../storage-class.yaml" ]; then
        sed -i "s/- node1  # Replace with your actual node name/- $WORKER_NODE/g" ../storage-class.yaml
        print_status "Updated storage-class.yaml with worker node: $WORKER_NODE"
    fi
    
    # Update canopy-nodes.yaml to add node affinity
    if [ -f "../canopy/canopy-nodes.yaml" ]; then
        # Create a backup of the original file
        cp ../canopy/canopy-nodes.yaml ../canopy/canopy-nodes.yaml.backup
        
        # Add node affinity to the pod spec (inside the StatefulSet template)
        # Find the line after "spec:" in the pod template and add nodeAffinity
        awk -v worker_node="$WORKER_NODE" '
        /^      spec:$/ {
            print $0
            print "        nodeAffinity:"
            print "          required:"
            print "            nodeSelectorTerms:"
            print "            - matchExpressions:"
            print "              - key: kubernetes.io/hostname"
            print "                operator: In"
            print "                values:"
            print "                - " worker_node
            next
        }
        { print }
        ' ../canopy/canopy-nodes.yaml > ../canopy/canopy-nodes.yaml.tmp && mv ../canopy/canopy-nodes.yaml.tmp ../canopy/canopy-nodes.yaml
        
        print_status "Added node affinity to canopy-nodes.yaml for worker node: $WORKER_NODE"
    fi
fi

# Update image in canopy-nodes.yaml
print_status "Setting container image to: $IMAGE"

# Update canopy-nodes.yaml with image
if [ -f "../canopy/canopy-nodes.yaml" ]; then
    # Create a backup if not already created
    if [ ! -f "../canopy/canopy-nodes.yaml.backup" ]; then
        cp ../canopy/canopy-nodes.yaml ../canopy/canopy-nodes.yaml.backup
    fi
    
    # Update the image in the StatefulSet
    sed -i "s|image: nodefleet/canopy:[^[:space:]]*|image: $IMAGE|g" ../canopy/canopy-nodes.yaml
    print_status "Updated canopy-nodes.yaml with image: $IMAGE"
fi


# Create namespaces
print_status "Creating namespaces..."
kubectl apply -f ../canopy/canopy-namespace.yaml
kubectl apply -f ../monitoring/monitoring-namespace.yaml
print_status "Namespaces created successfully"

# Create Docker registry secrets
print_status "Setting up Docker registry secrets..."
if [ -f "./scripts/create-docker-secret.sh" ]; then
    print_status "Running Docker secret creation script..."
    ./scripts/create-docker-secret.sh
else
    print_warning "Docker secret creation script not found. Please run ./scripts/create-docker-secret.sh manually if needed."
fi

# Note: We don't need to create separate PVCs anymore since StatefulSet will create them automatically
# and monitoring components use Helm charts that create their own PVCs

# Update PVC storage class if using Minikube
if kubectl get storageclass standard &> /dev/null; then
    PROVISIONER=$(kubectl get storageclass standard -o jsonpath='{.provisioner}')
    if [[ "$PROVISIONER" == "k8s.io/minikube-hostpath" ]]; then
        print_status "Detected Minikube - updating PVC files to use 'standard' storage class"
        # Update canopy PVCs
        sed -i 's/storageClassName: openebs-hostpath/storageClassName: standard/g' ../canopy/canopy-pvcs.yaml
        # Update monitoring PVCs
        sed -i 's/storageClassName: openebs-hostpath/storageClassName: standard/g' ../monitoring/monitoring-pvcs.yaml
        # Update Helm chart values
        sed -i 's/storageClass: "openebs-hostpath"/storageClass: "standard"/g' ../helm-charts/prometheus/values.yaml
        sed -i 's/storageClass: "openebs-hostpath"/storageClass: "standard"/g' ../helm-charts/grafana/values.yaml
        sed -i 's/storageClass: "openebs-hostpath"/storageClass: "standard"/g' ../helm-charts/loki/values.yaml
        sed -i 's/storageClass: "openebs-hostpath"/storageClass: "standard"/g' ../helm-charts/traefik/values.yaml
        print_status "PVC files and Helm chart values updated for Minikube"
    fi
fi

# Create canopy ConfigMaps (delete and recreate for fresh config)
print_status "Creating fresh canopy ConfigMaps..."
kubectl delete -f ../canopy/canopy-configmaps.yaml --ignore-not-found=true
sleep 2
kubectl apply -f ../canopy/canopy-configmaps.yaml
print_status "Fresh canopy ConfigMaps created successfully"

# Verify canopy ConfigMaps are created
print_status "Verifying canopy ConfigMaps..."
kubectl get configmap canopy-genesis -n canopy
kubectl get configmap canopy-config-template -n canopy
print_status "Canopy ConfigMaps verified successfully"

# Deploy Canopy nodes
print_status "Deploying Canopy nodes with $NODES replicas..."
kubectl apply -f ../canopy/canopy-nodes.yaml

# Scale to the specified number of replicas
print_status "Scaling StatefulSet to $NODES replicas..."
kubectl scale statefulset canopy-node --replicas=$NODES -n canopy

print_status "Canopy nodes deployed successfully"

# Auto-generate individual services for canopy nodes
print_status "Auto-generating individual services for canopy nodes..."

# Function to create service for a node
create_node_service() {
    local node_num=$1
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: node${node_num}
  namespace: canopy
  labels:
    app: canopy-node
    node: node${node_num}
spec:
  selector:
    app: canopy-node
    statefulset.kubernetes.io/pod-name: canopy-node-$((node_num-1))
  ports:
  - name: wallet
    port: 50000
    targetPort: 50000
  - name: explorer
    port: 50001
    targetPort: 50001
  - name: rpc
    port: 50002
    targetPort: 50002
  - name: admin-rpc
    port: 50003
    targetPort: 50003
  - name: p2p
    port: 9001
    targetPort: 9001
  - name: metrics
    port: 9090
    targetPort: 9090
  type: ClusterIP
EOF
}

# Use the specified number of nodes for service creation
CANOPY_REPLICAS=$NODES
print_status "Creating services for $CANOPY_REPLICAS canopy nodes..."

# Create individual services for each node
for i in $(seq 1 $CANOPY_REPLICAS); do
    print_status "Creating service for node$i..."
    create_node_service $i
done

print_status "Individual node services created successfully"

# Deploy monitoring stack with Helm
print_status "Deploying monitoring stack with Helm..."

# Deploy Prometheus
print_status "Installing Prometheus..."
helm install prometheus ../helm-charts/prometheus \
  --namespace monitoring \
  --create-namespace 

# Deploy Loki
print_status "Installing Loki..."
helm install loki ../helm-charts/loki \
  --namespace monitoring \
  --create-namespace

# Deploy Grafana
print_status "Installing Grafana..."
helm install grafana ../helm-charts/grafana \
  --namespace monitoring \
  --create-namespace 

# Deploy Traefik
print_status "Installing Traefik..."
helm install traefik ../helm-charts/traefik \
  --namespace monitoring \
  --create-namespace \
  --set canopy.nodeCount=$CANOPY_REPLICAS

# Deploy remaining components
print_status "Deploying remaining monitoring components..."
kubectl apply -f blackbox-config.yaml
kubectl apply -f node-monitoring.yaml
kubectl apply -f monitoring-services.yaml

print_status "Monitoring stack deployed successfully!"

# Wait for pods to be ready
print_status "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=loki -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=traefik -n monitoring --timeout=300s
kubectl wait --for=condition=ready pod -l app=canopy-node -n canopy --timeout=600s

print_status "All pods are ready!"

# Restore original storage class names in files
restore_storage_class_names

# Display status
echo ""
print_status "Deployment completed successfully!"
echo ""
print_status "Current status:"
echo "=================="

echo ""
print_status "Storage:"
kubectl get storageclass
echo ""
kubectl get pv 2>/dev/null | head -10 || print_status "No PVs found (using dynamic provisioning)"

echo ""
print_status "Canopy namespace:"
kubectl get pods -n canopy

echo ""
print_status "Monitoring namespace:"
kubectl get pods -n monitoring

echo ""
print_status "Helm releases:"
helm list -n monitoring

echo ""
print_status "Services:"
kubectl get svc -n canopy
kubectl get svc -n monitoring

echo ""
print_status "Individual Node Services:"
kubectl get svc -l app=canopy-node -n canopy

echo ""
print_status "Access Information:"
echo "========================"
echo "Grafana: http://monitoring.canopy.nodefleet.net (via Traefik)"
echo "Traefik Dashboard: http://traefik.canopy.nodefleet.net/dashboard/"
echo "Prometheus: Internal service at prometheus.monitoring.svc.cluster.local:9090"
echo "Loki: Internal service at loki.monitoring.svc.cluster.local:3100"

echo ""
print_status "Canopy Node Access (via Traefik):"
echo "Individual Nodes (External):"
for i in $(seq 1 $CANOPY_REPLICAS); do
    echo "  Node $i Wallet: https://wallet.node$i.canopy.nodefleet.net"
    echo "  Node $i Explorer: https://explorer.node$i.canopy.nodefleet.net"
    echo "  Node $i RPC: https://rpc.node$i.canopy.nodefleet.net"
    echo "  Node $i Admin RPC: https://adminrpc.node$i.canopy.nodefleet.net"
done

echo ""
print_status "Internal Kubernetes Access:"
echo "Load Balanced: http://canopy-node.canopy.svc.cluster.local:50002"
echo "Individual Nodes:"
for i in $(seq 1 $CANOPY_REPLICAS); do
    echo "  Node $i: http://node$i.canopy.svc.cluster.local:50002"
done

echo ""
print_status "Port Forward Examples:"
echo "kubectl port-forward service/grafana 3000:3000 -n monitoring"
echo "kubectl port-forward service/canopy-node 50002:50002 -n canopy"
for i in $(seq 1 $CANOPY_REPLICAS); do
    echo "kubectl port-forward service/node$i 5000$i:50002 -n canopy"
done

echo ""
print_warning "Note: You may need to configure your DNS or ingress to access external services"
print_warning "SSL certificates should be configured for production use"

echo ""
print_status "To check logs:"
echo "kubectl logs -f canopy-node-0 -n canopy"
echo "kubectl logs -f deployment/grafana -n monitoring"
echo "kubectl logs -f deployment/prometheus -n monitoring"

echo ""
print_status "To redeploy with different number of nodes:"
echo "./helm-deploy.sh --nodes 5"
echo "Or scale existing deployment: kubectl scale statefulset canopy-node --replicas=5 -n canopy && ./auto-generate-services.sh"

echo ""
print_status "To test dynamic configuration:"
echo "./test-dynamic-config.sh"

echo ""
print_status "To upgrade Helm releases:"
echo "helm upgrade prometheus ../helm-charts/prometheus -n monitoring"
echo "helm upgrade grafana ../helm-charts/grafana -n monitoring"
echo "helm upgrade loki ../helm-charts/loki -n monitoring"
echo "helm upgrade traefik ../helm-charts/traefik -n monitoring --set canopy.nodeCount=\$CANOPY_REPLICAS"

echo ""
print_status "To uninstall Helm releases:"
echo "helm uninstall prometheus grafana loki traefik -n monitoring"

echo ""
print_status "To clean up and redeploy:"
echo "./helm-deploy.sh --redeploy --nodes $CANOPY_REPLICAS"
if [[ "$PRODUCTION" == "true" ]]; then
    echo "./helm-deploy.sh --redeploy --production --nodes $CANOPY_REPLICAS"
fi
echo ""
print_status "To clean up without redeploying:"
echo "./cleanup-monitoring.sh"

if [[ "$PRODUCTION" == "true" ]]; then
    echo ""
    print_status "Production deployment completed!"
    print_status "Canopy nodes are now running with proper taint tolerations and node affinity."
    echo ""
    print_status "Node scheduling info:"
    kubectl get pods -n canopy -o wide
fi 

