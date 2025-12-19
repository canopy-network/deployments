#!/bin/bash

# Install All Helm Monitoring Charts Script
# This script installs all monitoring helm charts: Prometheus, Loki, Promtail, Blackbox, and Grafana
# Includes Kubernetes Service Discovery for automatic target and log collection
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_CHARTS_DIR="${SCRIPT_DIR}/helm"
NAMESPACE="monitoring"

# Default values
STORAGE_CLASS=""
UPGRADE=false
WAIT_TIMEOUT=300

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --storage-class)
            STORAGE_CLASS="$2"
            shift 2
            ;;
        --upgrade)
            UPGRADE=true
            shift
            ;;
        --timeout)
            WAIT_TIMEOUT="$2"
            if ! [[ "$WAIT_TIMEOUT" =~ ^[0-9]+$ ]]; then
                print_error "Timeout must be a positive integer"
                exit 1
            fi
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Install all Helm monitoring charts (Prometheus, Loki, Promtail, Blackbox, Grafana, kube-state-metrics)"
            echo ""
            echo "Features:"
            echo "  - Prometheus with Kubernetes Service Discovery (auto-discover pods/services)"
            echo "  - kube-state-metrics for Kubernetes object state metrics (kube_pod_info, etc.)"
            echo "  - Promtail DaemonSet for collecting logs from all pods"
            echo "  - Loki for log aggregation"
            echo "  - Grafana with pre-configured dashboards"
            echo ""
            echo "Options:"
            echo "  --namespace <name>      Kubernetes namespace (default: monitoring)"
            echo "  --storage-class <name>  Storage class for persistent volumes (auto-detect if not specified)"
            echo "  --upgrade               Upgrade existing releases instead of installing"
            echo "  --timeout <seconds>     Timeout for waiting for pods to be ready (default: 300)"
            echo "  -h, --help              Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Install all charts in 'monitoring' namespace"
            echo "  $0 --namespace custom-monitoring     # Install in custom namespace"
            echo "  $0 --storage-class standard          # Use specific storage class"
            echo "  $0 --upgrade                         # Upgrade existing releases"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Check prerequisites
print_step "Checking prerequisites..."

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

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

# Check if helm charts directory exists
if [ ! -d "$HELM_CHARTS_DIR" ]; then
    print_error "Helm charts directory not found: $HELM_CHARTS_DIR"
    exit 1
fi

# Detect storage class if not specified
detect_storage_class() {
    if [ -n "$STORAGE_CLASS" ]; then
        print_status "Using specified storage class: $STORAGE_CLASS"
        return
    fi

    print_status "Auto-detecting storage class..."
    
    # Check for common storage classes
    if kubectl get storageclass openebs-hostpath &> /dev/null; then
        STORAGE_CLASS="openebs-hostpath"
        print_status "Detected storage class: $STORAGE_CLASS"
    elif kubectl get storageclass standard &> /dev/null; then
        STORAGE_CLASS="standard"
        print_status "Detected storage class: $STORAGE_CLASS"
    elif kubectl get storageclass local-path &> /dev/null; then
        STORAGE_CLASS="local-path"
        print_status "Detected storage class: $STORAGE_CLASS"
    else
        # Get the default storage class
        DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}' 2>/dev/null | head -n1)
        if [ -n "$DEFAULT_SC" ]; then
            STORAGE_CLASS="$DEFAULT_SC"
            print_status "Using default storage class: $STORAGE_CLASS"
        else
            print_warning "No storage class detected. Charts will use default or empty storage class."
            STORAGE_CLASS=""
        fi
    fi
}

# Create namespace if it doesn't exist
create_namespace() {
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_status "Namespace '$NAMESPACE' already exists"
    else
        print_status "Creating namespace '$NAMESPACE'..."
        kubectl create namespace "$NAMESPACE"
        print_status "Namespace '$NAMESPACE' created successfully"
    fi
}

# Install or upgrade a helm chart
install_chart() {
    local chart_name=$1
    local chart_path=$2
    local release_name=$3
    local extra_args=$4

    if [ ! -d "$chart_path" ]; then
        print_error "Chart directory not found: $chart_path"
        return 1
    fi

    # Check if release already exists
    if helm list -n "$NAMESPACE" | grep -q "^$release_name"; then
        if [ "$UPGRADE" = true ]; then
            print_status "Upgrading $chart_name..."
            helm upgrade "$release_name" "$chart_path" \
                --namespace "$NAMESPACE" \
                $extra_args
        else
            print_warning "$chart_name release '$release_name' already exists. Skipping installation."
            print_warning "Use --upgrade flag to upgrade existing releases."
            return 0
        fi
    else
        print_status "Installing $chart_name..."
        helm install "$release_name" "$chart_path" \
            --namespace "$NAMESPACE" \
            --create-namespace \
            $extra_args
    fi
}

# Install Prometheus
install_prometheus() {
    print_step "Installing Prometheus..."
    
    local extra_args=""
    if [ -n "$STORAGE_CLASS" ]; then
        extra_args="--set server.persistentVolume.storageClass=$STORAGE_CLASS"
    fi
    
    install_chart "Prometheus" \
        "${HELM_CHARTS_DIR}/prometheus" \
        "prometheus" \
        "$extra_args"
}

# Install kube-state-metrics (Kubernetes object state metrics)
install_kube_state_metrics() {
    print_step "Installing kube-state-metrics..."
    
    install_chart "kube-state-metrics" \
        "${HELM_CHARTS_DIR}/kube-state-metrics" \
        "kube-state-metrics" \
        ""
}

# Install Loki
install_loki() {
    print_step "Installing Loki..."
    
    local extra_args=""
    if [ -n "$STORAGE_CLASS" ]; then
        extra_args="--set server.persistentVolume.storageClass=$STORAGE_CLASS"
    fi
    
    install_chart "Loki" \
        "${HELM_CHARTS_DIR}/loki" \
        "loki" \
        "$extra_args"
}

# Install Promtail (log collector with Kubernetes Service Discovery)
install_promtail() {
    print_step "Installing Promtail (Kubernetes log collector)..."
    
    # Promtail runs as DaemonSet on all nodes to collect logs
    install_chart "Promtail" \
        "${HELM_CHARTS_DIR}/promtail" \
        "promtail" \
        ""
}

# Install Blackbox Exporter
install_blackbox() {
    print_step "Installing Blackbox Exporter..."
    
    install_chart "Blackbox Exporter" \
        "${HELM_CHARTS_DIR}/blackbox" \
        "blackbox" \
        ""
}

# Install Grafana
install_grafana() {
    print_step "Installing Grafana..."
    
    local extra_args=""
    if [ -n "$STORAGE_CLASS" ]; then
        extra_args="--set server.persistentVolume.storageClass=$STORAGE_CLASS"
    fi
    
    # Note: Datasources are configured in values.yaml with proper uid, name, type fields
    # Do NOT override with --set as it replaces array items instead of merging
    
    install_chart "Grafana" \
        "${HELM_CHARTS_DIR}/grafana" \
        "grafana" \
        "$extra_args"
}

# Wait for pods to be ready
wait_for_pods() {
    print_step "Waiting for pods to be ready..."
    
    local charts=("prometheus" "kube-state-metrics" "loki" "promtail" "blackbox" "grafana")
    
    for chart in "${charts[@]}"; do
        print_status "Waiting for $chart pods..."
        if kubectl wait --for=condition=ready pod -l app.kubernetes.io/name="$chart" -n "$NAMESPACE" --timeout="${WAIT_TIMEOUT}s" 2>/dev/null; then
            print_status "$chart pods are ready"
        else
            print_warning "$chart pods may not be ready yet. Check with: kubectl get pods -n $NAMESPACE"
        fi
    done
}

# Display installation status
show_status() {
    echo ""
    print_status "Installation Summary"
    echo "======================"
    echo ""
    
    print_status "Helm Releases:"
    helm list -n "$NAMESPACE"
    
    echo ""
    print_status "Pods Status:"
    kubectl get pods -n "$NAMESPACE"
    
    echo ""
    print_status "Services:"
    kubectl get svc -n "$NAMESPACE"
    
    echo ""
    print_status "Persistent Volume Claims:"
    kubectl get pvc -n "$NAMESPACE" 2>/dev/null || print_warning "No PVCs found"
    
    echo ""
    print_status "Access Information:"
    echo "========================"
    echo "Prometheus: http://prometheus.${NAMESPACE}.svc.cluster.local:9090"
    echo "Grafana: http://grafana.${NAMESPACE}.svc.cluster.local:3000"
    echo "Loki: http://loki.${NAMESPACE}.svc.cluster.local:3100"
    echo "Blackbox: http://blackbox.${NAMESPACE}.svc.cluster.local:9115"
    
    echo ""
    print_status "Port Forward Examples:"
    echo "kubectl port-forward -n $NAMESPACE svc/prometheus 9090:9090"
    echo "kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000"
    echo "kubectl port-forward -n $NAMESPACE svc/loki 3100:3100"
    echo "kubectl port-forward -n $NAMESPACE svc/blackbox 9115:9115"
    
    echo ""
    print_status "Grafana Default Credentials:"
    echo "Username: admin"
    echo "Password: admin"
    print_warning "Please change the default password after first login!"
    
    echo ""
    print_status "To check logs:"
    echo "kubectl logs -f deployment/prometheus -n $NAMESPACE"
    echo "kubectl logs -f deployment/grafana -n $NAMESPACE"
    echo "kubectl logs -f deployment/loki -n $NAMESPACE"
    echo "kubectl logs -f daemonset/promtail -n $NAMESPACE"
    echo "kubectl logs -f deployment/blackbox -n $NAMESPACE"
    
    echo ""
    print_status "Kubernetes Service Discovery:"
    echo "========================"
    echo "Prometheus auto-discovers:"
    echo "  - kubernetes-apiservers: Kubernetes API server metrics"
    echo "  - kubernetes-nodes: Node kubelet metrics"
    echo "  - kubernetes-nodes-cadvisor: Container metrics via cAdvisor"
    echo "  - kubernetes-pods: Pods with prometheus.io/scrape=true annotation"
    echo "  - kubernetes-service-endpoints: Services with prometheus.io/scrape=true annotation"
    echo ""
    echo "Promtail auto-collects logs from all pods in the cluster"
    echo ""
    echo "To enable scraping for your pods/services, add annotations:"
    echo "  prometheus.io/scrape: \"true\""
    echo "  prometheus.io/port: \"9090\"      # Optional: custom metrics port"
    echo "  prometheus.io/path: \"/metrics\"  # Optional: custom metrics path"
    
    echo ""
    print_status "To upgrade charts:"
    echo "$0 --upgrade"
    
    echo ""
    print_status "To uninstall all charts:"
    echo "helm uninstall prometheus kube-state-metrics loki promtail blackbox grafana -n $NAMESPACE"
}

# Main execution
main() {
    echo ""
    print_status "🚀 Installing All Helm Monitoring Charts"
    echo "=============================================="
    echo ""
    print_status "Configuration:"
    print_status "  Namespace: $NAMESPACE"
    print_status "  Helm Charts Directory: $HELM_CHARTS_DIR"
    print_status "  Upgrade Mode: $UPGRADE"
    echo ""
    
    # Detect storage class
    detect_storage_class
    
    # Create namespace
    create_namespace
    
    # Install charts in order (with Kubernetes Service Discovery)
    install_prometheus         # Metrics collection with K8s SD
    install_kube_state_metrics # Kubernetes object state metrics
    install_loki               # Log aggregation
    install_promtail           # Log collection DaemonSet with K8s SD
    install_blackbox           # Endpoint monitoring
    install_grafana            # Visualization
    
    # Wait for pods
    wait_for_pods
    
    # Show status
    show_status
    
    echo ""
    print_status "✅ All monitoring charts installed successfully!"
    echo ""
}

# Run main function
main

