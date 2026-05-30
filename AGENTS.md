# Agent Instructions (AGENTS.md)

This repository packages **opencode** (AI-powered CLI tool) as a Docker image with
Docker-in-Docker support, non-root execution, and configurable agent settings.

## Key Files

| File             | Purpose                                                         |
|------------------|-----------------------------------------------------------------|
| `Dockerfile`     | Multi-stage build: installs Node.js 20, opencode-ai CLI, docker-ce stack (~5 stages) |
| `opencode.pl`    | Perl entry point - drops privileges (root → UID), sets up env   |
| `opencode.sh`    | DIND wrapper - starts dockerd if needed, shares host sockets    |
| `docker-bake.hcl`| Docker BuildKit bake config for publishing images to a registry |
| `config.json`    | Opencode agent config (model, tools, permissions, MCP servers)  |

## Project Structure

- **Build:** Use `docker buildx bake` (defined in `docker-bake.hcl`). Pushes to
  `${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}`.
  Set defaults via `make` variables or edit `.gitlab-ci.yml`. Multi-platform support for
  AMD (`--platform linux/amd64`) and NVIDIA (`nvidia/driver:rocm-dev`).

## Runtime Flow

```
opencode.sh (DIND check, starts dockerd if DIND=1)
  → opencode.pl drops privileges (root→node), sets up env vars
    → execs `/usr/local/bin/opencode` (the actual CLI tool)
```

Runtime user: `node:1000`, but entrypoint may switch to configured UID via the `UID`
environment variable.

## Opencode Config (`config.json`)

The config lives at `/home/node/config.json` inside the image. Edit rules:

- Use `$schema: "https://opencode.ai/config.json"` for validation
- Unknown fields are rejected - validate before committing (use `.opencode/schema/validate-config.js`)
- Variables resolve via `{env:LLAMA_MODEL}` style substitution at runtime
- After saving, tell the user to restart opencode (config is loaded once at startup)

## Docker / In-Docker

- The image installs `docker-ce`, `containerd`, and related packages so that containers
  inside can manage outer-host Docker.
- Sockets are shared via bind mounts (`/var/run/docker.sock`). Inner socket can be mounted
  to `/var/run/docker-inner.sock`.
- GPU support includes both NVIDIA (`nvidia/driver`) and AMD ROCm (`rocm-dev`).

## Conventions

- No hardcoded secrets in config or scripts - use env vars (`LLAMA_MODEL`, `OPENAI_API_KEY`)
- Commit messages follow `<type>: <description>` with standard types: `feat:`, `fix:`,
  `refactor:`, `chore:`, `docs:`
- Dockerfile installs grouped logically within a single `apt-get` to minimize layers

## Helpful Commands / Docs

See `README.md` for build, config, and DIND documentation.
