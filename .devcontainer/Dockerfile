ARG ALPINE_VERSION=latest
FROM alpine:${ALPINE_VERSION}

LABEL maintainer="Andre Dreyer"

# Install basic utilities
RUN apk add --no-cache shadow zsh starship nano fzf eza bat nerd-fonts curl wget git gcompat openssl
RUN git config --global user.name "Andre Dreyer" && git config --global user.email "git@andredreyer.com"

# Install 1Password CLI
RUN echo https://downloads.1password.com/linux/alpinelinux/stable/ >> /etc/apk/repositories && \
    wget https://downloads.1password.com/linux/keys/alpinelinux/support@1password.com-61ddfc31.rsa.pub -P /etc/apk/keys && \
    apk update && apk add 1password-cli

# Install GitHub CLI
RUN apk add --no-cache github-cli

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

# Install and setup Starship for ZSH
RUN curl -sS https://starship.rs/install.sh | sh -s -- -y
RUN wget -O ~/.zshrc https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/zshrc
RUN wget -O ~/.zshenv https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/zshenv
RUN wget -O ~/aliases https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/aliases
RUN wget -O ~/starship.toml https://raw.githubusercontent.com/dr3dr3/dotfiles/refs/heads/main/zsh/.config/starship.toml
ENV ZDOTDIR=~
ENV STARSHIP_CONFIG=~/starship.toml
ENV STARSHIP_CACHE=~/.starship/cache
RUN /bin/zsh ~/.zshrc

ENTRYPOINT ["/bin/zsh"]
