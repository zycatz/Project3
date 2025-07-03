# Lago Kubernetes Deployment Guide

## Prerequisites

Before deploying Lago, ensure you have:

1. **Kubernetes cluster** running (minikube, GKE, EKS, AKS, or any other K8s cluster)
2. **kubectl** configured to connect to your cluster
3. **NGINX Ingress Controller** installed (required for the ingress to work)
4. **Persistent Volume** support in your cluster

## Files Overview

Your deployment consists of:
- `lago.yaml` - Main deployment file with all services
- `lago-frontend-env.yaml` - Frontend environment configuration
- `lago-rsa-secrets.yaml` - RSA keys for JWT authentication

## Step 1: Verify Cluster Connection

First, verify your kubectl is connected to the cluster:

```bash
kubectl cluster-info
kubectl get nodes
```

## Step 2: Install NGINX Ingress Controller (if not already installed)

```bash
# For most Kubernetes clusters
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.1/deploy/static/provider/cloud/deploy.yaml

# For minikube
minikube addons enable ingress

# Verify ingress controller is running
kubectl get pods -n ingress-nginx
```

## Step 3: Deploy Lago Components

Deploy in the following order to ensure dependencies are available:

### 3.1 Deploy Core Configuration and Secrets

```bash
# Deploy RSA secrets first
kubectl apply -f lago-rsa-secrets.yaml

# Deploy frontend environment configuration
kubectl apply -f lago-frontend-env.yaml

# Deploy main Lago application
kubectl apply -f lago.yaml
```

### 3.2 Verify Deployment Status

Check if all components are being created:

```bash
# Check all pods
kubectl get pods

# Check services
kubectl get services

# Check persistent volume claims
kubectl get pvc

# Check ingress
kubectl get ingress
```

## Step 4: Wait for All Pods to be Ready

This process can take 5-10 minutes. Monitor the deployment:

```bash
# Watch all pods until they're running
watch kubectl get pods

# Check specific component logs if needed
kubectl logs -f deployment/lago-postgres
kubectl logs -f deployment/lago-redis
kubectl logs -f deployment/lago-api
kubectl logs -f deployment/lago-front
```

## Step 5: Configure Local Access (for lago.local)

Since your ingress uses `lago.local`, you need to configure local DNS:

### Option A: Edit /etc/hosts (Linux/Mac)

```bash
# Get the ingress IP address
kubectl get ingress lago-ingress

# Add to /etc/hosts (replace <INGRESS-IP> with actual IP)
echo "<INGRESS-IP> lago.local" | sudo tee -a /etc/hosts
```

### Option B: For LoadBalancer Service (Cloud environments)

```bash
# If using cloud load balancer, get external IP
kubectl get service -n ingress-nginx ingress-nginx-controller

# Add the EXTERNAL-IP to your /etc/hosts
echo "<EXTERNAL-IP> lago.local" | sudo tee -a /etc/hosts
```

### Option C: Port Forwarding (Development)

```bash
# Forward local port to the ingress controller
kubectl port-forward -n ingress-nginx service/ingress-nginx-controller 8080:80

# Then access via http://localhost:8080 (update lago-frontend-env.yaml accordingly)
```

## Step 6: Verify Database Initialization

Check if the database is properly initialized:

```bash
# Check API logs for database migration
kubectl logs deployment/lago-api | grep -i "migration\|database"

# If needed, run database migrations manually
kubectl exec -it deployment/lago-api -- bundle exec rails db:migrate
kubectl exec -it deployment/lago-api -- bundle exec rails db:seed
```

## Step 7: Access Lago

Once everything is ready:

1. **Open browser** and navigate to `http://lago.local`
2. **Create admin account** (if this is first time setup)
3. **Login** and verify functionality

## Troubleshooting Commands

### Check Pod Status and Logs

```bash
# Get detailed pod information
kubectl describe pod <pod-name>

# Check logs for specific services
kubectl logs -f deployment/lago-api
kubectl logs -f deployment/lago-front
kubectl logs -f deployment/lago-worker
kubectl logs -f deployment/lago-postgres
kubectl logs -f deployment/lago-redis

# Check last 100 lines of logs
kubectl logs --tail=100 deployment/lago-api
```

### Test Internal Connectivity

```bash
# Test database connection from API pod
kubectl exec -it deployment/lago-api -- nc -zv lago-postgres 5432

# Test Redis connection from API pod
kubectl exec -it deployment/lago-api -- nc -zv lago-redis 6379

# Test API from frontend pod
kubectl exec -it deployment/lago-front -- curl -I http://lago-api:3000/health
```

### Check Environment Variables

```bash
# Verify frontend environment variables
kubectl exec deployment/lago-front -- env | grep -E "(API_URL|LAGO_)"

# Verify API environment variables
kubectl exec deployment/lago-api -- env | grep -E "(POSTGRES|REDIS|LAGO_)"
```

### Check Persistent Volumes

```bash
# Check if PVCs are bound
kubectl get pvc

# Check persistent volume details
kubectl describe pv
```

## Step 8: Scaling and Management

### Scale Components

```bash
# Scale API replicas
kubectl scale deployment lago-api --replicas=3

# Scale frontend replicas
kubectl scale deployment lago-front --replicas=2

# Scale workers
kubectl scale deployment lago-worker --replicas=2
```

### Update Configuration

```bash
# After modifying config files, apply changes
kubectl apply -f lago-frontend-env.yaml
kubectl apply -f lago.yaml

# Restart deployments to pick up changes
kubectl rollout restart deployment/lago-front
kubectl rollout restart deployment/lago-api
```

## Expected Deployment Result

After successful deployment, you should have:

- ✅ **PostgreSQL** running with persistent storage
- ✅ **Redis** running with persistent storage  
- ✅ **Lago API** running and connected to database
- ✅ **Lago Worker** processing background jobs
- ✅ **Lago Clock** handling scheduled tasks
- ✅ **Lago PDF** service for invoice generation
- ✅ **Lago Frontend** accessible via `http://lago.local`
- ✅ **All services** communicating properly

## Security Considerations

### For Production Deployment:

1. **Change default secrets** in `lago.yaml`:
   - `POSTGRES_PASSWORD`
   - `SECRET_KEY_BASE`
   - `LAGO_ENCRYPTION_*` keys

2. **Use proper TLS certificates** for HTTPS

3. **Configure proper ingress** with authentication

4. **Set resource limits** for all containers

5. **Use network policies** to restrict pod-to-pod communication

6. **Enable monitoring** and logging

## Cleanup (if needed)

To remove the entire Lago deployment:

```bash
kubectl delete -f lago.yaml
kubectl delete -f lago-frontend-env.yaml
kubectl delete -f lago-rsa-secrets.yaml

# Remove persistent volumes (CAUTION: This deletes all data!)
kubectl delete pvc lago-postgres-pvc lago-redis-pvc
```

## Next Steps

1. **Configure Lago** through the web interface
2. **Set up payment providers** (Stripe, etc.)
3. **Configure email settings**
4. **Set up monitoring** and backups
5. **Configure proper domain** and SSL certificates for production

Your Lago deployment should now be fully functional!