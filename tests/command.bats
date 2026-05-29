#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/../lib/shared.bash"

setup() {
  export PLUGIN_DIR="${BATS_TEST_DIRNAME}/.."
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

@test "plugin_read_list with empty result" {
  unset MY_VAR
  unset MY_VAR_0
  mapfile -t result < <(plugin_read_list "MY_VAR")
  [[ "${#result[@]}" == "0" ]]
}

@test "Command fails when service is missing" {
  export BUILDKITE_JOB_ID="test-job-id"
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE

  run bash "${PLUGIN_DIR}/hooks/command"

  [ $status -eq 1 ]
  [[ "$output" =~ "service" ]]
}

@test "Command fails when docker is unavailable" {
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  export PATH="/usr/bin:/bin"

  if command -v docker &>/dev/null; then
    skip "Docker is available, cannot test failure case"
  fi

  run bash "${PLUGIN_DIR}/hooks/command"

  [ $status -ne 0 ]
}
