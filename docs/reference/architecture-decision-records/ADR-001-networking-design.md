# ADR-001: Networking Design for Kubernetes Homelab

**Status**: Accepted  
**Date**: 2025-12-08  
**Decision Makers**: Homelab Administrator  
**Technical Story**: Establishing secure networking architecture for Talos-based Kubernetes homelab clusters

## Context

The Kubernetes homelab consists of bare-metal clusters managed by Talos Linux. The primary use case is running applications for personal use, with occasional access by family members. The infrastructure needs to balance security, accessibility, and operational simplicity while avoiding the complexity and security risks of public internet exposure.

Key requirements:

- Secure cluster access limited to authorized users
- Support for personal and family use cases
- Ability to pull container images and Helm charts from the internet
- No public internet exposure of cluster services
- Simple operational model suitable for a homelab environment

## Decision

We will implement a **Tailscale-based private networking architecture** with the following components:

### 1. **Tailscale Mesh Network (Tailnet)**

All authorized users and cluster nodes will connect to a private Tailscale mesh network (Tailnet):

- **Control plane nodes**: Members of the Tailnet
- **Worker nodes**: Members of the Tailnet
- **Administrator devices**: Connected to Tailnet for cluster management
- **Family devices**: Connected to Tailnet for accessing applications

### 2. **Cluster Scope**

This networking design applies to:

- **Production cluster**: `k8s-homelab-production` (currently deployed)
- **Staging cluster**: `k8s-homelab-staging` (planned)

The k3d-based development cluster is **excluded** as it runs locally in containers and has different networking requirements.

### 3. **Tailscale Integration with Talos**

Tailscale will be deployed as a system extension in Talos Linux:

```yaml
customization:
    systemExtensions:
        officialExtensions:
            - siderolabs/tailscale
```

Configuration will be applied via patch files with authentication keys stored securely in 1Password.

### 4. **Ingress Strategy**

- **No LoadBalancer or NodePort services** exposed to the local network
- **ClusterIP services** by default
- **Tailscale Ingress** for exposing applications to Tailnet users
- Applications accessible via Tailscale domain names (e.g., `app-name.tail-scale-domain.ts.net`)

### 5. **Egress Strategy**

For cluster egress (accessing the internet):

- **Tailscale Exit Node**: Configure an exit node in the Tailnet to provide internet access
- Allows clusters to:
  - Pull container images from public registries (Docker Hub, GHCR, etc.)
  - Download Helm charts from repositories
  - Access external APIs if needed
- Exit node traffic is routed through the Tailnet, maintaining security

### 6. **Network Segmentation**

- **No public IP addresses** assigned to cluster nodes
- **Local network isolation**: Cluster nodes may use DHCP reservations on local network but services are not exposed locally
- **Tailnet-only access**: All cluster access (management and applications) occurs over Tailnet

## Consequences

### Positive

1. **Security**:
   - Zero public internet exposure eliminates most attack vectors
   - No need for external firewall management or DDoS protection
   - Encrypted WireGuard tunnels for all traffic
   - Built-in device authentication via Tailscale

2. **Simplicity**:
   - No complex network configuration (VLANs, firewall rules, port forwarding)
   - No need for external DNS, Let's Encrypt certificates, or reverse proxies
   - Tailscale handles NAT traversal automatically
   - Single authentication point (Tailscale) for all access

3. **Accessibility**:
   - Family members can access applications from any device on the Tailnet
   - Works from anywhere (home, work, mobile)
   - No VPN configuration needed beyond installing Tailscale

4. **Cost**:
   - Tailscale Personal plan is free for homelab use (up to 100 devices)
   - No need for paid DNS services, static IPs, or cloud load balancers

### Negative

1. **Tailscale Dependency**:
   - Critical dependency on Tailscale service availability
   - If Tailscale is down, cluster access is impacted
   - Mitigation: Tailscale has high availability and uses coordination servers only for initial connection

2. **Performance**:
   - Additional latency from WireGuard encryption/decryption
   - For homelab use cases, this overhead is negligible
   - Exit node adds an additional hop for internet egress

3. **Limited External Sharing**:
   - Cannot easily share applications with users outside the Tailnet
   - Would require inviting users to Tailnet or setting up Tailscale Funnel (public access)
   - For homelab use cases with family-only access, this is acceptable

4. **Learning Curve**:
   - Family members need to install and authenticate with Tailscale
   - Requires understanding of Tailnet concepts
   - Mitigation: Tailscale has good documentation and simple setup

### Neutral

1. **Operational Considerations**:
   - Need to manage Tailscale authentication keys (stored in 1Password)
   - Exit node must be configured and maintained
   - Tailscale system extension must be included in Talos images

## Implementation Notes

### Talos Configuration

The Tailscale extension is configured via `tailscale.patch.yaml`:

```yaml
apiVersion: v1alpha1
kind: ExtensionServiceConfig
name: tailscale
environment:
  - TS_AUTHKEY=op://homelab/tailscale.patch.authkey/notes
```

Authentication keys are injected from 1Password during cluster configuration.

### Cluster Access

- **kubectl**: Access via Tailnet IP addresses of control plane nodes
- **Talos API**: Access via Tailnet IP addresses using talosctl
- **Applications**: Access via Tailscale ingress or port forwarding over Tailnet

### Exit Node Configuration

An exit node should be configured in the Tailnet to provide internet access:

- Can be a dedicated device/VM or shared with other purposes
- Should have reliable internet connectivity
- Traffic from cluster nodes routes through this exit node

## Alternatives Considered

### 1. **Public Internet Exposure with Ingress Controller**

**Description**: Expose cluster services via LoadBalancer/NodePort with an ingress controller (NGINX, Traefik) and Let's Encrypt certificates.

**Rejected because**:

- Significant security risk for a homelab
- Requires port forwarding on router
- Exposes attack surface to the internet
- Requires ongoing certificate and DNS management
- Overkill for personal/family use case

### 2. **Traditional VPN (WireGuard, OpenVPN)**

**Description**: Self-hosted VPN server for cluster access.

**Rejected because**:

- More complex to set up and maintain
- Requires VPN server infrastructure
- Manual peer management
- Doesn't solve egress routing elegantly
- Tailscale provides similar functionality with less operational overhead

### 3. **Cloudflare Tunnel**

**Description**: Use Cloudflare Tunnel to expose services via Cloudflare's edge network.

**Rejected because**:

- Still exposes services to the internet (via Cloudflare)
- Requires Cloudflare account and configuration
- Adds external dependency beyond Tailscale
- Tailnet-only access is more secure for homelab use

### 4. **No Network Isolation (Local Network Only)**

**Description**: Expose services on local network only, no remote access.

**Rejected because**:

- Doesn't provide remote access for administrator
- Family members can only access from home network
- Doesn't solve egress routing
- Less flexible than Tailnet approach

## References

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Talos Linux System Extensions](https://www.talos.dev/latest/talos-guides/configuration/system-extensions/)
- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator)
- WireGuard Protocol Specification

## Related Decisions

- ADR-002: Authentication and Authorization Strategy (future)
- ADR-003: Storage Architecture (future)
- ADR-004: Backup and Disaster Recovery (future)

---

**Last Updated**: 2025-12-08
