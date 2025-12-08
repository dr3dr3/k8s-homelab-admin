#!/bin/bash

# ============================================================================
# DEPRECATED: This bash script is deprecated and will be removed in a future version.
# Please use the Nushell CLI instead: `nu cli.nu`
# See README.md for migration instructions.
# ============================================================================

# Pre-requisites
# CLUSTER env var is set to the cluster name
# 1Password vault is created

# Setup secrets into 1Password vault

target="talos.ca.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".contexts.$CLUSTER.ca" yq 'eval(strenv(p))' ./$CLUSTER/talosconfig)"
p=".contexts.$CLUSTER.ca" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/talosconfig

target="talos.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".contexts.$CLUSTER.crt" yq 'eval(strenv(p))' ./$CLUSTER/talosconfig)"
p=".contexts.$CLUSTER.crt" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/talosconfig

target="talos.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".contexts.$CLUSTER.key" yq 'eval(strenv(p))' ./$CLUSTER/talosconfig)"
p=".contexts.$CLUSTER.key" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/talosconfig

talosctl --talosconfig ./$CLUSTER/talosconfig config endpoint $MACHINE_IP
talosctl --talosconfig ./$CLUSTER/talosconfig config node $MACHINE_IP
