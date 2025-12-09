# Base Manifests

This directory contains the base Kubernetes manifests that are shared across all environments (production, staging, development).

## Purpose

Base manifests define the core resources for your applications without any environment-specific customizations. They should be generic enough to work across different environments.

## What Goes Here

- **Deployments** - Core deployment definitions with reasonable defaults
- **Services** - Service definitions for exposing applications
- **ConfigMaps** - Non-sensitive configuration shared across environments
- **PersistentVolumeClaims** - Storage definitions
- **RBAC Resources** - ServiceAccounts, Roles, RoleBindings
- **NetworkPolicies** - Network configuration
- **Ingress** - Ingress rules (basic structure)
- **Any other shared resources** - HPA, PDB, etc.

## What Should NOT Go Here

- Environment-specific values (replicas, resource requests, specific image tags per env)
- Secrets (use sealed-secrets or external-secrets instead)
- Environment-specific ConfigMap values (move these to overlays)
- Environment-specific patches or modifications

## Creating a New Application in Base

1. Create subdirectories for organizational purposes (optional):
   ```
   base/
   ├── my-app/
   │   ├── kustomization.yaml
   │   ├── deployment.yaml
   │   ├── service.yaml
   │   └── configmap.yaml
   └── kustomization.yaml  (top-level, references all apps)
   ```

2. Define your base resources with generic settings:
   ```yaml
   # deployment.yaml
   apiVersion: apps/v1
   kind: Deployment
   metadata:
     name: my-app
     labels:
       app: my-app
   spec:
     replicas: 1  # Default; can be overridden in overlays
     selector:
       matchLabels:
         app: my-app
     template:
       # ... your pod spec
   ```

3. Create a `kustomization.yaml` referencing your resources:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   
   resources:
     - deployment.yaml
     - service.yaml
     - configmap.yaml
   ```

## Naming Conventions

- Use lowercase with hyphens for names
- Use descriptive names that reflect the resource type
- Keep related resources in the same directory

## Testing Your Base

```bash
# View the manifests
kustomize build .

# Validate syntax
kustomize build . | kubectl apply --dry-run=client -f -
```

## Tips

- Keep base manifests simple and minimal
- Use meaningful labels and annotations for organization
- Document any assumptions or prerequisites in comments
- Use sidecar patterns sparingly; prefer dedicated deployments
- Consider using kustomization.yaml's `commonLabels` for consistency
