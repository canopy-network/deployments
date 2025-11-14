#!/bin/bash

# Script to fix storage class issues for local clusters
# This updates StatefulSets and cleans up Pending PVCs

set -e

echo "🔧 Fixing storage class issues for local cluster..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ ERROR: kubectl is not installed or not in PATH"
    exit 1
fi

# Check if cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ ERROR: Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Connected to Kubernetes cluster: $(kubectl config current-context)"

# Check available storage classes
echo ""
echo "📋 Available storage classes:"
kubectl get storageclass

# Get the default storage class
DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [ -z "$DEFAULT_SC" ]; then
    # Try to find standard or any storage class
    DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "standard")
fi

echo ""
echo "📋 Using storage class: $DEFAULT_SC"

# Update StatefulSets
echo ""
echo "🔄 Updating StatefulSets to use '$DEFAULT_SC' storage class..."

# Update canopy-node StatefulSet
if kubectl get statefulset canopy-node -n canopy &> /dev/null; then
    echo "Updating canopy-node StatefulSet..."
    kubectl patch statefulset canopy-node -n canopy -p '{"spec":{"volumeClaimTemplates":[{"metadata":{"name":"canopy-data"},"spec":{"accessModes":["ReadWriteOnce"],"storageClassName":"'$DEFAULT_SC'","resources":{"requests":{"storage":"50Gi"}}}}]}}'
    echo "✅ Updated canopy-node StatefulSet"
fi

# Update canopy-localnet-node StatefulSet
if kubectl get statefulset canopy-localnet-node -n canopy-localnet &> /dev/null; then
    echo "Updating canopy-localnet-node StatefulSet..."
    kubectl patch statefulset canopy-localnet-node -n canopy-localnet -p '{"spec":{"volumeClaimTemplates":[{"metadata":{"name":"canopy-data"},"spec":{"accessModes":["ReadWriteOnce"],"storageClassName":"'$DEFAULT_SC'","resources":{"requests":{"storage":"50Gi"}}}}]}}'
    echo "✅ Updated canopy-localnet-node StatefulSet"
fi

# Delete Pending PVCs with wrong storage class
echo ""
echo "🧹 Cleaning up Pending PVCs with wrong storage class..."

# Delete Pending PVCs in canopy namespace
PENDING_PVCS=$(kubectl get pvc -n canopy -o jsonpath='{range .items[?(@.status.phase=="Pending")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [ -n "$PENDING_PVCS" ]; then
    echo "Deleting Pending PVCs in canopy namespace..."
    for pvc in $PENDING_PVCS; do
        echo "  Deleting PVC: $pvc"
        kubectl delete pvc "$pvc" -n canopy --ignore-not-found=true
    done
fi

# Delete Pending PVCs in canopy-localnet namespace
PENDING_PVCS_LOCALNET=$(kubectl get pvc -n canopy-localnet -o jsonpath='{range .items[?(@.status.phase=="Pending")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [ -n "$PENDING_PVCS_LOCALNET" ]; then
    echo "Deleting Pending PVCs in canopy-localnet namespace..."
    for pvc in $PENDING_PVCS_LOCALNET; do
        echo "  Deleting PVC: $pvc"
        kubectl delete pvc "$pvc" -n canopy-localnet --ignore-not-found=true
    done
fi

# Delete PVCs with openebs-hostpath storage class
echo ""
echo "🧹 Deleting PVCs with 'openebs-hostpath' storage class..."

# In canopy namespace
OPENEBS_PVCS=$(kubectl get pvc -n canopy -o jsonpath='{range .items[?(@.spec.storageClassName=="openebs-hostpath")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [ -n "$OPENEBS_PVCS" ]; then
    echo "Deleting openebs-hostpath PVCs in canopy namespace..."
    for pvc in $OPENEBS_PVCS; do
        echo "  Deleting PVC: $pvc"
        kubectl delete pvc "$pvc" -n canopy --ignore-not-found=true
    done
fi

# In canopy-localnet namespace
OPENEBS_PVCS_LOCALNET=$(kubectl get pvc -n canopy-localnet -o jsonpath='{range .items[?(@.spec.storageClassName=="openebs-hostpath")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
if [ -n "$OPENEBS_PVCS_LOCALNET" ]; then
    echo "Deleting openebs-hostpath PVCs in canopy-localnet namespace..."
    for pvc in $OPENEBS_PVCS_LOCALNET; do
        echo "  Deleting PVC: $pvc"
        kubectl delete pvc "$pvc" -n canopy-localnet --ignore-not-found=true
    done
fi

# Apply updated YAML files
echo ""
echo "🔄 Applying updated StatefulSet configurations..."
kubectl apply -f ../canopy/canopy-nodes.yaml
if [ -f "../canopy/canopy-localnet-nodes.yaml" ]; then
    kubectl apply -f ../canopy/canopy-localnet-nodes.yaml
fi

echo ""
echo "✅ Storage class fix completed!"
echo ""
echo "📋 Current PVC status:"
kubectl get pvc -A

echo ""
echo "⏳ Waiting for StatefulSets to recreate PVCs..."
sleep 5

echo ""
echo "📋 Final PVC status:"
kubectl get pvc -A

echo ""
echo "✅ Done! The StatefulSets will automatically recreate PVCs with the correct storage class."

