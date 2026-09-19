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
| 7 | Personal apt packages: tmux, vim, emacs, ripgrep, ... | Occasional -- **add new tools here** |
| 8 | GUI stack: Xvfb/x11vnc/noVNC/Chrome -- **optional, off by default** | Rare -- only if enabled |
| 9 | Shell config, `.vimrc`, `.bash_aliases` | Frequent |

**Key design decisions:**
Layer 1 is infrastructure that almost never changes (build tools). Node and
npm config are merged (Layer 2) since they're always updated together; same
for uv and Python (Layer 3). The venv is its own layer (Layer 4) so adding
Python packages doesn't re-download Python itself. Personal apt tools
(Layer 7) sit just before the GUI/shell layers so adding `htop` or `jq` leaves
everything above cached. Both apt layers use BuildKit cache mounts so `.deb`
files are never re-downloaded from the internet, even on a layer rebuild.

The GUI stack (Layer 8) is gated behind the `ENABLE_GUI` build arg and skipped
entirely by default -- most projects never drive an in-container browser, and
skipping it means no Chrome download and a noticeably smaller, faster image.
It sits last among the rarely-changing layers so toggling it never invalidates
Node, Python, Claude, Codex, or your personal apt tools. See
[Chrome GUI (noVNC)](#chrome-gui-novnc-optional) below to enable it.

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

Edit **Layer 7** in `Dockerfile`:

```dockerfile
# ── Layer 7: Personal apt packages ──
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

Then rebuild. Only Layer 7 and below rebuild -- Node, Python, Claude, and Codex
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
| `.vimrc` / `.bash_aliases` / shell config | 9 | ~15 sec |
| `ENABLE_GUI` flipped on for the first time | 8-9 | ~2-3 min (Chrome download) |
| Personal apt package added (tmux, htop, ...) | 7-9 | ~1 min |
| Claude Code updated | 5-9 | ~1-2 min |
| Codex CLI updated | 6-9 | ~1-2 min |
| Python venv packages changed | 4-9 | ~2 min |
| uv / Python 3.12 version changed | 3-9 | ~3 min |
| Node / nvm version changed | 2-9 | ~3-4 min |
| System apt package added (rare) | 1-9 (full rebuild) | ~5-10 min |

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
├── .vimrc              # Copied into the image at build time (Layer 9)
├── .bash_aliases       # Copied into the image at build time (Layer 9)
└── README.md           # This file
```
