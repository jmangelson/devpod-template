# jmangelson DevPod Template

Originally based on [`jusevitch/claude_code_devpod`](https://github.com/jusevitch/claude_code_devpod);
heavily modified by jmangelson for personal workflow needs.

## How it works

The container is built from `.devcontainer/Dockerfile` rather than pulling a
plain base image and running a monolithic setup script. Nearly everything is
baked into Docker image layers, so rebuilds only redo work for the layers that
actually changed.

`postCreateCommand` runs only `start-display.sh` -- a lightweight script that
starts the Xvfb/VNC/noVNC daemons when the GUI stack is enabled. It no-ops
instantly otherwise. These must be live processes (can't be baked into an
image), but they start in a few seconds.

### Layer structure

Layers are ordered slowest-to-change -> fastest-to-change. A change to any
layer only invalidates that layer and everything below it.

| # | Contents | Change frequency |
|---|---|---|
| 1 | Core system packages: build tools | Rare -- low-level infra only |
| 2 | Node.js + npm global config | Rare -- coupled, always change together |
| 3 | uv + Python 3.12 | Rare -- coupled, always change together |
| 4 | Python venv + Jupyter | Occasional -- add base Python packages here |
| 5 | Claude Code | Occasional |
| 6 | Codex CLI | Occasional -- separate from Claude, independent cadence |
| 7 | LaTeX toolchain (`texlive-latex-extra`, `latexmk`) -- **optional, off by default** | Rare -- only if enabled |
| 8 | GUI stack: Xvfb/x11vnc/noVNC/Chrome -- **optional, off by default** | Rare -- only if enabled |
| 9 | Docker-in-Docker -- **optional, off by default** | Rare -- only if enabled |
| 10 | Personal apt packages: tmux, vim, emacs, ripgrep, ... | Occasional -- **add new tools here** |
| 11 | Shell config, `.vimrc`, `.bash_aliases` | Frequent |

**Key design decisions:**
Layer 1 is infrastructure that almost never changes (build tools). Node and
npm config are merged (Layer 2) since they're always updated together; same
for uv and Python (Layer 3). The venv is its own layer (Layer 4) so adding
Python packages doesn't re-download Python itself. The optional LaTeX, GUI, and
Docker-in-Docker layers (Layers 7-9) sit before the personal apt and shell layers.
Adding `htop` or `jq` rebuilds Layers 10-11 but leaves everything above cached.
All apt-install layers use BuildKit cache mounts so `.deb` files are never
re-downloaded from the internet, even on a layer rebuild.

The LaTeX toolchain (Layer 7) is gated behind the `ENABLE_LATEX` build arg and skipped entirely by default. The GUI stack (Layer 8) is gated behind the `ENABLE_GUI` build arg, and Docker-in-Docker (Layer 9) is gated behind `ENABLE_DOCKER_IN_DOCKER`; all are skipped by default. These optional layers sit after the Node, Python, and AI-tool layers, so toggling one preserves Layers 1-6 while rebuilding that layer and everything below it. See [Enabling LaTeX](#enabling-latex), [Docker-in-Docker](#enabling-docker-in-docker), and [Chrome GUI (noVNC)](#chrome-gui-novnc-optional) below to enable them.

**Mounts never trigger a rebuild.** They are container-level config, not part
of the image. Adding or changing a mount only recreates the container (seconds).

## Getting started

### Prerequisites

- [DevPod](https://devpod.sh) installed and configured with a Docker provider
- Docker with BuildKit enabled (default in Docker Desktop and Docker Engine 23+)

### Start the workspace

```bash
devpod up . --ide vscode
```

First run takes 5-10 minutes to build the image. Subsequent starts use the
layer cache and are much faster.

## Adding personal apt packages

Edit **Layer 10** in `Dockerfile`:

```dockerfile
# ── Layer 10: Personal apt packages ──
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        tmux \
        vim \
        emacs \
        ripgrep \
        htop       # ← add new packages here
```

Then rebuild. Only Layer 10 and below rebuild -- Node, Python, Claude, and Codex
all stay cached.

## Enabling the GUI stack

The Chrome/Xvfb/noVNC layer is **off by default**. To enable it for a project:

1. In `devcontainer.json`, uncomment `"ENABLE_GUI": "true"` in `build.args`.
2. Uncomment `containerEnv` and `forwardPorts` further down in the same file.
3. If you'll run this alongside other devpods at the same time, change
   `NOVNC_PORT` (in `containerEnv`) and the matching `forwardPorts` entry to a
   port unique to this project -- devpod forwards the literal port number, so
   two workspaces both left on `6080` will conflict.
4. Rebuild:
   ```bash
   devpod up . --recreate --ide vscode
   ```
   (`--recreate` is required -- `devpod up` reuses an already-running
   container and won't notice the Dockerfile/build-arg change otherwise.)

## Enabling LaTeX

The LaTeX toolchain is **off by default**. To enable it for a project:

1. In `devcontainer.json`, change `"ENABLE_LATEX": "false"` to `"ENABLE_LATEX": "true"` in `build.args`.
2. Rebuild:
   ```bash
   devpod up . --recreate --ide vscode
   ```
   (`--recreate` is required -- `devpod up` reuses an already-running container and will not notice the Dockerfile/build-arg change otherwise.)

This installs `texlive-latex-extra` and `latexmk`, including the standard LaTeX engines and commonly used packages.

## Enabling Docker-in-Docker

Docker-in-Docker is **off by default**. To enable it for a project:

1. In `devcontainer.json`, change `"ENABLE_DOCKER_IN_DOCKER": "false"` to `"ENABLE_DOCKER_IN_DOCKER": "true"` in `build.args`.
2. Uncomment `"runArgs": ["--privileged"]` near `remoteUser`; the inner Docker daemon requires privileged container access.
3. Rebuild:
   ```bash
   devpod up . --recreate --ide vscode
   ```
4. Start the inner daemon inside the container:
   ```bash
   sudo dockerd --storage-driver=vfs --host=unix:///var/run/docker.sock >/tmp/devpod-dockerd.log 2>&1 &
   ```

The Dockerfile installs `docker.io`, which provides both the Docker CLI and daemon. Use the `vfs` storage driver when starting the inner daemon because nested overlay mounts are not supported in the DevPod container environment.

## Adding external folder mounts

Edit the `mounts` array in `devcontainer.json`:

```json
"mounts": [
    "source=/your/host/path,target=/workspaces/external/name,type=bind,consistency=cached"
]
```

For example, to mount a Windows-side research folder into the container:

```json
"mounts": [
    "source=/mnt/c/Users/mangelson/jgm/work/byu/talks/research/26oceans-sim-workshop,target=/workspaces/external/26oceans-sim,type=bind,consistency=cached"
]
```

The folder will be accessible inside the container at `/workspaces/external/26oceans-sim`. Add as many entries as you need -- each mount is a separate line in the array.

**Read-only mounts:** append `,readonly` to keep the container from writing
back to the host path -- useful for shared reference data or datasets:

```json
"mounts": [
    "source=/mnt/c/Users/you/reference-data,target=/workspaces/external/reference-data,type=bind,consistency=cached,readonly"
]
```

**Mixing read-only and read-write:** nest a second mount at a sub-path to make
just that sub-path writable within an otherwise read-only tree -- e.g.
read-only access to a large shared dataset, with read-write on one working
subfolder inside it:

```json
"mounts": [
    "source=/mnt/c/Users/you/big-folder,target=/workspaces/external/big-folder,type=bind,consistency=cached,readonly",
    "source=/mnt/c/Users/you/big-folder/subfolder,target=/workspaces/external/big-folder/subfolder,type=bind,consistency=cached"
]
```

Each bind mount is independent at the kernel level, so the more specific
mount simply shadows that portion of the parent -- everything else under
`big-folder` stays read-only.

Then **recreate** (not rebuild) the container:

```bash
devpod up . --recreate --ide vscode
```

Or use the VS Code Command Palette: `Dev Containers: Rebuild Container`.
The cached image is reused -- the container is ready in seconds.

## Rebuild cheat sheet

| What changed | Layers rebuilt | Time |
|---|---|---|
| Mount added/changed | none (recreate only) | ~5 sec |
| `.vimrc` / `.bash_aliases` / shell config | 11 | ~15 sec |
| `ENABLE_LATEX` flipped on for the first time | 7-11 | several minutes |
| `ENABLE_GUI` flipped on for the first time | 8-11 | ~2-3 min (Chrome download) |
| `ENABLE_DOCKER_IN_DOCKER` flipped on for the first time | 9-11 | several minutes |
| Personal apt package added (tmux, htop, ...) | 10-11 | ~1 min |
| Claude Code updated | 5-11 | ~1-2 min |
| Codex CLI updated | 6-11 | ~1-2 min |
| Python venv packages changed | 4-11 | ~2 min |
| uv / Python 3.12 version changed | 3-11 | ~3 min |
| Node / nvm version changed | 2-11 | ~3-4 min |
| System apt package added (rare) | 1-11 (full rebuild) | ~5-10 min |

## What's installed

| Tool | Details |
|---|---|
| **Node.js** | LTS, via nvm |
| **Python 3.12** | via `uv`; `~/.venv` virtualenv with Jupyter and the `devpod` kernel |
| **Git** | latest stable |
| **GitHub CLI** | `gh` |
| **Claude Code** | `claude` -- Anthropic official installer |
| **Codex CLI** | `codex` -- OpenAI official standalone installer |
| **tmux** | terminal multiplexer |
| **ripgrep** | `rg` -- fast grep |
| **vim** | with personal `.vimrc` |
| **emacs** | |
| **LaTeX** *(optional)* | `texlive-latex-extra` + `latexmk` -- only if `ENABLE_LATEX=true` |
| **Docker** *(optional)* | `docker.io` CLI and daemon -- only if `ENABLE_DOCKER_IN_DOCKER=true` |
| **Chrome** *(optional)* | for browser GUI via noVNC -- only if `ENABLE_GUI=true` |
| **Xvfb / x11vnc / noVNC / Fluxbox** *(optional)* | virtual display + browser access -- only if `ENABLE_GUI=true` |

**VS Code extensions:** Python, Ruff, Jupyter, Claude Code, Codex

## Chrome GUI (noVNC) -- optional

Off by default -- see [Enabling the GUI stack](#enabling-the-gui-stack) above.
Once enabled, the container starts a virtual display (`:99`) with Fluxbox and
exposes it via noVNC on `NOVNC_PORT` (`6080` unless you changed it). Useful
for logging into web interfaces or running Chrome-based sessions inside the
container.

1. DevPod forwards the configured port automatically.
2. Open in a browser (substitute your `NOVNC_PORT` if not the default):
   ```
   http://localhost:6080/vnc.html?autoconnect=true&resize=remote
   ```

If you run multiple GUI-enabled devpods at once, give each project a distinct
`NOVNC_PORT` (and matching `forwardPorts` entry) -- devpod forwards the exact
port number, so two workspaces both on `6080` will collide.

## File structure

```
.devcontainer/
├── Dockerfile          # Image definition -- all installs live here
├── devcontainer.json   # DevPod/VS Code config, extensions, mounts
├── start-display.sh    # postCreateCommand -- starts Xvfb/VNC/noVNC/Fluxbox (no-ops if disabled)
├── .vimrc              # Copied into the image at build time (Layer 11)
├── .bash_aliases       # Copied into the image at build time (Layer 11)
└── README.md           # This file
```
