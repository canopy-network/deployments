#!/bin/bash

# Script to fix stuck PVCs and update StatefulSets
set -e

echo "🔧 Fixing stuck PVCs and updating StatefulSets..."

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

# Get the default storage class
DEFAULT_SC=$(kubectl get storageclass -o jsonpath='{.items[?(@.metadata.annotations.storageclass\.kubernetes\.io/is-default-class=="true")].metadata.name}')
if [ -z "$DEFAULT_SC" ]; then
    DEFAULT_SC="standard"
fi

echo "📋 Using storage class: $DEFAULT_SC"

# Function to fix stuck PVC
fix_stuck_pvc() {
    local namespace=$1
    local pvc_name=$2
    
    echo ""
    echo "🔧 Fixing stuck PVC: $pvc_name in namespace $namespace"
    
    # Check if PVC exists
    if ! kubectl get pvc "$pvc_name" -n "$namespace" &> /dev/null; then
        echo "  PVC doesn't exist, skipping..."
        return
    fi
    
    # Get PVC status
    PVC_STATUS=$(kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    echo "  Current status: $PVC_STATUS"
    
    # If PVC is stuck in deletion, remove finalizers
    if kubectl get pvc "$pvc_name" -n "$namespace" -o jsonpath='{.metadata.deletionTimestamp}' &> /dev/null; then
        echo "  PVC is stuck in deletion, removing finalizers..."
        kubectl patch pvc "$pvc_name" -n "$namespace" -p '{"metadata":{"finalizers":[]}}' --type=merge
        echo "  ✅ Finalizers removed"
    fi
    
    # Delete the PVC
    echo "  Deleting PVC..."
    kubectl delete pvc "$pvc_name" -n "$namespace" --ignore-not-found=true --wait=false
    sleep 2
    
    # If still exists, force remove finalizers again
    if kubectl get pvc "$pvc_name" -n "$namespace" &> /dev/null; then
        echo "  PVC still exists, force removing finalizers..."
        kubectl patch pvc "$pvc_name" -n "$namespace" -p '{"metadata":{"finalizers":[]}}' --type=merge
        kubectl delete pvc "$pvc_name" -n "$namespace" --ignore-not-found=true --wait=false
    fi
}

# Fix canopy-localnet StatefulSet
if kubectl get statefulset canopy-localnet-node -n canopy-localnet &> /dev/null; then
    echo ""
    echo "🔄 Fixing canopy-localnet-node StatefulSet..."
    
    # Scale down to 0
    echo "  Scaling down StatefulSet to 0..."
    kubectl scale statefulset canopy-localnet-node -n canopy-localnet --replicas=0
    echo "  Waiting for pods to terminate..."
    sleep 5
    
    # Fix stuck PVCs
    fix_stuck_pvc "canopy-localnet" "canopy-data-canopy-localnet-node-0"
    
    # Update StatefulSet storage class
    echo "  Updating StatefulSet storage class to '$DEFAULT_SC'..."
    kubectl patch statefulset canopy-localnet-node -n canopy-localnet -p '{"spec":{"volumeClaimTemplates":[{"metadata":{"name":"canopy-data"},"spec":{"accessModes":["ReadWriteOnce"],"storageClassName":"'$DEFAULT_SC'","resources":{"requests":{"storage":"50Gi"}}}}]}}'
    
    # Apply the updated YAML to ensure consistency
    if [ -f "../canopy/canopy-localnet-nodes.yaml" ]; then
        echo "  Applying updated YAML..."
        kubectl apply -f ../canopy/canopy-localnet-nodes.yaml
    fi
    
    # Scale back up
    echo "  Scaling StatefulSet back up to 3 replicas..."
    kubectl scale statefulset canopy-localnet-node -n canopy-localnet --replicas=3
    echo "  ✅ canopy-localnet-node StatefulSet fixed"
fi

# Fix canopy StatefulSet (if it has the wrong storage class)
if kubectl get statefulset canopy-node -n canopy &> /dev/null; then
    # Check if any PVCs have wrong storage class
    WRONG_PVCS=$(kubectl get pvc -n canopy -o jsonpath='{range .items[?(@.spec.storageClassName=="openebs-hostpath")]}{.metadata.name}{"\n"}{end}' 2>/dev/null || echo "")
    if [ -n "$WRONG_PVCS" ]; then
        echo ""
        echo "🔄 Fixing canopy-node StatefulSet..."
        
        # Scale down to 0
        echo "  Scaling down StatefulSet to 0..."
        kubectl scale statefulset canopy-node -n canopy --replicas=0
        echo "  Waiting for pods to terminate..."
        sleep 5
        
        # Fix stuck PVCs
        for pvc in $WRONG_PVCS; do
            fix_stuck_pvc "canopy" "$pvc"
        done
        
        # Update StatefulSet
        echo "  Updating StatefulSet storage class to '$DEFAULT_SC'..."
        kubectl patch statefulset canopy-node -n canopy -p '{"spec":{"volumeClaimTemplates":[{"metadata":{"name":"canopy-data"},"spec":{"accessModes":["ReadWriteOnce"],"storageClassName":"'$DEFAULT_SC'","resources":{"requests":{"storage":"50Gi"}}}}]}}'
        
        # Apply updated YAML
        if [ -f "../canopy/canopy-nodes.yaml" ]; then
            echo "  Applying updated YAML..."
            kubectl apply -f ../canopy/canopy-nodes.yaml
        fi
        
        # Scale back up
        REPLICAS=$(kubectl get statefulset canopy-node -n canopy -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "3")
        echo "  Scaling StatefulSet back up to $REPLICAS replicas..."
        kubectl scale statefulset canopy-node -n canopy --replicas=$REPLICAS
        echo "  ✅ canopy-node StatefulSet fixed"
    fi
fi

echo ""
echo "✅ Fix completed!"
echo ""
echo "📋 Current PVC status:"
kubectl get pvc -A

echo ""
echo "📋 Current StatefulSet status:"
kubectl get statefulset -A

echo ""
echo "⏳ Waiting for PVCs to be created and bound..."
sleep 10

echo ""
echo "📋 Final PVC status:"
kubectl get pvc -A

