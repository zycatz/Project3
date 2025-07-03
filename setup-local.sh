#!/bin/bash

# Lago Kubernetes Setup Script
# This script creates all necessary files for Lago deployment

echo "🚀 Setting up Lago Kubernetes deployment files..."

# Create lago.yaml
cat > lago.yaml << 'EOF'
# ---------------- CONFIGMAP & SECRETS ----------------
apiVersion: v1
kind: ConfigMap
metadata:
  name: lago-config
data:
  POSTGRES_DB: lago
  POSTGRES_USER: lago
  POSTGRES_HOST: lago-postgres
  POSTGRES_PORT: "5432"
  POSTGRES_SCHEMA: public
  REDIS_HOST: lago-redis
  REDIS_PORT: "6379"
  API_PORT: "3000"
  FRONT_PORT: "80"
  RAILS_ENV: production
  RAILS_LOG_TO_STDOUT: "true"
  LAGO_API_URL: http://lago.local/api
  LAGO_FRONT_URL: http://lago.local
  APP_ENV: production
---
apiVersion: v1
kind: Secret
metadata:
  name: lago-secrets
type: Opaque
stringData:
  POSTGRES_PASSWORD: changeme
  SECRET_KEY_BASE: 1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
  LAGO_ENCRYPTION_PRIMARY_KEY: abcdef1234567890abcdef1234567890
  LAGO_ENCRYPTION_DETERMINISTIC_KEY: 1234567890abcdef1234567890abcdef
  LAGO_ENCRYPTION_KEY_DERIVATION_SALT: salt123456

---
# ---------------- POSTGRES ----------------
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lago-postgres-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Service
metadata:
  name: lago-postgres
spec:
  ports:
    - port: 5432
  selector:
    app: lago-postgres
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-postgres
  template:
    metadata:
      labels:
        app: lago-postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14-alpine
        envFrom:
          - configMapRef:
              name: lago-config
          - secretRef:
              name: lago-secrets
        volumeMounts:
          - name: postgres-storage
            mountPath: /var/lib/postgresql/data
        ports:
          - containerPort: 5432
      volumes:
        - name: postgres-storage
          persistentVolumeClaim:
            claimName: lago-postgres-pvc

---
# ---------------- REDIS ----------------
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: lago-redis-pvc
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 512Mi
---
apiVersion: v1
kind: Service
metadata:
  name: lago-redis
spec:
  ports:
    - port: 6379
  selector:
    app: lago-redis
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-redis
  template:
    metadata:
      labels:
        app: lago-redis
    spec:
      containers:
      - name: redis
        image: redis:6-alpine
        command: ["redis-server", "--port", "6379"]
        volumeMounts:
          - name: redis-storage
            mountPath: /data
        ports:
          - containerPort: 6379
      volumes:
        - name: redis-storage
          persistentVolumeClaim:
            claimName: lago-redis-pvc

---
# ---------------- API ----------------
apiVersion: v1
kind: Service
metadata:
  name: lago-api
spec:
  ports:
    - port: 3000
  selector:
    app: lago-api
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-api
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-api
  template:
    metadata:
      labels:
        app: lago-api
    spec:
      containers:
      - name: api
        image: getlago/api:v1.31.0
        command: ["./scripts/start.api.sh"]
        envFrom:
          - configMapRef:
              name: lago-config
          - secretRef:
              name: lago-secrets
        ports:
          - containerPort: 3000

---
# ---------------- WORKER ----------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-worker
  template:
    metadata:
      labels:
        app: lago-worker
    spec:
      containers:
      - name: worker
        image: getlago/api:v1.31.0
        command: ["./scripts/start.worker.sh"]
        envFrom:
          - configMapRef:
              name: lago-config
          - secretRef:
              name: lago-secrets

---
# ---------------- CLOCK ----------------
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-clock
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-clock
  template:
    metadata:
      labels:
        app: lago-clock
    spec:
      containers:
      - name: clock
        image: getlago/api:v1.31.0
        command: ["./scripts/start.clock.sh"]
        envFrom:
          - configMapRef:
              name: lago-config
          - secretRef:
              name: lago-secrets

---
# ---------------- PDF ----------------
apiVersion: v1
kind: Service
metadata:
  name: lago-pdf
spec:
  ports:
    - port: 3000
  selector:
    app: lago-pdf
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-pdf
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-pdf
  template:
    metadata:
      labels:
        app: lago-pdf
    spec:
      containers:
      - name: pdf
        image: getlago/lago-gotenberg:7.8.2
        ports:
          - containerPort: 3000

---
# ---------------- FRONTEND ----------------
apiVersion: v1
kind: Service
metadata:
  name: lago-front
spec:
  ports:
    - port: 80
  selector:
    app: lago-front
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lago-front
spec:
  replicas: 1
  selector:
    matchLabels:
      app: lago-front
  template:
    metadata:
      labels:
        app: lago-front
    spec:
      containers:
      - name: front
        image: getlago/front:v1.31.0
        envFrom:
          - configMapRef:
              name: lago-config
          - configMapRef:
              name: lago-frontend-env
        ports:
          - containerPort: 80

---
# ---------------- INGRESS ----------------
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: lago-ingress
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - host: lago.local
    http:
      paths:
        - path: /
          pathType: Prefix
          backend:
            service:
              name: lago-front
              port:
                number: 80
        - path: /api
          pathType: Prefix
          backend:
            service:
              name: lago-api
              port:
                number: 3000
EOF

# Create lago-frontend-env.yaml
cat > lago-frontend-env.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: lago-frontend-env
data:
  API_URL: "http://lago.local/api"
  LAGO_DOMAIN: "lago.local"
  APP_ENV: "production"
  LAGO_OAUTH_PROXY_URL: ""
  LAGO_DISABLE_SIGNUP: ""
  NANGO_PUBLIC_KEY: ""
  SENTRY_DSN: ""
  LAGO_DISABLE_PDF_GENERATION: ""
EOF

# Create lago-rsa-secrets.yaml
cat > lago-rsa-secrets.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: lago-rsa-keys
type: Opaque
stringData:
  LAGO_RSA_PRIVATE_KEY: "LS0tLS1CRUdJTiBSU0EgUFJJVkFURSBLRVktLS0tLQpNSUlFb3dJQkFBS0NBUUVBMURTSm9nSFpKd3lqS0lkWTRPdzdWMjIrczZhUWQyRERvdnNQSW84bVhPVnFFMVA2CjM0RUV6cmNuUUM2YlV4eXloWHdyWjJXR0RsRVo4VGpBQmQ5c0ZPOTZ4ZkhKSHhJMkhDVkZqUTZMbjdMbXRUZVYKU01PU3ppTmxUNExDRTYxay9sZHptYjZ1UDRFYW04T3owU2xxS1FWZ3RTMHlVdmJjUEp0TnErNFM0bER5anFudwo3SmlFcmk1UGk2M25QUE90Y1F3aWZmQnpOYUxZSWJXNEYzTWFJNWRNelBRTk8vQTdraFYrU1MyQ3pNZmNVY29sCnVrdzJVeFhuSnAyNlg0UVlxTWRudTdNNjhQajZjYkhBdDBSMFhCVDF1VWlaeGJqYnlvQnpUUkRQaGF3YjEvTXkKSkNESWdUQ0IwdnFLKzVUR1liK3ZJeGZBKzlCQWZmQ0lWcVh5YndJREFRQUJBb0lCQUc1RXFxeER0NXFDQjVwOAowbU4yZmRPTmxJWDM3S1FMNVQwZ3BwbTN0eUNZbWNsWFgwcWEyV3V0WXJrSVB2QXVQbG44enZVWW5WTjlNelRVCjMzdHR3TlVVS0VFSnhnL2VQNzNhWkV6TEhTU3NLeFJKd01vaHpueE5pa3lKenQyNHdYMGs1azRpOXByTE5EOXkKWDFNMTZSTk4xeFh1V1hNaEVncHdUU2tsT2l6ZEhyRnVNVHl6Zk1DMFRzTU04U0ZuWjVSbWtXK1FoTTZFbXhJcApwR3VpbU5RekUwaGFLdEwrblVrNmxyc0RMNnhBRk1LWW9vYjQyQlFXZjFtdWVPcXpFVDdDQ2JDVTZXMkJaNDQzCnM4ZDhGSS9VeWxUZHNITFBZdjdhTGFGOG1EVEdkQnhRaWVtNUY0Y3c2bHNPYXN0a2doaERWc3gvUy9SL3ZFbVkKNmxFQXUxa0NnWUVBOTVicU1waVJUcGJEcWVEMHBHNUlXZEFrVGFpVnA1V20wMXB0ZGtGRzd3bUJUQTBnRzdLTApBenVMeUVZRzRVeFk0cVc5TEhyeW9vY0JscUNhMytia0NBWXZzYVVNVTAyWjFscVJ1clNpVmIwczRsR0c3VDh0CkFweWgrMUlaQzdhYk9vZForN3dGNE9JMG9ES3RnOGNsMW1VdXFQQjdGQlQxNElPRDYxTGx3L01DZ1lFQTIybnEKRTF0T2s2Q1BsVm9NL29oMFAzWVNPTzZneFUxNndVNHFuTDJiSkY0elV2aEZoVFJSd1h2a1lIbjc5eDZ5TDl2ZApiUk9EbDBOZHhSTytKQ2RzakxkWWV2WHN3eml5RWlKcjdObEFla2xwQXE2WGFObjlML3FsS1RtQWpSU2FZdlVICmxUWlhRa2JtcEJrQjBiUzZYcEVyK2hMWDZHNnpHVkJGRHViUkFwVUNnWUJ1Y1NGVEpIOWM0Uit5dmFnaldSWnAKQ2RISDJuVzNaYWdmQzIxY25NMjVmekh2N01MdjEvcnVuRGRFUlFoNG80ZmF3amZhaVpXR0xsYmxEQXRKNlVLNgoyWmVZMUpqazUrN0JrWEVFK2VObi81VHY5NUlLYm0zemhrOHpQbkh4cWFrZ3VNemg0QU4zUnpCV2JZUzlEYTZ4CkxqMWNHcm1zUVpWVWF4WURlTjBKUlFLQmdRQ01zMHloZ1FuUWJVUGwrRXNnNWd2MXJoZGRYdGpGN1R0c3ZsMWgKQ2MxMDh0dGl0MGFOZHRGK2k1NFZwK1BGd205dGRVWjI3ZTZTajJhUVBHclA4R0FSbEhrdTBJazFYeVFCc1FVWQphdkNIK285V1l2TkJENWptcllvLzkxblNIb1lxTXdyYnltOEdWMFVMc2VXU3ZweE1qRGR4TTZnMHF0ZzZ3VmluCmg2ZzhTUUtCZ0RaT0w2cFRKcVFlQnB4aWF1YkMvNHBxQjM0c251QnpVbCtiRHBJKzR2Q2htNFViNWRzcVYxS1cKOEM2UzJlcFgvUCtURzExODNMUzdZdFU1TkVRKy9BOElTeDBCemc0cGJlT0M0SlB2TmhCdEdPaUN0YlVpU3c4RgpOancxTmJtR083NjFmUmJjSHp6bVc0QTU1Q2tqVkFmaHdNMGYzWkNJcUFVOUZrWXc5SE9VCi0tLS0tRU5EIFJTQSBQUklWQVRFIEtFWS0tLS0tCg=="
  LAGO_RSA_PUBLIC_KEY: "LS0tLS1CRUdJTiBQVUJMSUMgS0VZLS0tLS0KTUlJQklqQU5CZ2txaGtpRzl3MEJBUUVGQUFPQ0FROEFNSUlCQ2dLQ0FRRUExRFNKb2dIWkp3eWpLSWRZNE93NwpWMjIrczZhUWQyRERvdnNQSW84bVhPVnFFMVA2MzRFRXpyY25RQzZiVXh5eWhYd3JaMldHRGxFWjhUakFCZDlzCkZPOTZ4ZkhKSHhJMkhDVkZqUTZMbjdMbXRUZVZTTU9TemlObFQ0TENFNjFrL2xkem1iNnVQNEVhbThPejBTbHEKS1FWZ3RTMHlVdmJjUEp0TnErNFM0bER5anFudzdKaUVyaTVQaTYzblBQT3RjUXdpZmZCek5hTFlJYlc0RjNNYQpJNWRNelBRTk8vQTdraFYrU1MyQ3pNZmNVY29sdWt3MlV4WG5KcDI2WDRRWXFNZG51N002OFBqNmNiSEF0MFIwClhCVDF1VWlaeGJqYnlvQnpUUkRQaGF3YjEvTXlKQ0RJZ1RDQjB2cUsrNVRHWWIrdkl4ZkErOUJBZmZDSVZxWHkKYndJREFRQUIKLS0tLS1FTkQgUFVCTElDIEtFWS0tLS0tCg=="
EOF

# Create deploy-lago.sh
cat > deploy-lago.sh << 'EOF'
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
EOF

# Make deploy script executable
chmod +x deploy-lago.sh

echo "✅ All files created successfully!"
echo ""
echo "Files created:"
echo "  - lago.yaml"
echo "  - lago-frontend-env.yaml" 
echo "  - lago-rsa-secrets.yaml"
echo "  - deploy-lago.sh"
echo ""
echo "🚀 Ready to deploy! Run: ./deploy-lago.sh"