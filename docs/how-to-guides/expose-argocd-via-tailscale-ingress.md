# How to Expose ArgoCD via Tailscale Ingress

This guide explains how to make ArgoCD always available to your Tailnet using Tailscale Ingress, following the security and networking model described in ADR-001.

---

## Prerequisites

- Talos nodes are updated and Tailscale is running as a system extension.
- ArgoCD is deployed in your cluster (namespace: `argocd`).
- You are authenticated to your Tailnet.

---

## 1. Verify Tailscale Connectivity

Ensure all cluster nodes and your admin device are connected to the same Tailnet.

```sh
tailscale status
```

---

## 2. Install Tailscale Kubernetes Operator (if not already installed)

Follow the [Tailscale Kubernetes Operator guide](https://tailscale.com/kb/1236/kubernetes-operator/) or use the following command:

```sh
kubectl apply -f https://github.com/tailscale/tailscale-operator/releases/latest/download/install.yaml
```

---

## 3. Create a Tailscale Ingress Resource for ArgoCD

Create a file named `argocd-tailscale-ingress.yaml`:

```yaml
apiVersion: tailscale.com/v1alpha1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
spec:
  rules:
    - host: argocd.YOUR_TAILNET.ts.net
      backend:
        serviceName: argocd-server
        servicePort: 443
```

Replace `YOUR_TAILNET` with your actual Tailnet name.

---

## 4. Apply the Ingress Resource

```sh
kubectl apply -f argocd-tailscale-ingress.yaml
```

---

## 5. Access ArgoCD

- From any device on your Tailnet, open:  
  `https://argocd.YOUR_TAILNET.ts.net`
- Login with your ArgoCD credentials.

---

## 6. (Optional) Restrict Access

You can restrict which Tailnet users/devices can access ArgoCD using Tailscale ACLs. See [Tailscale ACL documentation](https://tailscale.com/kb/1018/acls/).

---

## Troubleshooting

- Ensure the `argocd-server` service is of type `ClusterIP` and reachable within the cluster.
- Check the Tailscale Operator logs for errors:

  ```sh
  kubectl logs deployment/tailscale-operator -n kube-system
  ```

- Verify the Ingress status:

  ```sh
  kubectl get ingress -A
  ```

---

## References

- [Tailscale Kubernetes Operator](https://tailscale.com/kb/1236/kubernetes-operator/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [ADR-001: Networking Design](../reference/architecture-decision-records/ADR-001-networking-design.md)

---
