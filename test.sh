#!/bin/bash

gum style \
	--foreground 003 --border-foreground 003 --border rounded \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	'K8S Homelab Admin Container:' 'New Cluster Setup'

#clusterName=$(gum input --placeholder "Enter name of cluster and press [ENTER]: ")

d=$(ls -d */ | cut -f1 -d'/')

cluster=$(gum choose $d)

gum style \
	--foreground 003 --border-foreground 003 --border rounded \
	--align center --width 50 --margin "1 2" --padding "2 4" \
	'Cluster:' $cluster
