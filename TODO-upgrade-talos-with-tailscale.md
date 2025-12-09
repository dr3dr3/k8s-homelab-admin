# TODO: Upgrade Talos with Tailscale Extension

## Overview
Upgrade the k8s-homelab-production cluster to the latest Talos version with Tailscale extension, then configure Tailscale on all nodes.

## Current State
- **Cluster**: k8s-homelab-production
- **Current Talos Version**: v1.8.x (based on node age ~121-126 days)
- **Current Kubernetes Version**: v1.33.2
- **Nodes**:
  - Control Plane: talos-qj5-8o7 (192.168.10.174)
  - Worker 1: talos-0y4-zne (192.168.10.206)
  - Worker 2: talos-36q-vco (192.168.10.200)

## Prerequisites
- [ ] 1Password service account token set (`OP_SERVICE_ACCOUNT_TOKEN` environment variable)
- [ ] Network connectivity to all cluster nodes (192.168.10.174, 192.168.10.206, 192.168.10.200)
- [ ] `talosctl` installed and working
- [ ] `kubectl` installed and working
- [ ] Tailscale auth key stored in 1Password at `op://kubernetes/tailscale.patch.authkey/notes`
- [ ] Backup of critical workloads (recommended)

## Configuration Updates Needed

### 1. Update cli-config.yaml
- [ ] Decide on target Talos version (currently set to 1.10.5)
- [ ] Verify the `with-extensions.schemeid` includes Tailscale extension
  - Current: `4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b`
  - Includes: `siderolabs/tailscale`
- [ ] Update version if needed in `cli-config.yaml`

## Upgrade Process

### Phase 1: Pre-Upgrade Checks
- [ ] Check current versions on all nodes:
  ```fish
  talosctl version --nodes 192.168.10.174
  talosctl version --nodes 192.168.10.206
  talosctl version --nodes 192.168.10.200
  ```
- [ ] Verify cluster health:
  ```fish
  talosctl health --nodes 192.168.10.174
  kubectl get nodes
  kubectl get pods -A
  ```
- [ ] Review [Talos compatibility matrix](https://www.talos.dev/latest/introduction/support-matrix/)
- [ ] Review Talos release notes for breaking changes

### Phase 2: Prepare Configuration Files
- [ ] Start Nushell and load CLI:
  ```fish
  nu
  source cli.nu
  homelab config talosctl k8s-homelab-production
  ```
- [ ] Verify temp files created:
  - `k8s-homelab-production/temp.talosconfig`
  - `k8s-homelab-production/temp.controlplane.yaml`
  - `k8s-homelab-production/temp.worker.yaml`

### Phase 3: Upgrade Control Plane Node
- [ ] Upgrade control plane node (192.168.10.174):
  ```fish
  talosctl upgrade \
    --nodes 192.168.10.174 \
    --endpoints 192.168.10.174 \
    --image factory.talos.dev/installer/4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b:v1.10.5 \
    --preserve \
    --talosconfig ./k8s-homelab-production/temp.talosconfig
  ```
- [ ] Monitor upgrade progress (wait 5-10 minutes):
  ```fish
  talosctl health --nodes 192.168.10.174 --endpoints 192.168.10.174
  kubectl get nodes
  kubectl get pods -A
  ```
- [ ] Verify control plane node is Ready and all system pods are running
- [ ] Check Talos version:
  ```fish
  talosctl version --nodes 192.168.10.174
  ```

### Phase 4: Upgrade Worker Node 1
- [ ] Upgrade worker node 1 (192.168.10.206):
  ```fish
  talosctl upgrade \
    --nodes 192.168.10.206 \
    --endpoints 192.168.10.206 \
    --image factory.talos.dev/installer/4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b:v1.10.5 \
    --preserve \
    --talosconfig ./k8s-homelab-production/temp.talosconfig
  ```
- [ ] Monitor upgrade progress
- [ ] Verify node is Ready

### Phase 5: Upgrade Worker Node 2
- [ ] Upgrade worker node 2 (192.168.10.200):
  ```fish
  talosctl upgrade \
    --nodes 192.168.10.200 \
    --endpoints 192.168.10.200 \
    --image factory.talos.dev/installer/4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b:v1.10.5 \
    --preserve \
    --talosconfig ./k8s-homelab-production/temp.talosconfig
  ```
- [ ] Monitor upgrade progress
- [ ] Verify node is Ready

### Phase 6: Verify Cluster Health Post-Upgrade
- [ ] Check all nodes are upgraded:
  ```fish
  kubectl get nodes
  talosctl version --nodes 192.168.10.174,192.168.10.206,192.168.10.200
  ```
- [ ] Verify cluster health:
  ```fish
  talosctl health --nodes 192.168.10.174
  kubectl get pods -A
  ```

### Phase 7: Configure Tailscale Extension

#### 7.1 Prepare Tailscale Patch
- [ ] Copy Tailscale patch template:
  ```fish
  cp ./base-talos/tailscale.patch.yaml ./k8s-homelab-production/tailscale.patch.yaml
  ```
- [ ] Inject 1Password secrets:
  ```fish
  op inject -f -i ./k8s-homelab-production/tailscale.patch.yaml -o ./k8s-homelab-production/temp.tailscale.patch.yaml --cache=false
  ```

#### 7.2 Apply Tailscale to Control Plane
- [ ] Apply Tailscale patch to control plane (192.168.10.174):
  ```fish
  talosctl apply-config \
    -f ./k8s-homelab-production/temp.controlplane.yaml \
    -p @./k8s-homelab-production/temp.tailscale.patch.yaml \
    --nodes 192.168.10.174 \
    --talosconfig ./k8s-homelab-production/temp.talosconfig
  ```
- [ ] Monitor Tailscale extension logs:
  ```fish
  talosctl logs ext-tailscale -f --nodes 192.168.10.174
  ```
- [ ] Verify Tailscale is running and connected

#### 7.3 Apply Tailscale to Worker Node 1
- [ ] Apply Tailscale patch to worker 1 (192.168.10.206):
  ```fish
  talosctl apply-config \
    -f ./k8s-homelab-production/temp.worker.yaml \
    -p @./k8s-homelab-production/temp.tailscale.patch.yaml \
    --nodes 192.168.10.206 \
    --talosconfig ./k8s-homelab-production/temp.talosconfig
  ```
- [ ] Monitor and verify Tailscale extension

#### 7.4 Apply Tailscale to Worker Node 2
- [ ] Apply Tailscale patch to worker 2 (192.168.10.200):
  ```fish
  talosctl apply-config \
    -f ./k8s-homelab-production/temp.worker.yaml \
    -p @./k8s-homelab-production/temp.tailscale.patch.yaml \
    --nodes 192.168.10.200 \
    --talosconfig ./k8s-homelab-production/temp.talosconfig
  ```
- [ ] Monitor and verify Tailscale extension

### Phase 8: Final Verification
- [ ] Verify all nodes are on Tailscale network
- [ ] Check Tailscale admin console for all three nodes
- [ ] Verify cluster health:
  ```fish
  kubectl get nodes
  kubectl get pods -A
  talosctl health --nodes 192.168.10.174
  ```
- [ ] Test connectivity between nodes via Tailscale IPs (if needed)

## Rollback Plan
If issues occur during upgrade:
- Each node can be rolled back individually using a previous Talos version
- Keep temp config files until upgrade is confirmed successful
- Document any issues encountered for future reference

## Notes
- Upgrade time: ~5-10 minutes per node
- Total estimated time: ~30-45 minutes for all nodes + Tailscale configuration
- Use `--preserve` flag to keep current machine configuration during upgrade
- The schematic ID `4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b` already includes Tailscale extension
- Tailscale patch only configures the extension with auth key, doesn't install it

## Reference Documents
- `/workspace/docs/how-to-guides/upgrade-talos-and-kubernetes.md`
- `/workspace/cli-config.yaml`
- `/workspace/base-talos/tailscale.patch.yaml`
