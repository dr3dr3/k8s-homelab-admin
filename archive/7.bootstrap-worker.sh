#!/bin/bash

# ============================================================================
# DEPRECATED: This bash script is deprecated and will be removed in a future version.
# Please use the Nushell CLI instead: `nu cli.nu`
# See README.md for migration instructions.
# ============================================================================

talosctl apply-config --insecure -f ./$CLUSTER/temp.worker.yaml -n $MACHINE_IP -e $MACHINE_IP --talosconfig=./$CLUSTER/temp.talosconfig
sleep 10s
talosctl --talosconfig ./$CLUSTER/temp.talosconfig bootstrap
sleep 10s
talosctl --talosconfig ./$CLUSTER/temp.talosconfig kubeconfig ./$CLUSTER/kubeconfig
