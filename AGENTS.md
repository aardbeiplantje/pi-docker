# Agent Instructions (AGENTS.md)

This repository packages **opencode** (AI-powered CLI tool) as a Docker image with
Docker-in-Docker support, non-root execution, and configurable agent settings.

## Key Files

| File             | Purpose                                                         |
|------------------|-----------------------------------------------------------------|
| `Dockerfile`     | Multi-stage build: installs deps, opencode-ai, docker-ce stack  |
| `opencode.pl`    | Perl entry point - drops privileges (root → UID), sets up env   |
| `docker-bake.hcl`| Docker BuildKit bake config for publishing images to a registry |
| `config.json`    | Opencode agent config (model, tools, permissions, MCP servers)  |

## Project Structure

- **Build:** Use `docker buildx bake` (defined in `docker-bake.hcl`). Pushes to
  `${DOCKER_REGISTRY}/${DOCKER_REPOSITORY}/${DOCKER_IMAGE_NAME}:${DOCKER_TAG}`.
- **Entry point:** Containers run via `/usr/bin/perl /opencode.pl <args>`. The
  Perl script drops privileges, creates symlinks, and execs the opencode CLI.
- **Runtime user:** Starts as `node:1000`, entrypoint may switch to a configured
  UID if the `UID` environment variable is set.

## Opencode Config (`config.json`)

The config file lives at `/home/node/config.json` inside the image. When editing:

- Use `$schema: "https://opencode.ai/config.json"` for validation.
- Unknown fields are rejected - validate against the schema before committing.
- After saving, tell the user to restart opencode (config is loaded once at startup).

## Docker / In-Docker

- The image installs `docker-ce`, `containerd`, and related packages so that containers inside can manage outer-host Docker.
- Sockets are shared via bind mounts (`/var/run/docker.sock`).
- GPU support includes both NVIDIA (`nvidia/driver`) and AMD ROCm (`rocm-dev`).

## Conventions

- No hardcoded secrets in config or scripts - use env vars (`LLAMA_MODEL`, `OPENAI_API_KEY`, etc.).
- Commit messages follow the conventional format: `<type>: <description>` (e.g., `feat:`, `fix:`, `refactor:`, `chore:`).
- Dockerfile installs should be grouped logically with a single apt-get to minimize layers.
