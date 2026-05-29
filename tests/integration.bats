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

  cd "$TEST_TMPDIR"
}

teardown() {
  cd /
  rm -rf "$TEST_TMPDIR"
  docker buildx rm "docker-compose-build-buildkite-plugin-${BUILDKITE_JOB_ID}" 2>/dev/null || true
  docker rmi test-image:latest 2>/dev/null || true
}

skip_if_no_docker() {
  if ! command -v docker &>/dev/null || ! command -v docker-buildx &>/dev/null; then
    skip "Docker or docker-buildx is not available"
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

  run bash "$PLUGIN_PATH/hooks/command"

  [[ $status -eq 0 ]]
}

@test "integration: fails when service does not exist" {
  skip_if_no_docker

  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="nonexistent"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="$TEST_TMPDIR/docker-compose.yml"

  run bash "$PLUGIN_PATH/hooks/command"

  [[ $status -ne 0 ]]
}
