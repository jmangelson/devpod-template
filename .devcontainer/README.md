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
| 5 | Miniforge (conda) | Rare -- for tools/environments that specifically need conda |
| 6 | Claude Code | Occasional |
| 7 | Codex CLI | Occasional -- separate from Claude, independent cadence |
| 8 | LaTeX toolchain (`texlive-latex-extra`, `latexmk`) -- **optional, off by default** | Rare -- only if enabled |
| 9 | GUI stack: Xvfb/x11vnc/noVNC/Chrome -- **optional, off by default** | Rare -- only if enabled |
| 10 | Docker-in-Docker -- **optional, off by default** | Rare -- only if enabled |
| 11 | Android toolchain: JDK, Android SDK/adb, optional emulator, Maestro -- **optional, off by default** | Rare -- only if enabled |
| 12 | WeasyPrint HTML->PDF + Pango + fonts (incl. Times New Roman) -- **optional, on by default** | Rare |
| 13 | Personal apt packages: tmux, vim, emacs, ripgrep, ... | Occasional -- **add new tools here** |
| 14 | Shell config, `.vimrc`, `.bash_aliases` | Frequent |

**Key design decisions:**
Layer 1 is infrastructure that almost never changes (build tools). Node and
npm config are merged (Layer 2) since they're always updated together; same
for uv and Python (Layer 3). The venv is its own layer (Layer 4) so adding
Python packages doesn't re-download Python itself. Conda (Layer 5) is a
separate, optional interpreter stack via Miniforge -- `uv`/`~/.venv` remains
the default for everyday Python work and is what VS Code's
`python.defaultInterpreterPath` points at; conda's base environment is not
auto-activated, so it only comes into play when you explicitly `conda
activate`. The optional LaTeX, GUI, Docker-in-Docker, Android, and WeasyPrint
layers (Layers 8-12) sit after Claude/Codex and before the personal apt and shell
layers. Adding `htop` or `jq` rebuilds Layers 13-14 but leaves everything above
cached. All apt-install layers use BuildKit cache mounts so `.deb` files are
never re-downloaded from the internet, even on a layer rebuild.

The LaTeX toolchain (Layer 8) is gated behind the `ENABLE_LATEX` build arg and
skipped entirely by default. The GUI stack (Layer 9) is gated behind the
`ENABLE_GUI` build arg, Docker-in-Docker (Layer 10) is gated behind
`ENABLE_DOCKER_IN_DOCKER`, Android (Layer 11) is gated behind
`ENABLE_ANDROID`; these are skipped by default. WeasyPrint (Layer 12) is
gated behind `ENABLE_WEASYPRINT` and is **on** by default. These optional layers sit after
the Node, Python, conda, and AI-tool layers, so toggling one preserves Layers
1-7 while rebuilding that layer and everything below it. See
[Enabling LaTeX](#enabling-latex), [Enabling WeasyPrint](#enabling-weasyprint), [Docker-in-Docker](#enabling-docker-in-docker),
and [Chrome GUI (noVNC)](#chrome-gui-novnc-optional) below to enable them.
The Android emulator and system image are an additional opt-in controlled by
`ENABLE_ANDROID_EMULATOR`; see [Android development (optional)](#android-development-optional).

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

Edit **Layer 13** in `Dockerfile`:

```dockerfile
# ── Layer 13: Personal apt packages ──
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

Then rebuild. Only Layer 13 and below rebuild -- Node, Python, conda, Claude, and Codex
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

## Enabling WeasyPrint

WeasyPrint (HTML/CSS -> PDF) is **on by default**. To disable it for a project:

1. In `devcontainer.json`, change `"ENABLE_WEASYPRINT": "true"` to `"ENABLE_WEASYPRINT": "false"` in `build.args`.
2. Rebuild:
   ```bash
   devpod up . --recreate --ide vscode
   ```

This installs WeasyPrint's native dependencies (Pango, HarfBuzz subsetting,
fontconfig), Microsoft core fonts (Times New Roman, Arial, ... -- the EULA is
accepted non-interactively), Liberation and DejaVu fonts, and the `weasyprint`
Python package in `~/.venv`. The CLI is symlinked into `~/.local/bin`:

```bash
weasyprint letter.html letter.pdf
fc-list | grep -i "times new roman"   # confirm the font is available
```

Or from Python (`~/.venv`): `from weasyprint import HTML; HTML("letter.html").write_pdf("letter.pdf")`.

## Android development (optional)

The Android layer is intended for an Expo/React Native Android project. It
installs JDK 17 (`JAVA_HOME`, for Gradle) plus a Java 21 runtime (default
`java`, for Firebase emulators), Android SDK command-line tools, `adb`, one
Android compile platform, Android build tools, and Maestro. It does **not**
install React or Expo globally; those belong in the application project and
are created with `npx create-expo-app@latest`.

It also runs `android init` once while building the image. That installs the
Android CLI agent skill for the detected Claude and Codex installations, so the
agent can use the Android-specific workflows without repeating setup at every
container start. The SDK packages are installed with `android sdk install`; the
deprecated `sdkmanager` command is not used.

Enable the Android build toolchain by changing this build arg in
`devcontainer.json`:

```json
"ENABLE_ANDROID": "true"
```

For an autonomous Android emulator that Claude can drive from the container,
also enable the emulator and system image:

```json
"ENABLE_ANDROID_EMULATOR": "true"
```

The `ANDROID_KVM_GID` build arg and matching `--group-add` run arg must match
the host's `/dev/kvm` group ID. This workspace uses `993`; check another host
with `stat -c %g /dev/kvm` and update both values if needed.

An in-container emulator needs host KVM access, not Docker-in-Docker. Uncomment
the Android `runArgs` near `remoteUser`:

```json
"runArgs": ["--device=/dev/kvm", "--group-add=993", "--shm-size=2g"]
```

If Docker-in-Docker is also enabled, combine the arguments into one `runArgs`
entry rather than defining `runArgs` twice:

```json
"runArgs": ["--privileged", "--device=/dev/kvm", "--group-add=993", "--shm-size=2g"]
```

Docker-in-Docker is only needed if the app's development workflow also runs a
containerized backend, database, or integration-test service. It is not needed
to build or test an Android app.

Rebuild after changing the build args:

```bash
devpod up . --recreate --ide vscode
```

DevPod can remap the remote user's UID to match the host user when it creates
the container, which can leave `/opt/android-sdk` owned by the image's
build-time UID. Gradle then fails with "The SDK directory is not writable"
when a project needs an SDK package that is not preinstalled, such as the NDK
or CMake. `postCreateCommand` runs `fix-android-sdk-owner.sh` to re-own the
SDK for the remote user. To apply it to an existing container without
recreating it:

```bash
bash .devcontainer/fix-android-sdk-owner.sh
```

If the image was already built before the Android skill was added, initialize
the current container once with:

```bash
android init
```

Create and start an emulator inside the container:

```bash
bash .devcontainer/start-emulator.sh
```

The script creates `devpod-api35` if needed, gives it 4 GB of RAM, cold-boots
it, and waits for Android to finish booting. It skips an emulator that is
already running. Set `EMULATOR_COUNT=2` to start `devpod-api35` and
`devpod-api35-2` for parallel device testing; two emulators require roughly
8 GB of available host memory before accounting for Gradle and the container.
`EMULATOR_RAM_MB` overrides the per-emulator memory. Emulator logs are written
to `/tmp/devpod-emulator.log` and the AVDs live under `~/.android/avd/`, not in
the image.

The existing GUI/noVNC layer is not required for a headless emulator. Enable
it only if you want to watch the emulator visually; automated tests can use
`adb`, Maestro, logs, and screenshots without noVNC.

### Proposed Claude development pipeline

The intended loop is:

1. Claude receives a feature request and edits the Expo/React Native project.
2. Claude runs linting, TypeScript checks, and unit tests.
3. Claude starts Metro with `npx expo start`.
4. Claude builds the native app with `npx expo run:android` when the native
   project or native dependencies change. For JavaScript/TypeScript-only
   changes, Metro/Fast Refresh avoids a full native rebuild.
5. Claude runs Maestro flows in `.maestro/` to launch the app, tap controls,
   enter data, assert visible text, and capture screenshots.
6. Claude reads the test output and iterates until the checks pass.
7. A human reviews the feature on a real Android phone before release.

Typical commands after the first native build are:

```bash
npx expo start
maestro test --test-output-dir=build/maestro-results .maestro
```

For a production release, use EAS Build to create an Android App Bundle for
Google Play or an APK for direct installation. Keep signing credentials and
service tokens outside the repository.

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
| `.vimrc` / `.bash_aliases` / shell config | 14 | ~15 sec |
| `ENABLE_LATEX` flipped on for the first time | 8-14 | several minutes |
| `ENABLE_GUI` flipped on for the first time | 9-14 | ~2-3 min (Chrome download) |
| `ENABLE_DOCKER_IN_DOCKER` flipped on for the first time | 10-14 | several minutes |
| `ENABLE_ANDROID` flipped on for the first time | 11-14 | several minutes (SDK download) |
| `ENABLE_ANDROID_EMULATOR` flipped on for the first time | 11-14 | longer (emulator image download) |
| `ENABLE_WEASYPRINT` flipped on (default) for the first time | 12-14 | ~1-2 min (font download) |
| Personal apt package added (tmux, htop, ...) | 13-14 | ~1 min |
| Claude Code updated | 6-14 | ~1-2 min |
| Codex CLI updated | 7-14 | ~1-2 min |
| Miniforge/conda changed | 5-14 | ~1 min |
| Python venv packages changed | 4-14 | ~2 min |
| uv / Python 3.12 version changed | 3-14 | ~3 min |
| Node / nvm version changed | 2-14 | ~3-4 min |
| System apt package added (rare) | 1-14 (full rebuild) | ~5-10 min |

## What's installed

| Tool | Details |
|---|---|
| **Node.js** | LTS, via nvm |
| **Python 3.12** | via `uv`; `~/.venv` virtualenv with Jupyter and the `devpod` kernel |
| **Miniforge (conda)** | `~/miniforge3`; base env not auto-activated -- `conda activate <env>` to use it |
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
| **JDK 17 + Java 21 runtime** *(optional)* | Android/Gradle builds and Maestro (17, `JAVA_HOME`); Firebase emulators (21, default `java`) -- only if `ENABLE_ANDROID=true` |
| **Android SDK** *(optional)* | command-line tools, platform-tools/`adb`, API platform, and build tools -- only if `ENABLE_ANDROID=true` |
| **Android Emulator** *(optional)* | headless emulator plus API 35 Google APIs image -- only if `ENABLE_ANDROID_EMULATOR=true` |
| **Maestro** *(optional)* | Android end-to-end UI tests and screenshots -- only if `ENABLE_ANDROID=true` |
| **WeasyPrint** *(optional)* | `weasyprint` HTML->PDF CLI + Python package, Pango, Times New Roman/Liberation/DejaVu fonts -- on by default (`ENABLE_WEASYPRINT=true`) |

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

**Why noVNC instead of SSH X11 forwarding:** `devpod up`/`devpod ssh` don't go
through the container's real `sshd` at all -- DevPod deploys its own embedded
SSH server that runs over the container runtime's exec tunnel, and that
embedded server has no X11 forwarding support (an
[open DevPod feature request](https://github.com/loft-sh/devpod/issues/654)
with an unmerged draft PR as of late 2025). So enabling `X11Forwarding` in the
container's `sshd_config` has no effect on a normal DevPod connection. noVNC
(this section) is the supported path to GUI apps from inside the container.

## File structure

```
.devcontainer/
├── Dockerfile          # Image definition -- all installs live here
├── devcontainer.json   # DevPod/VS Code config, extensions, mounts
├── start-display.sh    # postCreateCommand -- starts Xvfb/VNC/noVNC/Fluxbox (no-ops if disabled)
├── fix-android-sdk-owner.sh # Repairs SDK ownership after UID remapping
├── start-emulator.sh   # Creates and cold-boots one or more Android AVDs
├── .vimrc              # Copied into the image at build time (Layer 14)
├── .bash_aliases       # Copied into the image at build time (Layer 14)
└── README.md           # This file
```
