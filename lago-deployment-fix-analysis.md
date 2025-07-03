# Lago Kubernetes Deployment Issue: GraphQL Endpoint Configuration Fix

## Problem Analysis

**Issue**: Lago frontend making POST requests to `http://lago.local/undefined/graphql` resulting in 405 (Not Allowed) errors.

**Root Cause**: The frontend deployment is not properly configured with the correct environment variables needed to construct the GraphQL API endpoint URL.

## Configuration Issues Identified

### 1. Missing Environment Variables in Frontend Deployment

In your `lago.yaml` file, the frontend deployment only references the `lago-config` ConfigMap:

```yaml
containers:
- name: front
  image: getlago/front:v1.31.0
  envFrom:
    - configMapRef:
        name: lago-config  # Missing lago-frontend-env ConfigMap
```

### 2. Environment Variable Configuration

Your `lago-frontend-env.yaml` contains the correct API_URL, but it's not being used by the frontend deployment.

## Solution

### Step 1: Fix Frontend Deployment Configuration

Update your `lago.yaml` file to include both ConfigMaps in the frontend deployment:

```yaml
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
              name: lago-frontend-env  # Add this line
        ports:
          - containerPort: 80
```

### Step 2: Verify Environment Variables in lago-frontend-env.yaml

Ensure your `lago-frontend-env.yaml` has the correct structure:

```yaml
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
```

### Step 3: Alternative Solution - Unified ConfigMap

If you prefer to keep everything in one ConfigMap, add the frontend environment variables to your existing `lago-config` ConfigMap:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: lago-config
data:
  # Existing backend variables
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
  
  # Add frontend-specific variables
  API_URL: "http://lago.local/api"
  LAGO_DOMAIN: "lago.local"
  LAGO_OAUTH_PROXY_URL: ""
  LAGO_DISABLE_SIGNUP: ""
  NANGO_PUBLIC_KEY: ""
  SENTRY_DSN: ""
  LAGO_DISABLE_PDF_GENERATION: ""
```

## Implementation Steps

### Apply the Fix

1. **Update the lago.yaml file** with the corrected frontend deployment configuration.

2. **Apply the updated configuration**:
```bash
kubectl apply -f lago.yaml
kubectl apply -f lago-frontend-env.yaml
```

3. **Restart the frontend deployment** to pick up the new environment variables:
```bash
kubectl rollout restart deployment/lago-front
```

4. **Verify the environment variables** are loaded correctly:
```bash
kubectl exec -it deployment/lago-front -- env | grep API_URL
```

### Troubleshooting Commands

1. **Check pod logs**:
```bash
kubectl logs -f deployment/lago-front
kubectl logs -f deployment/lago-api
```

2. **Verify service connectivity**:
```bash
kubectl exec -it deployment/lago-front -- curl http://lago-api:3000/health
```

3. **Check environment variables in running container**:
```bash
kubectl exec -it deployment/lago-front -- printenv | grep -E "(API_URL|LAGO_)"
```

4. **Test GraphQL endpoint**:
```bash
kubectl exec -it deployment/lago-front -- curl -X POST http://lago-api:3000/graphql \
  -H "Content-Type: application/json" \
  -d '{"query":"{ __schema { types { name } } }"}'
```

## Additional Considerations

### Frontend Application Requirements

Some frontend frameworks require specific environment variable prefixes to be accessible at build time:

- **React**: Variables must start with `REACT_APP_`
- **Vue**: Variables must start with `VUE_APP_`
- **Next.js**: Variables must start with `NEXT_PUBLIC_`

If Lago frontend uses any of these frameworks, you might need to adjust the variable names accordingly.

### Service Discovery

Ensure the frontend can resolve the API service. In Kubernetes, services are accessible via:
- Service name: `lago-api`
- FQDN: `lago-api.default.svc.cluster.local` (assuming default namespace)

### Ingress Configuration

Your current ingress routes `/api` to the `lago-api` service, which is correct. Make sure the frontend is making requests to the right endpoint structure.

## Expected Behavior After Fix

After applying these changes:

1. The frontend should be able to read the `API_URL` environment variable
2. GraphQL requests should go to `http://lago.local/api/graphql` instead of `http://lago.local/undefined/graphql`
3. The 405 (Not Allowed) errors should be resolved
4. Login functionality should work correctly

## Validation

To confirm the fix is working:

1. Check browser network tab for GraphQL requests
2. Verify requests are going to the correct URL
3. Test login functionality
4. Monitor application logs for any remaining errors

This solution addresses the core issue of missing environment variable configuration while providing comprehensive troubleshooting steps for further debugging if needed.