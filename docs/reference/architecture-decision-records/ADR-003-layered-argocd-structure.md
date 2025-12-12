# Architecture Decision Record: Layered ArgoCD Application Structure

## Status

**Superseded by simplified architecture**

This ADR is no longer being implemented. The homelab will use a simplified architecture without foundation/platform/application layers.

See [ADR-002: GitOps and ArgoCD Deployment Strategy](./ADR-002-gitops-argocd-deployment-strategy.md) for the current approach.

## Original Context

This document originally proposed a complex three-layer architecture (Foundation, Platform, Application) mirroring Terraform patterns. After review, this was determined to be over-engineered for a homelab environment.

## Current Decision (2025-12-12)

**We will NOT implement the layered architecture described below.**

Instead, we use a simplified approach:
- All Kubernetes manifests in `k8s-manifests/` with base and overlay structure
- ArgoCD only for production cluster
- Development uses k3d with direct kubectl apply
- No foundation/platform/application layer separation

## Rationale for Change

- **Over-complexity**: Three layers add unnecessary abstraction for homelab scale
- **Operational overhead**: Multiple sync waves, projects, and applications to manage
- **Limited benefit**: Homelab doesn't have separate teams needing distinct ownership boundaries
- **Simpler is better**: Flat structure in `k8s-manifests/` is easier to understand and maintain

---

# Original ADR Content (For Reference Only)

The content below represents the original proposal but is **not being implemented**.

<details>
<summary>Click to view original ADR-003 content</summary>

## Context

We are implementing GitOps practices using ArgoCD to manage Kubernetes resources across multiple environments (Development, Staging, Production). Our existing Terraform infrastructure follows a layered architecture pattern separating resources by:

- **Environment**: Development, Staging, Production
- **Layer**: Foundation, Platform, Application

This layering provides clear separation of concerns, dependency management, and ownership boundaries in our infrastructure-as-code. We need to apply similar architectural principles to our Kubernetes resource management to maintain consistency and leverage the same benefits within the cluster.

Currently, we use Kustomize for managing Kubernetes manifests with environment-specific overlays. However, we lack a clear structure for organizing resources by their architectural purpose and managing deployment dependencies between different types of infrastructure components.

### Key Requirements

- Maintain consistency with existing Terraform layering concepts
- Ensure proper deployment ordering (platform components before applications)
- Support different sync policies and automation levels per layer
- Enable clear ownership boundaries for different teams
- Provide blast radius control for changes
- Scale across multiple environments with minimal duplication

## Decision

We will structure our ArgoCD applications using a three-layer architecture that mirrors our Terraform organization:

### Layer Definitions

#### Foundation Layer (Sync Wave: 0)

- Purpose: Cluster-level foundational resources required before any workloads
- Components:
  - Namespaces
  - RBAC (ServiceAccounts, Roles, RoleBindings, ClusterRoles, ClusterRoleBindings)
  - Network policies
  - Resource quotas and limit ranges
  - StorageClasses
  - Priority classes

#### Platform Layer (Sync Wave: 10)

- Purpose: Shared infrastructure services that enable the cluster as a platform
- Components:
  - Observability: Prometheus, Grafana, Jaeger, OpenTelemetry Collector
  - Service Mesh: Istio control plane and data plane
  - Policy Enforcement: Kyverno, OPA Gatekeeper
  - Secrets Management: External Secrets Operator, Sealed Secrets
  - Certificate Management: cert-manager
  - Ingress Controllers: NGINX Ingress, ALB Controller
  - Cluster Management: Portainer, Dashboard

#### Application Layer (Sync Wave: 20)

- Purpose: End-user facing applications and their dependencies
- Components:
  - Web applications
  - APIs and microservices
  - Application-specific databases
  - Application-specific caches
  - Batch jobs and CronJobs

### Directory Structure

```text
argocd/
├── bootstrap.sh
├── root-app.yaml
├── README.md
├── projects/
│   ├── homelab.yaml
│   ├── foundation.yaml
│   ├── platform.yaml
│   └── applications.yaml
├── applications/
│   ├── README.md
│   ├── foundation/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespaces/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── namespaces.yaml
│   │   │   ├── rbac/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── service-accounts.yaml
│   │   │   └── network-policies/
│   │   │       ├── kustomization.yaml
│   │   │       └── default-deny.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       │   └── kustomization.yaml
│   │       ├── staging/
│   │       │   └── kustomization.yaml
│   │       └── production/
│   │           └── kustomization.yaml
│   ├── platform/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── prometheus/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── prometheus-stack.yaml
│   │   │   ├── istio/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   ├── istio-base.yaml
│   │   │   │   └── istiod.yaml
│   │   │   ├── cert-manager/
│   │   │   │   ├── kustomization.yaml
│   │   │   │   └── cert-manager.yaml
│   │   │   └── external-secrets/
│   │   │       ├── kustomization.yaml
│   │   │       └── external-secrets-operator.yaml
│   │   └── overlays/
│   │       ├── development/
│   │       │   └── kustomization.yaml
│   │       ├── staging/
│   │       │   └── kustomization.yaml
│   │       └── production/
│   │           └── kustomization.yaml
│   └── applications/
│       ├── base/
│       │   ├── kustomization.yaml
│       │   ├── web-app/
│       │   │   ├── kustomization.yaml
│       │   │   ├── deployment.yaml
│       │   │   └── service.yaml
│       │   └── api-service/
│       │       ├── kustomization.yaml
│       │       ├── deployment.yaml
│       │       └── service.yaml
│       └── overlays/
│           ├── development/
│           │   └── kustomization.yaml
│           ├── staging/
│           │   └── kustomization.yaml
│           └── production/
│               └── kustomization.yaml
└── apps/
    ├── development/
    │   ├── foundation.yaml
    │   ├── platform.yaml
    │   └── applications.yaml
    ├── staging/
    │   ├── foundation.yaml
    │   ├── platform.yaml
    │   └── applications.yaml
    └── production/
        ├── foundation.yaml
        ├── platform.yaml
        └── applications.yaml
```

### ArgoCD Application Pattern

Each layer will be represented as an ArgoCD Application with appropriate sync wave annotations:

#### Foundation Application (Wave 0)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: foundation-development
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: foundation
  source:
    repoURL: https://github.com/your-org/gitops-repo
    targetRevision: main
    path: argocd/applications/foundation/overlays/development
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### Platform Application (Wave 10)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: platform-development
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: platform
  source:
    repoURL: https://github.com/your-org/gitops-repo
    targetRevision: main
    path: argocd/applications/platform/overlays/development
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

#### Application Layer (Wave 20)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: applications-development
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "20"
spec:
  project: applications
  source:
    repoURL: https://github.com/your-org/gitops-repo
    targetRevision: main
    path: argocd/applications/applications/overlays/development
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

### ArgoCD Projects for Governance

Each layer will have a corresponding ArgoCD Project for access control and resource restrictions:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: platform
  namespace: argocd
spec:
  description: Platform infrastructure components
  sourceRepos:
    - 'https://github.com/your-org/gitops-repo'
  destinations:
    - namespace: 'kube-system'
      server: https://kubernetes.default.svc
    - namespace: 'istio-system'
      server: https://kubernetes.default.svc
    - namespace: 'monitoring'
      server: https://kubernetes.default.svc
    - namespace: 'cert-manager'
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: '*'
      kind: '*'
  roles:
    - name: platform-admin
      description: Platform team full access
      policies:
        - p, proj:platform:platform-admin, applications, *, platform/*, allow
      groups:
        - platform-engineering-team
```

## Consequences

### Positive

- **Consistent Architecture**: Maintains alignment with existing Terraform layering, reducing cognitive load for engineers
- **Explicit Dependencies**: Sync waves ensure platform components are ready before applications deploy
- **Clear Ownership**: Each layer can be owned by different teams (Platform Engineering owns foundation/platform, product teams own applications)
- **Blast Radius Control**: Issues in application layer don't cascade to platform infrastructure
- **Flexible Automation**: Different layers can have different sync policies (auto-sync for platform, manual for production applications)
- **Scalability**: Structure scales across multiple clusters and environments without modification
- **Progressive Rollout**: Can stage rollouts layer-by-layer for safer deployments
- **Easier Troubleshooting**: Layer separation makes it easier to identify which architectural component has issues

### Negative

- **Additional Complexity**: More ArgoCD Applications to manage compared to a flat structure
- **Learning Curve**: Team members need to understand layering concepts and where components belong
- **Initial Setup Overhead**: More upfront work to structure repositories and create layer-specific applications
- **Potential Sync Delays**: Sequential sync waves may slow down initial cluster bootstrapping
- **Maintenance Overhead**: Changes to layer definitions require updates across multiple environment applications

### Neutral

- **Migration Required**: Existing ArgoCD applications will need to be reorganized into the new structure
- **Documentation Needed**: Clear guidelines required for determining which layer new components belong to
- **Tooling Considerations**: May need additional tooling/scripts for managing multiple ArgoCD applications per environment

## Implementation Notes

### Phase 1: Foundation

1. Create directory structure in GitOps repository
2. Define ArgoCD Projects for each layer
3. Migrate existing foundation resources (namespaces, RBAC) to new structure
4. Deploy foundation layer ArgoCD Applications for development environment
5. Validate deployment and sync behavior

### Phase 2: Platform

1. Migrate platform components (Prometheus, Istio, cert-manager, etc.) to platform layer
2. Deploy platform layer ArgoCD Applications for development environment
3. Validate dependencies and sync wave ordering
4. Document platform component onboarding process

### Phase 3: Applications

1. Migrate application workloads to application layer
2. Deploy application layer ArgoCD Applications for development environment
3. Validate end-to-end deployment flow
4. Test failure scenarios and rollback procedures

### Phase 4: Expansion

1. Roll out structure to staging environment
2. Roll out structure to production environment
3. Document operational procedures and troubleshooting guides
4. Train teams on new structure and ownership model

### Decision Criteria for Layer Assignment

**Foundation Layer** - Resource required before any workloads can run:

- Creates fundamental cluster structures (namespaces, storage)
- Establishes security baseline (RBAC, network policies)
- Has no dependencies on other cluster resources

**Platform Layer** - Shared service used by multiple applications:

- Provides observability, security, or networking capabilities
- Managed by Platform Engineering team
- Enables but doesn't directly serve end users
- May depend on foundation resources

**Application Layer** - Delivers direct business value to end users:

- Serves customer-facing traffic
- Owned by product/feature teams
- May depend on platform services
- Business logic specific to particular features

## References

- [ArgoCD Sync Waves Documentation](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-waves/)
- [Kustomize Documentation](https://kustomize.io/)
- [ArgoCD App of Apps Pattern](https://argo-cd.readthedocs.io/en/stable/operator-manual/cluster-bootstrapping/)
- Internal: Terraform Layering Architecture (existing ADR)

## Related Decisions

- ADR: Terraform Layer Separation Strategy
- ADR: GitOps Tool Selection (ArgoCD vs Flux)
- ADR: Kubernetes Manifest Management (Helm vs Kustomize)

</details>

---

**Superseded**: 2025-12-12  
**Superseded By**: [ADR-002: GitOps and ArgoCD Deployment Strategy](./ADR-002-gitops-argocd-deployment-strategy.md)
