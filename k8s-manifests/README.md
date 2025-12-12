# Kubernetes Manifests for Homelab

This directory contains Kustomize-based Kubernetes manifests organized with a base configuration and environment-specific overlays.

## Architecture

This homelab uses a **two-environment architecture**:

- **Development**: k3d cluster, deployed with `kubectl apply -k`, no GitOps
- **Production**: Talos cluster, deployed with ArgoCD, full GitOps

## Structure

```
k8s-manifests/
├── base/                          # Base manifests shared across all environments
│   ├── kustomization.yaml
│   └── podinfo/                   # Example application
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
└── overlays/
    ├── development/               # Development environment (k3d + kubectl)
    │   └── kustomization.yaml
    └── production/                # Production environment (Talos + ArgoCD)
        └── kustomization.yaml
```

## Usage

### Development Environment (k3d)

```bash
# View manifests
kubectl kustomize k8s-manifests/overlays/development

# Apply to k3d cluster
kubectl apply -k k8s-manifests/overlays/development

# Update after changes
kubectl apply -k k8s-manifests/overlays/development
```

### Production Environment (Talos)

Production is managed by ArgoCD. After committing changes to `main`:

```bash
# ArgoCD automatically syncs changes from:
# k8s-manifests/overlays/production

# View what will be deployed
kubectl kustomize k8s-manifests/overlays/production

# Check ArgoCD sync status
argocd app get podinfo-production

# Manual sync (if needed)
argocd app sync podinfo-production
```

## How to Add New Applications

### For Both Environments

1. **Create base manifests** in `base/myapp/` directory
   - Include Deployment, Service, ConfigMap, Secret (references), etc.
   - Create a `kustomization.yaml` that references all resources

2. **Create overlays** in both `overlays/development/` and `overlays/production/`
   - Use patches to override specific fields (replicas, resources, env vars, etc.)
   - Use configMapGenerator/secretGenerator for environment-specific configs

3. **Deploy**:
   - **Development**: `kubectl apply -k k8s-manifests/overlays/development`
   - **Production**: Commit to git, ArgoCD auto-syncs

### Example: Adding a New App

```bash
# 1. Create base
mkdir -p k8s-manifests/base/myapp
# Add deployment.yaml, service.yaml, kustomization.yaml

# 2. Update development overlay
# Edit k8s-manifests/overlays/development/kustomization.yaml
# Add: - ../../base/myapp

# 3. Update production overlay  
# Edit k8s-manifests/overlays/production/kustomization.yaml
# Add: - ../../base/myapp

# 4. Create ArgoCD Application for production
# Create: argocd/apps/myapp-production.yaml
```

## Best Practices

- **Base manifests** should be generic and not environment-specific
- **Overlays** should contain only the differences (patches, environment-specific settings)
- **Development**: Fast iteration, test before committing
- **Production**: GitOps-managed, always matches git repository state
- Keep secrets out of git - use sealed-secrets, external-secrets, or similar
- Test manifests with `kubectl kustomize` before applying or committing

## Example Pattern

**base/myapp/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

**overlays/development/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/myapp

commonLabels:
  environment: development
  tier: dev

replicas:
  - name: myapp
    count: 1
```

**overlays/production/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/myapp

commonLabels:
  environment: production
  tier: prod

replicas:
  - name: myapp
    count: 3
```

## References

- [Kustomize Official Documentation](https://kustomize.io/)
- [kubectl - Kustomization](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
