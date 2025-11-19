#!/bin/env nu

$env.HOMELAB_ENV = 'homelab'

# Homelab CLI
#
# This CLI wraps the common actions in setting
# up and managing your Kubernetes Homelab
def homelab [
  cluster: string # Name of the cluster
] {
  "Initiating cluster" | msgbox $in "header"
  ### TALOS BASED
  if ($"./($cluster)/talosconfig" | path exists) {
    "Detected cluster is Talos based..." | msgbox $in
    homelab config talosctl $cluster
    let node = open $"./($cluster)/temp.talosconfig" | 
      from yaml | 
      get contexts | 
      get $cluster | 
      get endpoints.0
    talosctl kubeconfig --nodes $node --merge --force
  }

  $env.HOMELAB_ENV = 'homelab'
}

# Guided process to setup a new Kuberbetets cluster
def "homelab cluster create" [
  cluster?: string
] {
  "Create new cluster" | msgbox $in "header"
  if $cluster == null {
    "Provide name for new cluster:" | msgbox $in "line"
    let cluster: string = (input)
  }
  $cluster | path exists | if $in == true { 
    "❌ That cluster is already setup" | msgbox $in "error"
    return null
  }
  $cluster | path exists | if $in == false { 
    mkdir $cluster
    $"Created directory: /($cluster)" | msgbox $in "line"
  }
  let $cli_config: record = open "./cli-config.yaml"
  let $cluster_type: string = ( $cli_config.cluster-types | input list 'Select type of cluster' )
  $"Created directory: ($cluster_type)" | msgbox $in "line"
  match $cluster_type {
    "k3s-local" => { return null },
    "talos-baremetal" => { homelab cluster create-talos-baremetal $cluster }
  }
}

# Create a persistent K8S cluster using Talos on bare metal machines
def "homelab cluster create-talos-baremetal" [
  cluster: string = "mycluster"
] {
  "Create a new bare metal Talos k8s cluster" | msgbox $in "header"
  "Is the following ready?" | msgbox $in "line"
  "✅ Connected to the target Talos machine? (on the same LAN)" | msgbox $in
  "✅ The target Talos machine is ready in initial maintenance mode?" | msgbox $in
  "✅ Reserved the IP for the machine in your router" | msgbox $in
  "✅ 1Password vault created and service account token set" | msgbox $in
  gum confirm # else exits
  let config = open cli-config.yaml
  "What is IP address for the target Talos machine?" | msgbox $in "line"
  let target_ip: string = (input)
  # wrap in try catch
  talosctl gen config $cluster $"https://($target_ip):6443" --install-image=$"factory.talos.dev/installer/($config.talos.defaults.schemeid):v($config.talos.defaults.version)" -o $cluster --force
  ### ==================================== ###
  let disks = talosctl -n $target_ip get disks --insecure --talosconfig=$"./k8s-homelab-prod/temp.talosconfig" -o yaml | from yaml | 
    where spec.readonly == false | 
    where spec.transport != "usb" | 
    select metadata.id spec.pretty_size | 
    rename ID SIZE | table -i false
  "Select disk for Talos installation:" | msgbox $in "line"
  print $disks
  let disk_list = talosctl -n $target_ip get disks --insecure --talosconfig=$"./k8s-homelab-prod/temp.talosconfig" -o yaml | from yaml | 
    where spec.readonly == false | 
    where spec.transport != "usb" | 
    select metadata.id | 
    rename id
  let $disk_target: string = ( $disk_list.id | input list 'Select disk' )
  print $disk_target
  ### ==================================== ###
  "Creating 1Password secure notes for Talos config..." | msgbox $in
  let talos_config: record = open $"./($cluster)/talosconfig" | from yaml
  let tbl = $talos_config.contexts | select $cluster | flatten
  op-create $"($cluster).talos.ip.endpoint" $target_ip | print $"✓ ($in) Talos IP Endpoint"
  op-create $"($cluster).talos.api.endpoint" $"https://($target_ip):6443" | print $"✓ ($in) Talos API Endpoint"
  op-create $"($cluster).talos.ca" $tbl.ca.0 | print $"✓ ($in) Talos Certificate Authority"
  op-create $"($cluster).talos.crt" $tbl.crt.0 | print $"✓ ($in) Talos Cert"
  op-create $"($cluster).talos.key" $tbl.key.0 | print $"✓ ($in) Talos Key"
  $talos_config |
    reject contexts |
    insert contexts.xxxx.endpoints.0 $"op://($env.HOMELAB_ENV)/($cluster).talos.ip.endpoint/notes" |
    insert contexts.xxxx.ca $"op://($env.HOMELAB_ENV)/($cluster).talos.ca/notes" |
    insert contexts.xxxx.crt $"op://($env.HOMELAB_ENV)/($cluster).talos.crt/notes" |
    insert contexts.xxxx.key $"op://($env.HOMELAB_ENV)/($cluster).talos.key/notes" |
    to yaml |
    save -f $"./($cluster)/talosconfig"
  # Only need to do string replace as can't navigate dynamic path using Nushell
  open $"./($cluster)/talosconfig" | str replace --all 'xxxx' $cluster | save -f $"./($cluster)/talosconfig"
  ### ==================================== ###
  "Creating 1Password secure notes for Controlplane nodes..." | msgbox $in
  let cp_config: record = open $"./($cluster)/controlplane.yaml"
  op-create $"($cluster).controlplane.machine.token" $cp_config.machine.token | print $"✓ ($in) Machine Token"
  op-create $"($cluster).controlplane.machine.ca.crt" $cp_config.machine.ca.crt | print $"✓ ($in) Machine CA Cert"
  op-create $"($cluster).controlplane.machine.ca.key" $cp_config.machine.ca.key | print $"✓ ($in) Machine CA Key"
  op-create $"($cluster).controlplane.cluster.id" $cp_config.cluster.id | print $"✓ ($in) Cluster ID"
  op-create $"($cluster).controlplane.cluster.secret" $cp_config.cluster.secret | print $"✓ ($in) Cluster Secret"
  op-create $"($cluster).controlplane.cluster.token" $cp_config.cluster.token | print $"✓ ($in) Cluster Token"
  op-create $"($cluster).controlplane.cluster.secretbox" $cp_config.cluster.secretboxEncryptionSecret | print $"✓ ($in) Cluster Secretbox"
  op-create $"($cluster).controlplane.cluster.ca.crt" $cp_config.cluster.ca.crt | print $"✓ ($in) Cluster CA Cert"
  op-create $"($cluster).controlplane.cluster.ca.key" $cp_config.cluster.ca.key | print $"✓ ($in) Cluster CA Key"
  op-create $"($cluster).controlplane.cluster.aggregatorCA.crt" $cp_config.cluster.aggregatorCA.crt | print $"✓ ($in) Aggregator CA Cert"
  op-create $"($cluster).controlplane.cluster.aggregatorCA.key" $cp_config.cluster.aggregatorCA.key | print $"✓ ($in) Aggregator CA Key"
  op-create $"($cluster).controlplane.cluster.service-account.key" $cp_config.cluster.serviceAccount.key | print $"✓ ($in) Cluster Service Account"
  op-create $"($cluster).controlplane.cluster.etcd.ca.crt" $cp_config.cluster.etcd.ca.crt | print $"✓ ($in) etcd CA Cert"
  op-create $"($cluster).controlplane.cluster.etcd.ca.key" $cp_config.cluster.etcd.ca.key | print $"✓ ($in) etcd CA Key"
  $cp_config |
    upsert cluster.controlPlane.endpoint $"op://($env.HOMELAB_ENV)/($cluster).talos.api.endpoint/notes" |
    upsert cluster.apiServer.certSANs.0 $"op://($env.HOMELAB_ENV)/($cluster).talos.ip.endpoint/notes" |
    upsert machine.install.disk $"/dev/($disk_target)" |
    upsert machine.install.wipe true |
    upsert machine.token $"op://($env.HOMELAB_ENV)/($cluster).controlplane.machine.token/notes" |
    upsert machine.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).controlplane.machine.ca.crt/notes" |
    upsert machine.ca.key $"op://($env.HOMELAB_ENV)/($cluster).controlplane.machine.ca.key/notes" |
    upsert cluster.id $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.id/notes" |
    upsert cluster.secret $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.secret/notes" |
    upsert cluster.token $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.token/notes" |
    upsert cluster.secretboxEncryptionSecret $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.secretbox/notes" |
    upsert cluster.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.ca.crt/notes" |
    upsert cluster.ca.key $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.ca.key/notes" |
    upsert cluster.aggregatorCA.crt $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.aggregatorCA.crt/notes" |
    upsert cluster.aggregatorCA.key $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.aggregatorCA.key/notes" |
    upsert cluster.serviceAccount.key $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.service-account.key/notes" |
    upsert cluster.etcd.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.etcd.ca.crt/notes" |
    upsert cluster.etcd.ca.key $"op://($env.HOMELAB_ENV)/($cluster).controlplane.cluster.etcd.ca.key/notes" |
    to yaml |
    save -f $"./($cluster)/controlplane.yaml"
  ### ==================================== ###
  "Creating 1Password secure notes for Worker nodes..." | msgbox $in
  let w_config: record = open $"./($cluster)/worker.yaml"
  op-create $"($cluster).worker.machine.token" $w_config.machine.token | print $"✓ ($in) Machine Token"
  op-create $"($cluster).worker.machine.ca.crt" $w_config.machine.ca.crt | print $"✓ ($in) Machine CA Cert"
  op-create $"($cluster).worker.cluster.id" $w_config.cluster.id | print $"✓ ($in) Cluster ID"
  op-create $"($cluster).worker.cluster.secret" $w_config.cluster.secret | print $"✓ ($in) Cluster Secret"
  op-create $"($cluster).worker.cluster.token" $w_config.cluster.token | print $"✓ ($in) Cluster Token"
  op-create $"($cluster).worker.cluster.ca.crt" $w_config.cluster.ca.crt | print $"✓ ($in) Cluster CA Cert"
  $w_config |
    upsert cluster.controlPlane.endpoint $"op://($env.HOMELAB_ENV)/($cluster).talos.api.endpoint/notes" |
    upsert machine.token $"op://($env.HOMELAB_ENV)/($cluster).worker.machine.token/notes" |
    upsert machine.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).worker.machine.ca.crt/notes" |
    upsert cluster.id $"op://($env.HOMELAB_ENV)/($cluster).worker.cluster.id/notes" |
    upsert cluster.secret $"op://($env.HOMELAB_ENV)/($cluster).worker.cluster.secret/notes" |
    upsert cluster.token $"op://($env.HOMELAB_ENV)/($cluster).worker.cluster.token/notes" |
    upsert cluster.ca.crt $"op://($env.HOMELAB_ENV)/($cluster).worker.cluster.ca.crt/notes" |
    to yaml |
    save -f $"./($cluster)/worker.yaml"
  ### ==================================== ###
  homelab config talosctl $cluster
  "Bootstrapping initial controlplane..." | msgbox $in
  talosctl apply-config --insecure -f $"./($cluster)/temp.controlplane.yaml" --nodes $target_ip --endpoints $target_ip --talosconfig=$"./($cluster)/temp.talosconfig"
  "Talos config applied... removed USB and confirm once rebooted" | msgbox $in
  gum confirm
  talosctl bootstrap --talosconfig $"./($cluster)/temp.talosconfig" --nodes $target_ip
  'Talos machine bootstrapped... is Stage in "running"?' | msgbox $in
  gum confirm
  "Generating Kubernetes config..." | msgbox $in
  talosctl kubeconfig --nodes $target_ip --merge
  # NOTE: don't need the code below as can use talosctl kubeconfig to generate it as needed
  # let kube_config: record = open $"./($cluster)/kubeconfig" | from yaml
  # op-create $"($cluster).kubeconfig.certificate-authority-data" $kube_config.clusters.0.cluster.certificate-authority-data | print $"✓ ($in) Kubernetes Certificate Authority"
  # op-create $"($cluster).kubeconfig.client-certificate-data" $kube_config.users.0.user.client-certificate-data | print $"✓ ($in) Kubernetes Client Certificate"
  # op-create $"($cluster).kubeconfig.client-key-data" $kube_config.users.0.user.client-key-data | print $"✓ ($in) Kubernetes Client Key"
  # $kube_config | 
  #   upsert clusters.0.cluster.server $"op://($env.HOMELAB_ENV)/($cluster).talos.api.endpoint/notes" |
  #   upsert clusters.0.cluster.certificate-authority-data $"op://($env.HOMELAB_ENV)/($cluster).kubeconfig.certificate-authority-data/notes" |
  #   upsert clusters.0.cluster.client-certificate-data $"op://($env.HOMELAB_ENV)/($cluster).kubeconfig.client-certificate-data/notes" |
  #   upsert clusters.0.cluster.client-key-data $"op://($env.HOMELAB_ENV)/($cluster).kubeconfig.client-key-data/notes" |
  #   to yaml |
  #   save -f $"./($cluster)/kubeconfig.yaml"
  ### ==================================== ###
  "🍻 DONE - Cluster is ready" | msgbox $in
}


# Add a node to a Talos cluster, either a controlplane or worker node
def "homelab cluster talos-add-node" [
  cluster: string
] {
  "Add a worker node to a Talos cluster" | msgbox $in
  "Is the following ready?" | msgbox $in "line"
  "✅ Connected to the target Talos machine? (on the same LAN)" | msgbox $in
  "✅ The target Talos machine is ready in initial maintenance mode?" | msgbox $in
  "✅ Reserved the IP for the machine in your router" | msgbox $in
  "✅ 1Password service account token set" | msgbox $in
  gum confirm # else exits
  let config = open cli-config.yaml
  "What is IP address for the target Talos machine?" | msgbox $in "line"
  let target_ip: string = (input)
  ### ==================================== ###
  let disks = talosctl -n $target_ip get disks --insecure --talosconfig=$"./k8s-homelab-prod/temp.talosconfig" -o yaml | from yaml | 
    where spec.readonly == false | 
    where spec.transport != "usb" | 
    select metadata.id spec.pretty_size | 
    rename ID SIZE | table -i false
  "Select disk for Talos installation:" | msgbox $in "line"
  print $disks
  let disk_list = talosctl -n $target_ip get disks --insecure --talosconfig=$"./k8s-homelab-prod/temp.talosconfig" -o yaml | from yaml | 
    where spec.readonly == false | 
    where spec.transport != "usb" | 
    select metadata.id | 
    rename id
  let $disk_target: string = ( $disk_list.id | input list 'Select disk' )
  print $disk_target
  ### ==================================== ###
  if ($"./($cluster)/talosconfig" | path exists) {
    "Talos config found..." | msgbox $in
  } else {
    "Generating Talos config..." | msgbox $in
    homelab config talosctl $cluster
  }
  let node_type: string = (["controlplane", "worker"] | input list 'Select node type')
  talosctl apply-config --insecure -f $"./($cluster)/temp.($node_type).yaml" --nodes $target_ip --talosconfig=$"./($cluster)/temp.talosconfig"
  "🍻 DONE - Cluster is ready" | msgbox $in
}

# Setup the temp files for Talos so can use talosctl to manage the cluster
def "homelab config talosctl" [
  cluster: string
] {
  "Creating temp files for Talos..." | msgbox $in
  op inject -f -i $"./($cluster)/talosconfig" -o $"./($cluster)/temp.talosconfig" --cache=false
  op inject -f -i $"./($cluster)/controlplane.yaml" -o $"./($cluster)/temp.controlplane.yaml" --cache=false
  op inject -f -i $"./($cluster)/worker.yaml" -o $"./($cluster)/temp.worker.yaml" --cache=false
  talosctl config merge $"./($cluster)/temp.talosconfig" --context $cluster
}

def "homelab cluster up" [] {
  "Start and/or connect to existing cluster" | msgbox $in
}

def "homelab cluster stop" [] {
  "Stop an ephemeral cluster" | msgbox $in
}

def "homelab cluster delete" [] {
  "Delete an ephemeral cluster" | msgbox $in
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
  let x: int = op item list --vault $env.HOMELAB_ENV --format json | from json | select title | where $it.title == $title | length
  if x == 1 {
    op item edit $title --vault $env.HOMELAB_ENV $"notes=($note)"
    return 'Updating'
  } else {
    op item create --category 'Secure Note' --title $title --vault $env.HOMELAB_ENV $"notes=($note)"
    return 'Creating'
  }
}
