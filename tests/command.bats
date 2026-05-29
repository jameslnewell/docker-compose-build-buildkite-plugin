#!/usr/bin/env bats

setup() {
  load "$BATS_PLUGIN_PATH/load.bash"
}

@test "Minimal config with service only" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --load web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  assert_output --partial "Creating builder"
  assert_output --partial "Building web"
  unstub docker
}

@test "Single file specified" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE="docker-compose.yml"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --file * --load web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  unstub docker
}

@test "Array of files specified" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE_0="compose.yml"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_FILE_1="compose.override.yml"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --file * --file * --load web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  unstub docker
}

@test "Tags option enables push" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0="myapp:latest"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_1="myapp:v1.0"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --set * --set * --push web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  unstub docker
}

@test "No tags uses load" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --load web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  assert_output --partial "--load"
  unstub docker
}

@test "cache_from array" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_0="type=gha"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_1="type=local,src=/tmp/cache"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --set * --set * --load web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  unstub docker
}

@test "args option" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_0="VERSION=1.0"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_1="DEBUG=true"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : echo 'builder created'" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --set * --set * --load web : echo 'build complete'"

  run "$PLUGIN_COMMAND"

  assert_success
  unstub docker
}

@test "Missing required service option" {
  export BUILDKITE_JOB_ID="test-job-id"
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE

  run "$PLUGIN_COMMAND"

  assert_failure
  assert_output --partial "service"
}
