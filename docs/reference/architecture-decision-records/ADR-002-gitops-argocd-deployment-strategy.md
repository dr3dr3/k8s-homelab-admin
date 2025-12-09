# ADR-002: GitOps and ArgoCD Deployment Strategy

**Status**: Accepted
**Date**: 2025-12-09
**Decision Makers**: Homelab Administrator
**Technical Story**: Establishing GitOps-based application deployment strategy for homelab Kubernetes clusters

## Context

The Kubernetes homelab infrastructure includes multiple environments (production, staging, development) that require consistent, auditable, and automated deployment workflows. As the homelab grows, manual `kubectl apply` commands become error-prone and lack proper change tracking. A GitOps approach provides declarative infrastructure management with version control as the single source of truth.

Key requirements:

- Automated deployment from git repository on merge to main branch
- Self-healing capabilities to maintain desired state
- Support for multiple environments (production, staging, development)
- Simplified deployment workflow suitable for a single administrator
- Integration with existing Kustomize manifest structure
- Minimal operational overhead for homelab context

The manifests are organized using Kustomize with base configurations and environment-specific overlays at `k8s-manifests/overlays/{environment}`.

## Decision

We will implement a **GitOps workflow using ArgoCD** with environment-specific deployment strategies:

### 1. **Production Environment - Full GitOps with ArgoCD**

**Cluster**: Talos bare metal (`k8s-homelab-production`)
**ArgoCD**: YES, fully deployed and configured
**Purpose**: Real workloads, always-on applications

Configuration:

- ArgoCD installed in `argocd` namespace
- Applications managed via app-of-apps pattern
- Source repository: `https://github.com/dr3dr3/k8s-homelab-admin.git`
- Target overlay: `k8s-manifests/overlays/production`
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

### 3. **Staging Environment - Optional, Namespace-Based**

**Cluster**: Same as production (Talos bare metal)
**ArgoCD**: Shared with production (same instance)
**Purpose**: Pre-production validation (when needed)

Implementation:

- Additional ArgoCD Application manifest: `argocd/apps/podinfo-staging.yaml`
- Target overlay: `k8s-manifests/overlays/staging`
- Deploys to `staging` namespace within production cluster
- Uses same GitOps workflow as production
- Can be added later if/when needed

### 4. **App-of-Apps Pattern**

ArgoCD applications are managed using the app-of-apps pattern:

```text
root-app (watches argocd/apps/*.yaml)
├── podinfo-production (→ k8s-manifests/overlays/production/podinfo)
├── podinfo-staging (→ k8s-manifests/overlays/staging/podinfo) [optional]
└── [future applications]
```

Benefits:

- Single `kubectl apply -f argocd/root-app.yaml` bootstraps entire system
- New applications added by creating YAML files in `argocd/apps/`
- ArgoCD itself manages application lifecycle via GitOps

### 5. **Sync Policy Configuration**

All production applications use:

- **automated.prune**: `true` - Resources deleted from git are removed from cluster
- **automated.selfHeal**: `true` - Manual `kubectl` changes are automatically reverted
- **syncOptions.CreateNamespace**: `true` - Namespaces created automatically
- **syncOptions.ServerSideApply**: `true` - Use server-side apply for production
- **targetRevision**: `main` - Trunk-based development workflow

### 6. **Kustomize Integration**

ArgoCD has native Kustomize support:

- Automatically detects `kustomization.yaml` files
- Runs `kustomize build` on the specified overlay directory
- Follows base references (e.g., `../../base`) automatically
- No changes needed to existing Kustomize structure

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
   - Single ArgoCD instance for production
   - No complex multi-cluster management needed
   - Development stays simple with direct kubectl
   - Staging optional, can be added incrementally

5. **Developer Experience**:
   - Fast local development with k3d (no GitOps overhead)
   - Test changes before committing
   - Production deployment automatic after merge

6. **Scalability**:
   - Easy to add new applications (create YAML in `argocd/apps/`)
   - App-of-apps pattern scales to many applications
   - Can add staging or additional environments later

### Negative

1. **Learning Curve**:
   - Administrator needs to understand ArgoCD concepts
   - Different workflows for dev (kubectl) vs production (git)
   - Mitigation: Comprehensive documentation in `argocd/README.md`

2. **ArgoCD Dependency**:
   - Production cluster depends on ArgoCD availability
   - If ArgoCD fails, deployments are blocked
   - Mitigation: Can always fall back to `kubectl apply -k` in emergencies

3. **Development-Production Parity**:
   - Dev environment doesn't test GitOps workflow
   - Potential for issues that only appear in production
   - Mitigation: Use staging environment for pre-production testing when needed

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
    ├── podinfo-production.yaml   # Production applications
    └── [additional apps]          # Add more as needed
```

### Adding New Applications

1. Create base manifests in `k8s-manifests/base/myapp/`
2. Create overlay in `k8s-manifests/overlays/production/myapp/`
3. Create ArgoCD application in `argocd/apps/myapp-production.yaml`
4. Commit and push to `main` branch
5. ArgoCD automatically deploys the new application

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

## Alternatives Considered

### 1. **FluxCD Instead of ArgoCD**

**Description**: Use FluxCD for GitOps instead of ArgoCD.

**Rejected because**:

- ArgoCD has better UI/UX for visualizing application state
- App-of-apps pattern is more straightforward in ArgoCD
- ArgoCD has stronger community adoption and documentation
- For homelab with single administrator, ArgoCD UI is valuable
- Both are excellent choices; ArgoCD selected for UI benefits

### 2. **ArgoCD in All Environments (Including Dev)**

**Description**: Install ArgoCD in k3d development cluster for consistency.

**Rejected because**:

- Adds unnecessary overhead to local development workflow
- Slows down development iteration (requires git commits)
- k3d clusters are ephemeral and recreated frequently
- Direct `kubectl apply -k` is faster for development
- Production-development parity not critical for homelab

### 3. **Separate ArgoCD Instances per Environment**

**Description**: Deploy separate ArgoCD in production, staging, and development clusters.

**Rejected because**:

- Excessive complexity for homelab scale
- Multiple ArgoCD instances to maintain and upgrade
- No clear benefit over single instance or no ArgoCD in dev
- Staging can share production cluster and ArgoCD instance

### 4. **Manual kubectl apply for All Environments**

**Description**: Skip GitOps entirely, use manual deployments everywhere.

**Rejected because**:

- No audit trail of production changes
- Configuration drift over time
- Manual errors likely in production
- Doesn't scale as applications grow
- GitOps benefits outweigh minimal overhead

### 5. **GitHub Actions CI/CD**

**Description**: Use GitHub Actions to run `kubectl apply` on merge to main.

**Rejected because**:

- No built-in self-healing or drift detection
- Requires exposing cluster API to GitHub runners
- Security concerns with long-lived kubeconfig credentials
- ArgoCD provides continuous reconciliation, not just on-merge deployment
- ArgoCD UI valuable for monitoring and debugging

## References

- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ArgoCD App-of-Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- [Kustomize Integration](https://argo-cd.readthedocs.io/en/stable/user-guide/kustomize/)
- [GitOps Principles](https://opengitops.dev/)
- [Homelab k8s-manifests Structure](../../k8s-manifests/README.md)

## Related Decisions

- [ADR-001: Networking Design](./ADR-001-networking-design.md) - Tailscale-based private networking
- ADR-003: Secrets Management Strategy (future)
- ADR-004: Backup and Disaster Recovery (future)

---

**Last Updated**: 2025-12-09
