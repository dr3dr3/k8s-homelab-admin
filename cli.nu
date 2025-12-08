#!/bin/env nu

# Helper function to retrieve and select disk from target machine
def select-disk [cluster: string, target_ip: string] {
  "Select disk for Talos installation:" | msgbox $in "line"
  
  let disks = try {
    let result = (talosctl -n $target_ip get disks --insecure --talosconfig=$"./($cluster)/temp.talosconfig" -o yaml | complete)
    if $result.exit_code != 0 {
      error make {msg: $"Failed to retrieve disks: ($result.stderr)"}
    }
    $result.stdout | from yaml | 
      where spec.readonly == false | 
      where spec.transport != "usb"
  } catch {|err|
    "❌ Failed to retrieve disk information from target machine. Ensure the machine is accessible and in maintenance mode." | msgbox $in "error"
    print $"Error: ($err.msg)"
    return ""
  }
  
  if ($disks | is-empty) {
    "❌ No suitable disks found on target machine." | msgbox $in "error"
    return ""
  }
  
  $disks | select metadata.id spec.pretty_size | rename ID SIZE | table -i false | print
  let disk_target: string = ($disks.metadata.id | input list 'Select disk')
  print $disk_target
  
  $disk_target
}

# Validate cli-config.yaml structure and return validated config
def validate-config [] {
  let config_file = "cli-config.yaml"
  
  # Check if config file exists
  if not ($config_file | path exists) {
    error make {msg: $"Configuration file not found: ($config_file)"}
  }
  
  # Load and parse config
  let config = open $config_file
  
  # Validate required top-level keys
  let required_keys = ['cluster-types', 'talos']
  for key in $required_keys {
    if ($key not-in ($config | columns)) {
      error make {msg: $"Missing required config key: ($key)"}
    }
  }
  
  # Validate cluster-types is a list
  if ($config.cluster-types | describe) !~ "list" {
    error make {msg: "Config key 'cluster-types' must be a list"}
  }
  
  # Validate talos section structure
  if not ($config.talos | is-not-empty) {
    error make {msg: "Config key 'talos' cannot be empty"}
  }
  
  # Validate talos.defaults exists and has required fields
  if 'defaults' not-in ($config.talos | columns) {
    error make {msg: "Missing required config key: talos.defaults"}
  }
  
  let talos_defaults_required = ['schemeid', 'version']
  for key in $talos_defaults_required {
    if ($key not-in ($config.talos.defaults | columns)) {
      error make {msg: $"Missing required config key: talos.defaults.($key)"}
    }
  }
  
  # Return validated config
  $config
}

# Homelab CLI
#
# This CLI wraps the common actions in setting
# up and managing your Kubernetes Homelab
def homelab [
  cluster: string # Name of the cluster
] {
  $env.HOMELAB_ENV = 'homelab'
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

# Validate prerequisites before starting cluster creation
def validate-prerequisites [] {
  "Create a new bare metal Talos k8s cluster" | msgbox $in "header"
  "Is the following ready?" | msgbox $in "line"
  "✅ Connected to the target Talos machine? (on the same LAN)" | msgbox $in
  "✅ The target Talos machine is ready in initial maintenance mode?" | msgbox $in
  "✅ Reserved the IP for the machine in your router" | msgbox $in
  "✅ 1Password vault created and service account token set" | msgbox $in
  gum confirm # else exits
}

# Prompt for target machine IP address
def prompt-for-ip [] {
  "What is IP address for the target Talos machine?" | msgbox $in "line"
  let target_ip: string = (input)
  $target_ip
}

# Generate Talos configuration files
def generate-talos-config [cluster: string, target_ip: string] {
  let config = try {
    validate-config
  } catch {|err|
    "❌ Configuration validation failed" | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Invalid configuration"}
  }
  
  try {
    let result = (talosctl gen config $cluster $"https://($target_ip):6443" --install-image=$"factory.talos.dev/installer/($config.talos.defaults.schemeid):v($config.talos.defaults.version)" -o $cluster --force | complete)
    if $result.exit_code != 0 {
      error make {msg: $"Failed to generate Talos config: ($result.stderr)"}
    }
  } catch {|err|
    "❌ Failed to generate Talos config. Ensure talosctl is installed and the parameters are correct." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Talos config generation failed"}
  }
}

# Store Talos secrets in 1Password
def store-talos-secrets [cluster: string, target_ip: string] {
  "Creating 1Password secure notes for Talos config..." | msgbox $in
  let talos_config: record = try {
    open $"./($cluster)/talosconfig" | from yaml
  } catch {|err|
    "❌ Failed to read Talos configuration file." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Failed to read talosconfig"}
  }
  
  let tbl = $talos_config.contexts | select $cluster | flatten
  
  let results = [
    (op-create $"($cluster).talos.ip.endpoint" $target_ip)
    (op-create $"($cluster).talos.api.endpoint" $"https://($target_ip):6443")
    (op-create $"($cluster).talos.ca" $tbl.ca.0)
    (op-create $"($cluster).talos.crt" $tbl.crt.0)
    (op-create $"($cluster).talos.key" $tbl.key.0)
  ]
  
  for result in $results {
    if $result.success {
      print $"✓ ($result.action) ($result.title)"
    } else {
      "❌ Failed to create 1Password secure notes. Ensure 1Password CLI is configured and you have access to the vault." | msgbox $in "error"
      print $"✗ Failed to ($result.action | str downcase) ($result.title): ($result.error)"
      error make {msg: "Failed to store talos secrets"}
    }
  }
  
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
}

# Store controlplane secrets in 1Password
def store-controlplane-secrets [cluster: string, disk: string] {
  "Creating 1Password secure notes for Controlplane nodes..." | msgbox $in
  let cp_config: record = try {
    open $"./($cluster)/controlplane.yaml"
  } catch {|err|
    "❌ Failed to read controlplane configuration file." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Failed to read controlplane.yaml"}
  }
  
  let results = [
    (op-create $"($cluster).controlplane.machine.token" $cp_config.machine.token)
    (op-create $"($cluster).controlplane.machine.ca.crt" $cp_config.machine.ca.crt)
    (op-create $"($cluster).controlplane.machine.ca.key" $cp_config.machine.ca.key)
    (op-create $"($cluster).controlplane.cluster.id" $cp_config.cluster.id)
    (op-create $"($cluster).controlplane.cluster.secret" $cp_config.cluster.secret)
    (op-create $"($cluster).controlplane.cluster.token" $cp_config.cluster.token)
    (op-create $"($cluster).controlplane.cluster.secretbox" $cp_config.cluster.secretboxEncryptionSecret)
    (op-create $"($cluster).controlplane.cluster.ca.crt" $cp_config.cluster.ca.crt)
    (op-create $"($cluster).controlplane.cluster.ca.key" $cp_config.cluster.ca.key)
    (op-create $"($cluster).controlplane.cluster.aggregatorCA.crt" $cp_config.cluster.aggregatorCA.crt)
    (op-create $"($cluster).controlplane.cluster.aggregatorCA.key" $cp_config.cluster.aggregatorCA.key)
    (op-create $"($cluster).controlplane.cluster.service-account.key" $cp_config.cluster.serviceAccount.key)
    (op-create $"($cluster).controlplane.cluster.etcd.ca.crt" $cp_config.cluster.etcd.ca.crt)
    (op-create $"($cluster).controlplane.cluster.etcd.ca.key" $cp_config.cluster.etcd.ca.key)
  ]
  
  for result in $results {
    if $result.success {
      print $"✓ ($result.action) ($result.title)"
    } else {
      "❌ Failed to create 1Password secure notes for controlplane. Ensure 1Password CLI is configured." | msgbox $in "error"
      print $"✗ Failed to ($result.action | str downcase) ($result.title): ($result.error)"
      error make {msg: "Failed to store controlplane secrets"}
    }
  }
  
  $cp_config |
    upsert cluster.controlPlane.endpoint $"op://($env.HOMELAB_ENV)/($cluster).talos.api.endpoint/notes" |
    upsert cluster.apiServer.certSANs.0 $"op://($env.HOMELAB_ENV)/($cluster).talos.ip.endpoint/notes" |
    upsert machine.install.disk $"/dev/($disk)" |
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
}

# Store worker secrets in 1Password
def store-worker-secrets [cluster: string] {
  "Creating 1Password secure notes for Worker nodes..." | msgbox $in
  let w_config: record = try {
    open $"./($cluster)/worker.yaml"
  } catch {|err|
    "❌ Failed to read worker configuration file." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Failed to read worker.yaml"}
  }
  
  let results = [
    (op-create $"($cluster).worker.machine.token" $w_config.machine.token)
    (op-create $"($cluster).worker.machine.ca.crt" $w_config.machine.ca.crt)
    (op-create $"($cluster).worker.cluster.id" $w_config.cluster.id)
    (op-create $"($cluster).worker.cluster.secret" $w_config.cluster.secret)
    (op-create $"($cluster).worker.cluster.token" $w_config.cluster.token)
    (op-create $"($cluster).worker.cluster.ca.crt" $w_config.cluster.ca.crt)
  ]
  
  for result in $results {
    if $result.success {
      print $"✓ ($result.action) ($result.title)"
    } else {
      "❌ Failed to create 1Password secure notes for worker. Ensure 1Password CLI is configured." | msgbox $in "error"
      print $"✗ Failed to ($result.action | str downcase) ($result.title): ($result.error)"
      error make {msg: "Failed to store worker secrets"}
    }
  }
  
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
}

# Bootstrap the controlplane node
def bootstrap-controlplane [cluster: string, target_ip: string] {
  homelab config talosctl $cluster
  "Bootstrapping initial controlplane..." | msgbox $in
  
  try {
    let result = (talosctl apply-config --insecure -f $"./($cluster)/temp.controlplane.yaml" --nodes $target_ip --endpoints $target_ip --talosconfig=$"./($cluster)/temp.talosconfig" | complete)
    if $result.exit_code != 0 {
      error make {msg: $"Failed to apply Talos config: ($result.stderr)"}
    }
  } catch {|err|
    "❌ Failed to apply Talos configuration to target machine." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Failed to apply Talos config"}
  }
  
  "Talos config applied... removed USB and confirm once rebooted" | msgbox $in
  gum confirm
  
  try {
    let result = (talosctl bootstrap --talosconfig $"./($cluster)/temp.talosconfig" --nodes $target_ip | complete)
    if $result.exit_code != 0 {
      error make {msg: $"Failed to bootstrap: ($result.stderr)"}
    }
  } catch {|err|
    "❌ Failed to bootstrap Talos cluster." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Failed to bootstrap cluster"}
  }
  
  'Talos machine bootstrapped... is Stage in "running"?' | msgbox $in
  gum confirm
}

# Generate Kubernetes configuration
def generate-kubeconfig [target_ip: string] {
  "Generating Kubernetes config..." | msgbox $in
  
  try {
    let result = (talosctl kubeconfig --nodes $target_ip --merge | complete)
    if $result.exit_code != 0 {
      error make {msg: $"Failed to generate kubeconfig: ($result.stderr)"}
    }
  } catch {|err|
    "❌ Failed to generate Kubernetes configuration." | msgbox $in "error"
    print $"Error: ($err.msg)"
    error make {msg: "Failed to generate kubeconfig"}
  }
}

# Create a persistent K8S cluster using Talos on bare metal machines
def "homelab cluster create-talos-baremetal" [
  cluster: string = "mycluster"
] {
  $env.HOMELAB_ENV = 'homelab'
  
  # Step 1: Validate prerequisites
  validate-prerequisites
  
  # Step 2: Get target IP
  let target_ip = prompt-for-ip
  
  # Step 3: Generate Talos configuration
  generate-talos-config $cluster $target_ip
  
  # Step 4: Select disk for installation
  let disk = select-disk $cluster $target_ip
  if ($disk | is-empty) {
    return
  }
  
  # Step 5: Store secrets in 1Password
  store-talos-secrets $cluster $target_ip
  store-controlplane-secrets $cluster $disk
  store-worker-secrets $cluster
  
  # Step 6: Bootstrap controlplane
  bootstrap-controlplane $cluster $target_ip
  
  # Step 7: Generate kubeconfig
  generate-kubeconfig $target_ip
  
  # Done!
  "🍻 DONE - Cluster is ready" | msgbox $in
}


# Add a node to a Talos cluster, either a controlplane or worker node
def "homelab cluster talos-add-node" [
  cluster: string
] {
  $env.HOMELAB_ENV = 'homelab'
  "Add a worker node to a Talos cluster" | msgbox $in
  "Is the following ready?" | msgbox $in "line"
  "✅ Connected to the target Talos machine? (on the same LAN)" | msgbox $in
  "✅ The target Talos machine is ready in initial maintenance mode?" | msgbox $in
  "✅ Reserved the IP for the machine in your router" | msgbox $in
  "✅ 1Password service account token set" | msgbox $in
  gum confirm # else exits
  let config = try {
    validate-config
  } catch {|err|
    "❌ Configuration validation failed" | msgbox $in "error"
    print $"Error: ($err.msg)"
    return
  }
  "What is IP address for the target Talos machine?" | msgbox $in "line"
  let target_ip: string = (input)
  ### ==================================== ###
  # Retrieve available disks from target machine and select one
  let disk_target = select-disk $cluster $target_ip
  
  if ($disk_target | is-empty) {
    return
  }
  ### ==================================== ###
  if ($"./($cluster)/talosconfig" | path exists) {
    "Talos config found..." | msgbox $in
  } else {
    "Generating Talos config..." | msgbox $in
    homelab config talosctl $cluster
  }
  let node_type: string = (["controlplane", "worker"] | input list 'Select node type')
  
  try {
    let result = (talosctl apply-config --insecure -f $"./($cluster)/temp.($node_type).yaml" --nodes $target_ip --talosconfig=$"./($cluster)/temp.talosconfig" | complete)
    if $result.exit_code != 0 {
      error make {msg: $"Failed to apply config: ($result.stderr)"}
    }
  } catch {|err|
    "❌ Failed to apply Talos configuration to new node." | msgbox $in "error"
    print $"Error: ($err.msg)"
    return
  }
  
  "🍻 DONE - Node added successfully" | msgbox $in
}

# Setup the temp files for Talos so can use talosctl to manage the cluster
def "homelab config talosctl" [
  cluster: string
] {
  "Creating temp files for Talos..." | msgbox $in
  
  try {
    let result1 = (op inject -f -i $"./($cluster)/talosconfig" -o $"./($cluster)/temp.talosconfig" --cache=false | complete)
    if $result1.exit_code != 0 {
      error make {msg: $"Failed to inject talosconfig: ($result1.stderr)"}
    }
    
    let result2 = (op inject -f -i $"./($cluster)/controlplane.yaml" -o $"./($cluster)/temp.controlplane.yaml" --cache=false | complete)
    if $result2.exit_code != 0 {
      error make {msg: $"Failed to inject controlplane config: ($result2.stderr)"}
    }
    
    let result3 = (op inject -f -i $"./($cluster)/worker.yaml" -o $"./($cluster)/temp.worker.yaml" --cache=false | complete)
    if $result3.exit_code != 0 {
      error make {msg: $"Failed to inject worker config: ($result3.stderr)"}
    }
    
    let result4 = (talosctl config merge $"./($cluster)/temp.talosconfig" --context $cluster | complete)
    if $result4.exit_code != 0 {
      error make {msg: $"Failed to merge talosctl config: ($result4.stderr)"}
    }
  } catch {|err|
    "❌ Failed to create temp files. Ensure 1Password CLI is configured and talosctl is installed." | msgbox $in "error"
    print $"Error: ($err.msg)"
    return
  }
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
  try {
    let result = (op item list --vault $env.HOMELAB_ENV --format json | complete)
    if $result.exit_code != 0 {
      return {
        action: 'Failed'
        title: $title
        success: false
        error: $"Failed to list 1Password items: ($result.stderr)"
      }
    }
    
    let items = $result.stdout | from json | where title == $title
    
    if ($items | length) == 1 {
      let edit_result = (op item edit $title --vault $env.HOMELAB_ENV $"notes=($note)" | complete)
      if $edit_result.exit_code != 0 {
        return {
          action: 'Failed'
          title: $title
          success: false
          error: $"Failed to edit 1Password item: ($edit_result.stderr)"
        }
      }
      return {
        action: 'Updated'
        title: $title
        success: true
      }
    } else {
      let create_result = (op item create --category 'Secure Note' --title $title --vault $env.HOMELAB_ENV $"notes=($note)" | complete)
      if $create_result.exit_code != 0 {
        return {
          action: 'Failed'
          title: $title
          success: false
          error: $"Failed to create 1Password item: ($create_result.stderr)"
        }
      }
      return {
        action: 'Created'
        title: $title
        success: true
      }
    }
  } catch {|err|
    return {
      action: 'Failed'
      title: $title
      success: false
      error: $"1Password operation failed: ($err.msg)"
    }
  }
}
