#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/../lib/shared.bash"

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-mock/stub.bash"

  export PLUGIN_PATH="${BATS_TEST_DIRNAME}/.."
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
}

teardown() {
  unstub docker 2>/dev/null || true
}

@test "script has valid bash syntax" {
  bash -n "$PLUGIN_PATH/hooks/command"
}

@test "plugin_read_list with scalar value" {
  export MY_VAR="single-value"
  mapfile -t result < <(plugin_read_list "MY_VAR")
  [[ "${result[0]}" == "single-value" ]]
}

@test "plugin_read_list with indexed array" {
  export MY_VAR_0="first"
  export MY_VAR_1="second"
  export MY_VAR_2="third"
  result=$(plugin_read_list "MY_VAR")
  [[ "$result" == $'first\nsecond\nthird' ]]
}

@test "plugin_read_list with indexed array reads all items under set -e" {
  # Regression: (( i++ )) returns exit code 1 when i=0, which set -e in a
  # process substitution subshell would turn into an early exit, silently
  # dropping all items after index 0.
  export MY_VAR_0="first"
  export MY_VAR_1="second"
  export MY_VAR_2="third"
  mapfile -t result < <(set -e; plugin_read_list "MY_VAR")
  [[ "${#result[@]}" -eq 3 ]]
  [[ "${result[0]}" == "first" ]]
  [[ "${result[1]}" == "second" ]]
  [[ "${result[2]}" == "third" ]]
}

@test "plugin_read_list with empty result" {
  unset MY_VAR
  unset MY_VAR_0
  mapfile -t result < <(plugin_read_list "MY_VAR")
  [[ "${#result[@]}" == "0" ]]
}

@test "Command fails when service is missing" {
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE

  run bash "$PLUGIN_PATH/hooks/command"

  [ $status -eq 1 ]
  [[ "$output" =~ "service" ]]
}

@test "Command fails when docker is unavailable" {
  export PATH="/usr/bin:/bin"

  if command -v docker &>/dev/null; then
    skip "Docker is available, cannot test failure case"
  fi

  run bash "$PLUGIN_PATH/hooks/command"

  [ $status -ne 0 ]
}

@test "Warns when step has a command" {
  export BUILDKITE_COMMAND="make build"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  assert_output --partial "Warning:"
  unset BUILDKITE_COMMAND
}

@test "No warning when step has no command" {
  unset BUILDKITE_COMMAND

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  refute_output --partial "Warning:"
}
