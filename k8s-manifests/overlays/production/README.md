# Production Overlay

This overlay applies production-specific configurations to the base manifests.

## Purpose

The production overlay customizes base manifests for production environments with:

- **High availability** settings (multiple replicas, anti-affinity)
- **Resource requests and limits** (production-grade resources)
- **Production-grade** security policies
- **Production image tags** (specific versions, not latest)
- **Production-specific ConfigMaps** (domain names, service endpoints)
- **Production-specific ingress rules** (real domains, TLS)

## What Goes Here

- **Patches** - Strategic merge patches to override specific fields
  - Modify replica counts
  - Update resource requests/limits
  - Set environment variables
  - Update image tags

- **Kustomization.yaml** - References the base and applies all patches

- **Kustomizeconfig.yaml** - Custom merge directives (if needed)

## Structure

```bash
overlays/production/
├── kustomization.yaml          # Main kustomization file
├── patches/                     # Directory for patch files (optional)
│   ├── deployment-patch.yaml   # Example: increase replicas, resources
│   ├── ingress-patch.yaml      # Example: production domain, TLS
│   └── configmap-patch.yaml    # Example: production configs
└── README.md                    # This file
```

## Common Patches for Production

### Increase Replicas

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3
```

### Add Resource Limits

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
            cpu: "500m"
            memory: "512Mi"
          limits:
            cpu: "1000m"
            memory: "1Gi"
```

### Update Image Tag

In `kustomization.yaml`:

```yaml
images:
  - name: my-app
    newTag: v1.0.0
```

## Deployment

```bash
# View production manifests
kustomize build overlays/production

# Apply to production cluster
kubectl apply -k overlays/production

# Or validate first
kustomize build overlays/production | kubectl apply --dry-run=client -f -
```

## Pre-deployment Checklist

- [ ] All resource requests/limits are set appropriately
- [ ] Replicas are set to HA levels (minimum 2-3)
- [ ] Image tags are specific versions, not `latest`
- [ ] Ingress uses production domain names
- [ ] TLS certificates are configured
- [ ] Pod security policies are appropriate
- [ ] Network policies are in place
- [ ] Secrets are properly managed (not in git)
- [ ] Monitoring and logging are configured
- [ ] Tested in development first

## Important Notes

- **Never commit secrets** to this repository - use sealed-secrets or external-secrets
- **Always test in development** before committing to git (which auto-deploys to production)
- **Use specific image tags** (not latest) for reproducibility
- **Document any manual steps** required for production deployment
