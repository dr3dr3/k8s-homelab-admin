#!/bin/bash

talosctl apply-config --insecure -f ./$CLUSTER/temp.controlplane.yaml -n $MACHINE_IP -e $MACHINE_IP --talosconfig=./$CLUSTER/temp.talosconfig
sleep 10s
talosctl bootstrap --talosconfig ./$CLUSTER/temp.talosconfig -n $MACHINE_IP -e $MACHINE_IP
sleep 10s
talosctl kubeconfig --talosconfig ./$CLUSTER/temp.talosconfig ./$CLUSTER/kubeconfig
