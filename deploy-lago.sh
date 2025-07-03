#!/bin/bash

# Lago Kubernetes Deployment Script
# This script deploys Lago on Kubernetes using the provided YAML files

set -e  # Exit on any error

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

# Check if connected to cluster
if ! kubectl cluster-info &> /dev/null; then
    print_error "Not connected to a Kubernetes cluster"
    exit 1
fi

print_success "Connected to Kubernetes cluster"

# Check if required files exist
required_files=("lago.yaml" "lago-frontend-env.yaml" "lago-rsa-secrets.yaml")
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        print_error "Required file $file not found"
        exit 1
    fi
done

print_success "All required files found"

# Check if NGINX Ingress Controller is installed
print_status "Checking for NGINX Ingress Controller..."
if kubectl get pods -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx &> /dev/null; then
    print_success "NGINX Ingress Controller found"
else
    print_warning "NGINX Ingress Controller not found"
    read -p "Do you want to install it? (y/n): " install_ingress
    if [[ $install_ingress == "y" || $install_ingress == "Y" ]]; then
        print_status "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml
        print_status "Waiting for Ingress Controller to be ready..."
        kubectl wait --namespace ingress-nginx \
            --for=condition=ready pod \
            --selector=app.kubernetes.io/component=controller \
            --timeout=300s
        print_success "NGINX Ingress Controller installed"
    else
        print_warning "Proceeding without installing Ingress Controller"
    fi
fi

# Deploy Lago components
print_status "Deploying Lago RSA secrets..."
kubectl apply -f lago-rsa-secrets.yaml

print_status "Deploying Lago frontend environment configuration..."
kubectl apply -f lago-frontend-env.yaml

print_status "Deploying main Lago application..."
kubectl apply -f lago.yaml

print_success "All Lago components deployed"

# Wait for pods to be ready
print_status "Waiting for PostgreSQL to be ready..."
kubectl wait --for=condition=ready pod -l app=lago-postgres --timeout=300s

print_status "Waiting for Redis to be ready..."
kubectl wait --for=condition=ready pod -l app=lago-redis --timeout=300s

print_status "Waiting for Lago API to be ready..."
kubectl wait --for=condition=ready pod -l app=lago-api --timeout=300s

print_status "Waiting for Lago Frontend to be ready..."
kubectl wait --for=condition=ready pod -l app=lago-front --timeout=300s

print_success "All pods are ready!"

# Check deployment status
print_status "Deployment Status:"
kubectl get pods
echo ""
kubectl get services
echo ""
kubectl get ingress

# Get ingress IP for hosts file configuration
print_status "Getting Ingress IP address..."
INGRESS_IP=""
if command -v minikube &> /dev/null && minikube status &> /dev/null; then
    INGRESS_IP=$(minikube ip)
    print_success "Minikube detected. Ingress IP: $INGRESS_IP"
else
    # Try to get ingress IP from different sources
    INGRESS_IP=$(kubectl get ingress lago-ingress -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -z "$INGRESS_IP" ]]; then
        INGRESS_IP=$(kubectl get service -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    fi
    if [[ -z "$INGRESS_IP" ]]; then
        INGRESS_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null || echo "")
    fi
fi

if [[ -n "$INGRESS_IP" && "$INGRESS_IP" != "null" ]]; then
    print_success "Ingress IP found: $INGRESS_IP"
    echo ""
    print_warning "To access Lago, you need to add the following to your /etc/hosts file:"
    echo "echo '$INGRESS_IP lago.local' | sudo tee -a /etc/hosts"
    echo ""
    read -p "Do you want to add this entry automatically? (y/n): " add_hosts
    if [[ $add_hosts == "y" || $add_hosts == "Y" ]]; then
        if echo "$INGRESS_IP lago.local" | sudo tee -a /etc/hosts > /dev/null; then
            print_success "Added lago.local to /etc/hosts"
        else
            print_error "Failed to add entry to /etc/hosts"
        fi
    fi
else
    print_warning "Could not determine Ingress IP address"
    print_warning "You may need to configure port forwarding:"
    echo "kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80"
fi

# Check if database needs initialization
print_status "Checking database status..."
if kubectl exec deployment/lago-api -- bundle exec rails runner "puts User.count" &> /dev/null; then
    print_success "Database appears to be initialized"
else
    print_warning "Database may need initialization"
    read -p "Do you want to run database migrations? (y/n): " run_migrations
    if [[ $run_migrations == "y" || $run_migrations == "Y" ]]; then
        print_status "Running database migrations..."
        kubectl exec deployment/lago-api -- bundle exec rails db:migrate
        kubectl exec deployment/lago-api -- bundle exec rails db:seed
        print_success "Database migrations completed"
    fi
fi

echo ""
print_success "🎉 Lago deployment completed!"
echo ""
echo "Access Lago at: http://lago.local"
echo ""
echo "Useful commands:"
echo "  Check pods: kubectl get pods"
echo "  Check logs: kubectl logs -f deployment/lago-api"
echo "  Check frontend logs: kubectl logs -f deployment/lago-front"
echo "  Scale API: kubectl scale deployment lago-api --replicas=3"
echo ""
echo "For troubleshooting, check the deployment guide: lago-kubernetes-deployment-guide.md"