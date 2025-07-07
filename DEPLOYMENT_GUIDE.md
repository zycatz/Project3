# Lago Kubernetes Deployment Guide

This repository contains complete Kubernetes manifests to deploy the Lago billing application stack with persistent storage.

## Architecture Overview

The deployment includes the following components as separate Kubernetes Deployments and Services:

### Core Infrastructure
- **PostgreSQL** with Persistent Volume (1Gi storage)
- **Redis** with Persistent Volume (512Mi storage)

### Lago Application Stack
- **Lago API** - Main application API server
- **Lago Frontend** - Web UI application
- **Lago Worker** - Background job processing
- **Lago Clock** - Scheduled task management
- **Lago PDF** - PDF generation service

## Prerequisites

1. **Kubernetes Cluster**: Any Kubernetes cluster (minikube, kind, EKS, GKE, AKS, etc.)
2. **kubectl**: Kubernetes command-line tool
3. **Ingress Controller**: NGINX Ingress Controller (for external access)

## Quick Start

### 1. Deploy the Stack

```bash
# Apply secrets and configuration
kubectl apply -f lago-rsa-secrets.yaml
kubectl apply -f lago-frontend-env.yaml

# Deploy the complete stack
kubectl apply -f lago.yaml
```

### 2. Verify Deployment

```bash
# Check all pods are running
kubectl get pods

# Check services
kubectl get services

# Check persistent volumes
kubectl get pvc
```

### 3. Access the Application

#### Option A: Using Ingress (Recommended)

If you have an NGINX Ingress Controller installed:

```bash
# Add to your /etc/hosts file
echo "127.0.0.1 lago.local" | sudo tee -a /etc/hosts

# Access the application
# Frontend: http://lago.local
# API: http://lago.local/api
```

#### Option B: Port Forwarding (Development)

```bash
# Forward frontend port
kubectl port-forward service/lago-front 8080:80

# Forward API port  
kubectl port-forward service/lago-api 3000:3000

# Access via:
# Frontend: http://localhost:8080
# API: http://localhost:3000
```

## Component Details

### PostgreSQL Database
- **Image**: `postgres:14-alpine`
- **Storage**: 1Gi persistent volume
- **Service**: `lago-postgres:5432`
- **Database**: `lago`
- **User**: `lago`

### Redis Cache
- **Image**: `redis:6-alpine`
- **Storage**: 512Mi persistent volume
- **Service**: `lago-redis:6379`

### Lago API
- **Image**: `getlago/api:v1.31.0`
- **Service**: `lago-api:3000`
- **Dependencies**: PostgreSQL, Redis

### Lago Frontend
- **Image**: `getlago/front:v1.31.0`
- **Service**: `lago-front:80`
- **Environment**: Production configuration

## Configuration

### Environment Variables

Key configuration is managed through ConfigMaps and Secrets:

- **lago-config**: Database and Redis connection settings
- **lago-secrets**: Sensitive data (passwords, encryption keys)
- **lago-frontend-env**: Frontend-specific configuration
- **lago-rsa-keys**: RSA keys for encryption

### Security Notes

**Important**: The default configuration includes demo credentials. For production use:

1. Change the PostgreSQL password in `lago-secrets`
2. Generate new RSA keys for `lago-rsa-keys`
3. Update encryption keys in `lago-secrets`
4. Configure proper ingress with TLS

```bash
# Generate new secrets
kubectl create secret generic lago-secrets \
  --from-literal=POSTGRES_PASSWORD=$(openssl rand -base64 32) \
  --from-literal=SECRET_KEY_BASE=$(openssl rand -hex 64) \
  --from-literal=LAGO_ENCRYPTION_PRIMARY_KEY=$(openssl rand -hex 16) \
  --from-literal=LAGO_ENCRYPTION_DETERMINISTIC_KEY=$(openssl rand -hex 16) \
  --from-literal=LAGO_ENCRYPTION_KEY_DERIVATION_SALT=$(openssl rand -hex 16) \
  --dry-run=client -o yaml > lago-secrets-prod.yaml
```

## Scaling

### Horizontal Scaling

The following components can be scaled horizontally:

```bash
# Scale API servers
kubectl scale deployment lago-api --replicas=3

# Scale workers
kubectl scale deployment lago-worker --replicas=5

# Scale frontend
kubectl scale deployment lago-front --replicas=2
```

### Vertical Scaling

Update resource requests and limits in the deployment specs:

```yaml
resources:
  requests:
    memory: "512Mi"
    cpu: "250m"
  limits:
    memory: "1Gi"
    cpu: "500m"
```

## Monitoring

### Health Checks

```bash
# Check all pod status
kubectl get pods -o wide

# Check specific component logs
kubectl logs -f deployment/lago-api
kubectl logs -f deployment/lago-front
kubectl logs -f deployment/lago-worker

# Check database connectivity
kubectl exec -it deployment/lago-api -- pg_isready -h lago-postgres -U lago
```

### Resource Usage

```bash
# Check resource usage
kubectl top pods
kubectl top nodes

# Check persistent volume usage
kubectl exec -it deployment/lago-postgres -- df -h /var/lib/postgresql/data
kubectl exec -it deployment/lago-redis -- df -h /data
```

## Troubleshooting

### Common Issues

#### 1. Frontend showing "undefined/graphql" errors
- Verify `lago-frontend-env` ConfigMap is applied
- Check frontend deployment includes both ConfigMaps

#### 2. Database connection errors
- Verify PostgreSQL pod is running and ready
- Check database credentials in secrets
- Ensure database initialization completed

#### 3. Redis connection errors
- Verify Redis pod is running
- Check Redis service is accessible
- Verify Redis data directory permissions

### Debug Commands

```bash
# Get detailed pod information
kubectl describe pod <pod-name>

# Check service endpoints
kubectl get endpoints

# Test service connectivity
kubectl exec -it deployment/lago-api -- curl http://lago-postgres:5432
kubectl exec -it deployment/lago-api -- curl http://lago-redis:6379

# Check ConfigMap and Secret values
kubectl get configmap lago-config -o yaml
kubectl get secret lago-secrets -o yaml
```

## File Structure

```
.
├── lago.yaml                    # Main deployment manifest
├── lago-frontend-env.yaml       # Frontend environment config
├── lago-rsa-secrets.yaml        # RSA encryption keys
├── DEPLOYMENT_GUIDE.md          # This deployment guide
└── lago-deployment-fix-analysis.md  # Previous issue analysis
```

## Production Considerations

1. **Persistent Storage**: Configure appropriate StorageClass for your environment
2. **Backup Strategy**: Implement regular database backups
3. **SSL/TLS**: Configure HTTPS with proper certificates
4. **Monitoring**: Add Prometheus/Grafana monitoring
5. **Logging**: Configure centralized logging (ELK/EFK stack)
6. **Secrets Management**: Use external secret management (Vault, etc.)
7. **Network Policies**: Implement Kubernetes Network Policies for security

## Support

For issues and questions:
- Check the [Lago Documentation](https://getlago.com/docs)
- Review the troubleshooting section above
- Examine pod logs for specific error messages