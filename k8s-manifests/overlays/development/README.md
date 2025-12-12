# Development Overlay

This overlay applies development-specific configurations to the base manifests.

## Purpose

The development overlay optimizes base manifests for development and testing environments:

- **Minimal resource usage** (single replicas, small resource requests)
- **Fast iteration** (latest/development image tags, quick startup)
- **Development-friendly** logging and debugging (verbose logs, debug endpoints)
- **Local development** configurations (localhost, internal IPs)
- **Cost-effective** for non-critical testing

## What Goes Here

- **Patches** - Strategic merge patches for development-specific overrides
  - Single replica deployments
  - Minimal resource requests/limits
  - Development image tags (latest, dev, main branch builds)
  - Verbose logging and debug settings
  - Development-specific environment variables

- **Kustomization.yaml** - References the base and applies development patches

- **Kustomizeconfig.yaml** - Custom merge directives (if needed)

## Structure

```
overlays/development/
├── kustomization.yaml          # Main kustomization file
├── patches/                     # Directory for patch files (optional)
│   ├── deployment-patch.yaml   # Example: single replica, minimal resources
│   ├── ingress-patch.yaml      # Example: localhost or development domain
│   └── configmap-patch.yaml    # Example: development configs
└── README.md                    # This file
```

## Typical Development Configuration

### Single Replica
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 1
```

### Minimal Resources
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
            cpu: "50m"
            memory: "64Mi"
          limits:
            cpu: "200m"
            memory: "256Mi"
```

### Development-Specific Configs
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  ENVIRONMENT: development
  LOG_LEVEL: debug
  DEBUG: "true"
  API_ENDPOINT: http://localhost:3000
```

## Deployment

```bash
# View development manifests
kustomize build overlays/development

# Apply to development cluster/namespace
kubectl apply -k overlays/development

# Validate without applying
kustomize build overlays/development | kubectl apply --dry-run=client -f -
```

## Use Cases

- **Local development** clusters (k3d, minikube, Docker Desktop Kubernetes)
- **Feature branch testing** before merging
- **Rapid iteration** and debugging
- **Integration testing** in isolated environments
- **Learning and experimentation** with Kubernetes

## Development vs Production

| Aspect | Development | Production |
|--------|-------------|-----------|
| Replicas | 1 | 3+ |
| CPU Limit | 200m | 1000m+ |
| Memory Limit | 256Mi | 1Gi+ |
| Image Tags | latest, dev | Specific versions |
| Domain | localhost | example.com |
| TLS | None | Valid certificates |
| Logging | Verbose (DEBUG) | Minimal (INFO) |
| Resource Requests | Minimal | Production-grade |

## Best Practices

- Keep resource requests/limits reasonable even in dev (5-20% of prod)
- Use `latest` image tags for faster feedback loops
- Enable debug logging and endpoints
- Use simplified ingress rules (localhost or internal domains)
- Don't worry about high availability in dev
- Test the upgrade path even in dev (use proper image tags)
- Use resource quotas to prevent runaway resource usage

## Development Workflow

1. **Make code changes** in your application
2. **Build and push** Docker image with dev tag (e.g., `dev-main`)
3. **Update development overlay** with new image tag if needed
4. **Apply overlays**: `kubectl apply -k overlays/development`
5. **Test and iterate** quickly
6. **Commit to git** when ready to deploy to production (ArgoCD will auto-sync)
