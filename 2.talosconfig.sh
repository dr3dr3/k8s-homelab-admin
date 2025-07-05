#!/bin/bash

target="talos.ca.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".contexts.$CLUSTER.ca" yq 'eval(strenv(p))' ./$CLUSTER/talosconfig)"
p=".contexts.$CLUSTER.ca" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/talosconfig

target="talos.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".contexts.$CLUSTER.crt" yq 'eval(strenv(p))' ./$CLUSTER/talosconfig)"
p=".contexts.$CLUSTER.crt" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/talosconfig

target="talos.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(p=".contexts.$CLUSTER.key" yq 'eval(strenv(p))' ./$CLUSTER/talosconfig)"
p=".contexts.$CLUSTER.key" value="op://$CLUSTER/$target/notes" yq -i 'eval(strenv(p)) = env(value)' ./$CLUSTER/talosconfig
