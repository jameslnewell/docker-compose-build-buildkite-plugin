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
| `build.tags` | `tags` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS` | Image tags to assign |

### Non-Spec Options

Options not defined in the Compose spec follow CLI conventions:

| Plugin YAML option | Environment variable | Purpose |
|-----|-----|-----|
| `service` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE` | Service to build, and the bake target |
| `file` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE` | Compose file(s), matching `docker compose -f` |
| `cli_args` | `BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS` | Escape hatch for `docker buildx bake` flags |

Array options are read with `plugin_read_list` in [`lib/shared.bash`](./lib/shared.bash), which reads the `_0`, `_1`, … indexed variables the agent exports for YAML arrays and falls back to the unindexed variable for scalars.

### Why a generated compose override instead of `--set`

The array options could be passed as `docker buildx bake --set <service>.tags+=<value>`, but the array-append `+=` syntax needs buildx 0.13 or newer. Rendering the values into a compose override file — passed as the last `--file` so it merges last — carries the full arrays portably across older buildx versions. Because compose replaces (rather than appends to) arrays from a later file, these options are documented as "the final list to use".

The override is written to a per-job directory (`$TMPDIR/docker-compose-build-buildkite-plugin-<job id>`) and uploaded from there by bare filename, so the artifact appears in the Buildkite UI as `docker-compose-build-buildkite-plugin.yml` rather than a per-job tmp path. The name also avoids `docker-compose.override.yml`, which compose would auto-load.

When `file` is set, the hook `cd`s to the first file's directory before running bake (passing every file as an absolute path), matching compose's own rule that the project directory is the first file's directory.

## Testing

Run the full suite the same way CI does — the [`buildkite/plugin-tester`](https://github.com/buildkite-plugins/buildkite-plugin-tester) image bundles bats and its helper libraries:

```bash
docker run --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```

To run [bats](https://github.com/bats-core/bats-core) directly on macOS, install the helpers first — the unit tests stub Docker and need [bats-support](https://github.com/bats-core/bats-support), [bats-assert](https://github.com/bats-core/bats-assert) and [bats-mock](https://github.com/buildkite-plugins/bats-mock):

```bash
brew tap bats-core/bats-core
brew install bash bats-core bats-core/bats-core/bats-support bats-core/bats-core/bats-assert
# bats-mock is not in Homebrew — clone it alongside the others:
git clone https://github.com/buildkite-plugins/bats-mock "$(brew --prefix)/lib/bats-mock"
```

Unit tests (no Docker required):

```bash
PATH="$(brew --prefix)/bin:$PATH" BATS_LIB_PATH="$(brew --prefix)/lib" bats tests/command.bats
```

Integration tests (requires Docker and Docker Buildx):

```bash
bats tests/integration.bats
```

## Releasing

1. Merge all changes to `main`
2. Go to **Actions → Create Release → Run workflow**
3. Enter the version (e.g. `v0.4.0`) and click **Run workflow**

The workflow will tag the commit, push the tag, and create a GitHub release with an auto-generated changelog.

## Related Documentation

- [Docker Compose Specification](https://compose-spec.io/)
- [Plugin Configuration Reference](./README.md)
