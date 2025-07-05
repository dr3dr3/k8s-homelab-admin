#!/bin/bash

target="kube-config.certificate-authority-data.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.clusters[0].cluster.certificate-authority-data' ./$CLUSTER/kubeconfig)"
value="op://$CLUSTER/$target/notes" yq -i '.clusters[0].cluster.certificate-authority-data = env(value)' ./$CLUSTER/kubeconfig

target="kube-config.client-certificate-data.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.users[0].user.client-certificate-data' ./$CLUSTER/kubeconfig)"
value="op://$CLUSTER/$target/notes" yq -i '.users[0].user.client-certificate-data = env(value)' ./$CLUSTER/kubeconfig

target="kube-config.client-key-data.$CLUSTER"
op item create --category "Secure Note" --title $target --vault $CLUSTER "notes=$(yq '.users[0].user.client-key-data' ./$CLUSTER/kubeconfig)"
value="op://$CLUSTER/$target/notes" yq -i '.users[0].user.client-key-data = env(value)' ./$CLUSTER/kubeconfig
