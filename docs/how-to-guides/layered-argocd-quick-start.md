# Quick Start Guide: Layered ArgoCD Implementation

**Purpose**: Get started quickly with implementing the layered ArgoCD architecture  
**Audience**: Platform engineers and developers  
**Time to Complete Phase 0**: ~1 hour  
**Last Updated**: December 11, 2025

---

## Prerequisites

Before starting, ensure you have:

- [x] Kubernetes cluster running and accessible
- [x] `kubectl` configured and working
- [x] ArgoCD CLI installed (optional but helpful)
- [x] `kustomize` installed (v4.0+)
- [x] Git access to this repository
- [x] Permissions to create namespaces and deploy to cluster

**Verify prerequisites**:
```bash
# Check cluster access
kubectl cluster-info
kubectl get nodes

# Check kustomize
kustomize version

# Check ArgoCD CLI (optional)
argocd version

# Check repository access
git remote -v
git status
```

---

## Phase 0: Quick Win (Start Here!)

**Goal**: Get ArgoCD deploying Podinfo with the current setup

**Time**: 30-60 minutes

### Step 1: Create Application Directory

```bash
# Create the directory where root-app expects to find Applications
mkdir -p argocd/apps
```

### Step 2: Create Podinfo Application Manifest

Create `argocd/apps/podinfo-dev.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo-development
  namespace: argocd
  labels:
    environment: development
    app: podinfo
    layer: application
spec:
  project: homelab
  
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: k8s-manifests/overlays/development
  
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

### Step 3: Bootstrap ArgoCD

```bash
# Run the bootstrap script
cd /workspace
./argocd/bootstrap.sh

# Wait for ArgoCD to be ready (may take 2-3 minutes)
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server -n argocd
```

### Step 4: Verify Deployment

```bash
# Check ArgoCD is running
kubectl get pods -n argocd

# Check root-app was created
kubectl get application root-app -n argocd

# Check podinfo Application was created by root-app
kubectl get application podinfo-development -n argocd

# Check podinfo Application status
kubectl describe application podinfo-development -n argocd

# Check podinfo pods are running
kubectl get pods -l app=podinfo

# Check podinfo service
kubectl get svc podinfo
```

### Step 5: Access ArgoCD UI (Optional)

```bash
# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open browser to https://localhost:8080
# Username: admin
# Password: (from command above)
```

### Step 6: Access Podinfo (Optional)

```bash
# Port-forward to access Podinfo
kubectl port-forward svc/podinfo 9898:9898

# Open browser to http://localhost:9898
# Or curl it
curl http://localhost:9898
```

### Phase 0 Success Criteria

- ✅ ArgoCD pods running in `argocd` namespace
- ✅ Root-app shows as Healthy and Synced
- ✅ Podinfo Application shows as Healthy and Synced
- ✅ Podinfo pods running in `default` namespace
- ✅ Can access Podinfo service

**If successful, you're ready for Phase 1!**

---

## Phase 1: Create Layered Structure

**Goal**: Set up the new three-layer directory structure

**Time**: 2-3 hours

### Step 1: Create Directory Structure

```bash
# Create main argocd-applications directory
mkdir -p argocd-applications

# Create foundation layer structure
mkdir -p argocd-applications/foundation/base
mkdir -p argocd-applications/foundation/overlays/{development,staging,production}

# Create platform layer structure
mkdir -p argocd-applications/platform/base
mkdir -p argocd-applications/platform/overlays/{development,staging,production}

# Create application layer structure
mkdir -p argocd-applications/applications/base
mkdir -p argocd-applications/applications/overlays/{development,staging,production}

# Create directory for ArgoCD Application manifests
mkdir -p argocd-applications/argocd-apps/development
```

### Step 2: Create Placeholder Kustomizations

Create empty kustomization files for each layer/overlay:

**Foundation base** (`argocd-applications/foundation/base/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# Resources will be added in Phase 3
resources: []
```

**Platform base** (`argocd-applications/platform/base/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# Resources will be added in Phase 4
resources: []
```

**Application base** (`argocd-applications/applications/base/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# Resources will be added in Phase 2
resources: []
```

**Development overlays** (repeat for staging and production):

`argocd-applications/foundation/overlays/development/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
commonLabels:
  environment: development
```

`argocd-applications/platform/overlays/development/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
commonLabels:
  environment: development
```

`argocd-applications/applications/overlays/development/kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - ../../base
commonLabels:
  environment: development
```

### Step 3: Create ArgoCD Projects

Create three new project files in `argocd/projects/`:

**Foundation Project** (`argocd/projects/foundation.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: foundation
  namespace: argocd
spec:
  description: Foundation layer - namespaces, RBAC, network policies
  
  sourceRepos:
    - https://github.com/dr3dr3/k8s-homelab-admin.git
  
  destinations:
    - namespace: 'kube-*'
      server: https://kubernetes.default.svc
    - namespace: 'monitoring'
      server: https://kubernetes.default.svc
    - namespace: 'cert-manager'
      server: https://kubernetes.default.svc
    - namespace: 'opentelemetry'
      server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
    - group: 'rbac.authorization.k8s.io'
      kind: ClusterRole
    - group: 'rbac.authorization.k8s.io'
      kind: ClusterRoleBinding
    - group: 'networking.k8s.io'
      kind: NetworkPolicy
```

**Platform Project** (`argocd/projects/platform.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform layer - infrastructure services
  
  sourceRepos:
    - https://github.com/dr3dr3/k8s-homelab-admin.git
    - https://prometheus-community.github.io/helm-charts
    - https://charts.jetstack.io
  
  destinations:
    - namespace: 'monitoring'
      server: https://kubernetes.default.svc
    - namespace: 'cert-manager'
      server: https://kubernetes.default.svc
    - namespace: 'opentelemetry'
      server: https://kubernetes.default.svc
  
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
```

**Applications Project** (`argocd/projects/applications.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: applications
  namespace: argocd
spec:
  description: Application layer - application workloads
  
  sourceRepos:
    - https://github.com/dr3dr3/k8s-homelab-admin.git
  
  destinations:
    - namespace: 'default'
      server: https://kubernetes.default.svc
    - namespace: 'podinfo'
      server: https://kubernetes.default.svc
  
  namespaceResourceWhitelist:
    - group: '*'
      kind: '*'
  
  clusterResourceBlacklist:
    - group: '*'
      kind: '*'
```

### Step 4: Apply Projects

```bash
# Apply all projects
kubectl apply -f argocd/projects/foundation.yaml
kubectl apply -f argocd/projects/platform.yaml
kubectl apply -f argocd/projects/applications.yaml

# Verify projects were created
kubectl get appprojects -n argocd
```

### Step 5: Create Layer Applications

Create ArgoCD Application manifests for each layer:

**Foundation** (`argocd-applications/argocd-apps/development/foundation.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foundation-development
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  labels:
    layer: foundation
    environment: development
spec:
  project: foundation
  
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: argocd-applications/foundation/overlays/development
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated: false  # Manual sync during setup
    syncOptions:
      - CreateNamespace=true
```

**Platform** (`argocd-applications/argocd-apps/development/platform.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-development
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
  labels:
    layer: platform
    environment: development
spec:
  project: platform
  
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: argocd-applications/platform/overlays/development
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated: false  # Manual sync during setup
    syncOptions:
      - CreateNamespace=true
```

**Applications** (`argocd-applications/argocd-apps/development/applications.yaml`):
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: applications-development
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "20"
  labels:
    layer: application
    environment: development
spec:
  project: applications
  
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: argocd-applications/applications/overlays/development
  
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  
  syncPolicy:
    automated: false  # Manual sync during setup
    syncOptions:
      - CreateNamespace=true
```

### Step 6: Validate Structure

```bash
# Verify kustomize builds work (should return empty)
kustomize build argocd-applications/foundation/overlays/development
kustomize build argocd-applications/platform/overlays/development
kustomize build argocd-applications/applications/overlays/development

# Verify Application manifests are valid
kubectl apply --dry-run=client -f argocd-applications/argocd-apps/development/
```

### Phase 1 Success Criteria

- ✅ All directories created
- ✅ All kustomization files valid
- ✅ Three new ArgoCD Projects applied
- ✅ Three layer Application manifests created
- ✅ Kustomize builds succeed (with empty output)
- ✅ No errors in dry-run

**If successful, you're ready for Phase 2!**

---

## Next Steps

After completing Phase 0 and Phase 1:

1. **Review the full plan**: See [IMPLEMENTATION_PLAN.md](../../IMPLEMENTATION_PLAN.md) for Phases 2-7
2. **Track progress**: Update [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md)
3. **Proceed to Phase 2**: Migrate Podinfo to the new application layer structure

---

## Troubleshooting

### ArgoCD Bootstrap Fails

**Problem**: Bootstrap script fails or ArgoCD doesn't start

**Solutions**:
- Check cluster has sufficient resources: `kubectl top nodes`
- Check ArgoCD namespace exists: `kubectl get namespace argocd`
- Review ArgoCD pod logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`
- Verify network connectivity to container registry

### Root-App Not Syncing

**Problem**: Root-app exists but shows OutOfSync or doesn't create child apps

**Solutions**:
- Check root-app status: `kubectl describe application root-app -n argocd`
- Verify `argocd/apps/` directory exists and has YAML files
- Check repository permissions and credentials
- Force sync: `argocd app sync root-app` (if using CLI)

### Podinfo Application Not Appearing

**Problem**: Root-app synced but Podinfo Application not created

**Solutions**:
- Verify file exists: `ls -la argocd/apps/podinfo-dev.yaml`
- Check file syntax: `kubectl apply --dry-run=client -f argocd/apps/podinfo-dev.yaml`
- Check root-app logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller`
- Verify directory pattern in root-app matches

### Kustomize Build Errors

**Problem**: `kustomize build` fails with errors

**Solutions**:
- Check kustomize version: `kustomize version` (need v4.0+)
- Verify YAML syntax in kustomization files
- Check file paths in resources lists
- Ensure bases paths are correct relative paths

---

## Additional Resources

- **Full Implementation Plan**: [IMPLEMENTATION_PLAN.md](../../IMPLEMENTATION_PLAN.md)
- **Implementation Status**: [IMPLEMENTATION_STATUS.md](../../IMPLEMENTATION_STATUS.md)
- **Architecture Decision**: [ADR-003](../reference/architecture-decision-records/ADR-003-layered-argocd-structure.md)
- **ArgoCD Documentation**: https://argo-cd.readthedocs.io/
- **Kustomize Tutorial**: https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/
