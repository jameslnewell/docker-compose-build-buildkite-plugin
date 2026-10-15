#!/usr/bin/env bats

source "${BATS_TEST_DIRNAME}/../lib/shared.bash"

setup() {
  load "${BATS_LIB_PATH}/bats-support/load.bash"
  load "${BATS_LIB_PATH}/bats-assert/load.bash"
  load "${BATS_LIB_PATH}/bats-mock/stub.bash"

  export PLUGIN_PATH="${BATS_TEST_DIRNAME}/.."
  export BUILDKITE_JOB_ID="test-job-id"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_SERVICE="web"
  # Sandbox the generated compose override + uploaded artifact under the
  # test's tmpdir so paths are deterministic (matching the stubs) and so test
  # runs don't litter /tmp.
  export TMPDIR="${BATS_TEST_TMPDIR:-${TMPDIR:-/tmp}}"
  OVERRIDE_DIR="${TMPDIR}/docker-compose-build-buildkite-plugin-${BUILDKITE_JOB_ID}"
  OVERRIDE_FILE="${OVERRIDE_DIR}/docker-compose-build-buildkite-plugin.yml"
  export OVERRIDE_DIR
  export OVERRIDE_FILE
}

teardown() {
  unstub docker 2>/dev/null || true
  unstub buildkite-agent 2>/dev/null || true
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
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  assert_output --partial "Warning:"
  unset BUILDKITE_COMMAND
}

@test "No warning when step has no command" {
  unset BUILDKITE_COMMAND

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  refute_output --partial "Warning:"
}

@test "xtrace prefix never collides with Buildkite log-group markers" {
  unset BUILDKITE_COMMAND

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  # The agent sources this hook, so set -x runs deep enough that the default
  # PS4='+ ' would trace as a run of '+' (e.g. '+++ docker ...') — which
  # Buildkite parses as a log-group header. Source the hook to reproduce that
  # nesting and assert no traced docker command begins with a ---/+++/~~~ marker.
  # Legit headers ("+++ :docker: building") are fine; only flag a marker
  # immediately followed by a traced "docker" command.
  run bash -c "source \"$PLUGIN_PATH/hooks/command\" 2>&1"

  assert_success
  refute_line --regexp '^[-+~]+ docker '
  # Empty PS4 means traced commands start at column 0 with no prefix at all —
  # lock that in so we don't regress to an indented prefix.
  assert_line --regexp '^docker buildx'
}

@test "Passes cli_args through to bake" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_0="--provenance"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_1="false"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_2="--allow"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_3="fs.read=/tmp/.npmrc"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load --provenance false --allow fs.read=/tmp/.npmrc web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_1
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_2
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CLI_ARGS_3
}

@test "Writes no compose override when there is nothing to override" {
  # A service's `build:` key with nothing indented under it is YAML null, and
  # compose rejects the merged config with "invalid type <nil> for build". With
  # none of args/labels/cache_from/cache_to/platforms/tags set there is nothing
  # to put under it, so the plugin writes no override at all and passes no extra
  # --file — which also leaves a service that does not exist missing, rather than
  # one the override brings into being. Nothing to upload as an artifact either.
  unset BUILDKITE_COMMAND

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  [[ ! -e "$OVERRIDE_FILE" ]]
}

@test "Uploads the override file as a Buildkite artifact named docker-compose-build-buildkite-plugin.yml" {
  # The override carries the resolved tags/labels/cache/platforms/args; making
  # it a downloadable artifact from the build UI is the debugging payoff for
  # generating the file rather than passing every value via --set.
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0="img:t1"

  CAPTURE_FILE="${BATS_TEST_TMPDIR}/captured-upload.yml"
  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --file ${OVERRIDE_FILE} --push web : true"
  # Stub asserts the upload is invoked with the bare filename from inside the
  # override dir; copy the file so the test can confirm its content later.
  stub buildkite-agent "artifact upload docker-compose-build-buildkite-plugin.yml : cp docker-compose-build-buildkite-plugin.yml ${CAPTURE_FILE}"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  [[ -f "$CAPTURE_FILE" ]]
  run cat "$CAPTURE_FILE"
  assert_output --partial "        - 'img:t1'"
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0
}

@test "Writes args/labels/cache_from/cache_to/platforms/tags into a compose override file" {
  # Older buildx (< 0.13) doesn't grok `--set name.field+=value` array-append,
  # so the plugin builds these arrays in a compose override file passed as the
  # last --file. Verify the YAML the plugin emits is well-formed and contains
  # the full lists for each option.
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_0="FOO=1"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_1="BAR=2"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS_0="org.example.k=v"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_0="type=registry,ref=a"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_1="type=registry,ref=b"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_TO_0="type=registry,ref=a,mode=max"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_PLATFORMS_0="linux/arm64"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0="img:t1"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_1="img:t2"

  # Capture the override file before the EXIT trap nukes it.
  CAPTURE_FILE="${BATS_TEST_TMPDIR}/captured-override.yml"
  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --file ${OVERRIDE_FILE} --push web : cp ${OVERRIDE_FILE} ${CAPTURE_FILE}"
  stub buildkite-agent "artifact upload docker-compose-build-buildkite-plugin.yml : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  [[ -f "$CAPTURE_FILE" ]]
  run cat "$CAPTURE_FILE"
  assert_output --partial "services:"
  assert_output --partial "  web:"
  assert_output --partial "    build:"
  assert_output --partial "      args:"
  assert_output --partial "        - 'FOO=1'"
  assert_output --partial "        - 'BAR=2'"
  assert_output --partial "      labels:"
  assert_output --partial "        - 'org.example.k=v'"
  assert_output --partial "      cache_from:"
  assert_output --partial "        - 'type=registry,ref=a'"
  assert_output --partial "        - 'type=registry,ref=b'"
  assert_output --partial "      cache_to:"
  assert_output --partial "        - 'type=registry,ref=a,mode=max'"
  assert_output --partial "      platforms:"
  assert_output --partial "        - 'linux/arm64'"
  assert_output --partial "      tags:"
  assert_output --partial "        - 'img:t1'"
  assert_output --partial "        - 'img:t2'"

  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_ARGS_1
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_FROM_1
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_CACHE_TO_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_PLATFORMS_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_0
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_TAGS_1
}

@test "Adds Buildkite labels before user labels when buildkite_labels is true" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_BUILDKITE_LABELS="true"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS_0="com.buildkite.job_label=overridden"
  export BUILDKITE_PIPELINE_NAME="My Pipeline"
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"
  export BUILDKITE_BUILD_NUMBER="42"
  export BUILDKITE_LABEL=":docker: Build"
  export BUILDKITE_STEP_KEY="build"
  export BUILDKITE_AGENT_NAME="agent-1"
  export BUILDKITE_AGENT_ID="agent-id"

  CAPTURE_FILE="${BATS_TEST_TMPDIR}/captured-override.yml"
  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --file ${OVERRIDE_FILE} --load web : cp ${OVERRIDE_FILE} ${CAPTURE_FILE}"
  stub buildkite-agent "artifact upload docker-compose-build-buildkite-plugin.yml : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  run cat "$CAPTURE_FILE"
  # A user label must come after the Buildkite ones so it wins on a duplicate key.
  assert_output --partial "      labels:
        - 'com.buildkite.pipeline_name=My Pipeline'
        - 'com.buildkite.pipeline_slug=my-pipeline'
        - 'com.buildkite.build_number=42'
        - 'com.buildkite.job_id=test-job-id'
        - 'com.buildkite.job_label=:docker: Build'
        - 'com.buildkite.step_key=build'
        - 'com.buildkite.agent_name=agent-1'
        - 'com.buildkite.agent_id=agent-id'
        - 'com.buildkite.job_label=overridden'"

  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_BUILDKITE_LABELS
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS_0
}

@test "Adds no Buildkite labels by default" {
  export BUILDKITE_PIPELINE_SLUG="my-pipeline"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  [[ ! -e "$OVERRIDE_FILE" ]]
}

@test "Adds OCI labels before user labels when opencontainers_labels is true" {
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_OPENCONTAINERS_LABELS="true"
  export BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS_0="org.opencontainers.image.source=https://github.com/example/repo"
  export BUILDKITE_COMMIT="abc123"
  export BUILDKITE_REPO="git@github.com:example/repo.git"

  CAPTURE_FILE="${BATS_TEST_TMPDIR}/captured-override.yml"
  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --file ${OVERRIDE_FILE} --load web : cp ${OVERRIDE_FILE} ${CAPTURE_FILE}"
  stub buildkite-agent "artifact upload docker-compose-build-buildkite-plugin.yml : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  run cat "$CAPTURE_FILE"
  assert_line --index 4 --regexp "^        - 'org\.opencontainers\.image\.created=[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z'$"
  assert_line --index 5 "        - 'org.opencontainers.image.revision=abc123'"
  assert_line --index 6 "        - 'org.opencontainers.image.source=git@github.com:example/repo.git'"
  # A user label must come after the OCI ones so it wins on a duplicate key.
  assert_line --index 7 "        - 'org.opencontainers.image.source=https://github.com/example/repo'"

  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_OPENCONTAINERS_LABELS
  unset BUILDKITE_PLUGIN_DOCKER_COMPOSE_BUILD_LABELS_0
}

@test "Adds no OCI labels by default" {
  export BUILDKITE_COMMIT="abc123"

  stub docker \
    "buildx create --name docker-compose-build-buildkite-plugin-test-job-id --use : true" \
    "buildx bake --progress=plain --builder docker-compose-build-buildkite-plugin-test-job-id --load web : true"

  run "$PLUGIN_PATH/hooks/command"

  assert_success
  [[ ! -e "$OVERRIDE_FILE" ]]
}
