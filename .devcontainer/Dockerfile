FROM node:alpine

LABEL maintainer="André Dreyer"

# Fish Shell
RUN apk update && apk add fish

# Install basic utilities
RUN apk add --no-cache gum yq curl wget git gcompat openssl

# Install 1Password CLI
RUN echo https://downloads.1password.com/linux/alpinelinux/stable/ >> /etc/apk/repositories && \
    wget https://downloads.1password.com/linux/keys/alpinelinux/support@1password.com-61ddfc31.rsa.pub -P /etc/apk/keys && \
    apk update && apk add 1password-cli

# Install Talosctl
RUN curl -sL https://talos.dev/install | sh

# Install Kubectl
# Useful aliases for kubectl: https://github.com/ahmetb/kubectl-aliases/blob/master/.kubectl_aliases
RUN apk add --no-cache kubectl

# Install Kubectl Krew plugin manager
RUN set -x; cd "$(mktemp -d)" && \
    OS="$(uname | tr '[:upper:]' '[:lower:]')" && \
    ARCH="$(uname -m | sed -e 's/x86_64/amd64/' -e 's/\(arm\)\(64\)\?.*/\1\2/' -e 's/aarch64$/arm64/')" && \
    KREW="krew-${OS}_${ARCH}" && \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/${KREW}.tar.gz" && \
    tar zxvf "${KREW}.tar.gz" && \
    ./"${KREW}" install krew

# Set up PATH for krew
ENV PATH="/root/.krew/bin:${PATH}"

# Install Krew plugins
# https://github.com/ahmetb/kubectx
# https://github.com/yonahd/kor
# https://github.com/itaysk/kubectl-neat
# https://github.com/zegl/kube-score
RUN kubectl krew install ctx && \
    kubectl krew install ns && \
    kubectl krew install kor && \
    kubectl krew install neat && \
    kubectl krew install score

# Install Docker-CLI
RUN apk add --no-cache docker-cli

# Install k3d
RUN wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | ash

# Install Helm
RUN apk add --no-cache helm

# Install Argo CLI
RUN curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && \
    chmod +x argocd-linux-amd64 && \
    mv argocd-linux-amd64 /usr/local/bin/argocd

# Install git and configure user
RUN apk add git github-cli && git config --global user.name "André Dreyer" && git config --global user.email "github@andredreyer.com"

# Install Nushell
RUN apk add --no-cache nushell

# Install AI Assistants CLIs
RUN npm install -g @anthropic-ai/claude-code
RUN npm install -g @github/copilot

# Set Fish as default shell
ENV SHELL=/usr/bin/fish

ENTRYPOINT ["/usr/bin/fish"]


