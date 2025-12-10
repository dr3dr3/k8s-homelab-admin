# ArgoCD Configuration

This directory contains ArgoCD manifests for managing the homelab cluster using GitOps principles.

## Structure

```bash
argocd/
├── README.md                      # This file
├── bootstrap.sh                   # Bootstrap script to install ArgoCD
├── root-app.yaml                  # App-of-apps (manages all applications)
├── projects/
│   └── homelab.yaml              # ArgoCD Project definition
└── apps/
    └── podinfo-production.yaml   # Individual application definitions
```

## GitOps Workflow

1. **Single Source of Truth**: All manifests in `k8s-manifests/` are the desired state
2. **Automatic Sync**: Changes merged to `main` branch are auto-deployed
3. **Self-Healing**: Manual `kubectl` changes are automatically reverted
4. **Pruning**: Resources deleted from git are removed from cluster

## Bootstrap Process

### 1. Install ArgoCD

```bash
./argocd/bootstrap.sh
```

This script will:

- Install ArgoCD in the `argocd` namespace
- Wait for ArgoCD to be ready
- Apply the root application (app-of-apps pattern)
- Display access instructions

### 2. Access ArgoCD UI

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Login: admin / <password-from-above>
```

### 3. Change Admin Password (Recommended)

```bash
# Login first
argocd login localhost:8080

# Change password
argocd account update-password
```

## App-of-Apps Pattern

The `root-app.yaml` is the parent application that manages all other applications:

```bash
root-app (ArgoCD Application)
└── watches: argocd/apps/*.yaml
    ├── podinfo-production
    ├── (future applications...)
    └── ...
```

**Benefits:**

- Single `kubectl apply` to bootstrap entire system
- All applications managed via GitOps
- Easy to add new applications (just add YAML in `argocd/apps/`)

## Adding New Applications

1. Create application manifest in `argocd/apps/`:

```yaml
# argocd/apps/myapp-production.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: myapp-production
  namespace: argocd
spec:
  project: homelab
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: k8s-manifests/overlays/production/myapp
  destination:
    server: https://kubernetes.default.svc
    namespace: default
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

2. Commit and push to `main` branch
3. ArgoCD automatically detects and deploys the new application

## Kustomize Integration

ArgoCD automatically detects `kustomization.yaml` files and runs `kustomize build`:

- **Application path**: Points to overlay directory (e.g., `k8s-manifests/overlays/production`)
- **Kustomize builds**: Merges base + overlay automatically
- **No changes needed**: Your existing Kustomize structure works as-is

## Sync Policies

All applications use these sync policies:

- **automated.prune**: `true` - Delete resources removed from git
- **automated.selfHeal**: `true` - Revert manual changes
- **syncOptions.CreateNamespace**: `true` - Auto-create namespaces

## Monitoring

### CLI Commands

```bash
# List all applications
argocd app list

# Get application details
argocd app get podinfo-production

# Sync manually (if needed)
argocd app sync podinfo-production

# View sync history
argocd app history podinfo-production
```

### UI Dashboard

The ArgoCD UI provides:

- Visual application health status
- Sync status and history
- Resource tree view
- Live logs and events
- Manual sync controls

## Troubleshooting

### Application Not Syncing

```bash
# Check application status
argocd app get <app-name>

# View sync errors
argocd app sync <app-name> --dry-run

# Force refresh
argocd app get <app-name> --refresh
```

### Manual Override (Emergency)

```bash
# Disable auto-sync temporarily
argocd app set <app-name> --sync-policy none

# Make manual changes
kubectl apply -f ...

# Re-enable auto-sync
argocd app set <app-name> --sync-policy automated
```

## Security Considerations

- **Repository Access**: Public repo (no credentials needed)
- **RBAC**: ArgoCD Project limits what can be deployed
- **Namespace Isolation**: Applications deployed to specific namespaces
- **1Password Integration**: Secrets should use External Secrets Operator (future enhancement)

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize Integration](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
