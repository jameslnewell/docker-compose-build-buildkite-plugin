# Development Guide

## Configuration Naming Conventions

This plugin aligns its configuration option names with the [Docker Compose Specification](https://compose-spec.io/) to provide a familiar API for users who work with `docker-compose.yml` files.

### Naming Alignment with Compose Spec (Build Section)

| Docker Compose field | Plugin YAML option | Environment variable | Purpose |
|-----|-----|-----|-----|
| `build.args` | `args` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS` | Build arguments |
| `build.labels` | `labels` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS` | Build metadata labels |
| `build.cache_from` | `cache_from` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM` | Cache sources for build |
| `build.cache_to` | `cache_to` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_TO` | Cache destinations for build |
| `build.platforms` | `platforms` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_PLATFORMS` | Target platforms for multi-arch builds |

### CLI Argument Options

Options not defined in the Compose spec follow CLI conventions:
- `file` - path to compose file(s) (matches `docker compose -f` flag)
- `tags` - image tags to assign (used with `docker buildx bake --push`)

### Example Configuration

```yaml
steps:
  - name: Build and push image
    plugins:
      - docker-compose-build#v2.0.0:
          file: docker-compose.yml
          service: app
          args:
            - BUILD_DATE=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
            - VCS_REF=$(git rev-parse --short HEAD)
          labels:
            - org.opencontainers.image.source=https://github.com/example/repo
          platforms:
            - linux/amd64
            - linux/arm64
          tags:
            - myregistry.azurecr.io/myimage:latest
            - myregistry.azurecr.io/myimage:${BUILDKITE_BUILD_NUMBER}
          cache_from:
            - type=gha
          cache_to:
            - type=gha,mode=max
```

## Related Documentation

- [Docker Compose Specification](https://compose-spec.io/)
- [Plugin Configuration Reference](./README.md)
