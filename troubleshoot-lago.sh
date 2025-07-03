#!/bin/bash

# Lago Troubleshooting Script
# This script helps diagnose common deployment issues

echo "🔍 Lago Kubernetes Troubleshooting..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "================================"
echo "1. CHECKING CLUSTER CONNECTION"
echo "================================"

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found"
    exit 1
fi

if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to cluster"
    exit 1
fi

print_success "Connected to cluster"

echo ""
echo "================================"
echo "2. CHECKING POD STATUS"
echo "================================"

echo "All pods:"
kubectl get pods -o wide

echo ""
echo "Pods with issues:"
kubectl get pods | grep -v Running | grep -v Completed

echo ""
echo "================================"
echo "3. CHECKING DEPLOYMENTS"
echo "================================"

kubectl get deployments

echo ""
echo "================================"
echo "4. CHECKING SPECIFIC LAGO COMPONENTS"
echo "================================"

components=("lago-postgres" "lago-redis" "lago-api" "lago-front" "lago-worker" "lago-clock" "lago-pdf")

for component in "${components[@]}"; do
    echo ""
    print_status "Checking $component..."
    
    # Check if deployment exists
    if kubectl get deployment "$component" &> /dev/null; then
        echo "  ✅ Deployment exists"
        
        # Check pod status
        pod_status=$(kubectl get pods -l app="$component" -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "NotFound")
        echo "  📊 Pod status: $pod_status"
        
        # Check if pod is ready
        ready_status=$(kubectl get pods -l app="$component" -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "Unknown")
        echo "  🔄 Ready status: $ready_status"
        
        # If pod is not running, show more details
        if [[ "$pod_status" != "Running" ]]; then
            print_warning "Pod not running, checking events..."
            kubectl describe pod -l app="$component" | grep -A 10 "Events:"
            
            print_warning "Checking logs (if available)..."
            kubectl logs -l app="$component" --tail=20 2>/dev/null || echo "  No logs available"
        fi
    else
        print_error "Deployment not found"
    fi
done

echo ""
echo "================================"
echo "5. CHECKING SERVICES"
echo "================================"

kubectl get services

echo ""
echo "================================"
echo "6. CHECKING PERSISTENT VOLUMES"
echo "================================"

echo "PVCs:"
kubectl get pvc

echo ""
echo "PVs:"
kubectl get pv

echo ""
echo "================================"
echo "7. CHECKING CONFIGMAPS AND SECRETS"
echo "================================"

echo "ConfigMaps:"
kubectl get configmap | grep lago

echo ""
echo "Secrets:"
kubectl get secret | grep lago

echo ""
echo "================================"
echo "8. CHECKING INGRESS"
echo "================================"

kubectl get ingress

echo ""
echo "Ingress details:"
kubectl describe ingress lago-ingress 2>/dev/null || echo "Ingress not found"

echo ""
echo "================================"
echo "9. QUICK FIXES"
echo "================================"

echo "If you see issues, try these commands:"
echo ""
echo "🔄 Restart deployments:"
echo "  kubectl rollout restart deployment/lago-api"
echo "  kubectl rollout restart deployment/lago-front"
echo ""
echo "📊 Check detailed pod status:"
echo "  kubectl describe pod <pod-name>"
echo ""
echo "📝 Check logs:"
echo "  kubectl logs deployment/lago-api"
echo "  kubectl logs deployment/lago-front"
echo ""
echo "🗑️ Delete and recreate (if needed):"
echo "  kubectl delete pod -l app=lago-api"
echo "  kubectl delete pod -l app=lago-front"
echo ""
echo "🔍 Check resource usage:"
echo "  kubectl top pods"
echo "  kubectl top nodes"

echo ""
echo "================================"
echo "10. COMMON ISSUES & SOLUTIONS"
echo "================================"

echo "❌ 'container not found' error:"
echo "   - Wait for pods to fully start (can take 2-5 minutes)"
echo "   - Check if image can be pulled: kubectl describe pod <pod-name>"
echo "   - Restart the deployment: kubectl rollout restart deployment/lago-api"
echo ""

echo "❌ Pods stuck in Pending:"
echo "   - Check if PVCs are bound: kubectl get pvc"
echo "   - Check node resources: kubectl describe nodes"
echo "   - Check for scheduling issues: kubectl describe pod <pod-name>"
echo ""

echo "❌ ImagePullBackOff errors:"
echo "   - Check internet connectivity"
echo "   - Verify image names in deployments"
echo "   - Check if running on private cluster with registry access"
echo ""

echo "❌ Database connection issues:"
echo "   - Ensure PostgreSQL is running: kubectl get pods -l app=lago-postgres"
echo "   - Check database logs: kubectl logs deployment/lago-postgres"
echo "   - Verify ConfigMap values: kubectl describe configmap lago-config"
echo ""

echo "🎯 Next steps if issues persist:"
echo "1. Run: kubectl get events --sort-by=.metadata.creationTimestamp"
echo "2. Check specific pod logs: kubectl logs <pod-name> -c <container-name>"
echo "3. Describe problematic pods: kubectl describe pod <pod-name>"