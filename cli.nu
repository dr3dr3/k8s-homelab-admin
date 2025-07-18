#!/bin/env nu

# Homelab CLI
#
# This CLI wraps the common actions in setting
# up and managing your Kubernetes Homelab
def hl [] {
  "Welcome" | msgbox $in
  $env.HOMELAB_ENV = 'homelab-test'
}

def "hl cluster create" [] {
  "Create new cluster" | msgbox $in "header"
  "Provide name for new cluster:" | msgbox $in "line"
  # Get the name for the new cluster
  let cluster = (input)
  $cluster | path exists | if $in == true { 
    "❌ That cluster is already setup" | msgbox $in "error"
    return null
  }
  $cluster | path exists | if $in == false { 
    #mkdir $cluster
    $"Created directory: /($cluster)" | msgbox $in "line"
  }
  let $cluster_type: string = (cat cluster_types.txt | gum choose --limit 1)
  print $cluster_type
}

def "cluster create talos-baremetal" [
  cluster: string = "mycluster"
] {
  "Create a new bare metal Talos k8s cluster" | msgbox $in "header"
  "Is the following ready?" | msgbox $in "line"
  "✅ Connected to the target Talos machine are on the same LAN?" | msgbox $in
  "✅ The target Talos machine is ready in initial maintenance mode?" | msgbox $in
  "✅ Reserved the IP for the machine in your router" | msgbox $in
  "✅ 1Password vault created and service account token set" | msgbox $in
  gum confirm # else exits
  let config = open cli-config.yaml
  print $config.talos-defaults.schemeid
  "What is IP address for the target Talos machine?" | msgbox $in "line"
  let target_ip: string = (input)
  # wrap in try catch
  talosctl gen config $cluster $"https://($target_ip):6443" --install-image=$"factory.talos.dev/installer/($config.talos-defaults.schemeid):($config.talos-defaults.version)" -o $cluster --force
  ### TALOS CONFIG ###
  "Creating 1Password secure notes for Talos config..." | msgbox $in
  let talos_config: record = open $"./($cluster)/talosconfig" | from yaml
  op-create $"($cluster).talos.ca" $talos_config.contexts.test.ca | ignore | print $"✓ Talos Certificate Authority"
  op-create $"($cluster).talos.crt" $talos_config.contexts.test.crt | ignore | print $"✓ Talos Cert"
  op-create $"($cluster).talos.key" $talos_config.contexts.test.key | ignore | print $"✓ Talos Key"
  "Replacing secrets in talosconfig with OP reference" | msgbox $in
  $talos_config |
    reject contexts |
    insert contexts.xxxx.endpoints [$target_ip] |
    insert contexts.xxxx.ca $"op://($env.HOMELAB_ENV)/($cluster).talos.ca/notes" |
    insert contexts.xxxx.crt $"op://($env.HOMELAB_ENV)/($cluster).talos.crt/notes" |
    insert contexts.xxxx.key $"op://($env.HOMELAB_ENV)/($cluster).talos.key/notes" |
    to yaml |
    save -f $"./($cluster)/talosconfig"
  # Only need to do string replace as can't navigate dynamic path using Nushell
  open $"./($cluster)/talosconfig" | str replace --all 'xxxx' $cluster | save -f $"./($cluster)/talosconfig"
  "Replacing secrets in talosconfig with OP reference" | msgbox $in
  $talos_config |
    reject contexts |
    insert contexts.xxxx.endpoints [$target_ip] |
    insert contexts.xxxx.ca $"op://($env.HOMELAB_ENV)/($cluster).talos.ca/notes" |
    insert contexts.xxxx.crt $"op://($env.HOMELAB_ENV)/($cluster).talos.crt/notes" |
    insert contexts.xxxx.key $"op://($env.HOMELAB_ENV)/($cluster).talos.key/notes" |
    to yaml |
    save -f $"./($cluster)/talosconfig"
  ### ==================================== ###
  "Setting up Talos machine" | msgbox $in
  talosctl -n $target_ip get disks --insecure --talosconfig=$"./($cluster)/temp.talosconfig"
  let target_disk: string = (input)
  ### ==================================== ###
  "Creating 1Password secure notes for Controlplane nodes..." | msgbox $in
  let cp_config: record = open $"./($cluster)/controlplane.yaml"
  op-create $"($cluster).controlplane.machine.token" $cp_config.machine.token | ignore | print $"✓ Machine Token"
  op-create $"($cluster).controlplane.machine.ca.crt" $cp_config.machine.ca.crt | ignore | print $"✓ Machine CA Cert"
  op-create $"($cluster).controlplane.machine.ca.key" $cp_config.machine.ca.key | ignore | print $"✓ Machine CA Key"
  op-create $"($cluster).controlplane.cluster.id" $cp_config.cluster.id | ignore | print $"✓ Cluster ID"
  op-create $"($cluster).controlplane.cluster.secret" $cp_config.cluster.secret | ignore | print $"✓ Cluster Secret"
  op-create $"($cluster).controlplane.cluster.token" $cp_config.cluster.token | ignore | print $"✓ Cluster Token"
  op-create $"($cluster).controlplane.cluster.secretbox" $cp_config.cluster.secretbox | ignore | print $"✓ Cluster Secretbox"
  op-create $"($cluster).controlplane.cluster.ca.crt" $cp_config.cluster.ca.crt | ignore | print $"✓ Cluster CA Cert"
  op-create $"($cluster).controlplane.cluster.ca.key" $cp_config.cluster.ca.key | ignore | print $"✓ Cluster CA Key"
  op-create $"($cluster).controlplane.cluster.aggregatorCA.crt" $cp_config.cluster.aggregatorCA.crt | ignore | print $"✓ Aggregator CA Cert"
  op-create $"($cluster).controlplane.cluster.aggregatorCA.key" $cp_config.cluster.aggregatorCA.key | ignore | print $"✓ Aggregator CA Key"
  op-create $"($cluster).controlplane.cluster.service-account" $cp_config.cluster.service-account | ignore | print $"✓ Cluster Service Account"
  op-create $"($cluster).controlplane.cluster.etcd.ca.crt" $cp_config.cluster.etcd.ca.crt | ignore | print $"✓ ETCD CA Cert"
  op-create $"($cluster).controlplane.cluster.etcd.ca.key" $cp_config.cluster.etcd.ca.key | ignore | print $"✓ ETCD CA Key"
  "Replacing secrets in controlplane.yaml with OP reference" | msgbox $in
  $cp_config |
    insert machine.install.disk $"/dev/($target_disk)" |
    insert machine.install.wipe true |
    insert machine.token $"op://($env.HOMELAB_ENV)/($cluster).machine.token/notes" |
    insert machine.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).machine.ca.crt/notes" |
    insert machine.ca.key $"op://($env.HOMELAB_ENV)/($cluster).machine.ca.key/notes" |
    insert cluster.id $"op://($env.HOMELAB_ENV)/($cluster).cluster.id/notes" |
    insert cluster.secret $"op://($env.HOMELAB_ENV)/($cluster).cluster.secret/notes" |
    insert cluster.token $"op://($env.HOMELAB_ENV)/($cluster).cluster.token/notes" |
    insert cluster.secretbox $"op://($env.HOMELAB_ENV)/($cluster).cluster.secretbox/notes" |
    insert cluster.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).cluster.ca.crt/notes" |
    insert cluster.ca.key $"op://($env.HOMELAB_ENV)/($cluster).cluster.ca.key/notes" |
    insert cluster.aggregatorCA.crt $"op://($env.HOMELAB_ENV)/($cluster).cluster.aggregatorCA.crt/notes" |
    insert cluster.aggregatorCA.key $"op://($env.HOMELAB_ENV)/($cluster).cluster.aggregatorCA.key/notes" |
    insert cluster.service-account $"op://($env.HOMELAB_ENV)/($cluster).cluster.service-account/notes" |
    insert cluster.etcd.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).cluster.etcd.ca.crt/notes" |
    insert cluster.etcd.ca.key $"op://($env.HOMELAB_ENV)/($cluster).cluster.etcd.ca.key/notes" |
    to yaml |
    save -f $"./($cluster)/controlplane.yaml"
  ### ==================================== ###
  "Creating 1Password secure notes for Worker nodes..." | msgbox $in
  let w_config: record = open $"./($cluster)/worker.yaml"
  op-create $"($cluster).worker.machine.token" $w_config.machine.token | ignore | print $"✓ Machine Token"
  op-create $"($cluster).worker.machine.ca.crt" $w_config.machine.ca.crt | ignore | print $"✓ Machine CA Cert"
  op-create $"($cluster).worker.cluster.id" $w_config.cluster.id | ignore | print $"✓ Cluster ID"
  op-create $"($cluster).worker.cluster.secret" $w_config.cluster.secret | ignore | print $"✓ Cluster Secret"
  op-create $"($cluster).worker.cluster.token" $w_config.cluster.token | ignore | print $"✓ Cluster Token"
  op-create $"($cluster).worker.cluster.ca.crt" $w_config.cluster.ca.crt | ignore | print $"✓ Cluster CA Cert"
  "Replacing secrets in worker.yaml with OP reference" | msgbox $in
  $w_config |
    insert machine.token $"op://($env.HOMELAB_ENV)/($cluster).machine.token/notes" |
    insert machine.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).machine.ca.crt/notes" |
    insert cluster.id $"op://($env.HOMELAB_ENV)/($cluster).cluster.id/notes" |
    insert cluster.secret $"op://($env.HOMELAB_ENV)/($cluster).cluster.secret/notes" |
    insert cluster.token $"op://($env.HOMELAB_ENV)/($cluster).cluster.token/notes" |
    insert cluster.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).cluster.ca.crt/notes" |
    to yaml |
    save -f $"./($cluster)/worker.yaml"
  ### ==================================== ###
  "Creating temp files..." | msgbox $in
  op inject -i $"./($cluster)/talosconfig" -o $"./($cluster)/temp.talosconfig" --cache=false
  $env.TALOSCONFIG = $"./($cluster)/temp.talosconfig"
  op inject -i $"./($cluster)/controlplane.yaml" -o $"./($cluster)/temp.cp.yaml" --cache=false
  op inject -i $"./($cluster)/worker.yaml" -o $"./($cluster)/temp.w.yaml" --cache=false
  ### ==================================== ###
  "Bootstrapping initial controlplane..." | msgbox $in
  talosctl apply-config --insecure -f $"./($cluster)/temp.controlplane.yaml" -n $target_ip -e $target_ip --talosconfig=$"./($cluster)/temp.talosconfig"
  gum spin --spinner minidot --title "Talos config applied... waiting" -- sleep 10s
  talosctl --talosconfig $"./($cluster)/temp.talosconfig" bootstrap
  gum spin --spinner minidot --title "Talos machine bootstrapped... waiting" -- sleep 10s
  ### ==================================== ###
  "Generating Kubernetes config..." | msgbox $in
  talosctl --talosconfig $"./($cluster)/temp.talosconfig" kubeconfig $"./($cluster)/kubeconfig"
  let kube_config: record = open $"./($cluster)/kubeconfig"
  op-create $"($cluster).certificate-authority-data" $kube_config.certificate-authority-data | ignore | print $"✓ Kubernetes Certificate Authority"
  op-create $"($cluster).client-certificate-data" $kube_config.client-certificate-data | ignore | print $"✓ Kubernetes Client Certificate"
  op-create $"($cluster).client-key-data" $kube_config.client-key-data | ignore | print $"✓ Kubernetes Client Key"
  $env.KUBECONFIG = $"./($cluster)/temp.kubeconfig"
}

def "hl cluster up" [] {
  "Start and/or connect to existing cluster" | msgbox $in
}

def "hl cluster stop" [] {
  "Stop an ephemeral cluster" | msgbox $in
}

def "hl cluster delete" [] {
  "Delete an ephemeral cluster" | msgbox $in
}

def "hl cluster add-cp" [] {
  "Add a controlplane node to a cluster" | msgbox $in
}

def "hl cluster add-w" [] {
  "Add a worker node to a cluster" | msgbox $in
}

# Setup a new Talos machine as the initial controlplane
def "hl-talos first-cp" [
  cluster: string # Name for the new cluster
  ip: string # IP address of the target machine
] {
  "Add a worker node to a cluster" | msgbox $in
}



### Helper functions

def msgbox [ 
  msg: string # string for the message box
  type?: string # type of message box
] {
  match $type {
    "header" => { $msg | gum style --foreground 003 --border-foreground 003 --border thick --align center --width 60 --padding "1 4" },
    "error" => { $msg | gum style --foreground "#f00" --background "#fff" --padding "1 4" --margin "1 0" --align center --width 62 },
    "line" => { $msg | gum style --foreground 003 },
    _ => { $msg | gum style --foreground 000 }
  }
}

def op-create [
  title: string
  note: string
] {
  op item create --category 'Secure Note' --title $title --vault $env.HOMELAB_ENV $"notes=($note)"
}



####################


# gum style \
# 	--foreground 003 --border-foreground 003 --border rounded \
# 	--align center --width 50 --margin "1 2" --padding "2 4" \
# 	'K8S Homelab Admin Container:' 'New Cluster Setup'

# #clusterName=$(gum input --placeholder "Enter name of cluster and press [ENTER]: ")

# d=$(ls -d */ | cut -f1 -d'/')

# cluster=$(gum choose $d)

# gum style \
# 	--foreground 003 --border-foreground 003 --border rounded \
# 	--align center --width 50 --margin "1 2" --padding "2 4" \
# 	'Cluster:' $cluster
