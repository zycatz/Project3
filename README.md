# Lago Kubernetes Deployment

Complete Kubernetes deployment configuration for the Lago billing application stack with persistent storage.

## 🚀 Quick Deploy

```bash
# Make script executable and run
chmod +x deploy-lago.sh
./deploy-lago.sh
```

## 📦 What's Included

### Core Infrastructure (with Persistent Volumes)
- **PostgreSQL** (1Gi storage) - Main application database
- **Redis** (512Mi storage) - Caching and session storage

### Lago Application Stack  
- **Lago API** - RESTful API server with GraphQL endpoint
- **Lago Frontend** - React-based web UI
- **Lago Worker** - Background job processing
- **Lago Clock** - Scheduled task management  
- **Lago PDF** - PDF invoice generation service

### Configuration & Secrets
- Environment variables and database configuration
- RSA encryption keys for secure operations
- Frontend-specific environment settings

## 📁 File Structure

```
├── lago.yaml                    # Main Kubernetes manifests
├── lago-frontend-env.yaml       # Frontend configuration
├── lago-rsa-secrets.yaml        # RSA encryption keys
├── deploy-lago.sh              # Automated deployment script
├── DEPLOYMENT_GUIDE.md         # Comprehensive deployment guide
└── README.md                   # This file
```

## ⚡ Manual Deployment

If you prefer manual deployment:

```bash
# Apply configurations and secrets
kubectl apply -f lago-rsa-secrets.yaml
kubectl apply -f lago-frontend-env.yaml

# Deploy the complete stack
kubectl apply -f lago.yaml

# Wait for pods to be ready
kubectl get pods --watch
```

## 🌐 Access the Application

### Option 1: Ingress (Production)
```bash
# Add to /etc/hosts
echo "127.0.0.1 lago.local" | sudo tee -a /etc/hosts

# Access via browser
# Frontend: http://lago.local
# API: http://lago.local/api
```

### Option 2: Port Forwarding (Development)
```bash
# Frontend
kubectl port-forward service/lago-front 8080:80

# API  
kubectl port-forward service/lago-api 3000:3000

# Access via:
# Frontend: http://localhost:8080
# API: http://localhost:3000
```

## 📊 Monitoring

```bash
# Check deployment status
kubectl get pods
kubectl get services
kubectl get pvc

# View logs
kubectl logs -f deployment/lago-api
kubectl logs -f deployment/lago-front

# Check resource usage
kubectl top pods
```

## 🔧 Scaling

```bash
# Scale API servers
kubectl scale deployment lago-api --replicas=3

# Scale workers  
kubectl scale deployment lago-worker --replicas=5

# Scale frontend
kubectl scale deployment lago-front --replicas=2
```

## ⚠️ Security Notes

**Default Configuration**: This deployment includes demo credentials for quick setup.

**For Production**:
- Change PostgreSQL password
- Generate new RSA encryption keys
- Update all encryption keys
- Configure HTTPS/TLS
- Implement proper secret management

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)** - Complete deployment documentation
- **[Lago Official Docs](https://getlago.com/docs)** - Application documentation

## 🛠 Prerequisites

- Kubernetes cluster (minikube, kind, EKS, GKE, AKS, etc.)
- kubectl configured with cluster access
- NGINX Ingress Controller (optional, for ingress access)

## 🆘 Troubleshooting

Common issues and solutions are documented in the [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md#troubleshooting).

Quick debug commands:
```bash
# Check pod details
kubectl describe pod <pod-name>

# Test connectivity
kubectl exec -it deployment/lago-api -- curl http://lago-postgres:5432
kubectl exec -it deployment/lago-api -- curl http://lago-redis:6379

# Check configuration
kubectl get configmap lago-config -o yaml
```

---

🎯 **Ready to deploy?** Run `./deploy-lago.sh` and follow the instructions!