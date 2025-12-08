# Nushell CLI Review and Recommendations

**Date:** December 8, 2025  
**Reviewer:** GitHub Copilot  
**Target:** k8s-homelab Nushell CLI and associated scripts

## Executive Summary

Your Nushell CLI shows solid foundational work with good integration of 1Password for secrets management and automated Talos cluster provisioning. However, there are opportunities to improve code organization, error handling, idiomatic Nushell usage, and maintainability. This review provides actionable recommendations prioritized by impact.

---

## Critical Issues

### 1. **Inconsistent Error Handling**

**Current State:**
- No try-catch blocks around external command calls
- Silent failures possible with `talosctl`, `op`, and other commands
- User could proceed with partially failed operations

**Recommendations:**
```nushell
# Instead of:
talosctl gen config $cluster ...

# Use:
try {
    talosctl gen config $cluster ... | complete
    if $in.exit_code != 0 {
        error make {msg: "Failed to generate Talos config"}
    }
} catch {
    "❌ Failed to generate Talos config. Ensure talosctl is installed." | msgbox $in "error"
    return
}
```

**Impact:** High - Prevents silent failures and improves user experience

---

### 2. **Hardcoded References to Production Cluster**

**Current State:**
- Line 71 & 78 in `cli.nu`: `--talosconfig=$"./k8s-homelab-prod/temp.talosconfig"`
- Should reference the current `$cluster` variable

**Fix:**
```nushell
# Change:
talosctl -n $target_ip get disks --insecure --talosconfig=$"./k8s-homelab-prod/temp.talosconfig"

# To:
talosctl -n $target_ip get disks --insecure --talosconfig=$"./($cluster)/temp.talosconfig"
```

**Impact:** Critical - This is a bug that breaks multi-cluster support

---

### 3. **Bash Scripts Should Be Migrated to Nushell**

**Current State:**
- Multiple `.sh` files (0-9) that duplicate functionality in `cli.nu`
- Maintenance burden with two different implementations
- Bash scripts don't benefit from Nushell's structured data handling

**Recommendations:**
1. **Immediate:** Mark bash scripts as deprecated with header comments
2. **Short-term:** Complete migration to Nushell CLI
3. **Medium-term:** Remove bash scripts once Nu CLI is validated

**Benefits:**
- Single source of truth
- Better error handling
- Structured data processing
- More maintainable

---

## High Priority Improvements

### 4. **Code Duplication in Disk Selection**

**Current State:**
Lines 71-83 contain duplicated logic:
```nushell
let disks = talosctl ... | from yaml | where ... | select ...
# Then same query again
let disk_list = talosctl ... | from yaml | where ... | select ...
```

**Recommendation:**
```nushell
let disks = talosctl -n $target_ip get disks --insecure 
    --talosconfig=$"./($cluster)/temp.talosconfig" -o yaml 
    | from yaml 
    | where spec.readonly == false 
    | where spec.transport != "usb"

# Use the same data for both display and selection
$disks | select metadata.id spec.pretty_size | rename ID SIZE | table -i false | print

let $disk_target: string = ($disks.metadata.id | input list 'Select disk')
```

**Impact:** Medium-High - Reduces network calls and improves performance

---

### 5. **Improve Function Decomposition**

**Current State:**
- `create-talos-baremetal` is 91 lines with multiple responsibilities
- Difficult to test individual components
- Hard to maintain

**Recommendation:**
Extract logical sections into separate functions:

```nushell
def "homelab cluster create-talos-baremetal" [cluster: string] {
    validate-prerequisites
    let target_ip = prompt-for-ip
    let disk = select-disk $cluster $target_ip
    
    generate-talos-config $cluster $target_ip $disk
    store-secrets-in-1password $cluster
    bootstrap-controlplane $cluster $target_ip
    
    "🍻 DONE - Cluster is ready" | msgbox $in
}

def validate-prerequisites [] { ... }
def select-disk [cluster: string, ip: string] -> string { ... }
def generate-talos-config [cluster: string, ip: string, disk: string] { ... }
def store-secrets-in-1password [cluster: string] { ... }
def bootstrap-controlplane [cluster: string, ip: string] { ... }
```

**Benefits:**
- Easier to test
- More reusable
- Better documentation through function names
- Easier debugging

---

### 6. **Replace String Interpolation Hack**

**Current State:**
Lines 95-103 use `xxxx` placeholder and string replacement:
```nushell
insert contexts.xxxx.endpoints.0 ...
# Then later:
open $"./($cluster)/talosconfig" | str replace --all 'xxxx' $cluster
```

**Recommendation:**
```nushell
# Use Nushell's upsert with proper path construction
let context_path = ['contexts', $cluster]
$talos_config 
    | reject contexts
    | insert $context_path.endpoints.0 $"op://($env.HOMELAB_ENV)/($cluster).talos.ip.endpoint/notes"
    | insert $context_path.ca $"op://($env.HOMELAB_ENV)/($cluster).talos.ca/notes"
    # ... etc
```

**Alternative:** Use `merge` command if constructing full nested structure:
```nushell
$talos_config
    | reject contexts
    | merge {contexts: {$cluster: {
        endpoints: [$"op://..."],
        ca: $"op://...",
        crt: $"op://...",
        key: $"op://..."
    }}}
```

---

### 7. **Add Configuration Validation**

**Current State:**
- No validation of `cli-config.yaml` structure
- Silent failures if config is malformed

**Recommendation:**
```nushell
def validate-config [] {
    let required_keys = ['cluster-types', 'talos']
    let config = open cli-config.yaml
    
    for key in $required_keys {
        if ($key not-in ($config | columns)) {
            error make {msg: $"Missing required config key: ($key)"}
        }
    }
    
    $config
}

# Use in functions:
let config = validate-config
```

---

## Medium Priority Improvements

### 8. **Enhance the `op-create` Helper Function**

**Current State:**
- Returns string "Creating" or "Updating"
- Error handling could be improved

**Recommendation:**
```nushell
def op-create [title: string, note: string] -> record {
    try {
        let items = op item list --vault $env.HOMELAB_ENV --format json 
            | from json 
            | where title == $title
        
        if ($items | length) == 1 {
            op item edit $title --vault $env.HOMELAB_ENV $"notes=($note)" | complete
            {action: 'Updated', title: $title, success: true}
        } else {
            op item create --category 'Secure Note' --title $title 
                --vault $env.HOMELAB_ENV $"notes=($note)" | complete
            {action: 'Created', title: $title, success: true}
        }
    } catch {|err|
        {action: 'Failed', title: $title, success: false, error: $err.msg}
    }
}

# Usage:
let result = op-create $"($cluster).talos.ca" $tbl.ca.0
if $result.success {
    print $"✓ ($result.action) ($result.title)"
} else {
    print $"✗ Failed to create ($result.title): ($result.error)"
}
```

---

### 9. **Improve Message Box Function**

**Current State:**
- Uses `gum` which is external dependency
- No fallback if `gum` not available

**Recommendation:**
```nushell
def msgbox [msg: string, type?: string] {
    # Check if gum is available
    if (which gum | is-empty) {
        # Fallback to plain formatting
        match $type {
            "header" => { print $"=== ($msg) ===" },
            "error" => { print $"ERROR: ($msg)" },
            "line" => { print $"→ ($msg)" },
            _ => { print $msg }
        }
        return
    }
    
    # Use gum if available
    match $type {
        "header" => { $msg | gum style --foreground 003 --border-foreground 003 --border thick --align center --width 60 --padding "1 4" },
        "error" => { $msg | gum style --foreground "#f00" --background "#fff" --padding "1 4" --margin "1 0" --align center --width 62 },
        "line" => { $msg | gum style --foreground 003 },
        _ => { $msg | gum style --foreground 000 }
    }
}
```

---

### 10. **Add Logging and Verbosity Control**

**Current State:**
- All output goes to stdout
- No way to debug or trace operations
- No log files for later review

**Recommendation:**
```nushell
# Add to top of cli.nu
$env.HOMELAB_LOG_LEVEL = ($env.HOMELAB_LOG_LEVEL? | default "INFO")
$env.HOMELAB_LOG_FILE = ($env.HOMELAB_LOG_FILE? | default $"($env.HOME)/.homelab/homelab.log")

def log [level: string, message: string] {
    let timestamp = date now | format date "%Y-%m-%d %H:%M:%S"
    let log_entry = $"($timestamp) [($level)] ($message)"
    
    # Write to file
    $log_entry | save --append $env.HOMELAB_LOG_FILE
    
    # Print based on log level
    let levels = {TRACE: 0, DEBUG: 1, INFO: 2, WARN: 3, ERROR: 4}
    if ($levels | get $level) >= ($levels | get $env.HOMELAB_LOG_LEVEL) {
        print $log_entry
    }
}

# Usage:
log "INFO" "Starting cluster creation"
log "DEBUG" $"Using IP: ($target_ip)"
log "ERROR" "Failed to connect to cluster"
```

---

### 11. **Add Dry-Run Mode**

**Recommendation:**
```nushell
def "homelab cluster create-talos-baremetal" [
    cluster: string = "mycluster"
    --dry-run # Add flag for dry-run
] {
    if $dry_run {
        log "INFO" "DRY RUN MODE - No changes will be made"
    }
    
    # Wrap destructive operations
    if not $dry_run {
        talosctl gen config ...
    } else {
        print "Would run: talosctl gen config ..."
    }
}
```

---

### 12. **Use Records for Configuration**

**Current State:**
- Multiple variables scattered throughout
- Hard to pass context between functions

**Recommendation:**
```nushell
def create-cluster-context [cluster: string, ip: string, disk: string] -> record {
    {
        cluster: $cluster,
        target_ip: $ip,
        disk: $disk,
        config: (open cli-config.yaml),
        paths: {
            talosconfig: $"./($cluster)/talosconfig",
            controlplane: $"./($cluster)/controlplane.yaml",
            worker: $"./($cluster)/worker.yaml",
            temp_talosconfig: $"./($cluster)/temp.talosconfig"
        }
    }
}

# Use throughout:
def bootstrap-controlplane [ctx: record] {
    talosctl apply-config --insecure 
        -f $ctx.paths.controlplane 
        --nodes $ctx.target_ip
        --talosconfig $ctx.paths.temp_talosconfig
}
```

---

## Low Priority / Nice-to-Have

### 13. **Add Progress Indicators**

```nushell
def with-spinner [message: string, command: closure] {
    print $"($message)..."
    let result = do $command
    print "✓"
    $result
}

# Usage:
with-spinner "Generating Talos config" {
    talosctl gen config ...
}
```

---

### 14. **Add Tab Completion**

```nushell
# Add completions for cluster names
def cluster-names [] {
    ls -D | where type == dir | get name
}

export extern "homelab cluster talos-add-node" [
    cluster: string@cluster-names
]
```

---

### 15. **Add Rollback Capability**

```nushell
# Before destructive operations, save state
def save-state [cluster: string] {
    let backup_dir = $"./($cluster)/.backup/(date now | format date '%Y%m%d_%H%M%S')"
    mkdir $backup_dir
    cp $"./($cluster)/*.yaml" $backup_dir
}

def "homelab cluster rollback" [cluster: string, --to-timestamp: string] {
    # Restore from backup
}
```

---

### 16. **Environment Variable Management**

**Current State:**
- `$env.HOMELAB_ENV = 'homelab'` set globally

**Recommendation:**
```nushell
# Use config file for environment settings
# ~/.config/nushell/homelab.nu
$env.HOMELAB_ENV = 'homelab'
$env.HOMELAB_BASE_DIR = ($env.PWD | default $"($env.HOME)/k8s-homelab")
$env.HOMELAB_LOG_LEVEL = 'INFO'

# Source in cli.nu:
source ~/.config/nushell/homelab.nu
```

---

### 17. **Add Health Checks**

```nushell
def "homelab doctor" [] {
    "Checking homelab environment..." | msgbox $in "header"
    
    # Check required commands
    let required_cmds = ['talosctl', 'kubectl', 'op', 'gum', 'yq']
    for cmd in $required_cmds {
        if (which $cmd | is-empty) {
            print $"✗ ($cmd) not found"
        } else {
            print $"✓ ($cmd) found"
        }
    }
    
    # Check 1Password connection
    try {
        op vault list | complete
        print "✓ 1Password connected"
    } catch {
        print "✗ 1Password not accessible"
    }
    
    # Check clusters
    let clusters = ls -D | where type == dir | where name =~ "k8s-"
    print $"\nFound ($clusters | length) cluster(s)"
}
```

---

## Testing Recommendations

### 18. **Add Unit Tests**

Create `tests/cli_test.nu`:

```nushell
use std assert

export def test_msgbox_fallback [] {
    # Mock environment without gum
    let result = msgbox "test" "header"
    assert ($result | str contains "===")
}

export def test_op_create_validation [] {
    # Test with invalid vault
    # Assert error handling works
}

# Run with: nu -c "use tests/cli_test.nu *; test_msgbox_fallback"
```

---

## Documentation Improvements

### 19. **Add Inline Documentation**

```nushell
# Create a persistent K8S cluster using Talos on bare metal machines
#
# This command guides you through creating a new Talos-based Kubernetes cluster
# on bare metal hardware. It handles:
# - Talos configuration generation
# - Disk selection and installation
# - Secret management via 1Password
# - Initial bootstrap of the control plane
#
# Prerequisites:
# - Target machine in Talos maintenance mode
# - Network connectivity to target
# - 1Password vault configured
# - Reserved IP address
#
# Example:
#   homelab cluster create-talos-baremetal my-cluster
#
# Returns: null on success, exits on failure
def "homelab cluster create-talos-baremetal" [
    cluster: string = "mycluster" # Name of the cluster to create
] { ... }
```

---

### 20. **Add Troubleshooting Guide**

Create `docs/how-to-guides/troubleshooting-cli.md`:
- Common errors and solutions
- Debug mode instructions
- Log file locations
- How to report issues

---

## Architecture Improvements

### 21. **Separate Concerns into Modules**

Suggested structure:
```
cli/
├── main.nu              # Entry point, main commands
├── lib/
│   ├── talos.nu        # Talos-specific functions
│   ├── secrets.nu      # 1Password integration
│   ├── validation.nu   # Input validation
│   ├── ui.nu           # UI helpers (msgbox, spinners)
│   └── config.nu       # Configuration management
└── tests/
    ├── talos_test.nu
    └── secrets_test.nu
```

Usage:
```nushell
# In main.nu
use lib/talos.nu *
use lib/secrets.nu *
use lib/ui.nu *
```

---

## Migration Plan

### Phase 1: Bug Fixes (Week 1)
1. Fix hardcoded cluster reference (#2)
2. Add basic error handling (#1)
3. Fix disk selection duplication (#4)

### Phase 2: Code Quality (Week 2-3)
1. Extract functions for better decomposition (#5)
2. Replace string interpolation hack (#6)
3. Add configuration validation (#7)
4. Improve op-create function (#8)

### Phase 3: Features (Week 4-5)
1. Add logging (#10)
2. Add dry-run mode (#11)
3. Add health checks (#17)
4. Deprecate bash scripts (#3)

### Phase 4: Refinement (Week 6+)
1. Modularize codebase (#21)
2. Add comprehensive tests (#18)
3. Add tab completion (#14)
4. Complete bash script migration (#3)

---

## Conclusion

Your Nushell CLI is a solid foundation for homelab management. The integration with 1Password and Talos is well-conceived. Priority should be:

1. **Fix the critical bug** (hardcoded cluster reference)
2. **Add error handling** to prevent silent failures
3. **Refactor for maintainability** through better function decomposition
4. **Migrate away from bash scripts** to have a single source of truth

The recommendations above will result in a more robust, maintainable, and user-friendly CLI tool. Focus on the high-priority items first, as they provide the most value with reasonable effort.

### Strengths to Maintain
✅ 1Password integration for secrets  
✅ Interactive workflows with `gum`  
✅ Structured data handling with Nushell  
✅ Clear separation of cluster configurations  

### Areas for Growth
⚠️ Error handling and validation  
⚠️ Code organization and modularity  
⚠️ Testing and documentation  
⚠️ Migration from bash to Nushell  

---

**Questions or need clarification on any recommendation? Feel free to ask!**
