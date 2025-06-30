#!/bin/bash

op inject -i ./talosconfig -o talosconfig.temp
export TALOSCONFIG="./talosconfig.temp"

op inject -i ./kubeconfig -o kubeconfig.temp
export KUBECONFIG="./kubeconfig.temp"

# export VAR=$(op read op://path)

# Variables for cluster node IPs using Tailscale IPs
export C1_IP="100.97.3.86"
export W1_IP="x"
export W2_IP="x"