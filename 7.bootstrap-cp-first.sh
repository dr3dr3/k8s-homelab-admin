#!/bin/bash

talosctl apply-config --insecure -f ./$CLUSTER/temp.controlplane.yaml -n $MACHINE_IP -e $MACHINE_IP --talosconfig=./$CLUSTER/temp.talosconfig
sleep 10s
talosctl --talosconfig ./$CLUSTER/temp.talosconfig bootstrap
sleep 10s
talosctl --talosconfig ./$CLUSTER/temp.talosconfig kubeconfig ./$CLUSTER/kubeconfig
