# Docker Compose Build Buildkite Plugin

A [Buildkite plugin](https://buildkite.com/docs/plugins) that builds — and optionally pushes — a Docker Compose service with `docker buildx bake`.

Each build gets its own buildx builder, and the builder is deliberately left behind so later steps on the same agent reuse its layer cache.

## Requirements

- The `docker` CLI with Buildx (`docker buildx`) available to the Buildkite agent. Compose files are read by `bake` directly, so the Compose CLI plugin is not required.
- The `buildkite-agent` CLI on `PATH`, used to upload the generated compose override as an artifact.

## Usage

Build a service and load the image into the agent's Docker daemon:

```yaml
steps:
  - plugins:
      - jameslnewell/docker-compose-build#v0.3.1:
          service: web
```

Tag the image to push it to a registry instead:

```yaml
steps:
  - plugins:
      - jameslnewell/docker-compose-build#v0.3.1:
          service: web
          file: docker-compose.yml
          tags:
            - myregistry.io/myapp:latest
            - myregistry.io/myapp:${BUILDKITE_COMMIT}
          platforms:
            - linux/amd64
            - linux/arm64
          cache_from:
            - type=registry,ref=myregistry.io/myapp:cache
          cache_to:
            - type=registry,ref=myregistry.io/myapp:cache,mode=max
```

Pass build args and labels:

```yaml
steps:
  - plugins:
      - jameslnewell/docker-compose-build#v0.3.1:
          service: api
          args:
            - NODE_ENV=production
            - VCS_REF=${BUILDKITE_COMMIT}
          labels:
            - org.opencontainers.image.revision=${BUILDKITE_COMMIT}
            - org.opencontainers.image.source=https://github.com/example/repo
```

Pass a bake flag the plugin doesn't model as a first-class option — each array item is one argv token:

```yaml
steps:
  - plugins:
      - jameslnewell/docker-compose-build#v0.3.1:
          service: web
          cli_args:
            - --provenance
            - "false"
```

## Configuration

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `service` | string | — | **Required.** Compose service to build. Also the bake target. |
| `file` | string or array | bake's own file discovery (`compose.yaml`, `docker-compose.yml`, `docker-bake.hcl`, …) | Compose file(s), passed through as `--file`. Later files override earlier ones. Bake runs from the first file's directory, so relative build contexts resolve against it. |
| `args` | array | — | Build args as `KEY=VALUE`, set as the service's `build.args`. |
| `labels` | array | — | Image labels as `KEY=VALUE`, set as the service's `build.labels`. |
| `tags` | array | — | Image tags, set as the service's `build.tags`. Providing any tag switches the build from `--load` to `--push`. |
| `platforms` | array | — | Target platforms (e.g. `linux/amd64`), set as the service's `build.platforms`. |
| `cache_from` | array | — | Cache sources (e.g. `type=registry,ref=…`), set as the service's `build.cache_from`. |
| `cache_to` | array | — | Cache destinations (e.g. `type=registry,ref=…,mode=max`), set as the service's `build.cache_to`. |
| `cli_args` | array | — | Extra flags passed straight through to `docker buildx bake` (e.g. `["--provenance", "false"]`). Each array item is one argv token. |

`additionalProperties` is disabled, so an unrecognised or misspelled option fails validation rather than being silently ignored.

Every array option **replaces** the equivalent field in your compose file rather than appending to it — the values you give here are the final list used for the build.

This plugin only builds; it does not run the step's command. A step that sets both prints a warning and the command is ignored — run it in a separate step, or use [docker-compose-run](https://github.com/jameslnewell/docker-compose-run-buildkite-plugin).

## How it works

1. **Configure** — creates a buildx builder named `docker-compose-build-buildkite-plugin-<job id>` and selects it, renders `args`/`labels`/`cache_from`/`cache_to`/`platforms`/`tags` into a compose override file, and uploads that override as the Buildkite artifact `docker-compose-build-buildkite-plugin.yml`.
2. **Build** — runs `docker buildx bake` against your compose file(s) plus the generated override, with `--push` when `tags` are set and `--load` otherwise.

Each phase is its own log group, so you can fold and expand them independently and see exactly where time is spent.

The builder is **not** removed after the build, so successive steps on the same agent reuse its layer cache. The agent's own prune operations eventually clean up old builders.

The override is uploaded before the build starts, so a failed build still leaves it in the build's artifacts — download `docker-compose-build-buildkite-plugin.yml` to see exactly which tags, cache refs, labels, platforms and args were used for that run.

## Other plugins that may be useful

- [docker-run](https://github.com/jameslnewell/docker-run-buildkite-plugin) — Run a command in a Docker image with phase-level timing and automatic cleanup
- [docker-compose-run](https://github.com/jameslnewell/docker-compose-run-buildkite-plugin) — Run a docker compose service with phase-level timing and automatic cleanup

## Contributing

See [DEVELOPMENT.md](./DEVELOPMENT.md) for how to run the tests and cut a release.
