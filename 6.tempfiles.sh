#!/bin/bash

op inject -i ./$CLUSTER/talosconfig -o ./$CLUSTER/temp.talosconfig --cache=false
export TALOSCONFIG="./$CLUSTER/temp.talosconfig"

yq eval '... comments=""' ./$CLUSTER/controlplane.yaml > ./$CLUSTER/clean.controlplane.yaml
op inject -i ./$CLUSTER/clean.controlplane.yaml -o ./$CLUSTER/temp.controlplane.yaml --cache=false

yq eval '... comments=""' ./$CLUSTER/worker.yaml > ./$CLUSTER/clean.worker.yaml
op inject -i ./$CLUSTER/clean.worker.yaml -o ./$CLUSTER/temp.worker.yaml --cache=false
