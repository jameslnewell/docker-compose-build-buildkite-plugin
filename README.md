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
