#!/bin/bash

# Get the available disks on the target machnine
talosctl -n $MACHINE_IP get disks --insecure --talosconfig=./$CLUSTER/temp.talosconfig

# Update the controlplane.yaml with the disk
yq -i '.machine.install.disk = "/dev/mmcblk1"' ./$CLUSTER/controlplane.yaml
yq -i '.machine.install.wipe = true' ./$CLUSTER/controlplane.yaml

# Update the worker.yaml with the disk
yq -i '.machine.install.disk = "/dev/nvme0n1"' ./$CLUSTER/worker.yaml
yq -i '.machine.install.wipe = true' ./$CLUSTER/worker.yaml
