# devpod-template

A portable DevPod devcontainer template. Everything lives under
[`.devcontainer/`](.devcontainer) so the whole setup can be copied into any
project as a single folder.

See [`.devcontainer/README.md`](.devcontainer/README.md) for full details:
layer structure, adding packages/mounts, and what's installed.

## Quick start

Copy `.devcontainer/` into a project, then:

```bash
devpod up . --ide vscode
```
