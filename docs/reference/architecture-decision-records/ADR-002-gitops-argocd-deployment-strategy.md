# ADR-002: GitOps and ArgoCD Deployment Strategy

**Status**: Accepted

**Date**: 2025-12-09 (Updated: 2025-12-12)

**Decision Makers**: Homelab Administrator

**Technical Story**: Establishing GitOps-based application deployment strategy for homelab Kubernetes clusters

## Context

The Kubernetes homelab infrastructure has two distinct environments with different operational needs:

1. **Development**: Fast iteration, frequent changes, learning and experimentation
2. **Production**: Stable deployments, audit trail, automated consistency

Key requirements:

- Automated deployment from git repository for production workloads
- Self-healing capabilities to maintain desired state in production
- Fast local development workflow without GitOps overhead
- Simplified deployment workflow suitable for a single administrator
- Integration with existing Kustomize manifest structure
- Minimal operational overhead for homelab context

The manifests are organized using Kustomize with base configurations and environment-specific overlays at `k8s-manifests/overlays/{environment}`.

## Decision

We will implement **two distinct deployment strategies** based on environment:

### 1. **Production Environment - Full GitOps with ArgoCD**

**Cluster**: Talos bare metal (`k8s-homelab-production`)  
**ArgoCD**: YES, fully deployed and configured  
**Purpose**: Real workloads, always-on applications

Configuration:

- ArgoCD installed in `argocd` namespace
- Applications managed via app-of-apps pattern
- Source repository: `https://github.com/dr3dr3/k8s-homelab-admin.git`
- Target path: `k8s-manifests/overlays/production`
- Auto-sync enabled on merge to `main` branch
- Self-healing enabled (auto-revert manual changes)
- Pruning enabled (auto-delete resources removed from git)

### 2. **Development Environment - Direct kubectl (No ArgoCD)**

**Cluster**: k3d local (developer workstation)  
**ArgoCD**: NO  
**Purpose**: Fast iteration and testing before committing changes

Workflow:

- Manual deployment via `kubectl apply -k k8s-manifests/overlays/development`
- Allows quick testing without git commits
- Rapid feedback loop for manifest changes
- No GitOps overhead for ephemeral development cluster
- Can tear down and recreate cluster frequently

### 3. **App-of-Apps Pattern**

ArgoCD applications are managed using the app-of-apps pattern:

```text
root-app (watches argocd/apps/*.yaml)
├── podinfo-production (→ k8s-manifests/overlays/production)
└── [future applications]
```

Benefits:

- Single `kubectl apply -f argocd/root-app.yaml` bootstraps entire system
- New applications added by creating YAML files in `argocd/apps/`
- ArgoCD itself manages application lifecycle via GitOps
- All ArgoCD Application manifests point to paths in `k8s-manifests/overlays/production`

### 4. **Sync Policy Configuration**

All production applications use:

- **automated.prune**: `true` - Resources deleted from git are removed from cluster
- **automated.selfHeal**: `true` - Manual `kubectl` changes are automatically reverted
- **syncOptions.CreateNamespace**: `true` - Namespaces created automatically
- **syncOptions.ServerSideApply**: `true` - Use server-side apply for production
- **targetRevision**: `main` - Trunk-based development workflow

### 5. **Kustomize Integration**

ArgoCD has native Kustomize support:

- Automatically detects `kustomization.yaml` files
- Runs `kustomize build` on the specified overlay directory (e.g., `k8s-manifests/overlays/production`)
- Follows base references (e.g., `../../base`) automatically
- No changes needed to existing Kustomize structure in `k8s-manifests/`

### 6. **Directory Structure**

```text
k8s-manifests/               # All Kubernetes manifests
├── base/                    # Base configurations
│   └── podinfo/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
└── overlays/
    ├── development/         # For k3d cluster (kubectl apply -k)
    │   └── kustomization.yaml
    └── production/          # For Talos cluster (ArgoCD)
        └── kustomization.yaml

argocd/                      # ArgoCD configuration only
├── bootstrap.sh             # Installation script
├── root-app.yaml            # App-of-apps root
├── README.md
├── projects/
│   └── homelab.yaml         # ArgoCD project definition
└── apps/                    # ArgoCD Application manifests
    ├── podinfo-production.yaml
    └── [additional apps]
```

## Consequences

### Positive

1. **Auditability**:
   - All production changes tracked in git history
   - Clear audit trail of who changed what and when
   - Easy rollback to previous versions via git

2. **Automation**:
   - Zero-touch deployment on merge to main
   - Eliminates manual `kubectl apply` errors in production
   - Consistent deployment process across all applications

3. **Self-Healing**:
   - Production cluster automatically reverts to desired state
   - Prevents configuration drift from manual changes
   - Ensures production matches git repository

4. **Simplicity for Homelab**:
   - Single ArgoCD instance for production only
   - No complex multi-cluster or multi-environment management
   - Development stays simple with direct kubectl
   - Production gets full GitOps benefits

5. **Developer Experience**:
   - Fast local development with k3d (no GitOps overhead)
   - Test changes locally before committing
   - Production deployment automatic after merge to main
   - Clear separation: k3d = dev, Talos = production

6. **Scalability**:
   - Easy to add new applications (create YAML in `argocd/apps/`)
   - App-of-apps pattern scales to many applications
   - Can add additional environments later if needed

### Negative

1. **Learning Curve**:
   - Administrator needs to understand ArgoCD concepts
   - Different workflows for dev (kubectl) vs production (GitOps)
   - Mitigation: Comprehensive documentation in `argocd/README.md`

2. **ArgoCD Dependency**:
   - Production cluster depends on ArgoCD availability
   - If ArgoCD fails, deployments are blocked
   - Mitigation: Can always fall back to `kubectl apply -k k8s-manifests/overlays/production` in emergencies

3. **Development-Production Parity**:
   - Dev environment doesn't test GitOps workflow
   - Potential for issues that only appear in production
   - Mitigation: Homelab scale makes this acceptable; can test ArgoCD sync locally if needed

4. **Overhead for Small Changes**:
   - Small production changes require git commit/push/merge
   - Slower than direct `kubectl apply` for quick fixes
   - Mitigation: This is intentional for production stability and auditability

### Neutral

1. **Operational Considerations**:
   - ArgoCD UI requires port-forward for access
   - Initial admin password needs to be retrieved and changed
   - ArgoCD upgrades need to be managed
   - Bootstrap script simplifies initial setup

2. **Resource Usage**:
   - ArgoCD adds 5 deployments to production cluster
   - Minimal resource overhead acceptable for homelab
   - Development cluster saves resources by not running ArgoCD

## Implementation Notes

### Bootstrap Process

ArgoCD is bootstrapped using the provided script:

```bash
./argocd/bootstrap.sh
```

This script:

1. Creates `argocd` namespace
2. Installs ArgoCD from upstream manifests
3. Waits for ArgoCD to be ready
4. Applies the homelab ArgoCD project
5. Deploys the root application (app-of-apps)
6. Displays admin credentials

### Directory Structure

```text
argocd/
├── README.md                      # Complete documentation
├── bootstrap.sh                   # Installation script
├── root-app.yaml                  # App-of-apps root
├── projects/
│   └── homelab.yaml              # ArgoCD project definition
└── apps/
    ├── podinfo-production.yaml   # Production application
    └── [additional apps]          # Add more as needed
```

**Note**: All ArgoCD Application manifests in `argocd/apps/` point to paths in `k8s-manifests/overlays/production`.

### Adding New Applications

1. Create base manifests in `k8s-manifests/base/myapp/`
2. Create production overlay in `k8s-manifests/overlays/production/` (and optionally development overlay)
3. Create ArgoCD application in `argocd/apps/myapp-production.yaml` pointing to `k8s-manifests/overlays/production`
4. Commit and push to `main` branch
5. ArgoCD automatically deploys the new application to production cluster

### Developing Applications

1. Create/update manifests in `k8s-manifests/base/myapp/`
2. Create development overlay in `k8s-manifests/overlays/development/`
3. Test locally on k3d cluster: `kubectl apply -k k8s-manifests/overlays/development`
4. Iterate and test until satisfied
5. Commit changes and merge to `main`
6. ArgoCD automatically deploys to production

### Accessing ArgoCD UI

```bash
# Port forward
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get initial password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Open https://localhost:8080
# Login: admin / <password>
```

### Emergency Procedures

If ArgoCD is unavailable, applications can be deployed manually:

```bash
# Bypass ArgoCD for emergency changes
kubectl apply -k k8s-manifests/overlays/production

# Note: ArgoCD will revert changes when it recovers
# To make permanent: disable auto-sync or commit to git
```

### Local Development Workflow

```bash
# Start k3d cluster
k3d cluster create dev

# Deploy application for testing
kubectl apply -k k8s-manifests/overlays/development

# Make changes to manifests
# Test changes
kubectl apply -k k8s-manifests/overlays/development

# When satisfied, commit and push
git add .
git commit -m "Update application"
git push origin main

# ArgoCD automatically deploys to production cluster
```

## Alternatives Considered

### 1. **ArgoCD in Development Environment**

**Description**: Install ArgoCD in k3d development cluster for environment parity.

**Rejected because**:

- Adds unnecessary overhead to local development workflow
- Slows down development iteration (requires git commits)
- k3d clusters are ephemeral and recreated frequently
- Direct `kubectl apply -k` is faster for development
- Environment parity not critical for homelab scale
- Can always test GitOps workflow on production cluster if needed

### 2. **Manual kubectl apply for All Environments**

**Description**: Skip GitOps entirely, use manual deployments everywhere.

**Rejected because**:

- No audit trail of production changes
- Configuration drift over time
- Manual errors likely in production
- Doesn't scale as applications grow
- GitOps benefits outweigh minimal overhead for production

### 3. **GitHub Actions CI/CD**

**Description**: Use GitHub Actions to run `kubectl apply` on merge to main.

**Rejected because**:

- No built-in self-healing or drift detection
- Requires exposing cluster API to GitHub runners
- Security concerns with long-lived kubeconfig credentials
- ArgoCD provides continuous reconciliation, not just on-merge deployment
- ArgoCD UI valuable for monitoring and debugging

### 4. **Staging Environment**

**Description**: Add a staging environment for pre-production testing.

**Rejected because**:

- Unnecessary complexity for single-administrator homelab
- Limited hardware resources (single bare-metal cluster)
- Can test on development k3d cluster before pushing to production
- Adds maintenance overhead without significant benefit
- Can be added later if needs change

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize Integration](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [GitOps Principles](https://opengitops.dev/)
- [k3d Documentation](https://k3d.io/)

## Related Decisions

- [ADR-001: Networking Design](./ADR-001-networking-design.md) - Tailscale-based private networking
- ADR-003: Secrets Management Strategy (future)
- ADR-004: Backup and Disaster Recovery (future)

---

**Last Updated**: 2025-12-12
