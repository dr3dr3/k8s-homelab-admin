#!/bin/bash

target="tailscale.patch.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".environment[0]" yq 'eval(strenv(p))' ./$CLUSTER/tailscale.patch.yaml)"
p=".environment[0]" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/tailscale.patch.yaml
