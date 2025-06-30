# Kubernetes Homelab Admin Container

## Setup

You will need to setup 1Password with the relevant Srvice Account token

```bash
export OP_SERVICE_ACCOUNT_TOKEN=xxxx
```

### Initialize ZSH

```bash
eval "$(starship init zsh)"
```

## Instructions

1. Choose which Kubernetes cluster you want to work on (based on directories)
1. CD into that directory in the terminal
1. Run start script: `source ./start.sh`
