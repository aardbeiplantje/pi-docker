# opencode

AI-powered CLI tool packaged as a Docker image with Docker-in-Docker support for managing containers from within code sessions.

## Quick Start

```bash
docker run --rm -it \
  --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/your-org/opencode:latest
```

Or with Compose (recommended):

```yaml
services:
  opencode:
    image: "${COMPOSE_PROJECT_NAME:-dev}-opencode"
    build: .
    environment:
      - DOCKER_HOST=unix:///var/run/docker.sock
    extra_hosts:
      - "host.docker.internal:host-gateway"
    ports: [3254]
```

Run with `make run`.

## Configuration

Create a `.env` file (or source env vars before running):

| Variable               | Default          | Description                        |
|------------------------|------------------|------------------------------------|
| OPENAI_API_KEY         | —                | LLM provider key                   |
| DIND                   | 1                | Set to `0` to disable Docker-in-Docker |
| LLAMA_MODEL            | qwen2.5-coder-7b  | If using llama.cpp                 |

Environment variables are defined in `.env` or the compose file and sourced by `make`.

## Features

- **Docker-in-Docker** — Start a local dockerd with `DIND=1` (default) to manage containers from within your session
- **GPU support** — NVIDIA CUDA runtime (`DIND=0`) and AMD ROCm (`DIND=0`) builds included
- **Privilege dropping** — Automatic root → non-root user switching before running the agent

## Build

```bash
# Image for current platform with DOCKER_HOST configuration
make image IMAGE_TAG=edge DEV_REGISTRY=localhost:5555

# Multi-platform push to a registry using Docker bake (HCL)
IMAGE_TAG=1.0 make all-push REGISTRY=ghcr.io NAMESPACE=my-org IMAGE_NAME=opencode
```

## License

Apache-2.0 — see LICENSE.
