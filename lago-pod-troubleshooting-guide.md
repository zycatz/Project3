# Lago Kubernetes Pod Troubleshooting Guide

## Current Pod Status Analysis

Based on your pod status output:

**❌ FAILING PODS:**
- `lago-api-57959c7d45-sd9cg` - **CrashLoopBackOff** (111 restarts)
- `lago-clock-7546757574-qs9gb` - **Error** (127 restarts) 
- `lago-worker-f57756b98-f295m` - **Error** (127 restarts)

**✅ HEALTHY PODS:**
- `lago-front-697f8df6f5-b5mkz` - Running
- `lago-pdf-7bd9f67ddf-8fkh4` - Running
- `lago-postgres-84948c8956-fnxpk` - Running
- `lago-redis-694578bcd9-vttn4` - Running

## Root Cause Analysis

The pattern shows that all **Rails application components** (API, Clock, Worker) are failing while **infrastructure components** (Postgres, Redis) and **stateless services** (Frontend, PDF) are working. This suggests:

1. **Database connectivity issues**
2. **Missing database setup/migrations**
3. **Environment variable problems**
4. **Application startup script failures**

## Immediate Diagnostic Commands

Run these commands to gather diagnostic information:

### 1. Check Pod Logs
```bash
# API pod logs (most critical)
kubectl logs -l app=lago-api --tail=100

# Worker pod logs
kubectl logs -l app=lago-worker --tail=100

# Clock pod logs  
kubectl logs -l app=lago-clock --tail=100

# Previous container logs (if pods restarted)
kubectl logs -l app=lago-api --previous --tail=100
```

### 2. Check Pod Details
```bash
# Detailed pod information
kubectl describe pod -l app=lago-api
kubectl describe pod -l app=lago-worker
kubectl describe pod -l app=lago-clock
```

### 3. Verify Database Connectivity
```bash
# Test database connection from API pod
kubectl exec -it deployment/lago-api -- sh -c 'nc -zv lago-postgres 5432'

# Check if database exists
kubectl exec -it deployment/lago-postgres -- psql -U lago -d lago -c "\l"
```

### 4. Check Environment Variables
```bash
# Verify environment variables in API pod
kubectl exec -it deployment/lago-api -- env | grep -E "(POSTGRES|REDIS|RAILS|LAGO)"
```

## Common Issues and Solutions

### Issue 1: Database Not Initialized

**Symptoms:** API logs show database connection errors or missing tables

**Solution:**
```bash
# Run database setup
kubectl exec -it deployment/lago-api -- bin/rails db:create db:migrate db:seed

# Or use the setup script if available
kubectl exec -it deployment/lago-api -- ./scripts/start.api.sh
```

### Issue 2: Redis Connection Problems

**Symptoms:** Worker/Clock logs show Redis connection errors

**Solution:**
```bash
# Test Redis connectivity
kubectl exec -it deployment/lago-worker -- sh -c 'nc -zv lago-redis 6379'

# Check Redis pod logs
kubectl logs -l app=lago-redis --tail=50
```

### Issue 3: Missing Environment Variables

**Symptoms:** Application fails to start with configuration errors

**Solution:**
```bash
# Apply updated configurations
kubectl apply -f lago.yaml
kubectl apply -f lago-frontend-env.yaml
kubectl apply -f lago-rsa-secrets.yaml

# Restart deployments to pick up new config
kubectl rollout restart deployment/lago-api
kubectl rollout restart deployment/lago-worker
kubectl rollout restart deployment/lago-clock
```

### Issue 4: Startup Script Failures

**Symptoms:** Pods exit immediately or show script execution errors

**Solution:**
```bash
# Check if startup scripts exist in container
kubectl exec -it deployment/lago-api -- ls -la ./scripts/

# Try manual startup for debugging
kubectl exec -it deployment/lago-api -- bash
# Then inside container: ./scripts/start.api.sh
```

## Step-by-Step Recovery Plan

### Step 1: Fix Database Issues
```bash
# 1. Verify Postgres is healthy
kubectl logs -l app=lago-postgres --tail=20

# 2. Check database exists and is accessible
kubectl exec -it deployment/lago-postgres -- psql -U lago -c "\l"

# 3. If database is empty, initialize it
kubectl exec -it deployment/lago-api -- bin/rails db:create db:migrate
```

### Step 2: Update Configuration
```bash
# Apply all configuration files
kubectl apply -f lago.yaml
kubectl apply -f lago-frontend-env.yaml 
kubectl apply -f lago-rsa-secrets.yaml
```

### Step 3: Restart Failed Services
```bash
# Restart in dependency order
kubectl rollout restart deployment/lago-api
kubectl rollout restart deployment/lago-worker
kubectl rollout restart deployment/lago-clock
```

### Step 4: Monitor Recovery
```bash
# Watch pod status
kubectl get pods -w

# Monitor logs during startup
kubectl logs -f deployment/lago-api
```

## Configuration Issues Found

### 1. Frontend Environment Variables (Already Fixed)
✅ The frontend deployment is now correctly configured with both ConfigMaps:
```yaml
envFrom:
  - configMapRef:
      name: lago-config
  - configMapRef:
      name: lago-frontend-env
```

### 2. Missing Database Initialization
The Rails API likely needs database initialization. Add an init container or job:

```yaml
# Add this as a Job before the API deployment
apiVersion: batch/v1
kind: Job
metadata:
  name: lago-db-migrate
spec:
  template:
    spec:
      containers:
      - name: migrate
        image: getlago/api:v1.31.0
        command: ["bin/rails", "db:create", "db:migrate", "db:seed"]
        envFrom:
          - configMapRef:
              name: lago-config
          - secretRef:
              name: lago-secrets
      restartPolicy: OnFailure
```

### 3. Potential Memory/Resource Limits
Consider adding resource limits to prevent OOM kills:

```yaml
resources:
  limits:
    memory: "1Gi"
    cpu: "500m"
  requests:
    memory: "512Mi"
    cpu: "250m"
```

## Validation Steps

After applying fixes:

### 1. Health Checks
```bash
# All pods should be Running
kubectl get pods

# Check service endpoints
kubectl get endpoints
```

### 2. Application Testing
```bash
# Test API health endpoint
kubectl exec -it deployment/lago-front -- curl http://lago-api:3000/health

# Test GraphQL endpoint
kubectl exec -it deployment/lago-front -- curl -X POST http://lago-api:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { types { name } } }"}'
```

### 3. Frontend Connectivity
```bash
# Verify frontend can reach API
kubectl exec -it deployment/lago-front -- env | grep API_URL
kubectl exec -it deployment/lago-front -- curl http://lago.local/api/health
```

## Emergency Recovery Commands

If issues persist:

```bash
# Delete and recreate problematic pods
kubectl delete pod -l app=lago-api
kubectl delete pod -l app=lago-worker  
kubectl delete pod -l app=lago-clock

# Scale down and up
kubectl scale deployment lago-api --replicas=0
kubectl scale deployment lago-api --replicas=1

# Check resource usage
kubectl top pods
kubectl describe nodes
```

## Next Steps

1. **Run the diagnostic commands** to identify specific error messages
2. **Check database initialization** - this is likely the primary issue
3. **Apply configuration updates** if needed
4. **Monitor pod logs** during restart process
5. **Test application functionality** once pods are healthy

The high restart counts (111, 127) suggest the pods have been failing for a while, likely due to database connectivity or initialization issues that need to be addressed systematically.