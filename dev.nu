#!/bin/env nu

let $cluster = "k8s-homelab-prod"
let talos_config: record = open $"./($cluster)/talosconfig" | from yaml
let v = $.$talos_config.contexts.$cluster.ca
print $v
#op-create $"($cluster).talos.ca" $v.1 | ignore | print $"✓ Talos Certificate Authority"