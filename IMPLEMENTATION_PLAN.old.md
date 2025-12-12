# Implementation Plan: Layered ArgoCD Architecture

**Date**: December 11, 2025  
**Based On**: ADR-003: Layered ArgoCD Application Structure  
**Status**: Updated - Incremental Migration Approach  
**Last Updated**: December 11, 2025

## Executive Summary

This plan outlines an **incremental, phase-by-phase** implementation of a three-layer ArgoCD architecture for the homelab Kubernetes cluster. The approach mirrors the existing Terraform layering patterns and provides clear separation of concerns across Foundation, Platform, and Application layers.

### Current State Analysis

**What Exists:**
- ✅ ArgoCD bootstrap script (`argocd/bootstrap.sh`) - fully functional
- ✅ Root app (`argocd/root-app.yaml`) - configured for app-of-apps pattern pointing to `argocd/apps/`
- ✅ Single ArgoCD project (`argocd/projects/homelab.yaml`) - permissive configuration
- ✅ Kustomize structure in `k8s-manifests/` with base and environment overlays
- ✅ Podinfo manifests in `k8s-manifests/base/podinfo/` (deployment and service)
- ✅ Empty directory structure under `argocd/applications/` (base/overlays exist - ready to populate)
- ❌ Missing `argocd/apps/` directory (where root-app expects Application manifests)

**Critical Gap:** Root-app points to non-existent `argocd/apps/`, so nothing is currently deployed.

**Target State:**
- Fully functional three-layer architecture in `argocd/applications/`
- Foundation layer with namespaces, RBAC, and network policies
- Platform layer with observability (Prometheus, Grafana), telemetry (OpenTelemetry Collector), and certificate management (Cert-Manager)
- Application layer with Podinfo and future applications
- Separate ArgoCD Projects for governance and access control
- Sync waves enforcing correct deployment order (0 → 10 → 20)
- Multi-environment support (development, staging, production)

### Migration Strategy

**Incremental phases** with working deployments after each phase, allowing for:
- Lower risk through smaller changes
- Faster feedback and learning
- Ability to pause or rollback at any phase
- Parallel operation of old and new structures during transition
- Team validation at each milestone

---

## Phase 0: Quick Win - Get Current Setup Working

**Duration**: 1 day  
**Objective**: Make the existing structure functional before refactoring  
**Risk Level**: Low

### Why This Phase?
- Proves the current setup works end-to-end
- Provides working baseline for comparison
- Identifies any ArgoCD installation/configuration issues
- Delivers immediate value (working Podinfo deployment)
- Builds team confidence in GitOps approach

### Tasks

#### 0.1 Create Missing Directory
**Action**: Create `argocd/apps/` directory (where root-app expects to find Application manifests)

```bash
mkdir -p argocd/apps
```

#### 0.2 Create Simple Podinfo Application
**Action**: Create `argocd/apps/podinfo-dev.yaml` pointing to existing kustomize structure

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: podinfo-development
  namespace: argocd
  labels:
    environment: development
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

#### 0.3 Test Bootstrap Process
**Action**: Run bootstrap script and verify deployment

```bash
./argocd/bootstrap.sh
```

**Validation Checklist:**
- [ ] ArgoCD installs successfully
- [ ] Root-app is created and synced
- [ ] Podinfo Application appears in ArgoCD UI
- [ ] Podinfo Application syncs successfully
- [ ] Podinfo pods are running in cluster
- [ ] Can access Podinfo service

#### 0.4 Document Current Working State
**Action**: Take note of working configuration for baseline comparison

### Deliverables
- ✅ Working Podinfo deployment via ArgoCD
- ✅ Validated app-of-apps pattern
- ✅ Confidence in bootstrap process
- ✅ Baseline for migration comparison

### Success Criteria
- Podinfo accessible and responding
- ArgoCD shows all applications healthy
- Bootstrap script runs without errors
- Team understands current GitOps workflow

---

## Phase 1: Foundation for Layered Architecture

**Duration**: 2-3 days  
**Objective**: Create new directory structure and governance model alongside existing setup  
**Risk Level**: Low (non-disruptive)

### Why This Phase?
- Creates structure without disrupting working deployment
- Allows team review and feedback before migration
- Enables incremental population of layers
- Establishes governance model early

### Tasks

#### 1.1 Create ArgoCD Projects for Governance

#### 1.1 Create ArgoCD Projects for Governance

**Objective**: Define separate ArgoCD Projects for each layer to enforce access control and resource boundaries.

**Tasks**:

1. **Create Foundation Project** (`argocd/projects/foundation.yaml`)
   - Source repos: GitHub homelab admin repo
   - Destinations: Foundation namespaces (kube-system, monitoring, cert-manager, opentelemetry)
   - Cluster resources: Allow namespaces, RBAC resources, network policies
   - Owned by: Platform Engineering team

2. **Create Platform Project** (`argocd/projects/platform.yaml`)
   - Source repos: GitHub homelab admin repo + external Helm repos
   - Destinations: Platform namespaces (monitoring, cert-manager, istio-system, etc.)
   - Cluster resources: Broad access for infrastructure components
   - Owned by: Platform Engineering team

3. **Create Applications Project** (`argocd/projects/applications.yaml`)
   - Source repos: GitHub homelab admin repo
   - Destinations: Application namespaces (default, podinfo, etc.)
   - Cluster resources: Limited to application-level resources
   - Owned by: Product/Application teams

4. **Keep Existing homelab.yaml** for backward compatibility during migration

**Deliverables**:
- `/workspace/argocd/projects/foundation.yaml`
- `/workspace/argocd/projects/platform.yaml`
- `/workspace/argocd/projects/applications.yaml`

---

#### 1.2 Create New Directory Structure

**Objective**: Establish complete directory hierarchy for layered architecture

**Structure to Create**:

```
argocd/applications/
├── README.md
├── foundation/
│   ├── base/
│   │   └── kustomization.yaml (empty initially, will reference subdirectories)
│   └── overlays/
│       ├── development/
│       │   └── kustomization.yaml
│       ├── staging/
│       │   └── kustomization.yaml
│       └── production/
│           └── kustomization.yaml
├── platform/
│   ├── base/
│   │   └── kustomization.yaml (empty initially)
│   └── overlays/
│       ├── development/
│       │   └── kustomization.yaml
│       ├── staging/
│       │   └── kustomization.yaml
│       └── production/
│           └── kustomization.yaml
├── applications/
│   ├── base/
│   │   └── kustomization.yaml (empty initially)
│   └── overlays/
│       ├── development/
│       │   └── kustomization.yaml
│       ├── staging/
│       │   └── kustomization.yaml
│       └── production/
│           └── kustomization.yaml

argocd/apps/
└── development/
        ├── foundation.yaml
        ├── platform.yaml
        └── applications.yaml
```

**Note**: Create minimal/placeholder kustomization.yaml files initially:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
# Resources will be added in subsequent phases
resources: []
```

---

#### 1.3 Create Placeholder ArgoCD Applications for Development

**Objective**: Define ArgoCD Application manifests with correct sync waves but pointing to empty kustomizations

**Tasks**:

1. **Create Development Foundation Application** (`argocd/apps/development/foundation.yaml`)
   - Name: `foundation-development`
   - Sync Wave: `0`
   - Path: `argocd-applications/foundation/overlays/development`
   - Project: `foundation`
   - Sync Policy: **Manual** (automated: false) during initial setup
   - Prune: false (safety during migration)

2. **Create Development Platform Application** (`argocd/apps/development/platform.yaml`)
   - Name: `platform-development`
   - Sync Wave: `10`
   - Path: `argocd-applications/platform/overlays/development`
   - Project: `platform`
   - Sync Policy: **Manual** initially
   - Prune: false

3. **Create Development Applications** (`argocd/apps/development/applications.yaml`)
   - Name: `applications-development`
   - Sync Wave: `20`
   - Path: `argocd-applications/applications/overlays/development`
   - Project: `applications`
   - Sync Policy: **Manual** initially
   - Prune: false

**Important**: These applications won't deploy anything yet since kustomizations are empty.

**Deliverables**:
- Complete directory structure created
- Three new ArgoCD Projects defined
- Three placeholder Application manifests for development environment
- Documentation README in argocd-applications/

### Validation

**Checklist**:
- [ ] All directories created with correct structure
- [ ] Kustomization files have valid YAML syntax
- [ ] ArgoCD Projects apply without errors: `kubectl apply -f argocd/projects/`
- [ ] Can do `kustomize build` on all overlays (returns empty result)
- [ ] Application manifests have valid syntax

### Deliverables
- ✅ Complete `argocd/applications/` directory structure (foundation, platform, applications layers)
- ✅ Complete `argocd/apps/` directory with Application manifests
- ✅ Three new ArgoCD Projects for governance
- ✅ Placeholder Application manifests with correct sync waves
- ✅ Documentation of structure in argocd/applications/README.md

### Success Criteria
- Structure mirrors ADR-003 specification
- Projects enforce appropriate access controls
- Team understands new organization
- Ready to populate layers incrementally

---

## Phase 2: Migrate Podinfo to Application Layer

**Duration**: 1-2 days  
**Objective**: Move first application to new structure as proof-of-concept  
**Risk Level**: Low (test application)

### Why This Phase?
- Proves application layer works end-to-end
- Low risk since Podinfo is a test application
- Creates reusable pattern for future applications
- Validates kustomize overlay approach
- Can run parallel to Phase 0 deployment initially

### Tasks

#### 2.1 Copy Podinfo to New Application Layer Structure

**Objective**: Migrate Podinfo manifests from `k8s-manifests/` to `argocd/applications/applications/`

**Actions**:

1. **Create Podinfo subdirectory** in application layer base:
   ```
   argocd-applications/applications/base/podinfo/
   ├── deployment.yaml
   ├── service.yaml
   └── kustomization.yaml
   ```

2. **Copy manifests** from `k8s-manifests/base/podinfo/`:
   - Copy `deployment.yaml`
   - Copy `service.yaml`
   - Create new `kustomization.yaml` that references these files

3. **Update base kustomization** (`argocd/applications/applications/base/kustomization.yaml`):
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - podinfo
   ```

---

#### 2.2 Create Environment-Specific Overlays

**Objective**: Configure Podinfo for each environment with appropriate settings

**Development Overlay** (`argocd/applications/applications/overlays/development/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
commonLabels:
  environment: development
namespace: default
# Could add patches for dev-specific config
```

**Staging Overlay** (`argocd/applications/applications/overlays/staging/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
commonLabels:
  environment: staging
namespace: default
# Could increase replicas, change resource limits, etc.
```

**Production Overlay** (`argocd/applications/applications/overlays/production/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
commonLabels:
  environment: production
namespace: default
# Production-specific patches (more replicas, resource limits, etc.)
```

---

#### 2.3 Update Application Layer ArgoCD Application

**Objective**: Point ArgoCD Application to new location

**Action**: Update `argocd/apps/development/applications.yaml`

Change from empty resources to:
```yaml
spec:
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: argocd-applications/applications/overlays/development
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

---

#### 2.4 Deploy New Structure Alongside Existing

**Objective**: Test new structure without disrupting current deployment

**Steps**:

1. **Manually apply new Application**:
   ```bash
   kubectl apply -f argocd-applications/argocd-apps/development/applications.yaml
   ```

2. **Watch sync in ArgoCD UI**:
   - Verify `applications-development` appears
   - Watch it sync and deploy Podinfo
   - Check sync wave 20 is respected

3. **Validate deployment**:
   ```bash
   kubectl get pods -l app=podinfo
   kubectl get svc podinfo
   ```

4. **Compare with Phase 0 deployment**:
   - May have two Podinfo deployments temporarily
   - Verify new one works correctly

---

#### 2.5 Cutover to New Structure

**Objective**: Remove old Podinfo deployment and keep new one

**Steps**:

1. **Delete old Application**:
   ```bash
   kubectl delete -f argocd/apps/podinfo-dev.yaml
   # Or remove the file and let root-app prune it
   ```

2. **Keep new Application** in `argocd/apps/development/`

3. **Root-app already points to** `argocd/apps/` (correct location):
   - Old: `argocd/apps/`
   - New: `argocd-applications/argocd-apps/`
   
   Or move old apps to new location incrementally

### Validation

**Checklist**:
- [ ] `kustomize build argocd/applications/applications/overlays/development` produces valid manifests
- [ ] New Podinfo Application syncs successfully
- [ ] Podinfo pods are running and healthy
- [ ] Service is accessible
- [ ] Old Podinfo deployment removed cleanly
- [ ] No orphaned resources

### Deliverables
- ✅ Podinfo running from new application layer structure
- ✅ Working kustomize overlays for all environments
- ✅ Pattern documented for future applications
- ✅ Proof that sync wave 20 works correctly

### Success Criteria
- Podinfo deployed from `argocd/applications/applications/`
- Environment overlays functioning correctly
- Team confident in application migration pattern
- Ready to add more applications to this layer

---

## Phase 3: Foundation Layer - Namespaces Only

**Duration**: 2 days  
**Objective**: Start with simplest foundation component  
**Risk Level**: Low (namespaces are non-disruptive)

### Why This Phase?
- Namespaces are simplest foundation resource
- Non-disruptive (can coexist with existing namespaces)
- Proves sync wave ordering (wave 0 before wave 20)
- Quick win before tackling complex RBAC/network policies
- Establishes pattern for foundation layer

### Tasks

#### 3.1 Create Namespace Definitions

**Objective**: Define namespaces needed for platform components

**Structure**:
```
argocd/applications/foundation/base/namespaces/
├── kustomization.yaml
└── namespaces.yaml
```

**namespaces.yaml** content:
```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
    layer: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: cert-manager
  labels:
    name: cert-manager
    layer: platform
---
apiVersion: v1
kind: Namespace
metadata:
  name: opentelemetry
  labels:
    name: opentelemetry
    layer: platform
```

**kustomization.yaml**:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces.yaml
```

---

#### 3.2 Update Foundation Base Kustomization

**Objective**: Reference namespaces in foundation layer

**Action**: Update `argocd/applications/foundation/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces
```

---

#### 3.3 Create Environment Overlays

**Objective**: Add environment-specific labels to namespaces

**Development Overlay** (`argocd/applications/foundation/overlays/development/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
commonLabels:
  environment: development
```

**Repeat for staging and production** with appropriate environment labels.

---

#### 3.4 Deploy Foundation Layer

**Objective**: Enable sync for foundation-development Application

**Steps**:

1. **Apply Foundation Application manually**:
   ```bash
   kubectl apply -f argocd-applications/argocd-apps/development/foundation.yaml
   ```

2. **Watch sync in ArgoCD**:
   - Should sync before other applications (wave 0)
   - Verify namespaces created

3. **Validate**:
   ```bash
   kubectl get namespaces -l layer=platform
   kubectl get namespace monitoring -o yaml
   ```

4. **Enable automated sync** if comfortable:
   - Update foundation.yaml to set `automated: true`

### Validation

**Checklist**:
- [ ] Foundation Application syncs at wave 0
- [ ] Namespaces created with correct labels
- [ ] Environment-specific labels applied
- [ ] Sync occurs before platform/application layers
- [ ] Can rebuild namespaces idempotently

### Deliverables
- ✅ Working foundation layer (namespaces)
- ✅ Proof sync waves work (0 before 10, 20)
- ✅ Base for adding RBAC and network policies
- ✅ Pattern for foundation resources

### Success Criteria
- Namespaces exist and labeled correctly
- Foundation syncs before other layers
- Team understands foundation layer purpose
- Ready to add RBAC and network policies (Phase 6)

---

## Phase 4: Platform Layer - Observability Stack

**Duration**: 4-5 days  
**Objective**: Add first platform components (Prometheus, Grafana)  
**Risk Level**: Medium (more complex manifests)

### Why This Phase?
- Observability is immediately useful for monitoring
- Relatively self-contained components
- Non-blocking for applications
- Can defer Istio/External-Secrets for later
- Provides metrics for all cluster components

### Tasks

#### 4.1 Choose Platform Component Approach

**Decision Point**: Helm Charts via Kustomize vs. Raw Manifests

**Recommended**: Use **kube-prometheus-stack** Helm chart via Kustomize helmCharts

**Rationale**:
- Pre-configured Prometheus + Grafana + Alertmanager
- Well-maintained by community
- Easier to upgrade
- Kustomize supports helmCharts natively

---

#### 4.2 Create Prometheus/Grafana Stack

**Structure**:
```
argocd/applications/platform/base/prometheus/
├── kustomization.yaml
└── helmCharts.yaml (or inline in kustomization)
```

**kustomization.yaml** with Helm chart:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: monitoring
helmCharts:
  - name: kube-prometheus-stack
    repo: https://prometheus-community.github.io/helm-charts
    version: 55.0.0  # pin version
    releaseName: prometheus
    namespace: monitoring
    valuesInline:
      prometheus:
        prometheusSpec:
          retention: 7d
          storageSpec:
            volumeClaimTemplate:
              spec:
                resources:
                  requests:
                    storage: 10Gi
      grafana:
        adminPassword: changeme  # Use sealed-secrets in real deployment
```

**Alternative**: If using raw manifests, generate from Helm and commit

---

#### 4.3 Add Cert-Manager (Optional for Phase 4)

**If needed for TLS**:
```
argocd/applications/platform/base/cert-manager/
├── kustomization.yaml
└── cert-manager.yaml
```

**Can defer to later** if not immediately needed.

---

#### 4.4 Create Platform Base Kustomization

**Action**: Update `argocd/applications/platform/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - prometheus
  # - cert-manager  # Add when ready
  # - jaeger  # Add in future phase
  # - opentelemetry  # Add in future phase
```

---

#### 4.5 Create Environment Overlays

**Development Overlay** (`argocd/applications/platform/overlays/development/kustomization.yaml`):
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
  - ../../base
commonLabels:
  environment: development
# Could patch Helm values for dev (less retention, smaller storage)
```

**Production**: Higher retention, more storage, HA configuration

---

#### 4.6 Deploy Platform Layer

**Steps**:

1. **Apply Platform Application**:
   ```bash
   kubectl apply -f argocd-applications/argocd-apps/development/platform.yaml
   ```

2. **Watch sync** (may take several minutes for Helm charts):
   ```bash
   kubectl get applications -n argocd -w
   ```

3. **Verify platform components**:
   ```bash
   kubectl get pods -n monitoring
   kubectl get svc -n monitoring
   ```

4. **Access Grafana**:
   ```bash
   kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
   ```

5. **Enable automated sync** once validated

### Validation

**Checklist**:
- [ ] Platform Application syncs at wave 10 (after foundation)
- [ ] Prometheus pods running and healthy
- [ ] Grafana accessible with dashboards
- [ ] Prometheus scraping metrics from cluster
- [ ] Platform layer syncs before applications (wave 20)

### Deliverables
- ✅ Working Prometheus/Grafana stack
- ✅ Metrics collection from cluster
- ✅ Pattern for adding more platform components
- ✅ Validation of wave 10 ordering

### Success Criteria
- Observability stack operational
- Metrics visible in Grafana
- Platform syncs after foundation, before apps
- Team can monitor cluster health

**Note**: Defer Jaeger, OpenTelemetry, Istio, External-Secrets to future phases as needed.

---

## Phase 5: Expand to Staging & Production Environments

**Duration**: 2-3 days  
**Objective**: Replicate working development setup to other environments  
**Risk Level**: Low (proven pattern)

### Why This Phase?
- Proves multi-environment approach works
- Validates environment-specific configurations
- Establishes promotion workflow
- Completes full implementation

### Tasks

#### 5.1 Create Staging Environment Applications

**Objective**: Replicate development structure for staging

**Actions**:

1. **Create staging directory**: `argocd/apps/staging/`

2. **Copy and adjust Application manifests**:
   - `foundation.yaml` → adjust name to `foundation-staging`, path to staging overlay
   - `platform.yaml` → adjust name to `platform-staging`, path to staging overlay
   - `applications.yaml` → adjust name to `applications-staging`, path to staging overlay

3. **Adjust sync policies**:
   - Keep automated sync but with more conservative settings
   - May want `prune: false` for platform in staging

---

#### 5.2 Create Production Environment Applications

**Objective**: Create production with manual controls

**Actions**:

1. **Create production directory**: `argocd/apps/production/`

2. **Create Application manifests** with production-specific settings:
   - Foundation: automated sync (low risk)
   - Platform: automated sync with `prune: false` (safety)
   - Applications: **manual sync only** (no automated)

3. **Production-specific configurations**:
   - Higher resource limits in overlays
   - More replicas for HA
   - Longer retention for metrics

---

#### 5.3 Update Root Application

**Objective**: Configure root-app to manage all environments

**Action**: Update `argocd/root-app.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/dr3dr3/k8s-homelab-admin.git
    targetRevision: main
    path: argocd-applications/argocd-apps  # Root of all environments
    directory:
      recurse: true
      include: '*.yaml'
```

This will pick up development/, staging/, and production/ subdirectories.

---

#### 5.4 Deploy Environments

**Development**: Already deployed and validated

**Staging**:
1. Ensure staging overlays exist for all layers
2. Apply staging Applications (or let root-app do it)
3. Validate all layers sync correctly
4. Test Podinfo in staging

**Production**:
1. Ensure production overlays exist with production settings
2. Apply production Applications
3. **Manually sync** each application
4. Validate before enabling any automation

### Validation

**Checklist**:
- [ ] All three environments have Application manifests
- [ ] Each environment has appropriate overlays
- [ ] Sync policies appropriate for each environment
- [ ] Root-app discovers all Application manifests
- [ ] Can promote changes: dev → staging → production

### Deliverables
- ✅ Staging environment fully deployed
- ✅ Production environment deployed with manual controls
- ✅ Multi-environment structure validated
- ✅ Promotion workflow established

### Success Criteria
- All three environments operational
- Environment-specific configurations working
- Team understands promotion process
- Production has appropriate safeguards

---

## Phase 6: Foundation Layer - Complete RBAC & Network Policies

**Duration**: 2-3 days  
**Objective**: Add remaining foundation components  
**Risk Level**: Medium (can impact existing workloads)

### Why This Phase?
- Completes foundation layer
- Enhances security posture
- Can be done in parallel with Phase 5
- Not blocking for functionality

### Tasks

#### 6.1 Add RBAC Resources

**Structure**:
```
argocd/applications/foundation/base/rbac/
├── kustomization.yaml
├── service-accounts.yaml
└── roles.yaml
```

**service-accounts.yaml**:
```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus-operator
  namespace: monitoring
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cert-manager
  namespace: cert-manager
```

**roles.yaml** - ClusterRoles and RoleBindings as needed

---

#### 6.2 Add Network Policies

**Structure**:
```
argocd/applications/foundation/base/network-policies/
├── kustomization.yaml
├── default-deny.yaml
└── allow-dns.yaml
```

**default-deny.yaml**:
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: default
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

**Important**: Test thoroughly in development before production!

---

#### 6.3 Update Foundation Base Kustomization

**Action**: Update `argocd/applications/foundation/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespaces
  - rbac
  - network-policies
```

---

#### 6.4 Deploy and Validate

**Steps**:
1. Test in development first
2. Verify no connectivity issues from network policies
3. Adjust policies as needed
4. Roll out to staging, then production

### Deliverables
- ✅ Complete foundation layer
- ✅ Enhanced security with RBAC and network policies
- ✅ Resource governance in place

### Success Criteria
- Foundation layer complete per ADR-003
- No unintended connectivity issues
- Security posture improved

---

## Phase 7: Cleanup & Documentation

**Duration**: 1-2 days  
**Objective**: Remove old structure, finalize documentation  
**Risk Level**: Low

### Why This Phase?
- Clean repository structure
- Complete documentation for team
- Archive old approach
- Update ADR status

### Tasks

#### 7.1 Remove Old Structure

**Actions**:

1. **Archive k8s-manifests**:
   ```bash
   mv k8s-manifests archive/k8s-manifests-old
   ```

2. **Remove old argocd/apps** (if anything remains there)

3. **Clean up argocd/applications** empty directories:
   ```bash
   rm -rf argocd/applications
   ```

4. **Update .gitignore** if needed

---

#### 7.2 Create Operations Documentation

**Create**: `docs/how-to-guides/layered-argocd-operations.md`

**Contents**:
- How to add new application to application layer
- How to add new platform component
- How to promote changes between environments
- Troubleshooting common issues
- How to view sync status by layer

---

#### 7.3 Create Architecture Documentation

**Create**: `docs/explanations/argocd-layered-architecture.md`

**Contents**:
- Visual diagram of three layers
- Sync wave flow diagram
- Dependency relationships
- When to use each layer

---

#### 7.4 Update ADR-003

**Action**: Update status from "Proposed" to "Implemented"

Add implementation notes:
- Date completed
- Any deviations from original design
- Lessons learned
- Future improvements

---

#### 7.5 Update Repository README

**Action**: Update main README.md with:
- Link to layered architecture documentation
- Quick start guide for new team members
- Link to operations guide

### Deliverables
- ✅ Clean repository structure
- ✅ Complete operational documentation
- ✅ Architecture diagrams and explanations
- ✅ Updated ADR-003
- ✅ Team training materials

### Success Criteria
- Old structure archived
- All documentation complete
- Team trained and comfortable
- ADR-003 marked as implemented

---

## Implementation Order & Dependencies

```
Phase 0 (Quick Win)
├── 0.1 Create argocd/apps/ Directory
├── 0.2 Create Simple Podinfo Application Manifest
├── 0.3 Test Bootstrap Process
└── 0.4 Document Current Working State

Phase 1 (Foundation Structure)
├── 1.1 Create ArgoCD Projects (foundation, platform, applications)
├── 1.2 Create New Directory Structure (argocd-applications/)
└── 1.3 Create Placeholder ArgoCD Applications for Development

Phase 2 (Application Layer Migration)
├── 2.1 Copy Podinfo to New Application Layer Structure
├── 2.2 Create Environment-Specific Overlays
├── 2.3 Update Application Layer ArgoCD Application
├── 2.4 Deploy New Structure Alongside Existing
└── 2.5 Cutover to New Structure

Phase 3 (Foundation - Namespaces)
├── 3.1 Create Namespace Definitions
├── 3.2 Update Foundation Base Kustomization
├── 3.3 Create Environment Overlays
└── 3.4 Deploy Foundation Layer

Phase 4 (Platform - Observability)
├── 4.1 Choose Platform Component Approach
├── 4.2 Create Prometheus/Grafana Stack
├── 4.3 Add Cert-Manager (Optional)
├── 4.4 Create Platform Base Kustomization
├── 4.5 Create Environment Overlays
└── 4.6 Deploy Platform Layer

Phase 5 (Multi-Environment Expansion)
├── 5.1 Create Staging Environment Applications
├── 5.2 Create Production Environment Applications
├── 5.3 Update Root Application
└── 5.4 Deploy Environments

Phase 6 (Foundation - Complete)
├── 6.1 Add RBAC Resources
├── 6.2 Add Network Policies
├── 6.3 Update Foundation Base Kustomization
└── 6.4 Deploy and Validate

Phase 7 (Cleanup & Documentation)
├── 7.1 Remove Old Structure
├── 7.2 Create Operations Documentation
├── 7.3 Create Architecture Documentation
├── 7.4 Update ADR-003
└── 7.5 Update Repository README
```

---

## Resource Inventory

### Foundation Layer Components

- **Namespaces**: monitoring, cert-manager, opentelemetry, argocd (reference)
- **RBAC**: Service accounts, roles, role bindings per namespace
- **Network Policies**: Default deny + DNS + ArgoCD API access

### Platform Layer Components

- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboarding
- **Jaeger**: Distributed tracing
- **OpenTelemetry Collector**: Telemetry collection and forwarding
- **Cert-Manager**: TLS certificate management

### Application Layer Components

- **Podinfo**: Web application (migrated from current setup)
- **Future**: web-app, api-service, and other applications

### ArgoCD Projects

- **foundation**: Controls foundation resources
- **platform**: Controls platform infrastructure
- **applications**: Controls application workloads

---

## Risk Mitigation

### Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|-----------|
| Namespace conflicts | High | Test in dev first, verify no existing resources conflict |
| RBAC too restrictive | High | Start permissive, tighten gradually with monitoring |
| Sync wave ordering delays | Medium | Monitor initial deployment, document expected timing |
| External service dependencies | Medium | Pin Helm chart/image versions, use image pull policy |
| Certificate renewal | Medium | Cert-manager has auto-renewal built-in, monitor |
| Data loss in transition | High | Backup all existing k8s-manifests before migration |

---

## Success Criteria

- [ ] All three layers deploy successfully in development
- [ ] Sync waves execute in correct order (foundation → platform → applications)
- [ ] Foundation resources (namespaces, RBAC, network policies) exist and function
- [ ] Platform components (Prometheus, Grafana, Jaeger, OTEL, Cert-Manager) are healthy
- [ ] Podinfo application is accessible and functioning
- [ ] ArgoCD Projects enforce appropriate access controls
- [ ] Root application successfully orchestrates all three layers
- [ ] Changes to git repo trigger appropriate sync behavior
- [ ] Documentation is complete and team is trained
- [ ] Same structure successfully deployed to staging and production

---

## Timeline Estimate

- **Phase 0 (Quick Win)**: 1 day
  - Create directory: 0.1 days
  - Create Application manifest: 0.2 days
  - Bootstrap testing: 0.5 days
  - Documentation: 0.2 days

- **Phase 1 (Foundation Structure)**: 2-3 days
  - Project creation: 0.5 days
  - Directory structure: 0.5 days
  - Placeholder applications: 0.5 days
  - Validation: 0.5 days
  - Documentation: 0.5 days

- **Phase 2 (Application Migration)**: 1-2 days
  - Copy Podinfo manifests: 0.25 days
  - Create overlays: 0.25 days
  - Deploy alongside existing: 0.5 days
  - Cutover and validation: 0.5 days

- **Phase 3 (Foundation - Namespaces)**: 2 days
  - Namespace definitions: 0.5 days
  - Kustomization setup: 0.5 days
  - Environment overlays: 0.5 days
  - Deployment and validation: 0.5 days

- **Phase 4 (Platform - Observability)**: 4-5 days
  - Prometheus/Grafana setup: 1.5 days
  - Cert-Manager (optional): 0.5 days
  - Kustomization setup: 0.5 days
  - Environment overlays: 0.5 days
  - Deployment and validation: 1-1.5 days

- **Phase 5 (Multi-Environment)**: 2-3 days
  - Staging setup: 1 day
  - Production setup: 0.5 days
  - Root app update: 0.5 days
  - Rollout and validation: 0.5-1 day

- **Phase 6 (Foundation Complete)**: 2-3 days
  - RBAC resources: 1 day
  - Network policies: 1 day
  - Testing and validation: 0.5-1 day

- **Phase 7 (Cleanup)**: 1-2 days
  - Archive old structure: 0.5 days
  - Operations documentation: 0.5 days
  - Architecture documentation: 0.5 days
  - ADR and README updates: 0.25 days

**Total Estimated Duration**: 15-21 days

**Note**: Phases can overlap in some cases:
- Phase 6 can start in parallel with Phase 5 after Phase 3 is complete
- Documentation in Phase 7 can be written incrementally throughout earlier phases

---

## Team Responsibilities

- **Platform Engineering**: Phases 1-2, 4-5, 6
- **Application Teams**: Phase 3 (initial setup), future application migrations
- **All Teams**: Phase 5 training and Phase 6 validation

---

## References

- [ADR-003: Layered ArgoCD Application Structure](/workspace/docs/reference/architecture-decision-records/ADR-003-layered-argocd-structure.md)
- [ArgoCD Sync Waves](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD Application Specification](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)

---

## Summary & Next Steps

### Key Advantages of This Approach

This incremental implementation plan offers significant advantages over a "big bang" migration:

1. **Lower Risk**: Each phase is independently testable and can be validated before proceeding
2. **Faster Feedback**: Working deployments after each phase enable quick course correction
3. **Rollback Capability**: Can revert individual phases without losing all progress
4. **Team Confidence**: Series of wins builds momentum and understanding
5. **Parallel Operation**: New structure runs alongside old during transition, minimizing disruption
6. **Learning Opportunity**: Discover edge cases and tooling issues incrementally

### Critical Success Factors

- **Start with Phase 0**: Get the current setup working before refactoring
- **Validate Each Phase**: Don't proceed until current phase is stable
- **Document As You Go**: Capture learnings and decisions during implementation
- **Test in Development**: Prove each layer works before expanding to other environments
- **Incremental Automation**: Start with manual sync policies, enable automation after validation

### Getting Started

**To begin implementation:**

1. **Review and approve** this plan with the team
2. **Set up tracking**: Consider using GitHub Issues or a project board for phase tracking
3. **Start Phase 0**: Create `argocd/apps/` directory and get Podinfo deploying
4. **Validate baseline**: Ensure bootstrap process works end-to-end
5. **Proceed to Phase 1**: Build new structure alongside working deployment

**Recommended decision points:**

- After Phase 0: Confirm baseline works, decide to proceed
- After Phase 2: Validate application layer pattern, get team buy-in
- After Phase 4: Assess platform components, decide on additional tools
- After Phase 5: Review multi-environment setup before completing foundation

### Questions or Concerns?

If any phase reveals unexpected complexity or issues:
- Pause and reassess before continuing
- Consider breaking the phase into smaller sub-phases
- Document the issue and proposed solution
- Get team input before proceeding

This plan is designed to be flexible - adjust as needed based on learnings from each phase.
