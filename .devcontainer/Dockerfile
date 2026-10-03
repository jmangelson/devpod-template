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
#   5  Miniforge (conda)                                      — rare
#   6  Claude Code                                            — occasional
#   7  Codex CLI                                               — occasional
#   8  LaTeX toolchain — OPTIONAL, off by default              — rare
#   9  GUI stack: Xvfb/noVNC/Chrome — OPTIONAL, off by default — rare
#  10  Docker-in-Docker — OPTIONAL, off by default              — rare
#  11  Android toolchain — OPTIONAL, off by default             — rare
#  12  Personal apt packages                                  — occasional
#  13  Shell config + dotfiles                                — frequent
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
ARG ENABLE_ANDROID=false
ARG ENABLE_ANDROID_EMULATOR=false
ARG ANDROID_CMDLINE_TOOLS_VERSION=15859902
ARG ANDROID_PLATFORM=android-35
ARG ANDROID_BUILD_TOOLS=36.0.0
ARG ANDROID_SYSTEM_IMAGE=system-images;android-35;google_apis;x86_64
ARG ANDROID_KVM_GID=993
ARG MAESTRO_VERSION=

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
# nvm-sourcing block to .bashrc -- Layer 13 adds the one we actually want.
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

# ── Layer 5: Miniforge (conda) ────────────────────────────────────────────────
# conda-forge-based installer -- no Anaconda Inc. ToS/licensing concerns.
# Kept separate from uv/venv (Layers 3-4): uv remains the default for
# everyday Python work, conda is there for tools/environments that need it.
# Base env is NOT auto-activated on shell start, so it never shadows the
# uv venv or VS Code's python.defaultInterpreterPath.
ENV CONDA_DIR=$HOME/miniforge3
RUN curl -fsSL -o /tmp/miniforge.sh \
        "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh" && \
    bash /tmp/miniforge.sh -b -p $CONDA_DIR && \
    rm /tmp/miniforge.sh && \
    $CONDA_DIR/bin/conda init bash && \
    $CONDA_DIR/bin/conda config --set auto_activate_base false
ENV PATH="$CONDA_DIR/bin:$PATH"

# ── Layer 6: Claude Code ──────────────────────────────────────────────────────
RUN curl -fsSL https://claude.ai/install.sh | bash

# ── Layer 7: Codex CLI ────────────────────────────────────────────────────────
# Separate from Claude: independent tool, independent release cadence.
RUN curl -fsSL https://chatgpt.com/codex/install.sh | sh

# ── Layer 8: LaTeX toolchain (optional) ───────────────────────────────────────
# Off by default — enable with --build-arg ENABLE_LATEX=true. The extra
# distribution includes the standard LaTeX engines and commonly used packages;
# texlive-fonts-recommended supplies the Times metrics used by mathptmx, and
# latexmk provides convenient dependency-aware builds.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked if [ "$ENABLE_LATEX" = "true" ]; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends texlive-latex-extra texlive-fonts-recommended latexmk; fi
USER $USERNAME

# ── Layer 9: GUI stack (optional) ─────────────────────────────────────────────
# Xvfb/x11vnc/noVNC/fluxbox + Chrome, for projects that drive an in-container
# browser. Off by default -- the whole install is skipped unless built with
# --build-arg ENABLE_GUI=true. Placed last among the rarely-changing layers so
# flipping the flag never invalidates Node/Python/conda/Claude/Codex/apt above.
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

# ── Layer 10: Docker-in-Docker (optional) ────────────────────────────────────
# Off by default — enable with --build-arg ENABLE_DOCKER_IN_DOCKER=true.
# docker.io provides both the Docker CLI and inner daemon.
USER root
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked --mount=type=cache,target=/var/lib/apt,sharing=locked if [ "$ENABLE_DOCKER_IN_DOCKER" = "true" ]; then apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends docker.io && usermod -aG docker "$USERNAME"; fi
USER $USERNAME

# ── Layer 11: Android toolchain (optional) ────────────────────────────────────
# Installs a headless Android development toolchain for Expo/React Native:
# JDK 17, Android SDK command-line tools, platform tools/adb, one compile
# platform, build tools, and Maestro for device-level UI tests. The Android CLI
# (the replacement for deprecated sdkmanager) installs the SDK packages. The
# emulator package and system image are included only when
# ENABLE_ANDROID_EMULATOR=true.
# Docker-in-Docker is not required for this layer; an in-container emulator
# needs host KVM access instead (see devcontainer.json and README.md).
USER root
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV ANDROID_HOME=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=/opt/android-sdk/cmdline-tools/latest/bin:/opt/android-sdk/platform-tools:/opt/android-sdk/emulator:$PATH
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    if [ "$ENABLE_ANDROID" = "true" ]; then \
        apt-get update && \
        DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
            openjdk-17-jdk-headless \
            unzip \
            libasound2t64 \
            libdbus-1-3 \
            libfontconfig1 \
            libgl1 \
            libglu1-mesa \
            libxkbfile1 \
            libnss3 \
            libpulse0 \
            libx11-6 \
            libxcomposite1 \
            libxcursor1 \
            libxdamage1 \
            libxfixes3 \
            libxi6 \
            libxrandr2 \
            libxtst6 && \
        mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest" /tmp/android-cmdline-tools && \
        curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" \
            -o /tmp/android-cmdline-tools.zip && \
        unzip -q /tmp/android-cmdline-tools.zip -d /tmp/android-cmdline-tools && \
        mv /tmp/android-cmdline-tools/cmdline-tools/* "$ANDROID_SDK_ROOT/cmdline-tools/latest/"; \
    fi
RUN if [ "$ENABLE_ANDROID" = "true" ]; then \
        ANDROID_CLI="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/android" && \
        yes | "$ANDROID_CLI" sdk install \
            "platform-tools" \
            "platforms/${ANDROID_PLATFORM}" \
            "build-tools/${ANDROID_BUILD_TOOLS}" \
            $(if [ "$ENABLE_ANDROID_EMULATOR" = "true" ]; then printf '%s\n' emulator "system-images/${ANDROID_PLATFORM}/google_apis/x86_64"; fi) && \
        find "$ANDROID_SDK_ROOT" -type f -perm -u+x -exec chmod a+rx {} + && \
        chown -R "$USER_UID:$USER_GID" "$ANDROID_SDK_ROOT"; \
        if [ "$ENABLE_ANDROID_EMULATOR" = "true" ]; then \
            if getent group "$ANDROID_KVM_GID" >/dev/null; then \
                KVM_GROUP="$(getent group "$ANDROID_KVM_GID" | cut -d: -f1)"; \
            else \
                groupadd --system --gid "$ANDROID_KVM_GID" kvm; \
                KVM_GROUP=kvm; \
            fi; \
            usermod -aG "$KVM_GROUP" "$USERNAME"; \
        fi; \
    fi
USER $USERNAME
RUN if [ "$ENABLE_ANDROID" = "true" ]; then \
        mkdir -p "$HOME/.android"; \
    fi
USER root
RUN if [ "$ENABLE_ANDROID" = "true" ]; then \
        chown -R "$USER_UID:$USER_GID" "/home/$USERNAME/.android"; \
    fi
USER $USERNAME
RUN if [ "$ENABLE_ANDROID" = "true" ]; then \
        android init; \
    fi
RUN if [ "$ENABLE_ANDROID" = "true" ]; then \
        if [ -n "$MAESTRO_VERSION" ]; then export MAESTRO_VERSION; fi; \
        curl -fsSL "https://get.maestro.mobile.dev" | bash; \
    fi

# ── Layer 12: Personal apt packages ────────────────────────────────────────────
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

# ── Layer 13: Shell config + dotfiles ─────────────────────────────────────────
RUN { \
        echo ''; \
        echo '# DevPod tool paths'; \
        echo 'export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$HOME/.maestro/bin:$PATH"'; \
        echo 'export NVM_DIR="/usr/local/share/nvm"'; \
        echo 'export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk-amd64}"'; \
        echo 'export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/emulator:$PATH"'; \
        echo '# nvm refuses to source while NPM_CONFIG_PREFIX is set -- unset for the'; \
        echo '# duration of sourcing, then restore it for our custom global installs.'; \
        echo 'unset NPM_CONFIG_PREFIX'; \
        echo '[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"'; \
        echo 'export NPM_CONFIG_PREFIX="$HOME/.npm-global"'; \
        echo 'if [ -f ~/.bash_aliases ]; then . ~/.bash_aliases; fi'; \
    } >> $HOME/.bashrc

COPY --chown=$USERNAME:$USERNAME .vimrc $HOME/.vimrc
COPY --chown=$USERNAME:$USERNAME .bash_aliases $HOME/.bash_aliases
