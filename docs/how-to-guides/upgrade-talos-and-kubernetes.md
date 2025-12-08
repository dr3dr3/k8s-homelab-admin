# How to Upgrade Talos and Kubernetes

## Problem Statement

You need to upgrade your Talos Linux homelab cluster to newer versions of Talos OS and/or Kubernetes while maintaining cluster availability and data integrity.

## Prerequisites

- Access to your homelab cluster with `talosctl` configured
- 1Password CLI with service account token set
- Network connectivity to all cluster nodes
- Current cluster running and healthy
- Backup of critical workloads (recommended)

## Overview

Talos upgrades can include both the Talos OS version and the Kubernetes version. Upgrades should be performed:

1. Control plane nodes first (one at a time)
2. Worker nodes second (can be done in parallel, but recommended one at a time for stability)

## Pre-Upgrade Checks

### 1. Verify Current Versions

Check your current Talos version:

```bash
talosctl version --nodes <node-ip>
```

Check your current Kubernetes version:

```bash
kubectl get nodes
```

### 2. Review Compatibility

- Check the [Talos compatibility matrix](https://www.talos.dev/latest/introduction/support-matrix/) for supported Kubernetes versions
- Review release notes for breaking changes
- Ensure your schematic ID includes required extensions

### 3. Update Your Configuration Files

Update `cli-config.yaml` with the new versions:

```yaml
talos:
  defaults:
    schemeid: "376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba"
    version: "1.10.6"  # Update to new version
  with-extensions:
    schemeid: "4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b"
```

### 4. Generate New Schematic (if using extensions)

If you need to update extensions or change the Talos configuration, regenerate your schematic:

```bash
curl -X POST --data-binary @base-talos/extensions.yaml https://factory.talos.dev/schematics
```

Save the returned schematic ID to your configuration.

## Upgrade Process

### Step 1: Prepare Temporary Configuration Files

Generate temporary config files from 1Password:

```bash
nu
source cli.nu
homelab config talosctl k8s-homelab-production
```

Or manually:

```bash
set CLUSTER k8s-homelab-production
op inject -i ./$CLUSTER/talosconfig -o ./$CLUSTER/temp.talosconfig --cache=false
```

### Step 2: Set Environment Variables

```bash
set CLUSTER k8s-homelab-production
set TALOS_VERSION 1.10.6  # Your target version
set SCHEMATIC_ID 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba
set TALOSCONFIG ./$CLUSTER/temp.talosconfig
```

### Step 3: Upgrade Control Plane Nodes

Upgrade each control plane node one at a time:

```bash
set CP_NODE_IP 192.168.8.110  # Update for each control plane node

talosctl upgrade \
  --nodes $CP_NODE_IP \
  --endpoints $CP_NODE_IP \
  --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION \
  --preserve \
  --talosconfig $TALOSCONFIG
```

**Important flags:**
- `--preserve`: Keeps the current machine configuration
- `--image`: Specifies the new Talos version with your schematic
- Without `--preserve`, use `--stage` to stage the upgrade for next reboot

### Step 4: Wait for Node to Complete Upgrade

Monitor the upgrade progress:

```bash
talosctl health --nodes $CP_NODE_IP --endpoints $CP_NODE_IP --talosconfig $TALOSCONFIG
```

Check node status in Kubernetes:

```bash
kubectl get nodes
kubectl get pods -A
```

Wait until:
- The node is back online and Ready
- All system pods are running
- Cluster shows healthy status

**Typical upgrade time**: 5-10 minutes per node

### Step 5: Upgrade Additional Control Plane Nodes

Repeat Step 3 and Step 4 for each additional control plane node, waiting for each to complete before proceeding to the next.

### Step 6: Upgrade Worker Nodes

After all control plane nodes are upgraded, upgrade worker nodes:

```bash
set WORKER_NODE_IP 192.168.8.111  # Update for each worker node

talosctl upgrade \
  --nodes $WORKER_NODE_IP \
  --endpoints $WORKER_NODE_IP \
  --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION \
  --preserve \
  --talosconfig $TALOSCONFIG
```

Repeat for each worker node, waiting for each to return to Ready state.

## Upgrading Kubernetes Version Only

If you only need to upgrade Kubernetes (without changing Talos OS):

### Step 1: Update Machine Configuration

Edit your control plane and worker YAML files to update the kubelet image version:

```yaml
machine:
  kubelet:
    image: ghcr.io/siderolabs/kubelet:v1.33.3  # Update to new version
```

### Step 2: Apply Updated Configuration

For each node:

```bash
set NODE_IP 192.168.8.110

talosctl apply-config \
  --nodes $NODE_IP \
  --endpoints $NODE_IP \
  --file ./$CLUSTER/temp.controlplane.yaml \
  --talosconfig $TALOSCONFIG
```

The kubelet will restart with the new Kubernetes version.

## Post-Upgrade Verification

### 1. Check Cluster Health

```bash
# Verify all nodes are ready
kubectl get nodes

# Check system pods
kubectl get pods -A

# Verify Talos health
talosctl health --talosconfig $TALOSCONFIG
```

### 2. Verify Versions

```bash
# Check Talos version on all nodes
talosctl version --nodes <node-ip>

# Check Kubernetes version
kubectl version
```

### 3. Test Workloads

- Verify your applications are running correctly
- Check logs for any errors
- Test critical functionality

## Troubleshooting

### Node Won't Come Back Online

1. Check node status from another control plane:
   ```bash
   talosctl get members --talosconfig $TALOSCONFIG
   ```

2. Review logs:
   ```bash
   talosctl logs --nodes $NODE_IP --talosconfig $TALOSCONFIG
   ```

3. If node is stuck, try manual reboot:
   ```bash
   talosctl reboot --nodes $NODE_IP --talosconfig $TALOSCONFIG
   ```

### Etcd Issues After Upgrade

If etcd shows errors:

```bash
# Check etcd member list
talosctl etcd members --nodes $CP_NODE_IP --talosconfig $TALOSCONFIG

# Check etcd status
talosctl etcd status --nodes $CP_NODE_IP --talosconfig $TALOSCONFIG
```

### Rollback (if necessary)

If you used `--stage` flag, you can cancel the upgrade before reboot:

```bash
talosctl upgrade --revert --nodes $NODE_IP --talosconfig $TALOSCONFIG
```

For immediate upgrades (`--preserve`), rollback requires re-imaging with the previous version.

## Advanced Scenarios

### Upgrading with Extensions (e.g., Tailscale)

When using extensions, ensure your schematic includes all required extensions:

```bash
set SCHEMATIC_ID 4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b

talosctl upgrade \
  --nodes $NODE_IP \
  --endpoints $NODE_IP \
  --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION \
  --preserve \
  --talosconfig $TALOSCONFIG
```

If you need to apply patches during upgrade:

```bash
# Generate temp patch file from 1Password
op inject -i ./base-talos/tailscale.patch.yaml -o ./temp.tailscale.patch.yaml --cache=false

# Apply with patch
talosctl apply-config \
  --nodes $NODE_IP \
  --file ./$CLUSTER/temp.controlplane.yaml \
  --config-patch @./temp.tailscale.patch.yaml \
  --talosconfig $TALOSCONFIG
```

### Forced Upgrade

For unresponsive nodes or when you need to force the upgrade:

```bash
talosctl upgrade \
  --nodes $NODE_IP \
  --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION \
  --force \
  --talosconfig $TALOSCONFIG
```

**Warning**: Use `--force` only when necessary as it may cause data loss.

### Power Cycle During Upgrade

To force a reboot during upgrade:

```bash
talosctl upgrade \
  --nodes $NODE_IP \
  --image factory.talos.dev/installer/$SCHEMATIC_ID:v$TALOS_VERSION \
  --mode powercycle \
  --force \
  --talosconfig $TALOSCONFIG
```

## Best Practices

1. **Always upgrade control plane nodes first**, one at a time
2. **Wait for cluster health** between each node upgrade
3. **Take etcd snapshots** before major upgrades
4. **Review release notes** for breaking changes
5. **Test in a dev environment** if possible before production
6. **Schedule maintenance windows** for production upgrades
7. **Keep configuration files in sync** with 1Password
8. **Document your specific setup** (schematic IDs, versions, extensions)
9. **Avoid upgrading more than one minor version** at a time
10. **Monitor cluster during and after** the upgrade process

## References

- [Talos Upgrade Documentation](https://www.talos.dev/latest/talos-guides/upgrading-talos/)
- [Talos Factory Image Builder](https://factory.talos.dev/)
- [Kubernetes Version Skew Policy](https://kubernetes.io/releases/version-skew-policy/)
- [Talos Support Matrix](https://www.talos.dev/latest/introduction/support-matrix/)
