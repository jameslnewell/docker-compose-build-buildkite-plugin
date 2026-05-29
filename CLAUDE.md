# Docker Compose Build Buildkite Plugin

## Running tests

```bash
docker run --rm -v "$PWD:/plugin:ro" buildkite/plugin-tester
```

## Testing with bats-mock

Stub patterns are parsed via `eval "parsed_patterns=(...)"`, so any argument
containing spaces must be wrapped in escaped quotes so eval treats it as one token:

```bash
# Wrong — eval splits "my service" into two tokens, won't match the single arg
"compose ... bake my service : true"

# Correct — eval sees "my service" as one token
"compose ... bake \"my service\" : true"
```

For stubs where an argument contains a newline, use `:: true` to accept the call
unconditionally and verify via `assert_output --partial` with stderr captured:

```bash
stub docker \
  "compose ... build : true" \
  ":: true" \
  ...

run bash -c "${PLUGIN_DIR}/hooks/command 2>&1"
assert_output --partial "expected pattern"
```

## shared.bash — use printf not echo

`echo "$value"` swallows values starting with `-e` (bash treats it as a flag).
Always use `printf '%s\n' "$value"` when printing arbitrary variable values.
