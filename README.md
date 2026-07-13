# pi.dev

AI-powered CLI tool packaged as a Docker image with Docker-in-Docker (DIND) support for managing containers from within code sessions with secure non-root execution.

## 🎯 Overview

**pi.dev** is a Docker-based development environment that provides:
- **Docker-in-Docker (DIND)** — Start a local dockerd with `DIND=1` to manage containers from within your session
- **AI-powered CLI** — Integrated pi.dev agent for code sessions with local LLM inference
- **GPU acceleration** — NVIDIA CUDA and AMD ROCm support
- **Secure execution** — Automatic privilege dropping (root → non-root user)
- **Host context sharing** — Docker socket, SSH agent, git config, X11 display

---

## 📦 Architecture

| Component | Purpose |
|----------|--------|
| **Dockerfile** | Multi-stage build (~4 stages): installs Node.js 26, pi.dev CLI, docker-ce, llama.cpp, Python |
| **pi.pl** | Perl entry point - drops privileges, sets env, starts dockerd if DIND=1, execs pi.dev |
| **pi.sh** | Shell wrapper - shares host sockets (docker.sock, SSH agent, git config), sets env, launches container |
| **pi** | Thin wrapper around `pi.sh` with `-pi` flag for direct pi.dev execution |
| **pi.json** | Pi.dev agent configuration (model, tools, permissions, MCP servers) |
| **mcp.json** | MCP server configuration for CocoIndex tools |
| **pi_settings.json** | Pi agent runtime settings (theme, retry policies, thinking budgets) |
| **pi_auth.json** | Lemonade OAuth authentication configuration |
| **pi-llama/** | pi-llama extension for auto-discovering llama.cpp models |
| **lemonade-pi-plugin/** | Lemonade LLM server extension with login flow |
| **mcp/** | CocoIndex MCP server (ccc-granular) |
| **cocoindex_plugins/** | Custom embedding providers (LiteLLM, llamacpp) |
| **skills/** | Task-specific skill definitions (.gitkeep) |
| **themes/** | UI theme configurations (.gitkeep) |

### Runtime Flow

```
pi.sh (Docker run with shared volumes: docker.sock, SSH agent, git config, X11, ROCm)
  → pi.pl drops privileges (root→node), sets up env, starts dockerd if DIND=1
    → execs `/home/node/.npm-global/bin/pi` (the actual CLI tool)
```

Runtime user: `node:1000` (configurable via `$ENV{UID}`), groups: `video` (986), `render` (983), `audio` (992). Memory limits: stack 64MB, memlock unlimited.

---

## Quick Start

### Running the Container

```bash
# Basic usage with Docker-in-Docker
bash aicli.sh

# Run pi.dev CLI specifically
bash aicli.sh -pi

# Run pi-coding-agent
bash aicli.sh -pi-coding-agent
```

---

## Configuration

Set environment variables before running `aicli.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| OPENAI_API_KEY | — | LLM provider key |
| DIND | 1 | Set to `0` to disable Docker-in-Docker |
| LLAMA_MODEL | qwen3.5:0.8b | Model name (for llama.cpp) |
| LLAMA_SERVER_URL | http://[::1]:4000/v1 | LLM server base URL |
| LLAMA_SERVER_API_KEY | — | LLM server API key |
| DOCKER_HOST | — | Docker daemon socket (set for non-DIND) |
| CONTAINERD_ADDRESS | — | Containerd socket path |
| ROCM_PATH | ~/therock-dist-linux-gfx1151-latest | AMD ROCm runtime path |
| DISPLAY | — | X11 display for GUI access |
| HTTP_PROXY / HTTPS_PROXY | — | Proxy settings |
| UID | — | Override default runtime UID (default: 1000) |

### Example: Run with GPU and custom model

```bash
export LLAMA_MODEL="qwen3.5:0.8b"
export LLAMA_SERVER_API_KEY="your-key"
export ROCM_PATH="/opt/rocm"
export DISPLAY=:0
bash aicli.sh -pi
```

### Example: Non-DIND mode (existing Docker daemon)

```bash
export DOCKER_HOST="unix:///var/run/docker.sock"
export DIND=0
bash aicli.sh -pi
```

---

## Features

### Docker-in-Docker (DIND)
- Automatically starts local `dockerd` when `DIND=1` (default)
- Forks dockerd process with proper session handling
- Mounts Docker socket inside container for container management
- Supports GPU passthrough (`--device /dev/kfd`, `/dev/dri`)

### Security & Privilege Management
- Drops privileges: root → UID 1000 (user `node`)
- Configurable UID via `$ENV{UID}` environment variable
- Groups added: video (986), render (983), audio (992)
- Memory lock and stack limits for GPU access
- Seccomp disabled for maximum permissions when needed

### GPU Support
- **NVIDIA**: `/dev/kfd`, `/dev/dri` devices
- **AMD ROCm**: `/opt/rocm` bind-mount
- **Apple Silicon**: `/dev/accel`

### Shared Host Context
- Docker socket, SSH agent, git config, Docker config
- X11 display for GUI access
- Proxy settings (HTTP/HTTPS)
- Git authentication via environment variables

### LLM Integration
- **Local LLM inference**: llama.cpp with model auto-discovery
- **Lemonade**: OAuth-based local LLM server integration
- **LiteLLM**: Embedding provider for search
- Configurable via `LLAMA_SERVER_URL`, `LLAMA_MODEL`, `LEMONADE_URL` env vars

### CocoIndex Features
- Semantic code indexing via `ccc` command
- MCP tools for codebase search, init, status, reset
- State per directory (per-workdir isolation)

### Extension Ecosystem
- **pi-llama**: Auto-discovers llama.cpp models via `/model` command
- **lemonade-pi-plugin**: Lemonade server integration with login flow
- Extensible via `~/.pi/agent/extensions/`

### Docker-in-Docker (DIND)
- Automatically starts local `dockerd` when `DIND=1` (default)
- Forks dockerd process with proper session handling
- Mounts Docker socket inside container for container management
- Supports GPU passthrough (`--device /dev/kfd`, `/dev/dri`)

### Security & Privilege Management
- Drops privileges: root → UID 1000 (user `node`)
- Configurable UID via `$ENV{UID}` environment variable
- Groups added: video (986), render (983), audio (992)
- Memory lock and stack limits for GPU access
- Seccomp disabled for maximum permissions when needed

### GPU Support
- **NVIDIA**: `/dev/kfd`, `/dev/dri` devices
- **AMD ROCm**: `/opt/rocm` bind-mount
- **Apple Silicon**: `/dev/accel`

### Shared Host Context
- Docker socket, SSH agent, git config, Docker config
- X11 display for GUI access
- Proxy settings (HTTP/HTTPS)
- Git authentication via environment variables

---

## 🏗️ Dockerfile Structure

### Multi-stage Build (3 Stages)

1. **`AS base`**: ~40+ development tools, Docker CE, Node.js 26, Python 3.13
2. **`AS runtime`**: Clean installs, symlink setup, environment configuration
3. **Final stage**: Copies configuration files, sets entrypoint

### Cache Busting Mechanism

To force rebuild of specific layers:

1. **Dockerfile ARG `CACHEBUST`** with default value "1"
2. Set this variable higher in `docker-bake.hcl` triggers cache invalidation

---

## 📐 Build System

### Local Build

```bash
# Local build for current platform
docker buildx bake -f docker-bake.hcl --no-cache

# With cache busting (e.g., after apt package changes)
docker buildx bake -f docker-bake.hcl --set "*.CACHEBUST=2"
```

### Multi-platform Push

```bash
# Push to a registry
docker buildx bake -f docker-bake.hcl release \
  --set "*.DOCKER_REGISTRY=ghcr.io" \
  --set "*.DOCKER_REPOSITORY=my-org" \
  --set "*.DOCKER_IMAGE_NAME=pi-dev" \
  --set "*.DOCKER_TAG=1.0"

# Custom image name
docker buildx bake -f docker-bake.hcl release \
  --set "*.DOCKER_IMAGE_NAME=ai-dev-tools" \
  --set "*.DOCKER_TAG=latest"
```

### Build Targets

| Target | Description |
|--------|-------------|
| `local` | Build image locally for use with `docker run` |
| `containers` | Build and push to registry (with provenance/SBOM) |

### Build Outputs

- **Provenance**: Type: `provenance`, Mode: `max`
- **SBOM**: Software Bill of Materials
- **Platform**: `linux/amd64` (customizable in docker-bake.hcl)

---

## 📐 Build System

### Build Targets (docker-bake.hcl)

| Target | Description |
|--------|-------------|
| `local` | Build for local use with `docker run` |
| `containers` | Build and push to registry with provenance and SBOM |

### Local Build

```bash
# Clean build
docker buildx bake -f docker-bake.hcl --no-cache

# With cache busting
docker buildx bake -f docker-bake.hcl --set "*.CACHEBUST=2"

# Custom cache busting (after apt changes)
docker buildx bake -f docker-bake.hcl --set "*.CACHEBUST=2"
```

### Multi-platform Push

```bash
# Push to a registry
docker buildx bake -f docker-bake.hcl release \
  --set "*.DOCKER_REGISTRY=ghcr.io" \
  --set "*.DOCKER_REPOSITORY=my-org" \
  --set "*.DOCKER_IMAGE_NAME=pi-dev" \
  --set "*.DOCKER_TAG=1.0"

# Custom image name
docker buildx bake -f docker-bake.hcl release \
  --set "*.DOCKER_IMAGE_NAME=ai-dev-tools" \
  --set "*.DOCKER_TAG=latest"
```

### Multi-Platform Build

```bash
# Build for multiple platforms
docker buildx bake -f docker-bake.hcl release \
  --set "*.DOCKER_PLATFORM=linux/amd64,linux/arm64" \
  --set "*.DOCKER_TAG=latest"
```

### Cache Busting Mechanism

To force rebuild of specific layers:

1. **Dockerfile ARG `CACHEBUST`** with default value "1"
2. Set this variable higher in `docker-bake.hcl` triggers cache invalidation

### Dockerfile Structure

Multi-stage build (~4 stages):

1. **`AS base`**: ~40+ development tools, Docker CE, Node.js 26, Python 3.13
2. **`AS runtime`**: Clean installs, symlink setup, environment configuration
3. **Final**: Copies configuration files, sets entrypoint

### Build Outputs

- **Provenance**: Type: `provenance`, Mode: `max`
- **SBOM**: Software Bill of Materials
- **Platform**: `linux/amd64` (customizable in docker-bake.hcl)

---

## 🔧 Configuration (pi.json)

The configuration file lives at `/home/node/pi.json` inside the image.

### Configuration Schema

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
  "permission": {
    "edit": "allow",
    "bash": "allow"
  },
  "compaction": {
    "enabled": true,
    "auto": true,
    "threshold": 0.90,
    "strategy": "summarize",
    "preserveRecentMessages": 6,
    "preserveSystemPrompt": true
  },
  "mcp": {
    "ccc-granular": {
      "type": "local",
      "enabled": true,
      "command": ["python3", "/mcp/ccc/server.py"]
    },
    "cocoindex-code": {
      "type": "local",
      "enabled": true,
      "command": ["ccc", "mcp"]
    }
  }
}
```

### Configuration Rules

- **Variable resolution**: Use `{env:VAR_NAME}` style substitution at runtime
- **Validation**: Uses `$schema` for pi.dev schema validation
- **Persistence**: Config is loaded once at startup; changes require restart

### Example: Full Configuration

```json
{
  "$schema": "https://pi.dev/config.json",
  "provider": {
    "llama.cpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "apiKey": "{env:LLAMA_SERVER_API_KEY}",
        "baseURL": "{env:LLAMA_SERVER_URL}"
      },
      "models": {
        "{env:LLAMA_MODEL}": {
          "name": "{env:LLAMA_MODEL}",
          "constraints": {"jsonMode": true},
          "parameters": {
            "stop": ["␣", "‪", "‭"],
            "temperature": 0.1
          }
        }
      }
    }
  },
  "model": "llama.cpp/{env:LLAMA_MODEL}",
  "permission": {
    "edit": "allow",
    "bash": "allow"
  },
  "plugin": [
    "pi-working-memory",
    "pi-plugin-openspec",
    "pi-ralph-loop",
    "pi-mem",
    "/plugins/pi-slot-cache/manifest.js"
  ],
  "compaction": {
    "enabled": true,
    "auto": true,
    "threshold": 0.90,
    "strategy": "summarize",
    "preserveRecentMessages": 6,
    "preserveSystemPrompt": true
  },
  "mcp": {
    "ccc-granular": {
      "type": "local",
      "enabled": true,
      "command": ["python3", "/mcp/ccc/server.py"]
    },
    "cocoindex-code": {
      "type": "local",
      "enabled": true,
      "command": ["ccc", "mcp"]
    }
  }
}
```

---

## 🛠️ Development Workflow

### 1. Build the Image

```bash
# Clean build
docker buildx bake -f docker-bake.hcl --no-cache

# Use cache busting
docker buildx bake -f docker-bake.hcl --set "*.CACHEBUST=2"

# Multi-platform build
docker buildx bake -f docker-bake.hcl release --set "*.DOCKER_TAG=1.0"
```

### 2. Run with Docker-in-Docker (default)

```bash
# Basic usage
bash aicli.sh

# With custom settings
export LLAMA_MODEL="qwen3.5:0.8b"
export LLAMA_SERVER_API_KEY="your-key"
bash aicli.sh -pi
```

### 3. Run Without DIND (existing Docker daemon)

```bash
export DOCKER_HOST="unix:///var/run/docker.sock"
export DIND=0
bash aicli.sh -pi
```

### 4. Run with GPU

```bash
export LLAMA_MODEL="qwen3.5:0.8b"
export ROCM_PATH="/opt/rocm"
export DISPLAY=:0
bash aicli.sh -pi
```

---

## 🔐 Security Considerations

| Aspect | Status | Notes |
|--------|--------|-------|
| Privilege dropping | ✅ | Root → UID 1000 (user `node`) |
| Docker socket mounting | ⚠️ | Requires `--privileged=true` or host socket |
| GPU passthrough | ✅ | Requires kernel permissions |
| SSH agent sharing | ⚠️ | Script warns "dangerous" |
| Environment variables | ✅ | No hardcoded secrets |
| Config validation | ✅ | Uses `$schema` for pi.dev |
| Memory limits | ✅ | Stack: 64MB, Memlock: unlimited |

### Security Best Practices

1. **Never expose host network** if not needed (`--network=host`)
2. **Use specific groups** instead of `--security-opt seccomp=unconfined`
3. **Avoid `--privileged=true`** if possible
4. **Verify Docker socket permissions** before mounting

---

## 📁 Project Structure

```
/workdir/pi.git/
├── Dockerfile           # Multi-stage build (~4 stages)
├── pi.pl            # Perl entrypoint - main logic
│   - Drop privileges (root → UID)
│   - Setup environment
│   - Start dockerd if DIND=1
│   - Execute pi.dev CLI
├── pi.sh                  # Shell wrapper
│   - Share host sockets (docker.sock, SSH agent, git config)
│   - Set environment variables
│   - Launch container
├── pi                     # Thin wrapper around pi.sh with -pi flag
├── mcp.json                   # MCP server configuration
├── pi_settings.json   # Pi agent runtime settings (theme, compaction)
├── pi_auth.json       # Lemonade OAuth authentication configuration
├── pi-llama/              # pi-llama extension (model discovery)
├── lemonade-pi-plugin/    # Lemonade server extension
├── mcp/                    # CocoIndex MCP server (ccc-granular)
│   └── ccc/server.py
├── cocoindex_plugins/      # Custom embedding providers
│   ├── register_providers.py
│   ├── sitecustomize.py
│   └── llamacpp_provider/
├── skills/                # Task-specific skills (.gitkeep)
├── themes/                # UI themes (.gitkeep)
├── docker-bake.hcl     # Build targets and configuration
├── pi.json             # Agent configuration
└── README.md          # This file
```

---

## 🎯 Use Cases

- **Code sessions** with local LLM inference using llama.cpp
- **Docker container management** from within AI-assisted workflow with DIND
- **GPU-accelerated development** (NVIDIA CUDA / AMD ROCm)
- **CI/CD integration** with provenance and SBOM generation
- **X11 development environments** with GUI support

---

## 📝 License

Unlicense (public domain) — see LICENSE.

---

## 🔗 Contributing

This is a community-maintained project. Feel free to:
- Submit bug reports
- Suggest enhancements
- Share feedback on Dockerfile optimizations
- Propose new plugins or commands

---

## 🐛 Troubleshooting

### Common Issues

#### "permission denied" errors
- Verify you have proper kernel permissions for GPU devices
- Check `--device` mounts in `aicli.sh`
- Ensure `ROCM_PATH` or `/dev/kfd` exists

#### DIND failing to start
- Check Docker host permissions
- Verify `DIND` environment variable is set to `1`
- Review dockerd logs in `/workspace/docker/*.log`

#### Config not loading
- Ensure `pi.json` uses `$schema` for validation
- Restart the container after config changes
- Check for environment variable substitution errors

---

## 📚 References

- [pi.dev Documentation](https://pi.dev/)
- [Docker-in-Docker Guide](https://docs.docker.com/engine/)
- [llama.cpp Documentation](https://github.com/ggerganov/llama.cpp)
- [Model Context Protocol](https://modelcontextprotocol.io/)

---

*Last updated: 2026-07-13*
