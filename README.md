# Docker Compose Build Buildkite Plugin

Build and push a docker compose service using `docker buildx bake`, with an isolated buildx builder per job and no post-build cleanup to preserve layer cache for successive steps.

## Requirements

- Docker 25.0+
- Docker Buildx 0.15+
- Docker Compose 2.9+

## Configuration

| Option | Type | Required | Description |
|--------|------|----------|-------------|
| `file` | string or array | — | Docker compose file(s) |
| `service` | string | ✓ | Service to build |
| `args` | array | — | Build args as `KEY=VALUE` |
| `cache_from` | array | — | Cache sources |
| `cache_to` | array | — | Cache destinations |
| `labels` | array | — | Image labels as `KEY=VALUE` |
| `tags` | array | — | Image tags |
| `platforms` | array | — | Target platforms |

## Usage

```yaml
steps:
  - command: "echo Building"
    plugins:
      - jameslnewell/docker-compose-build#v1.0.0:
          service: web
          file: docker-compose.yml
          tags:
            - myapp:latest
            - myapp:${BUILDKITE_COMMIT:0:7}
          platforms:
            - linux/amd64
            - linux/arm64
          cache_from:
            - type=gha
          cache_to:
            - type=gha,mode=max
```

## Notes

- An isolated buildx builder is created per Buildkite job and is not cleaned up after the step. This preserves layer cache for successive steps on the same agent. The agent's prune operations will eventually clean up old builders.
- If `tags` are provided, `--push` is used; otherwise `--load` is used.

## How It Works

The plugin:

1. **Create Builder**: Creates an isolated buildx builder for this job (`docker buildx create`)
2. **Build**: Runs `docker buildx bake` with the specified configuration and service
3. **Cache Preservation**: The builder is not cleaned up, preserving layer cache for successive builds on the same agent

Each phase is a separate log group in Buildkite, so you can see exactly where time is spent.

## Other plugins that may be useful

- [docker-run](https://github.com/jameslnewell/docker-run-buildkite-plugin) — Run a command in a Docker image with phase-level timing and automatic cleanup
- [docker-compose-run](https://github.com/jameslnewell/docker-compose-run-buildkite-plugin) — Run a docker compose service with phase-level timing and automatic cleanup
