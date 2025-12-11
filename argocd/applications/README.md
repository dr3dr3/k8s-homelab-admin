# ArgoCD Layered Architecture

This directory contains the **three-layer** Kubernetes manifest structure that mirrors our Terraform layering pattern.

## Directory Structure

```
argocd/
├── apps/                           # ArgoCD Application manifests (app-of-apps pattern)
│   ├── development/
│   │   ├── foundation.yaml        # Sync wave 0
│   │   ├── platform.yaml          # Sync wave 10
│   │   └── applications.yaml      # Sync wave 20
│   ├── staging/
│   │   ├── foundation.yaml
│   │   ├── platform.yaml
│   │   └── applications.yaml
│   └── production/
│       ├── foundation.yaml
│       ├── platform.yaml
│       └── applications.yaml
│
├── applications/                   # Kubernetes manifests organized by layer
│   ├── foundation/
│   │   ├── base/
│   │   │   ├── namespaces/        # Platform namespaces
│   │   │   ├── rbac/              # Service accounts, roles
│   │   │   └── network-policies/  # Network security policies
│   │   └── overlays/
│   │       ├── development/
│   │       ├── staging/
│   │       └── production/
│   │
│   ├── platform/
│   │   ├── base/
│   │   │   ├── prometheus/        # Monitoring stack
│   │   │   ├── cert-manager/      # Certificate management
│   │   │   └── opentelemetry/     # Observability
│   │   └── overlays/
│   │       ├── development/
│   │       ├── staging/
│   │       └── production/
│   │
│   └── applications/
│       ├── base/
│       │   └── podinfo/           # Example application
│       └── overlays/
│           ├── development/
│           ├── staging/
│           └── production/
│
├── projects/                       # ArgoCD Project definitions (governance)
│   ├── foundation.yaml
│   ├── platform.yaml
│   └── applications.yaml
│
├── root-app.yaml                   # Root Application (manages apps/)
└── bootstrap.sh                    # ArgoCD installation script
```

## Layer Definitions

### Foundation Layer (Sync Wave: 0)
**Purpose**: Cluster-level foundational resources required before any workloads

**Components**:
- Namespaces
- RBAC (ServiceAccounts, Roles, RoleBindings)
- Network policies
- Resource quotas

**Governed by**: `argocd/projects/foundation.yaml`

### Platform Layer (Sync Wave: 10)
**Purpose**: Shared infrastructure services that enable the cluster as a platform

**Components**:
- Observability: Prometheus, Grafana, OpenTelemetry
- Certificate Management: cert-manager
- Additional platform services as needed

**Governed by**: `argocd/projects/platform.yaml`

### Application Layer (Sync Wave: 20)
**Purpose**: End-user facing applications

**Components**:
- Web applications (e.g., podinfo)
- APIs and microservices
- Application-specific resources

**Governed by**: `argocd/projects/applications.yaml`

## How It Works

1. **Root App** (`root-app.yaml`) points to `argocd/apps/` directory
2. **Application manifests** in `argocd/apps/{environment}/` define three Applications:
   - `foundation-{env}` → points to `argocd/applications/foundation/overlays/{env}`
   - `platform-{env}` → points to `argocd/applications/platform/overlays/{env}`
   - `applications-{env}` → points to `argocd/applications/applications/overlays/{env}`
3. **Sync waves** ensure proper ordering:
   - Wave 0: Foundation deploys first
   - Wave 10: Platform deploys after foundation
   - Wave 20: Applications deploy last

## Environment Structure

Each layer uses **Kustomize overlays** for environment-specific configuration:

- **Base**: Common configuration shared across all environments
- **Overlays**: Environment-specific patches and configurations
  - `development/`: Lower resources, permissive policies
  - `staging/`: Production-like settings for testing
  - `production/`: High availability, strict policies

## Adding Resources

### Add a new application:
1. Create manifests in `argocd/applications/applications/base/{app-name}/`
2. Create kustomization.yaml referencing the manifests
3. Update `argocd/applications/applications/base/kustomization.yaml` to include new app
4. Add environment-specific patches in overlays if needed

### Add a platform component:
1. Create manifests in `argocd/applications/platform/base/{component}/`
2. Follow same kustomize pattern as applications
3. Ensure it deploys to appropriate namespace (defined in foundation layer)

### Add foundation resources:
1. Add to appropriate subdirectory in `argocd/applications/foundation/base/`
2. Update foundation base kustomization.yaml
3. Test carefully as these affect cluster-wide policies

## Validation

Test kustomize builds before committing:

```bash
# Test foundation layer
kustomize build argocd/applications/foundation/overlays/development

# Test platform layer
kustomize build argocd/applications/platform/overlays/development

# Test application layer
kustomize build argocd/applications/applications/overlays/development
```

## References

- [ADR-003: Layered ArgoCD Application Structure](../docs/reference/architecture-decision-records/ADR-003-layered-argocd-structure.md)
- [Implementation Plan](../IMPLEMENTATION_PLAN.md)
- [Implementation Status](../IMPLEMENTATION_STATUS.md)
