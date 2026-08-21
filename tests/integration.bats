#!/usr/bin/env bats

setup() {
  export PLUGIN_PATH="${BATS_TEST_DIRNAME}/.."
  export BUILDKITE_JOB_ID="dcb-test-$$"
  export TEST_TMPDIR="$(mktemp -d)"

  # Create a simple test docker-compose.yml
  cat > "$TEST_TMPDIR/docker-compose.yml" <<'EOF'
version: '3'
services:
  test:
    build:
      context: .
      dockerfile: Dockerfile
    image: test-image:latest
EOF

  # Create a simple test Dockerfile
  cat > "$TEST_TMPDIR/Dockerfile" <<'EOF'
FROM busybox:latest
RUN echo "Build successful"
EOF

  # hooks/command uploads the generated override as an artifact, unconditionally.
  # Outside a Buildkite agent that binary does not exist, so without a stub the hook
  # dies with "buildkite-agent: command not found" before it ever reaches bake.
  STUB_BIN="$TEST_TMPDIR/stub-bin"
  mkdir -p "$STUB_BIN"
  printf '#!/bin/sh\necho "buildkite-agent $*"\n' > "$STUB_BIN/buildkite-agent"
  chmod +x "$STUB_BIN/buildkite-agent"
  export PATH="$STUB_BIN:$PATH"

  cd "$TEST_TMPDIR"
}

teardown() {
  cd /
  rm -rf "$TEST_TMPDIR"
  docker buildx rm "docker-compose-build-buildkite-plugin-${BUILDKITE_JOB_ID}" 2>/dev/null || true
  docker rmi test-image:latest 2>/dev/null || true
}

skip_if_no_docker() {
  # `docker buildx version`, not `command -v docker-buildx`: buildx is a CLI plugin
  # installed under the Docker CLI plugins directory, not on PATH, so the old check
  # failed even on machines where buildx was present and working. These tests
  # therefore skipped everywhere — including anywhere they could actually have run.
  if ! docker buildx version > /dev/null 2>&1; then
    skip "docker buildx is not available"
  fi
}

@test "integration: builds docker image successfully" {
  skip_if_no_docker

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="test"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="$TEST_TMPDIR/docker-compose.yml"

  run bash "$PLUGIN_PATH/hooks/command"

  [[ $status -eq 0 ]]
}

@test "integration: respects build args" {
  skip_if_no_docker

  # Create docker-compose with build args
  cat > "$TEST_TMPDIR/docker-compose.yml" <<'EOF'
version: '3'
services:
  test:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        BUILD_ARG: test_value
    image: test-image:latest
EOF

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="test"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="$TEST_TMPDIR/docker-compose.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_0="BUILD_ARG=test_value"

  run bash "$PLUGIN_PATH/hooks/command"

  [[ $status -eq 0 ]]
}

@test "integration: respects image tags" {
  skip_if_no_docker

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="test"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="$TEST_TMPDIR/docker-compose.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0="test-image:custom-tag"
  # Any tag switches the build from --load to --push, so actually building here
  # would need a registry to push to — and the builder this plugin creates uses
  # the docker-container driver, which cannot reach a registry on the host
  # without networking options the plugin does not expose. `bake --print`
  # resolves the compose files, the generated override and the tag list into the
  # final build definition and prints it instead of building, which is the part
  # this test is about. It still exercises the real merge, not a stub.
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_0="--print"

  run bash "$PLUGIN_PATH/hooks/command"

  [[ $status -eq 0 ]]
  # The tag reached the resolved build definition...
  [[ "$output" == *'"test-image:custom-tag"'* ]]
  # ...and having one selected a push rather than a load.
  [[ "$output" == *'"push": "true"'* ]]
}

@test "integration: fails when service does not exist" {
  skip_if_no_docker

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="nonexistent"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="$TEST_TMPDIR/docker-compose.yml"

  run bash "$PLUGIN_PATH/hooks/command"

  [[ $status -ne 0 ]]
}
