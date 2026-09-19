# syntax=docker/dockerfile:1
# =============================================================================
# jmangelson/devpod-template
#
# Originally based on jusevitch/claude_code_devpod; heavily modified by
# jmangelson for personal workflow needs.
#
# Layer order: slowest-to-change at top, fastest-to-change at bottom.
# Changing a layer only invalidates that layer and everything below it.
#
# LAYER GUIDE:
#   1  Core system packages (build tools, X stack, Chrome)   — rare
#   2  Node.js + npm global config                           — rare
#   3  uv + Python 3.12                                      — rare
#   4  Python venv + Jupyter                                 — occasional
#   5  Claude Code                                           — occasional
#   6  Codex CLI                                             — occasional
#   7  Personal apt packages                                 — occasional
#   8  Shell config + dotfiles                               — frequent
# =============================================================================

FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# ── Layer 1: Core system packages ─────────────────────────────────────────────
# Infrastructure only: build tools, X forwarding stack, Chrome.
# Only touch this layer for low-level system dependencies.
# BuildKit cache mounts keep .deb files on the host so packages aren't
# re-fetched from the internet on every rebuild.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget gnupg ca-certificates build-essential \
        xvfb x11vnc novnc fluxbox x11-utils \
    && \
    wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /etc/apt/trusted.gpg.d/google-chrome.gpg && \
    echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        google-chrome-stable

# ── Layer 2: Node.js + npm global config ──────────────────────────────────────
# Grouped together: npm config is meaningless without Node, and you'd
# never update one independently of the other.
ENV NVM_DIR=/usr/local/share/nvm
RUN mkdir -p "$NVM_DIR" && chown -R $USER_UID:$USER_GID "$NVM_DIR"

USER $USERNAME
ENV HOME=/home/$USERNAME

# PROFILE=/dev/null stops the installer from appending its own (unguarded)
# nvm-sourcing block to .bashrc -- Layer 8 adds the one we actually want.
RUN export PROFILE=/dev/null && \
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash && \
    . "$NVM_DIR/nvm.sh" && \
    nvm install --lts && \
    nvm alias default node && \
    nvm cache clear

ENV NPM_GLOBAL_DIR=$HOME/.npm-global
ENV NPM_CONFIG_PREFIX=$HOME/.npm-global
ENV PATH="$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"

RUN mkdir -p $NPM_GLOBAL_DIR

# ── Layer 3: uv + Python 3.12 ─────────────────────────────────────────────────
# Grouped together: uv is just the Python installer/package manager;
# you'd never update one without the other.
# Kept separate from the venv so a Python version bump doesn't also
# wipe out your installed packages.
ENV PATH="$HOME/.local/bin:$PATH"

RUN curl -LsSf https://astral.sh/uv/install.sh | sh && \
    uv python install 3.12

# ── Layer 4: Python venv + Jupyter ────────────────────────────────────────────
# Separate from Layer 3 so you can add packages to the venv
# (e.g. numpy, scipy) without re-downloading Python itself.
RUN uv venv $HOME/.venv && \
    . $HOME/.venv/bin/activate && \
    uv pip install ipykernel jupyter && \
    python -m ipykernel install --user --name devpod --display-name "Python (DevPod)"

# ── Layer 5: Claude Code ──────────────────────────────────────────────────────
RUN curl -fsSL https://claude.ai/install.sh | bash

# ── Layer 6: Codex CLI ────────────────────────────────────────────────────────
# Separate from Claude: independent tool, independent release cadence.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh

# ── Layer 7: Personal apt packages ────────────────────────────────────────────
# Add everyday tools here. Placed after the AI CLI layers so adding a
# package (htop, tree, jq, etc.) doesn't invalidate Claude, Codex,
# Python, or Node. BuildKit cache avoids re-downloading existing packages.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        tmux \
        vim \
        emacs \
        ripgrep
USER $USERNAME

# ── Layer 8: Shell config + dotfiles ──────────────────────────────────────────
RUN { \
        echo ''; \
        echo '# DevPod tool paths'; \
        echo 'export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"'; \
        echo 'export NVM_DIR="/usr/local/share/nvm"'; \
        echo '# nvm refuses to source while NPM_CONFIG_PREFIX is set -- unset for the'; \
        echo '# duration of sourcing, then restore it for our custom global installs.'; \
        echo 'unset NPM_CONFIG_PREFIX'; \
        echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'; \
        echo 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"'; \
        echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi'; \
    } >> $HOME/.bashrc

COPY --chown=$USERNAME:$USERNAME .vimrc $HOME/.vimrc
COPY --chown=$USERNAME:$USERNAME .bash_aliases $HOME/.bash_aliases
