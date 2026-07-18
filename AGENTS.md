# Pi.dev Agent Instructions (AGENTS.md)

This repository packages **pi.dev** (AI-powered CLI tool) as a Docker image with
Docker-in-Docker (DIND) support, secure non-root execution, local LLM inference,
and integrated code indexing capabilities.

## Key Files

| File             | Purpose                                                         |
|------------------|-----------------------------------------------------------------|
| `Dockerfile`     | Multi-stage build: Node.js 26, pi.dev CLI, docker-ce, llama.cpp, Python, LLM tools (~4 stages) |
| `pi.pl`          | Perl entrypoint - drops privileges (root → UID), sets env, starts dockerd if DIND=1, execs pi.dev |
| `pi.sh`          | Shell wrapper - shares host sockets (docker.sock, SSH agent, git config), sets env, launches container |
| `pi`             | Thin wrapper around `pi.sh` with `-pi` flag for direct pi.dev execution |
| `docker-bake.hcl`| Docker BuildKit bake config with local, containers targets and SBOM/attestation |
| `pi.json`        | Pi.dev agent config (model, tools, permissions, MCP servers) |
| `mcp.json`       | Model Context Protocol server configuration for CocoIndex tools |
| `pi_settings.json`| Pi agent runtime settings (theme, retry policies, thinking budgets) |
| `pi_auth.json`   | OAuth authentication configuration (empty, no providers configured) |
| `mcp/`           | CocoIndex MCP server (ccc-granular) |
| `cocoindex_plugins/` | Custom embedding providers (LiteLLM, llamacpp) |
| `skills/`        | Task-specific skill definitions (.gitkeep) |
| `themes/`        | UI theme configurations (.gitkeep) |

## Project Structure

- **Build:** Use `docker buildx bake` (defined in `docker-bake.hcl`).
  - Targets: `local`, `containers` (with provenance/SBOM)
  - Set environment variables or edit `docker-bake.hcl` for custom build outputs

## Runtime Flow

```
pi.sh (Docker run with shared volumes: docker.sock, SSH agent, git config, X11, ROCm)
  → pi.pl drops privileges (root→node), sets up env, starts dockerd if DIND=1
    → execs `/home/node/.npm-global/bin/pi` (the actual CLI tool)
```

Runtime user: `node:1000` (configurable via `$ENV{UID}`), groups: `video` (986),
`render` (983), `audio` (992). Memory limits: stack 64MB, memlock unlimited.

## Pi.dev Config (`pi.json`)

The config lives at `/home/node/pi.json` inside the image. Edit rules:

- Use `$schema: "https://pi.dev/config.json"` for validation
- Variables resolve via `{env:VAR_NAME}` style substitution at runtime
- After saving, restart pi.dev (config is loaded once at startup)

### Configuration Sections

- **provider**: LLM configuration (llama.cpp only)
- **model**: Resolved from `{env:LLAMA_MODEL}` substitution
- **permission**: edit, bash permissions
- **compaction**: auto-compaction settings, thresholds, strategies
- **mcp**: MCP server configurations (ccc-granular, cocoindex-code)

### Example Configuration

```json
{
  "$schema": "https://pi.dev/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "models": {
        "{env:LLAMA_MODEL}": {
          "constraints": {"jsonMode": true},
          "parameters": {"stop": ["␣", "‪", "‭"], "temperature": 0.1}
        }
      }
    }
  },
  "model": "llama.cpp/{env:LLAMA_MODEL}",
  "permission": {"edit": "allow", "bash": "allow"},
  "compaction": {
    "enabled": true, "auto": true, "threshold": 0.90,
    "strategy": "summarize", "preserveRecentMessages": 6
  },
  "mcp": {
    "ccc-granular": {
      "type": "local", "enabled": true,
      "command": ["python3", "/mcp/ccc/server.py"]
    }
  }
}
```

## Notable Features & Capabilities

### Docker-in-Docker (DIND)
- Automatically forks `dockerd` when `DIND=1` (default)
- Forked dockerd runs with:
  - `--host=unix:///var/run/docker.sock`
  - `-G 1000` (group-based access)
  - Custom logging to `/workspace/docker/docker-*.log`
- Proper signal handling via fork/daemonizing

### Security & Privilege Management
- Privilege dropping: root → UID 1000, RGID → 983 986 992 109
- Groups added: `video` (986), `render` (983), `audio` (992)
- Memory limits: stack 64MB, memlock unlimited
- `seccomp=unconfined` for maximum permissions when needed

### GPU Support
- NVIDIA: `/dev/kfd`, `/dev/dri` devices
- AMD ROCm: `/opt/rocm` bind-mounted
- Apple Silicon: `/dev/accel`

### Shared Host Context
- Docker socket, SSH agent, git config, Docker registry auth, buildx state
- X11 display for GUI access (`DISPLAY` env var)
- HTTP/HTTPS proxy settings
- Git authentication via environment variables

### LLM Integration
- **Local LLM inference**: llama.cpp with model auto-discovery
- **LiteLLM**: Embedding provider for search
- Configurable via `LLAMA_SERVER_URL`, `LLAMA_MODEL` env vars

### CocoIndex Features
- Semantic code indexing via `ccc` command
- MCP tools: `ccc_init_project`, `ccc_index_codebase`, `ccc_semantic_search`
- State per directory (per-workdir isolation)

### Extension Ecosystem
- **pi-llama**: Auto-discovers llama.cpp models via `/model` command
- Extensible via `~/.pi/agent/extensions/`

## Build Targets (docker-bake.hcl)

| Target | Description |
|--------|-------------|
| `local` | Build for local use with `docker run` |
| `containers` | Build and push to registry with provenance and SBOM |

## Cache Busting Mechanism

To force rebuild of specific layers during Docker image builds:

1. **Dockerfile ARG `CACHEBUST`** with default value "1"
2. Setting this variable higher in `docker-bake.hcl` triggers layer cache invalidation

## Helpful Commands

See `README.md` for build, config, and DIND documentation.

Skills provide specialized instructions and workflows for specific tasks.
Use the skill tool to load a skill when a task matches its description.

- The image installs `docker-ce`, `containerd`, and related packages so that containers
  inside can manage outer-host Docker.
- Sockets shared via bind mounts:
  - Docker: `/var/run/docker.sock`
  - Containerd: Configurable via `CONTAINERD_ADDRESS` env var
- GPU support includes:
  - NVIDIA: `/dev/kfd`, `/dev/dri` devices
  - AMD ROCm: `/opt/rocm` bind-mounted (configurable via `ROCM_PATH`)
  - Apple Silicon: `/dev/accel`

### Shared Host Context

- Docker socket, SSH agent, git config, Docker registry auth, buildx state
- X11 display for GUI access (`DISPLAY` env var)
- HTTP/HTTPS proxy settings
- Git authentication via environment variables

## Conventions

- No hardcoded secrets in config or scripts - use env vars (`LLAMA_MODEL`, `OPENAI_API_KEY`)
- Commit messages follow `<type>: <description>` with standard types: `feat:`, `fix:`,
  `refactor:`, `chore:`, `docs:`
- Dockerfile installs grouped logically within a single `apt-get` to minimize layers

## Cache Busting Mechanism

To force a rebuild of specific layers during Docker image builds (particularly useful when testing changes to apt packages or other cached steps), the project now supports:

1. A **Dockerfile ARG `CACHEBUST`** with default value "1"
2. Setting this variable higher in docker-bake.hcl triggers cache invalidation

## Helpful Commands / Docs

See `README.md` for build, config, and DIND documentation.

Skills provide specialized instructions and workflows for specific tasks.
Use the skill tool to load a skill when a task matches its description.