#!/bin/bash

# Target cluster
export CLUSTER="k8s-homelab-dev1"

# Variables for cluster node IPs using Tailscale IPs
export C1_IP="192.168.8.140"
export W1_IP="x"
export W2_IP="x"

op inject -i ./talosconfig -o temp.talosconfig
export TALOSCONFIG="./temp.talosconfig"

op inject -i ./tailscale.patch.yaml -o temp.tailscale.patch.yaml
export TAILSCALE_PATCH_YAML="./temp.tailscale.patch.yaml"

op inject -i ./kubeconfig -o temp.kubeconfig
export KUBECONFIG="./temp.kubeconfig"

op inject -i ./controlplane.yaml -o temp.controlplane.yaml
export CONTROLPLANE_YAML="./temp.controlplane.yaml"

op inject -i ./worker.yaml -o temp.worker.yaml
export WORKER_YAML="./temp.worker.yaml"


# export VAR=$(op read op://path)