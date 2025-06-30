# Scratch Pad

## Get TALOS ISO

From: https://factory.talos.dev/

Talos schematic ID for base AMD64 v10.4.0: 376567988ad370138ad8b2698212367b8edcb69b5fd68c80be1f2ec7d603b4ba

Talos schematic ID for base AMD64 v10.4.0 with extenstions: 4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b

Save the extensions schematic to `extensions.yaml`

```yaml
customization:
    systemExtensions:
        officialExtensions:
            - siderolabs/tailscale
```

Note: You can get the schematic ID via:

```bash
curl -X POST --data-binary @extensions.yaml https://factory.talos.dev/schematics
```

## Create a Virtualbox VM

* Use the above ISO in the optical drive
* Set network to Bridge adapter
* New mac address for all network interfaces (only one setup)

Start the VM

## Set Static IP

Get the MAC address from the networking setup in Virtual Box or via your router

Or via Powershell using the IP shown in VM. Example: `arp -a 192.168.8.108`

In your router set a DHCP Reservation for this IP using the MAC address

## Get TALOS config

Note: Choose your cluster name. Example: `eggplant-lab-k8s`

First... create folder for the new cluster. Example: `\eggplant-lab-k8s` and CD into that directory in terminal

### Generate TALOS config

Only do this ONCE! (Not for each VM)

```bash

export TALOSIP="192.168.8.108"

talosctl gen config eggplant-lab-k8s https://$TALOSIP:6443 --install-image=factory.talos.dev/installer/4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b:v1.10.4

export TALOSCONFIG="./talosconfig"

```

This creates files for:

* controlplane.yaml
* worker.yaml
* talosconfig

## Apply TALOS config

Update `talosconfig` with the IP for the primary controlplane

```bash

talosctl --talosconfig $TALOSCONFIG config endpoint $TALOSIP
talosctl --talosconfig $TALOSCONFIG config node $TALOSIP

```

Do this for each VM you have setup for controlplane and worker nodes

Remember to update `TALOSIP` for the workers

### Masters / Controlplane

```bash

export TALOSIP="192.168.8.110"
talosctl apply-config --insecure -f ./controlplane.yaml -n $TALOSIP -e $TALOSIP --talosconfig=$TALOSCONF --config-patch @tailscale.patch.yaml

```

### Workers

```bash

export TALOSIP="192.168.8.110"
talosctl apply-config --insecure -f ./worker.yaml -n $TALOSIP -e $TALOSIP --talosconfig=$TALOSCONF --config-patch @tailscale.patch.yaml

```

## Bootstrap K8s

NOTE: Only need to bootstrap the first controlplane (no other CPs or Workers)

Wait for logs to show `etcd` is waiting to join the cluster

```bash

talosctl --talosconfig $TALOSCONFIG bootstrap

```

Note: Stage should change to `Running` in Talos

Check everything is healthy by running `talosctl health`

## Setup kubectl

```bash

talosctl --talosconfig $TALOSCONFIG kubeconfig .
export KUBECONFIG="./kubeconfig"

```

## Ready to go

Go ahead and use your K8s cluster

Check by running `kubectl get nodes`

## Talos maintenance

### Setup Tailscale extension

```bash
talosctl apply-config -f controlplane.yml -p @tailscale.patch.yaml
```

Find the new IP from Tailscale and enable on controlplane

```bash
talosctl logs ext-tailscale -f
```

-f = follow

Find the new node and IP

Update controlplane.yaml config. Search for `certSANS` and change for both for `apiServer` and `machine`

Note: Can leave the LAN address there as well

Then apply config again:

```bash
talosctl apply-config -f controlplane.yml -p @tailscale.patch.yaml
```

Then update the `talosconfig` with the new IP as well

### Upgrade Talos

```bash
talosctl upgrade --image factory.talos.dev/installer/<ID>:<version> -m powercycle -f -e 192.168.8.108 -n 192.168.8.108
```

-f = force

### Get logs

```bash
talosctl dmesg -f -e $TALOSIP -n $TALOSIP
```

-f = follow

### See extensions

```bash
talosctl get extensions
```

### See services

```bash
talosctl services
```

## Kubectl Commands

* Set role of workers: `kubectl label node talos-kyh-7ph node-role.kubernetes.io/worker=worker`
