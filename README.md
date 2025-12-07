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

## Quick Start

### 1. Setup 1Password

Set your 1Password Service Account token:

```fish
set -Ux OP_SERVICE_ACCOUNT_TOKEN your_token_here
```

Create a vault named `homelab` in 1Password for storing cluster secrets.

### 2. Install and Use Nushell CLI

Enter Nushell and source the CLI:

```fish
nu
source cli.nu
```

The `homelab` command will now be available with the following subcommands.

## CLI Commands

### Create a New Cluster

```nushell
homelab cluster create
```

Interactive wizard that:
- Prompts for cluster name
- Lets you choose cluster type (k3d-local or talos-baremetal)
- Guides you through the setup process

### Create Talos Bare Metal Cluster

```nushell
homelab cluster create-talos-baremetal [cluster-name]
```

Automated setup for Talos bare metal clusters:
- Generates Talos configuration
- Detects available disks on target machine
- Stores all secrets in 1Password
- Bootstraps the first control plane node
- Generates kubeconfig

**Prerequisites:**
- Target machine in Talos maintenance mode
- Reserved IP address in your router
- Network connectivity to the target machine
- 1Password vault configured

### Add Nodes to Talos Cluster

```nushell
homelab cluster talos-add-node [cluster-name]
```

Add control plane or worker nodes to an existing Talos cluster.

### Configure talosctl

```nushell
homelab config talosctl [cluster-name]
```

Generate temporary configuration files from 1Password secrets for using `talosctl` commands.

## Workspace Structure

```
.
├── cli.nu                      # Main Nushell CLI
├── cli-config.yaml            # CLI configuration
├── dev.nu                     # Development utilities
├── base-talos/               # Base Talos configurations
│   └── tailscale.patch.yaml  # Tailscale extension patch
├── base-k3d/                 # Base k3d configurations
│   └── config.yaml
├── k8s-homelab-production/   # Example cluster directory
│   ├── controlplane.yaml     # Control plane config (with 1Password refs)
│   ├── worker.yaml          # Worker config (with 1Password refs)
│   └── talosconfig          # Talos CLI config (with 1Password refs)
└── *.sh                     # Legacy shell scripts
```

## Configuration

Edit `cli-config.yaml` to customize:

- **Cluster types**: Available cluster types for creation
- **Talos defaults**: Schema ID and version for Talos installations
- **System extensions**: Talos extensions like Tailscale

Current defaults:
- Talos version: 1.10.5
- Extensions: Tailscale

## Security

All sensitive cluster information is stored in 1Password:
- Talos certificates and keys
- Cluster tokens and secrets
- Machine certificates
- etcd certificates
- Kubernetes service account keys

Configuration files use 1Password references (e.g., `op://homelab/cluster.talos.ca/notes`) and are injected at runtime using `op inject`.

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

## References

- [Talos Linux Documentation](https://www.talos.dev/docs/)
- [Talos Factory](https://factory.talos.dev/) - Custom Talos images
- [k3d Documentation](https://k3d.io/)
- [Nushell Documentation](https://www.nushell.sh/)