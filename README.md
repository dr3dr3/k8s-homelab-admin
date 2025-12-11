# Kubernetes Homelab Admin

A development container for managing Kubernetes homelab clusters using Talos Linux and k3d, with a custom Nushell CLI for streamlined operations.

## Features

- **Talos Linux Support**: Create and manage bare metal Kubernetes clusters with Talos
- **k3d Support**: Run local development clusters
- **Nushell CLI**: Custom commands for cluster lifecycle management
- **1Password Integration**: Secure storage of cluster credentials and certificates
- **Multi-cluster Management**: Organize and manage multiple clusters from one workspace

## Prerequisites

- Docker (for devcontainer)
- 1Password CLI and Service Account token
- For Talos bare metal: Physical machines or VMs with network access

## Development Environment

This project uses a VS Code devcontainer with all necessary tools pre-installed:

**Installed Tools:**

- **Kubernetes & Container Tools**: kubectl, talosctl, k3d, helm, krew plugins (ctx, ns, kor, neat, score)
- **CLI Utilities**: gum (interactive prompts), yq (YAML processing), jq
- **Shells**: Fish (default), Nushell (for CLI)
- **Secrets Management**: 1Password CLI
- **AI Assistants**: Claude Code CLI
- **Git Tools**: GitHub CLI (gh)

**VS Code Extensions:**

- Anthropic Claude Code
- Kubernetes tools (ms-kubernetes-tools.vscode-kubernetes-tools)
- Docker, YAML, Markdown support
- Nushell syntax highlighting
- 1Password integration

To start:

1. Open the project in VS Code
2. When prompted, click "Reopen in Container"
3. Once loaded, enter Nushell: `nu`
4. Source the CLI: `source cli.nu`

## Quick Start

### 1. Setup Environment Variables

Create a `.env` file in the workspace root with your 1Password Service Account token:

```bash
# Copy the example file
cp .env.example .env

# Edit .env and add your token
# Get your token from: https://my.1password.com/developer-tools/infrastructure-secrets/serviceaccount
```

Your `.env` file should contain:

```bash
OP_SERVICE_ACCOUNT_TOKEN=your_service_account_token_here
```

**Important:** The `.env` file is automatically ignored by git to protect your secrets.

Alternatively, you can set the environment variable in your shell:

```fish
# For Fish shell
set -Ux OP_SERVICE_ACCOUNT_TOKEN your_token_here
```

```bash
# For Bash/Zsh
export OP_SERVICE_ACCOUNT_TOKEN=your_token_here
```

### 2. Setup 1Password Vault

Create a vault named `homelab` in 1Password for storing cluster secrets.

### 3. Install and Use Nushell CLI

Enter Nushell and source the CLI:

```fish
nu
source cli.nu
```

The `homelab` command will now be available with the following subcommands.

## CLI Commands

The `homelab` command provides several subcommands for cluster lifecycle management.

### Create a New Cluster

```nushell
homelab cluster create
```

Interactive wizard that:

- Prompts for cluster name
- Lets you choose cluster type (k3d-local or talos-baremetal)
- Guides you through the setup process
- Currently only talos-baremetal is fully implemented

### Create Talos Bare Metal Cluster

```nushell
homelab cluster create-talos-baremetal [cluster-name]
```

Automated setup for Talos bare metal clusters:

- Generates Talos configuration with optional system extensions (Tailscale)
- Interactive disk selection on target machine (filters out USB drives and read-only disks)
- Stores all secrets in 1Password vault
- Bootstraps the first control plane node
- Generates and configures kubeconfig
- Uses `gum` for interactive prompts and `op inject` for secure secret handling

**Prerequisites:**

- Target machine in Talos maintenance mode
- Reserved IP address in your router
- Network connectivity to the target machine
- 1Password vault named `homelab` configured
- Environment variable `OP_SERVICE_ACCOUNT_TOKEN` set

### Add Nodes to Talos Cluster

```nushell
homelab cluster talos-add-node [cluster-name]
```

Add control plane or worker nodes to an existing Talos cluster:

- Prompts for node type (control-plane or worker)
- Interactive disk selection with safety filters
- Applies configuration from 1Password-stored secrets
- Automatic configuration injection using `op inject`

### Configure talosctl

```nushell
homelab config talosctl [cluster-name]
```

Generate temporary configuration files from 1Password secrets for using `talosctl` commands:

- Creates temporary `talosconfig` file (prefixed with `temp.`)
- Injects secrets from 1Password
- Sets up talosctl context for the specified cluster
- Temporary files should not be committed to version control

## Workspace Structure

```bash
.
├── cli.nu                      # Main Nushell CLI
├── cli-config.yaml            # CLI configuration
├── .devcontainer/             # Development container setup
│   ├── Dockerfile            # Container with all tools (Talos, K8s, AI)
│   └── devcontainer.json     # VS Code configuration
├── base-talos/               # Base Talos configurations
│   └── tailscale.patch.yaml  # Tailscale extension patch
├── base-k3d/                 # Base k3d configurations
│   └── config.yaml
├── k8s-homelab-production/   # Example cluster directory
│   ├── controlplane.yaml     # Control plane config (with 1Password refs)
│   ├── worker.yaml          # Worker config (with 1Password refs)
│   └── talosconfig          # Talos CLI config (with 1Password refs)
├── archive/                  # Deprecated bash scripts
│   └── README.md            # Migration guide
└── docs/                     # Documentation (Diataxis structure)
    ├── explanations/
    ├── how-to-guides/
    └── reference/
```

## Configuration

Edit `cli-config.yaml` to customize:

- **Cluster types**: Available cluster types for creation
- **Talos defaults**: Schema ID and version for Talos installations
- **System extensions**: Talos extensions like Tailscale

Current defaults:

- Talos version: 1.11.5
- Extensions: Tailscale

## Security

All sensitive cluster information is stored in 1Password:

- Talos certificates and keys
- Cluster tokens and secrets
- Machine certificates
- etcd certificates
- Kubernetes service account keys

Configuration files use 1Password references (e.g., `op://homelab/cluster.talos.ca/notes`) and are injected at runtime using `op inject`.

## Legacy Scripts

Previous bash-based automation scripts have been moved to the `/archive/` directory. These scripts are deprecated in favor of the Nushell CLI:

- Original scripts: `0.start.sh` through `9.tailscale.sh`
- See [archive/README.md](archive/README.md) for:
  - List of archived scripts and their purposes
  - Migration path to Nushell CLI equivalents
  - When legacy scripts might still be useful

All new development focuses on the `cli.nu` Nushell implementation.

## Manual Operations

For advanced Talos operations, see [TALOS.md](TALOS.md) for detailed instructions on:

- Disk selection
- Tailscale setup
- Talos upgrades
- Troubleshooting and logs

## Workflow

1. **Create cluster**: `homelab cluster create` or use specific commands
2. **Configure access**: CLI automatically sets up talosctl and kubectl
3. **Add nodes**: Use `homelab cluster talos-add-node` to expand
4. **Manage**: Use standard `kubectl` and `talosctl` commands
5. **Switch clusters**: Change directory to different cluster folder

## Tips

- Always run commands from the workspace root directory
- Cluster configurations are stored in dedicated directories (e.g., `k8s-homelab-production/`)
- Temporary files (prefixed with `temp.`) are generated from 1Password and should not be committed
- Use `kubectl config get-contexts` to see available Kubernetes contexts
- Use `talosctl config contexts` to see available Talos contexts

## Useful Commands

```nushell
# Inside Nushell with cli.nu sourced
homelab cluster create                    # Create new cluster
homelab cluster create-talos-baremetal    # Create Talos cluster
homelab cluster talos-add-node           # Add node to cluster
homelab config talosctl                  # Setup talosctl access
```

### Testing Talos Control Plane

```bash
# Check overall cluster health
talosctl health --nodes 192.168.10.174

# Get cluster members
talosctl get members --nodes 192.168.10.174

# Check services status
talosctl services --nodes 192.168.10.174

# Get node name
talosctl get nodename --nodes 192.168.10.174

# Interactive dashboard
talosctl dashboard --nodes 192.168.10.174
```

## Documentation

This project follows the [Diataxis documentation framework](https://diataxis.fr/) with structured docs in `/docs/`:

**How-To Guides:**

- [Layered ArgoCD Quick Start](docs/how-to-guides/layered-argocd-quick-start.md) - Get started implementing the three-layer ArgoCD architecture
- [Upgrade Talos and Kubernetes](docs/how-to-guides/upgrade-talos-and-kubernetes.md)
- [Expose ArgoCD via Tailscale Ingress](docs/how-to-guides/expose-argocd-via-tailscale-ingress.md)

**Reference:**

- [Implementation Plan](IMPLEMENTATION_PLAN.md) - Detailed phased implementation plan for layered ArgoCD architecture
- [Implementation Status](IMPLEMENTATION_STATUS.md) - Current status tracker for implementation phases
- [Nushell CLI Review & Recommendations](docs/reference/nushell-cli-review-recommendations.md) - 21 improvement recommendations
- [ADR-001: Networking Design](docs/reference/architecture-decision-records/ADR-001-networking-design.md)
- [ADR-002: GitOps ArgoCD Deployment Strategy](docs/reference/architecture-decision-records/ADR-002-gitops-argocd-deployment-strategy.md)
- [ADR-003: Layered ArgoCD Structure](docs/reference/architecture-decision-records/ADR-003-layered-argocd-structure.md)

**Explanations:**

- [Diataxis for Documentation](docs/explanations/diataxis-for-documentation.md)

**Legacy Documentation:**

- [TALOS.md](TALOS.md) - Scratch pad for Talos operations
- [archive/README.md](archive/README.md) - Information about deprecated bash scripts

## Known Limitations

- **k3d-local cluster type**: Configuration exists but creation is not yet implemented (placeholder only)
- **Cluster management commands**: `homelab cluster up`, `stop`, and `delete` are placeholders awaiting implementation

## References

- [Talos Linux Documentation](https://www.talos.dev/docs/)
- [Talos Factory](https://factory.talos.dev/) - Custom Talos images
- [k3d Documentation](https://k3d.io/)
- [Nushell Documentation](https://www.nushell.sh/)
