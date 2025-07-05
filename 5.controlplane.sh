#!/bin/bash

target="controlplane.machine.token.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.machine.token' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.machine.token = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.machine.ca.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.machine.ca.crt' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.machine.ca.crt = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.machine.ca.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.machine.ca.key' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.machine.ca.key = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.id.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.id' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.id = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.secret.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.secret' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.secret = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.token.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.token' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.token = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.secretbox.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.secretboxEncryptionSecret' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.secretboxEncryptionSecret = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.ca.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.ca.crt' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.ca.crt= env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.ca.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.ca.key' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.ca.key = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.aggregatorCA.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.aggregatorCA.crt' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.aggregatorCA.crt = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.aggregatorCA.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.aggregatorCA.key' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.aggregatorCA.key = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.service-account.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.serviceAccount.key' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.serviceAccount.key = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.etcd.ca.crt.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.etcd.ca.crt' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.etcd.ca.crt = env(value)' ./$CLUSTER/controlplane.yaml

target="controlplane.cluster.etcd.ca.key.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.cluster.etcd.ca.key' ./$CLUSTER/controlplane.yaml)"
value="op://$CLUSTER/$target/notes" yq -i '.cluster.etcd.ca.key = env(value)' ./$CLUSTER/controlplane.yaml
