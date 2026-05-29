#!/usr/bin/env bats

setup() {
  export PLUGIN_COMMAND="${BATS_TEST_DIRNAME}/../hooks/command"
  export PLUGIN_DIR="${BATS_TEST_DIRNAME}/.."
}

@test "Minimal config with service only" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "Single file specified" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="docker-compose.yml"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "Array of files specified" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE_0="compose.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE_1="compose.override.yml"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "Tags option enables push" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0="myapp:latest"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_1="myapp:v1.0"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "No tags uses load" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "cache_from array" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_0="type=gha"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_1="type=local,src=/tmp/cache"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "args option" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_0="VERSION=1.0"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_1="DEBUG=true"

  run bash "$PLUGIN_COMMAND"

  assert_failure
}

@test "Missing required service option" {
  export BUILDKITE_JOB_ID="test-job-id"
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE

  run bash "$PLUGIN_COMMAND"

  assert_failure
  assert_output --partial "service"
}
