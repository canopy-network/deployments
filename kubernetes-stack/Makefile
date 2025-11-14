# Canopy Kubernetes Stack Makefile
# Load .env if it exists
ifneq (,$(wildcard .env))
  include .env
  export
endif

.PHONY: help check-kubectl check-cluster namespaces pvcs configmaps verify-configmaps monitoring canopy wait status logs clean deploy download-localnet-files generate-localnet-configmaps localnet-configmaps localnet-canopy localnet-wait deploy-localnet clean-localnet fix-storage fix-pvc

# Default target
help:
	@echo "Canopy Kubernetes Stack - Available targets:"
	@echo "  make deploy          - Full deployment (all steps)"
	@echo "  make namespaces      - Create namespaces"
	@echo "  make pvcs            - Create persistent volume claims"
	@echo "  make configmaps      - Create ConfigMaps"
	@echo "  make verify-configmaps - Verify canopy ConfigMaps"
	@echo "  make monitoring      - Deploy monitoring stack"
	@echo "  make canopy          - Deploy Canopy nodes"
	@echo "  make wait            - Wait for pods to be ready"
	@echo "  make status          - Show deployment status"
	@echo "  make logs            - Show logs commands"
	@echo "  make clean           - Clean up deployment"
	@echo "  make check-kubectl   - Check if kubectl is available"
	@echo "  make check-cluster   - Check cluster connectivity"
	@echo ""
	@echo "Localnet Deployment (3 nodes with files from GitHub):"
	@echo "  make download-localnet-files - Download localnet files from GitHub"
	@echo "  make generate-localnet-configmaps - Generate ConfigMaps from downloaded files"
	@echo "  make localnet-configmaps - Apply localnet ConfigMaps"
	@echo "  make localnet-canopy - Deploy localnet Canopy nodes (3 nodes)"
	@echo "  make localnet-wait - Wait for localnet pods to be ready"
	@echo "  make deploy-localnet - Full localnet deployment (all steps)"
	@echo "  make clean-localnet - Clean up localnet deployment"
	@echo "  make localnet-namespace - Create canopy-localnet namespace"
	@echo ""
	@echo "Troubleshooting:"
	@echo "  make fix-storage - Fix storage class issues for local clusters"
	@echo "  make fix-pvc - Fix stuck PVCs (removes finalizers, updates StatefulSets)"

# Check if kubectl is available
check-kubectl:
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ ERROR: kubectl is not installed or not in PATH"; exit 1; }
	@echo "✅ kubectl is available"

# Check if cluster is accessible
check-cluster:
	@kubectl cluster-info >/dev/null 2>&1 || { echo "❌ ERROR: Cannot connect to Kubernetes cluster"; exit 1; }
	@echo "✅ Connected to Kubernetes cluster: $$(kubectl config current-context)"

# Create namespaces
namespaces: check-kubectl check-cluster
	@echo "🚀 Creating namespaces..."
	@kubectl apply -f canopy/canopy-namespace.yaml
	@kubectl apply -f monitoring/monitoring-namespace.yaml
	@echo "✅ Namespaces created successfully"

# Create persistent volume claims
pvcs: check-kubectl check-cluster
	@echo "🚀 Creating persistent volume claims..."
	@kubectl apply -f canopy/canopy-pvcs.yaml
	@kubectl apply -f monitoring/monitoring-pvcs.yaml
	@echo "✅ PVCs created successfully"

# Create ConfigMaps
configmaps: check-kubectl check-cluster
	@echo "🚀 Creating ConfigMaps..."
	@kubectl apply -f monitoring/prometheus-config.yaml
	@kubectl apply -f monitoring/loki-config.yaml
	@kubectl apply -f monitoring/blackbox-config.yaml
	@kubectl apply -f monitoring/grafana-datasources.yaml
	@kubectl apply -f monitoring/grafana-dashboards.yaml
	@kubectl apply -f monitoring/grafana-alerting.yaml
	@kubectl apply -f monitoring/haproxy-config.yaml
	@kubectl apply -f canopy/canopy-configmaps.yaml
	@echo "✅ ConfigMaps created successfully"

# Verify canopy ConfigMaps are created
verify-configmaps: check-kubectl check-cluster
	@echo "🚀 Verifying canopy ConfigMaps..."
	@kubectl get configmap canopy-genesis -n canopy
	@kubectl get configmap all-node-configs -n canopy
	@echo "✅ Canopy ConfigMaps verified successfully"

# Deploy monitoring stack
monitoring: check-kubectl check-cluster
	@echo "🚀 Deploying monitoring stack..."
	@kubectl apply -f monitoring/node-monitoring.yaml
	@kubectl apply -f monitoring/monitoring-stack.yaml
	@kubectl apply -f monitoring/haproxy.yaml
	@kubectl apply -f monitoring/monitoring-services.yaml
	@echo "✅ Monitoring stack deployed successfully"

# Deploy Canopy nodes
canopy: check-kubectl check-cluster
	@echo "🚀 Deploying Canopy nodes..."
	@kubectl apply -f canopy/canopy-nodes.yaml
	@echo "✅ Canopy nodes deployed successfully"

# Wait for pods to be ready
wait: check-kubectl check-cluster
	@echo "⏳ Waiting for pods to be ready..."
	@kubectl wait --for=condition=ready pod -l app=prometheus -n monitoring --timeout=300s || true
	@kubectl wait --for=condition=ready pod -l app=grafana -n monitoring --timeout=300s || true
	@kubectl wait --for=condition=ready pod -l app=loki -n monitoring --timeout=300s || true
	@kubectl wait --for=condition=ready pod -l app=haproxy -n monitoring --timeout=300s || true
	@kubectl wait --for=condition=ready pod -l app=canopy-node -n canopy --timeout=600s || true
	@echo "✅ All pods are ready!"

# Show deployment status
status: check-kubectl check-cluster
	@echo ""
	@echo "📊 Current status:"
	@echo "=================="
	@echo ""
	@echo "Canopy namespace:"
	@kubectl get pods -n canopy || true
	@echo ""
	@echo "Monitoring namespace:"
	@kubectl get pods -n monitoring || true
	@echo ""
	@echo "Services:"
	@kubectl get svc -n canopy || true
	@kubectl get svc -n monitoring || true
	@echo ""
	@echo "📋 Access Information:"
	@echo "======================"
	@echo "Grafana: http://monitoring.canopy.nodefleet.net (via HAProxy)"
	@echo "HAProxy Stats: http://haproxy.monitoring.svc.cluster.local:8404/stats"
	@echo "Prometheus: Internal service at prometheus.monitoring.svc.cluster.local:9090"
	@echo "Loki: Internal service at loki.monitoring.svc.cluster.local:3100"
	@echo ""
	@echo "⚠️  Note: You may need to configure your DNS or ingress to access external services"
	@echo "⚠️  SSL certificates should be configured for production use"

# Show logs commands
logs:
	@echo "📋 To check logs:"
	@echo "kubectl logs -f canopy-node-0 -n canopy"
	@echo "kubectl logs -f deployment/grafana -n monitoring"
	@echo "kubectl logs -f deployment/prometheus -n monitoring"
	@echo ""
	@echo "📋 To scale Canopy nodes:"
	@echo "kubectl scale statefulset canopy-node --replicas=5 -n canopy"

# Clean up deployment
clean: check-kubectl check-cluster
	@echo "🧹 Cleaning up deployment..."
	@kubectl delete -f canopy/canopy-nodes.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/monitoring-stack.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/node-monitoring.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/haproxy.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/monitoring-services.yaml --ignore-not-found=true || true
	@kubectl delete -f canopy/canopy-configmaps.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/grafana-alerting.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/grafana-dashboards.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/grafana-datasources.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/blackbox-config.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/loki-config.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/prometheus-config.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/haproxy-config.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/monitoring-pvcs.yaml --ignore-not-found=true || true
	@kubectl delete -f canopy/canopy-pvcs.yaml --ignore-not-found=true || true
	@kubectl delete -f monitoring/monitoring-namespace.yaml --ignore-not-found=true || true
	@kubectl delete -f canopy/canopy-namespace.yaml --ignore-not-found=true || true
	@echo "✅ Cleanup completed"

# Full deployment (all steps in order)
deploy: check-kubectl check-cluster namespaces pvcs configmaps verify-configmaps monitoring canopy wait status
	@echo ""
	@echo "✅ Deployment completed successfully!"
	@echo ""
	@echo "📋 To check logs:"
	@echo "kubectl logs -f canopy-node-0 -n canopy"
	@echo "kubectl logs -f deployment/grafana -n monitoring"
	@echo "kubectl logs -f deployment/prometheus -n monitoring"
	@echo ""
	@echo "📋 To scale Canopy nodes:"
	@echo "kubectl scale statefulset canopy-node --replicas=5 -n canopy"
	@echo ""
	@echo "📋 To clean up and redeploy:"
	@echo "make clean && make deploy"

# Download localnet files from GitHub
download-localnet-files:
	@echo "📥 Downloading localnet files from GitHub..."
	@./scripts/download-localnet-files.sh

# Generate localnet ConfigMaps from downloaded files
generate-localnet-configmaps:
	@echo "🔧 Generating localnet ConfigMaps..."
	@./scripts/generate-localnet-configmaps.sh

# Apply localnet ConfigMaps
localnet-configmaps: check-kubectl check-cluster
	@echo "🚀 Applying localnet ConfigMaps..."
	@if [ ! -f canopy/canopy-localnet-genesis-keys.yaml ]; then \
		echo "⚠️  Warning: canopy/canopy-localnet-genesis-keys.yaml not found. Running generate-localnet-configmaps..."; \
		$(MAKE) generate-localnet-configmaps; \
	fi
	@kubectl apply -f canopy/canopy-localnet-configmaps.yaml
	@kubectl apply -f canopy/canopy-localnet-genesis-keys.yaml
	@echo "✅ Localnet ConfigMaps applied successfully"

# Deploy localnet Canopy nodes
localnet-canopy: check-kubectl check-cluster
	@echo "🚀 Deploying localnet Canopy nodes (3 nodes)..."
	@kubectl apply -f canopy/canopy-localnet-nodes.yaml
	@echo "✅ Localnet Canopy nodes deployed successfully"

# Wait for localnet pods to be ready
localnet-wait: check-kubectl check-cluster
	@echo "⏳ Waiting for localnet pods to be ready..."
	@kubectl wait --for=condition=ready pod -l app=canopy-localnet-node -n canopy-localnet --timeout=600s || true
	@echo "✅ Localnet pods are ready!"

# Create localnet namespace
localnet-namespace: check-kubectl check-cluster
	@echo "🚀 Creating canopy-localnet namespace..."
	@kubectl apply -f canopy/canopy-localnet-namespace.yaml
	@echo "✅ Localnet namespace created successfully"

# Full localnet deployment (all steps in order)
deploy-localnet: check-kubectl check-cluster localnet-namespace
	@echo "🚀 Starting localnet deployment..."
	@if [ ! -d localnet-files ] || [ -z "$$(ls -A localnet-files 2>/dev/null)" ]; then \
		echo "📥 Localnet files not found. Downloading..."; \
		$(MAKE) download-localnet-files; \
	fi
	@if [ ! -f canopy/canopy-localnet-genesis-keys.yaml ]; then \
		echo "🔧 Generating localnet ConfigMaps..."; \
		$(MAKE) generate-localnet-configmaps; \
	fi
	@$(MAKE) localnet-configmaps
	@$(MAKE) monitoring
	@$(MAKE) localnet-canopy
	@$(MAKE) localnet-wait
	@echo ""
	@echo "✅ Localnet deployment completed successfully!"
	@echo ""
	@echo "📋 Localnet nodes:"
	@kubectl get pods -l app=canopy-localnet-node -n canopy-localnet || true
	@echo ""
	@echo "📋 To check logs:"
	@echo "kubectl logs -f canopy-localnet-node-0 -n canopy-localnet"
	@echo "kubectl logs -f canopy-localnet-node-1 -n canopy-localnet"
	@echo "kubectl logs -f canopy-localnet-node-2 -n canopy-localnet"
	@echo ""
	@echo "📋 To clean up localnet deployment:"
	@echo "make clean-localnet"

# Clean up localnet deployment
clean-localnet: check-kubectl check-cluster
	@echo "🧹 Cleaning up localnet deployment..."
	@kubectl delete -f canopy/canopy-localnet-nodes.yaml --ignore-not-found=true || true
	@kubectl delete -f canopy/canopy-localnet-configmaps.yaml --ignore-not-found=true || true
	@kubectl delete -f canopy/canopy-localnet-genesis-keys.yaml --ignore-not-found=true || true
	@kubectl delete -f canopy/canopy-localnet-namespace.yaml --ignore-not-found=true || true
	@echo "✅ Localnet cleanup completed"

# Fix storage class issues (for local clusters)
fix-storage: check-kubectl check-cluster
	@echo "🔧 Fixing storage class issues..."
	@./scripts/fix-storage-class.sh
	@echo "✅ Storage class fix completed!"

# Fix stuck PVCs (removes finalizers and updates StatefulSets)
fix-pvc: check-kubectl check-cluster
	@echo "🔧 Fixing stuck PVCs..."
	@./scripts/fix-pvc-stuck.sh
	@echo "✅ PVC fix completed!"

