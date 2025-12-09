# Staging Overlay

This overlay applies staging-specific configurations to the base manifests.

## Purpose

The staging overlay prepares manifests for staging environments that mirror production but allow for testing and validation:

- **Near-production settings** (fewer replicas than prod, but HA-ready)
- **Moderate resource allocations** (not minimal, but less than production)
- **Staging-specific configurations** (test domains, internal endpoints)
- **Staging image tags** (development versions, release candidates)
- **Pre-production validation** environment

## What Goes Here

- **Patches** - Strategic merge patches for staging-specific overrides
  - Reduced replica counts (1-2 instead of 3+)
  - Moderate resource requests/limits
  - Staging-specific environment variables
  - Staging image tags (RC, beta, or recent commits)

- **Kustomization.yaml** - References the base and applies staging patches

- **Kustomizeconfig.yaml** - Custom merge directives (if needed)

## Structure

```
overlays/staging/
├── kustomization.yaml          # Main kustomization file
├── patches/                     # Directory for patch files (optional)
│   ├── deployment-patch.yaml   # Example: moderate replicas
│   ├── ingress-patch.yaml      # Example: staging domain
│   └── configmap-patch.yaml    # Example: staging configs
└── README.md                    # This file
```

## Typical Staging Configuration

### Moderate Replicas
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 2  # Less than production but still HA
```

### Moderate Resource Limits
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: my-app
        resources:
          requests:
            cpu: "250m"
            memory: "256Mi"
          limits:
            cpu: "500m"
            memory: "512Mi"
```

### Staging-Specific Configs
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  ENVIRONMENT: staging
  LOG_LEVEL: debug  # More verbose than production
  API_ENDPOINT: https://staging-api.internal.local
```

## Deployment

```bash
# View staging manifests
kustomize build overlays/staging

# Apply to staging cluster
kubectl apply -k overlays/staging

# Validate without applying
kustomize build overlays/staging | kubectl apply --dry-run=client -f -
```

## Use Cases

- **Testing new features** before production rollout
- **Validating infrastructure changes** (security policies, network configs)
- **Load testing** with near-production configuration
- **User acceptance testing** (UAT)
- **Hotfix validation** before production deployment

## Staging vs Production

| Aspect | Staging | Production |
|--------|---------|-----------|
| Replicas | 2 | 3+ |
| CPU Limit | 500m | 1000m+ |
| Memory Limit | 512Mi | 1Gi+ |
| Image Tags | RC, beta, commits | Specific versions only |
| Domain | staging.internal | example.com |
| TLS | Self-signed OK | Valid certificates |
| Data | Realistic subset | Real production data |

## Best Practices

- Keep staging as close to production as feasible
- Use realistic test data volumes
- Test all deployment procedures in staging first
- Validate that monitoring and logging work in staging
- Use staging for capacity and load testing
- Never commit secrets; use external secret management
