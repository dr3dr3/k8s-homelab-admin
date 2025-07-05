#!/bin/bash

target="worker.machine.token.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.machine.token' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.machine.token = env(value)' ./$CLUSTER/worker.yaml

target="worker.machine.ca.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.machine.ca.crt' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.machine.ca.crt = env(value)' ./$CLUSTER/worker.yaml

target="worker.machine.ca.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.machine.ca.key' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.machine.ca.key = env(value)' ./$CLUSTER/worker.yaml

target="worker.cluster.id.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.id' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.id = env(value)' ./$CLUSTER/worker.yaml

target="worker.cluster.secret.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.secret' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.secret = env(value)' ./$CLUSTER/worker.yaml

target="worker.cluster.token.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.token' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.token = env(value)' ./$CLUSTER/worker.yaml

target="worker.cluster.ca.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.ca.crt' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.ca.crt= env(value)' ./$CLUSTER/worker.yaml

target="worker.cluster.ca.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.ca.key' ./$CLUSTER/worker.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.ca.key = env(value)' ./$CLUSTER/worker.yaml
