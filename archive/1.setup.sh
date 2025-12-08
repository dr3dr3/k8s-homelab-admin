#!/bin/bash

# ============================================================================
# DEPRECATED: This bash script is deprecated and will be removed in a future version.
# Please use the Nushell CLI instead: `nu cli.nu`
# See README.md for migration instructions.
# ============================================================================

# Pre-requisites
# CLUSTER env var is set to the cluster name
# CP_IP env var is set to the control plane node IP
# TALOS_SCHEMEID env var is set to the Talos scheme ID
# TALOS_VERSION env var is set to the Talos version

# Setup cluster
mkdir -p $CLUSTER
talosctl gen config $CLUSTER https://$MACHINE_IP:6443 --install-image=factory.talos.dev/installer/$TALOS_SCHEMEID:$TALOS_VERSION -o $CLUSTER --force

