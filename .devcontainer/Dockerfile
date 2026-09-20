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
#   1  Core system packages (build tools)                     — rare
#   2  Node.js + npm global config                            — rare
#   3  uv + Python 3.12                                       — rare
#   4  Python venv + Jupyter                                  — occasional
#   5  Claude Code                                            — occasional
#   6  Codex CLI                                               — occasional
#   7  LaTeX toolchain — OPTIONAL, off by default              — rare
#   8  GUI stack: Xvfb/noVNC/Chrome — OPTIONAL, off by default — rare
#   9  Docker-in-Docker — OPTIONAL, off by default              — rare
#  10  Personal apt packages                                  — occasional
#  11  Shell config + dotfiles                                — frequent
#
# Optional layers run their installs only when enabled with their build args.
# See devcontainer.json for the available options.
# =============================================================================

FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG ENABLE_LATEX=false
ARG ENABLE_GUI=false
ARG ENABLE_DOCKER_IN_DOCKER=false

# ── Layer 1: Core system packages ─────────────────────────────────────────────
# Infrastructure only: build tools. Only touch this layer for low-level
# system dependencies needed by every project.
# BuildKit cache mounts keep .deb files on the host so packages aren't
# re-fetched from the internet on every rebuild.
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        curl wget gnupg ca-certificates build-essential

# ── Layer 2: Node.js + npm global config ──────────────────────────────────────
# Grouped together: npm config is meaningless without Node, and you'd
# never update one independently of the other.
ENV NVM_DIR=/usr/local/share/nvm
RUN mkdir -p "$NVM_DIR" && chown -R $USER_UID:$USER_GID "$NVM_DIR"

USER $USERNAME
ENV HOME=/home/$USERNAME

# PROFILE=/dev/null stops the installer from appending its own (unguarded)
# nvm-sourcing block to .bashrc -- Layer 11 adds the one we actually want.
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

# ── Layer 7: LaTeX toolchain (optional) ───────────────────────────────────────
# Off by default — enable with --build-arg ENABLE_LATEX=true. The extra
# distribution includes the standard LaTeX engines and commonly used packages;
# latexmk provides convenient dependency-aware builds.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked if [ "$ENABLE_LATEX" = "true" ]; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends texlive-latex-extra latexmk; fi
USER $USERNAME

# ── Layer 8: GUI stack (optional) ─────────────────────────────────────────────
# Xvfb/x11vnc/noVNC/fluxbox + Chrome, for projects that drive an in-container
# browser. Off by default -- the whole install is skipped unless built with
# --build-arg ENABLE_GUI=true. Placed last among the rarely-changing layers so
# flipping the flag never invalidates Node/Python/Claude/Codex/apt above.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ "$ENABLE_GUI" = "true" ]; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            xvfb x11vnc novnc fluxbox x11-utils && \
        wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub \
            | gpg --dearmor -o /etc/apt/trusted.gpg.d/google-chrome.gpg && \
        echo "deb [arch=amd64] https://dl.google.com/linux/chrome/deb/ stable main" \
            > /etc/apt/sources.list.d/google-chrome.list && \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            google-chrome-stable; \
    fi
USER $USERNAME

# ── Layer 9: Docker-in-Docker (optional) ─────────────────────────────────────
# Off by default — enable with --build-arg ENABLE_DOCKER_IN_DOCKER=true.
# docker.io provides both the Docker CLI and inner daemon.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked if [ "$ENABLE_DOCKER_IN_DOCKER" = "true" ]; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends docker.io && usermod -aG docker "$USERNAME"; fi
USER $USERNAME

# ── Layer 10: Personal apt packages ────────────────────────────────────────────
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

# ── Layer 11: Shell config + dotfiles ─────────────────────────────────────────
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
