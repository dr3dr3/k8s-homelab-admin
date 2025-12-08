# Archived Bash Scripts

**Status:** DEPRECATED  
**Date Archived:** December 8, 2025

## Overview

This directory contains the original bash scripts used for Talos Kubernetes cluster provisioning. These scripts have been **deprecated** in favor of the new Nushell CLI (`cli.nu`).

## Why Deprecated?

The bash scripts have been replaced with a unified Nushell CLI for the following reasons:

1. **Better Error Handling** - Nushell provides structured error handling and validation
2. **Structured Data Processing** - Native support for YAML, JSON, and other formats
3. **Single Source of Truth** - One implementation instead of maintaining parallel codebases
4. **Improved Maintainability** - Better code organization and modularity
5. **Enhanced User Experience** - Interactive workflows with better feedback

## Migration

Instead of using these bash scripts, please use the Nushell CLI:

```bash
# Old way (deprecated)
./0.start.sh
./1.setup.sh
# ... etc

# New way (recommended)
nu cli.nu
# Then use interactive commands like:
# homelab cluster create-talos-baremetal my-cluster
```

See the main [README.md](../README.md) for complete documentation on using the Nushell CLI.

## Script Inventory

The following scripts are archived here:

- `0.start.sh` - Environment setup and variable initialization
- `1.setup.sh` - Cluster directory creation and initial setup
- `2.talosconfig.sh` - Talos configuration secrets management
- `3.controlplane.sh` - Control plane configuration and secrets
- `4.worker.sh` - Worker node configuration and secrets
- `5.disk.sh` - Disk selection and installation configuration
- `6.tempfiles.sh` - Temporary file generation for 1Password injection
- `7.bootstrap-cp-first.sh` - Control plane bootstrap process
- `7.bootstrap-worker.sh` - Worker node bootstrap process
- `8.kubeconfig.sh` - Kubernetes configuration management
- `9.tailscale.sh` - Tailscale VPN integration

## Future Plans

These scripts will be permanently removed in a future release once the Nushell CLI has been fully validated and adopted.

## Questions?

If you have questions about the migration or need help with the new CLI, please refer to:
- [README.md](../README.md) - Main documentation
- [TALOS.md](../TALOS.md) - Talos-specific documentation
- [docs/](../docs/) - Additional guides and references
