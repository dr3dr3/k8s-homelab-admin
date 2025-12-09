# Kubernetes Manifests for Homelab

This directory contains Kustomize-based Kubernetes manifests organized with a base configuration and environment-specific overlays.

## Structure

```
k8s-manifests/
├── base/                          # Base manifests shared across all environments
│   ├── kustomization.yaml
│   ├── namespace.yaml             # (optional) shared namespace definitions
│   └── ...                         # Other shared resources
└── overlays/
    ├── production/                # Production environment
    │   ├── kustomization.yaml
    │   ├── kustomizeconfig.yaml  # (optional) custom merge directives
    │   └── patches/               # (optional) strategic merge patches
    ├── staging/                   # Staging environment
    │   ├── kustomization.yaml
    │   └── patches/
    └── development/               # Development environment
        ├── kustomization.yaml
        └── patches/
```

## Usage

### View manifests for an environment

```bash
# Production
kustomize build overlays/production

# Staging
kustomize build overlays/staging

# Development
kustomize build overlays/development
```

### Apply manifests to your cluster

```bash
# Using kubectl with kustomize
kubectl apply -k overlays/production

# Or with kustomize separately
kustomize build overlays/production | kubectl apply -f -
```

## How to Add New Applications

1. **Create base manifests** in `base/` directory
   - Include Deployment, Service, ConfigMap, Secret (references), etc.
   - Create a `kustomization.yaml` that references all resources

2. **Create environment overlays** in `overlays/{environment}/`
   - Use patches to override specific fields (replicas, resources, env vars, etc.)
   - Use configMapGenerator/secretGenerator for environment-specific configs

3. **Update the overlay's kustomization.yaml** to reference the base and apply patches

## Best Practices

- **Base manifests** should be generic and not environment-specific
- **Overlays** should contain only the differences (patches, replacements)
- Use `kustomizeconfig.yaml` in overlays for custom field merging if needed
- Keep secrets out of git - use sealed-secrets, external-secrets, or similar
- Use `-k` flag with kubectl for seamless Kustomize integration
- Test manifests with `kustomize build` before applying

## Example Pattern

**base/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
```

**overlays/production/kustomization.yaml:**
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

bases:
  - ../../base

replicas:
  - name: my-app
    count: 3

patchesStrategicMerge:
  - deployment-patch.yaml
```

## References

- [Kustomize Official Documentation](https://kustomize.io/)
- [kubectl - Kustomization](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/declarative-config/)
