# Implementation Plan: Simplified GitOps with ArgoCD

**Date**: December 12, 2025  
**Based On**: ADR-002: GitOps and ArgoCD Deployment Strategy  
**Status**: Active  
**Last Updated**: December 12, 2025

## Executive Summary

This plan outlines the implementation of a **simplified GitOps approach** for the homelab Kubernetes infrastructure:

- **Development**: k3d cluster with direct kubectl apply (no ArgoCD)
- **Production**: Talos cluster with ArgoCD for full GitOps
- **No staging environment** (removed for simplicity)
- **All manifests** in `k8s-manifests/` folder
- **ArgoCD configuration** in `argocd/` folder

### Current State Analysis

**What Exists:**
- ✅ ArgoCD bootstrap script (`argocd/bootstrap.sh`) - fully functional
- ✅ Root app (`argocd/root-app.yaml`) - configured for app-of-apps pattern
- ✅ ArgoCD project (`argocd/projects/homelab.yaml`) - permissive configuration
- ✅ Kustomize structure in `k8s-manifests/` with base and overlays
- ✅ Podinfo manifests in `k8s-manifests/base/podinfo/`
- ✅ Directory `argocd/apps/` with podinfo-dev.yaml

**Target State:**
- Production ArgoCD Applications pointing to `k8s-manifests/overlays/production`
- Development overlay for local k3d testing only (no ArgoCD)
- Clean workspace with no staging references
- Updated documentation

---

## Implementation Phases

### Phase 1: Cleanup Workspace (Current)

**Duration**: 1 day  
**Objective**: Remove unnecessary directories and staging references  
**Risk Level**: Low

#### Tasks

1. **Remove argocd/applications directory**
   ```bash
   rm -rf argocd/applications/
   ```
   This was created for the complex layered approach we're not implementing.

2. **Remove staging overlay**
   ```bash
   rm -rf k8s-manifests/overlays/staging/
   ```

3. **Update podinfo-dev.yaml to podinfo-production.yaml**
   - Rename file: `mv argocd/apps/podinfo-dev.yaml argocd/apps/podinfo-production.yaml`
   - Update name to `podinfo-production`
   - Update path to point to `k8s-manifests/overlays/production`

4. **Update kustomize overlays**
   - Ensure `k8s-manifests/overlays/development/kustomization.yaml` exists and is correct
   - Ensure `k8s-manifests/overlays/production/kustomization.yaml` exists and is correct
   - Both should reference `../../base`

#### Validation

- [ ] `argocd/applications/` directory removed
- [ ] No staging references in workspace
- [ ] `argocd/apps/podinfo-production.yaml` exists and points to production overlay
- [ ] `kustomize build k8s-manifests/overlays/production` produces valid manifests
- [ ] `kustomize build k8s-manifests/overlays/development` produces valid manifests

#### Deliverables
- ✅ Clean workspace structure
- ✅ Production-ready ArgoCD Application manifest
- ✅ Separate development overlay for local testing

---

### Phase 2: Deploy to Production

**Duration**: 1 day  
**Objective**: Deploy corrected configuration to production cluster  
**Risk Level**: Low

#### Tasks

1. **Commit and push changes**
   ```bash
   git add .
   git commit -m "Simplify architecture: remove staging, use k8s-manifests overlays"
   git push origin main
   ```

2. **Delete old Application from cluster**
   ```bash
   kubectl delete application podinfo-development -n argocd
   ```

3. **Apply new Application**
   ```bash
   kubectl apply -f argocd/apps/podinfo-production.yaml
   ```
   Or let root-app sync automatically if it's watching `argocd/apps/`

4. **Monitor sync**
   - Check ArgoCD UI for sync status
   - Verify podinfo pods are running
   - Check service accessibility

#### Validation

- [ ] Old `podinfo-development` Application removed
- [ ] New `podinfo-production` Application synced and healthy
- [ ] Podinfo pods running in production cluster
- [ ] Service accessible
- [ ] No orphaned resources

#### Deliverables
- ✅ Podinfo deployed from production overlay
- ✅ ArgoCD managing production cluster
- ✅ Working GitOps workflow

---

### Phase 3: Documentation

**Duration**: 1 day  
**Objective**: Update all documentation to reflect simplified architecture  
**Risk Level**: Low

#### Tasks

1. **Update argocd/README.md**
   - Document bootstrap process
   - Explain app-of-apps pattern
   - Describe how to add new applications
   - Include development workflow

2. **Update k8s-manifests/README.md**
   - Explain base/overlay structure
   - Document development vs production overlays
   - Provide examples of local testing
   - Explain how changes flow to production

3. **Update root README.md**
   - Update architecture overview
   - Link to ADR-002
   - Remove references to staging
   - Update directory structure diagram

4. **Update IMPLEMENTATION_STATUS.md**
   - Mark Phase 1-3 as complete
   - Document final state
   - Archive this as historical record

#### Validation

- [ ] All READMEs updated and accurate
- [ ] No references to staging environment
- [ ] No references to layered architecture (foundation/platform/application)
- [ ] Documentation matches actual implementation
- [ ] Examples are tested and working

#### Deliverables
- ✅ Complete documentation suite
- ✅ Clear onboarding for new applications
- ✅ Development workflow documented

---

## Adding New Applications (Future)

### Process

1. **Create base manifests**
   ```bash
   mkdir -p k8s-manifests/base/myapp/
   # Add deployment.yaml, service.yaml, etc.
   # Create kustomization.yaml
   ```

2. **Create overlays**
   ```bash
   # Development overlay
   cat > k8s-manifests/overlays/development/myapp-patch.yaml
   
   # Production overlay  
   cat > k8s-manifests/overlays/production/myapp-patch.yaml
   ```

3. **Test locally on k3d**
   ```bash
   kubectl apply -k k8s-manifests/overlays/development
   # Test and iterate
   ```

4. **Create ArgoCD Application**
   ```bash
   cat > argocd/apps/myapp-production.yaml
   # Configure to point to k8s-manifests/overlays/production
   ```

5. **Commit and deploy**
   ```bash
   git add .
   git commit -m "Add myapp"
   git push origin main
   # ArgoCD syncs automatically
   ```

---

## Local Development Workflow

### Setup k3d Cluster

```bash
# Create development cluster
k3d cluster create dev

# Verify cluster
kubectl cluster-info
```

### Deploy Application

```bash
# Deploy to development cluster
kubectl apply -k k8s-manifests/overlays/development

# Watch pods
kubectl get pods -w

# Test application
kubectl port-forward svc/podinfo 9898:9898
curl http://localhost:9898
```

### Iterate and Test

```bash
# Make changes to manifests
vim k8s-manifests/base/podinfo/deployment.yaml

# Apply changes
kubectl apply -k k8s-manifests/overlays/development

# Test changes
# Repeat until satisfied
```

### Promote to Production

```bash
# Commit changes
git add .
git commit -m "Update podinfo configuration"
git push origin main

# ArgoCD automatically deploys to production
# Monitor in ArgoCD UI
```

---

## Directory Structure (Final)

```text
k8s-manifests/               # All Kubernetes manifests
├── README.md
├── base/                    # Base configurations
│   ├── kustomization.yaml
│   └── podinfo/
│       ├── deployment.yaml
│       ├── service.yaml
│       └── kustomization.yaml
└── overlays/
    ├── development/         # For k3d (kubectl apply -k)
    │   ├── kustomization.yaml
    │   └── README.md
    └── production/          # For Talos (ArgoCD)
        ├── kustomization.yaml
        └── README.md

argocd/                      # ArgoCD configuration
├── README.md
├── bootstrap.sh             # Installation script
├── root-app.yaml            # App-of-apps root
├── projects/
│   └── homelab.yaml         # ArgoCD project
└── apps/                    # ArgoCD Applications
    ├── podinfo-production.yaml
    └── [future apps]
```

---

## Success Criteria

- [x] ADR-002 updated to reflect simplified architecture
- [x] ADR-003 marked as superseded
- [ ] Workspace cleaned of staging and complex layered structure
- [ ] Production cluster using ArgoCD with correct manifests
- [ ] Development workflow documented and tested
- [ ] All documentation updated and accurate
- [ ] Team can add new applications easily

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Deleting wrong directories | Medium | Test kustomize build before deleting; have git history |
| ArgoCD sync issues after changes | Medium | Can manually apply with kubectl if needed |
| Missing documentation | Low | Update docs as part of each phase |
| Development-production drift | Low | Use same base manifests, only differ in overlays |

---

## References

- [ADR-002: GitOps and ArgoCD Deployment Strategy](docs/reference/architecture-decision-records/ADR-002-gitops-argocd-deployment-strategy.md)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [Kustomize Documentation](https://kustomize.io/)
- [k3d Documentation](https://k3d.io/)

---

**Last Updated**: 2025-12-12
