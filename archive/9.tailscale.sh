#!/bin/bash

# ============================================================================
# DEPRECATED: This bash script is deprecated and will be removed in a future version.
# Please use the Nushell CLI instead: `nu cli.nu`
# See README.md for migration instructions.
# ============================================================================

talosctl upgrade --image factory.talos.dev/installer/4a0d65c669d46663f377e7161e50cfd570c401f26fd9e7bda34a0216b6f1922b:v1.10.5 -m powercycle -f -n $MACHINE_IP -e $MACHINE_IP 

cp ./base/tailscale.patch.yaml ./$CLUSTER/tailscale.patch.yaml

op inject -i ./$CLUSTER/tailscale.patch.yaml -o ./temp.tailscale.patch.yaml --cache=false

talosctl apply-config -f ./$CLUSTER/temp.controlplane.yaml -p @temp.tailscale.patch.yaml
