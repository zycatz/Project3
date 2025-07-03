# Lago Kubernetes Deployment

This repository contains everything needed to deploy Lago (open-source billing platform) on Kubernetes.

## Quick Start

### Prerequisites
- Kubernetes cluster (minikube, GKE, EKS, AKS, etc.)
- kubectl configured and connected to your cluster
- NGINX Ingress Controller (will be installed automatically if missing)

### One-Command Deployment

```bash
./deploy-lago.sh
```

This script will:
- ✅ Check prerequisites
- ✅ Install NGINX Ingress Controller (if needed)
- ✅ Deploy all Lago components
- ✅ Configure networking
- ✅ Set up database
- ✅ Configure /etc/hosts for local access

### Manual Deployment

If you prefer manual deployment:

```bash
# Deploy in order
kubectl apply -f lago-rsa-secrets.yaml
kubectl apply -f lago-frontend-env.yaml
kubectl apply -f lago.yaml

# Wait for pods to be ready
kubectl get pods -w
```

## Files Included

- `lago.yaml` - Main deployment with all services
- `lago-frontend-env.yaml` - Frontend environment configuration  
- `lago-rsa-secrets.yaml` - RSA keys for JWT authentication
- `deploy-lago.sh` - Automated deployment script
- `lago-kubernetes-deployment-guide.md` - Detailed deployment guide

## Services Deployed

- **PostgreSQL** - Database with persistent storage
- **Redis** - Cache and session storage
- **Lago API** - Main backend service
- **Lago Frontend** - Web interface
- **Lago Worker** - Background job processor
- **Lago Clock** - Scheduled task runner
- **Lago PDF** - Invoice PDF generation

## Access

After deployment, Lago will be available at:
- **URL**: http://lago.local
- **Login**: Create admin account on first visit

## Common Commands

```bash
# Check deployment status
kubectl get pods
kubectl get services
kubectl get ingress

# View logs
kubectl logs -f deployment/lago-api
kubectl logs -f deployment/lago-front

# Scale services
kubectl scale deployment lago-api --replicas=3

# Restart services
kubectl rollout restart deployment/lago-api
```

## Troubleshooting

If you encounter issues:

1. **Check pod logs**: `kubectl logs deployment/lago-api`
2. **Verify environment variables**: `kubectl exec deployment/lago-front -- env | grep API_URL`
3. **Test connectivity**: `kubectl exec deployment/lago-front -- curl http://lago-api:3000/health`
4. **Database issues**: `kubectl exec deployment/lago-api -- bundle exec rails db:migrate`

For detailed troubleshooting, see `lago-kubernetes-deployment-guide.md`.

## Production Considerations

Before using in production:

1. **Change default secrets** in `lago.yaml`
2. **Configure proper domain** instead of lago.local
3. **Set up TLS/SSL certificates**
4. **Configure resource limits**
5. **Set up monitoring and backups**
6. **Use external databases** for better reliability

## Cleanup

To remove everything:

```bash
kubectl delete -f lago.yaml
kubectl delete -f lago-frontend-env.yaml
kubectl delete -f lago-rsa-secrets.yaml
kubectl delete pvc lago-postgres-pvc lago-redis-pvc
```

## Support

For Lago-specific issues, visit: https://github.com/getlago/lago