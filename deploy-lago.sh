#!/bin/bash

# Lago Kubernetes Deployment Script
# This script deploys the complete Lago billing application stack

set -e

echo "🚀 Starting Lago Kubernetes Deployment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
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

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed or not in PATH"
    exit 1
fi

# Check if we can connect to Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster. Please ensure:"
    echo "  - Kubernetes cluster is running"
    echo "  - kubectl is configured with proper context"
    echo "  - You have necessary permissions"
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Check if required files exist
required_files=("lago.yaml" "lago-frontend-env.yaml" "lago-rsa-secrets.yaml")
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        print_error "Required file $file not found"
        exit 1
    fi
done

print_success "All required manifest files found"

# Deploy RSA secrets first
print_status "Deploying RSA secrets..."
kubectl apply -f lago-rsa-secrets.yaml
print_success "RSA secrets deployed"

# Deploy frontend environment configuration
print_status "Deploying frontend environment configuration..."
kubectl apply -f lago-frontend-env.yaml
print_success "Frontend environment configuration deployed"

# Deploy the main Lago stack
print_status "Deploying Lago application stack..."
kubectl apply -f lago.yaml
print_success "Lago application stack deployed"

# Wait for deployments to be ready
print_status "Waiting for deployments to become ready..."

deployments=("lago-postgres" "lago-redis" "lago-api" "lago-front" "lago-worker" "lago-clock" "lago-pdf")

for deployment in "${deployments[@]}"; do
    print_status "Waiting for $deployment to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/$deployment
    print_success "$deployment is ready"
done

# Check pod status
print_status "Checking pod status..."
kubectl get pods -o wide

# Check services
print_status "Checking services..."
kubectl get services

# Check persistent volumes
print_status "Checking persistent volumes..."
kubectl get pvc

print_success "🎉 Lago deployment completed successfully!"

echo ""
echo "📋 Access Information:"
echo "===================="

# Check if ingress is available
if kubectl get ingress lago-ingress &> /dev/null; then
    echo "🌐 Ingress configured:"
    echo "   Frontend: http://lago.local"
    echo "   API: http://lago.local/api"
    echo ""
    echo "📝 To access via ingress, add this to your /etc/hosts file:"
    echo "   echo '127.0.0.1 lago.local' | sudo tee -a /etc/hosts"
    echo ""
fi

echo "🔧 Port forwarding (alternative access):"
echo "   Frontend: kubectl port-forward service/lago-front 8080:80"
echo "   API:      kubectl port-forward service/lago-api 3000:3000"
echo ""

echo "📊 Monitoring commands:"
echo "   Logs: kubectl logs -f deployment/lago-api"
echo "   Status: kubectl get pods"
echo "   Events: kubectl get events --sort-by=.metadata.creationTimestamp"
echo ""

print_warning "⚠️  Security Notice:"
echo "   This deployment uses default credentials and keys."
echo "   For production use, please update:"
echo "   - PostgreSQL password in lago-secrets"
echo "   - RSA keys in lago-rsa-keys"
echo "   - Encryption keys in lago-secrets"
echo ""

print_success "Deployment completed! Check the DEPLOYMENT_GUIDE.md for detailed information."