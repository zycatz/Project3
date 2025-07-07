#!/bin/bash

echo "🔧 Lago Kubernetes Recovery Script"
echo "=================================="

# Function to wait for user confirmation
confirm() {
    read -p "$1 (y/N): " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if kubectl is available
if ! command_exists kubectl; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

echo "📊 Current pod status:"
kubectl get pods | grep lago

echo ""
echo "🔍 Step 1: Checking logs for errors..."
if confirm "Show API pod logs?"; then
    echo "📋 API Pod Logs (last 50 lines):"
    kubectl logs -l app=lago-api --tail=50
fi

if confirm "Show Worker pod logs?"; then
    echo "📋 Worker Pod Logs (last 50 lines):"
    kubectl logs -l app=lago-worker --tail=50
fi

if confirm "Show Clock pod logs?"; then
    echo "📋 Clock Pod Logs (last 50 lines):"
    kubectl logs -l app=lago-clock --tail=50
fi

echo ""
echo "🔧 Step 2: Database initialization (most likely fix)"
if confirm "Run database initialization job?"; then
    echo "🚀 Applying database initialization job..."
    kubectl apply -f lago-db-init-job.yaml
    
    echo "⏳ Waiting for database initialization to complete..."
    kubectl wait --for=condition=complete job/lago-db-init --timeout=300s
    
    echo "📋 Database initialization logs:"
    kubectl logs job/lago-db-init
fi

echo ""
echo "🔄 Step 3: Restart failing services"
if confirm "Restart API deployment?"; then
    kubectl rollout restart deployment/lago-api
fi

if confirm "Restart Worker deployment?"; then
    kubectl rollout restart deployment/lago-worker
fi

if confirm "Restart Clock deployment?"; then
    kubectl rollout restart deployment/lago-clock
fi

echo ""
echo "⏳ Step 4: Monitoring recovery..."
echo "Waiting for deployments to be ready..."

kubectl rollout status deployment/lago-api --timeout=300s
kubectl rollout status deployment/lago-worker --timeout=300s
kubectl rollout status deployment/lago-clock --timeout=300s

echo ""
echo "📊 Final pod status:"
kubectl get pods | grep lago

echo ""
echo "🧪 Step 5: Testing connectivity"
if confirm "Test API health endpoint?"; then
    echo "Testing API health..."
    kubectl exec deployment/lago-front -- curl -f http://lago-api:3000/health || echo "❌ Health check failed"
fi

if confirm "Test GraphQL endpoint?"; then
    echo "Testing GraphQL..."
    kubectl exec deployment/lago-front -- curl -X POST http://lago-api:3000/graphql \
        -H "Content-Type: application/json" \
        -d '{"query":"{ __schema { types { name } } }"}' || echo "❌ GraphQL test failed"
fi

echo ""
echo "✅ Recovery script completed!"
echo ""
echo "If pods are still failing, check the troubleshooting guide:"
echo "📖 lago-pod-troubleshooting-guide.md"
echo ""
echo "Next steps if issues persist:"
echo "1. Check pod logs: kubectl logs -l app=lago-api"
echo "2. Describe pod: kubectl describe pod -l app=lago-api"
echo "3. Check events: kubectl get events --sort-by=.metadata.creationTimestamp"