#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only

set -euo pipefail

readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly CONTROLLER="${PROJECT_DIR}/scripts/fcitx-statusctl"
readonly TEST_DIR="$(mktemp -d /tmp/fcitx-status-test.XXXXXX)"
readonly MOCK_DIR="${TEST_DIR}/bin"
readonly STATE_FILE="${TEST_DIR}/state"
readonly IM_FILE="${TEST_DIR}/im"
readonly RUNNING_FILE="${TEST_DIR}/running"
readonly SCHEMA_FILE="${TEST_DIR}/schema"
readonly CALL_LOG="${TEST_DIR}/calls"

cleanup() {
  rm -rf -- "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$MOCK_DIR"
printf '1\n' >"$STATE_FILE"
printf 'keyboard-us\n' >"$IM_FILE"
printf 'yes\n' >"$RUNNING_FILE"
printf 'rime_ice\n' >"$SCHEMA_FILE"
: >"$CALL_LOG"

export XDG_DATA_HOME="${TEST_DIR}/data"
export XDG_DATA_DIRS="${TEST_DIR}/shared"
readonly RIME_BUILD_DIR="${XDG_DATA_HOME}/fcitx5/rime/build"
mkdir -p "$RIME_BUILD_DIR"
printf 'schema:\n  name: "雾凇拼音"\n' >"${RIME_BUILD_DIR}/rime_ice.schema.yaml"
printf 'schema:\n  name: 小鹤双拼\n' >"${RIME_BUILD_DIR}/double_pinyin_flypy.schema.yaml"
printf 'schema:\n  name: 未启用方案\n' >"${RIME_BUILD_DIR}/disabled.schema.yaml"

cat >"${MOCK_DIR}/fcitx5-remote" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'fcitx5-remote' >>"$MOCK_CALL_LOG"
printf ' %q' "$@" >>"$MOCK_CALL_LOG"
printf '\n' >>"$MOCK_CALL_LOG"
case "${1:-}" in
  --check) [[ "$(cat "$MOCK_RUNNING_FILE")" == yes ]] ;;
  -n) cat "$MOCK_IM_FILE" ;;
  -s) printf '%s\n' "$2" >"$MOCK_IM_FILE" ;;
  -o) printf '2\n' >"$MOCK_STATE_FILE" ;;
  -c) printf '1\n' >"$MOCK_STATE_FILE" ;;
  "") cat "$MOCK_STATE_FILE" ;;
  *) exit 2 ;;
esac
MOCK

cat >"${MOCK_DIR}/busctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'busctl' >>"$MOCK_CALL_LOG"
printf ' %q' "$@" >>"$MOCK_CALL_LOG"
printf '\n' >>"$MOCK_CALL_LOG"
[[ "${MOCK_BUSCTL_FAIL:-no}" != yes ]] || exit 1
case "${7:-}" in
  ListAllSchemas)
    [[ "$5" == /rime && "$6" == org.fcitx.Fcitx.Rime1 ]]
    printf '%s\n' '{"type":"as","data":[["double_pinyin_flypy","rime_ice","missing_metadata"]]}'
    ;;
  GetCurrentSchema) jq -cn --arg schema "$(cat "$MOCK_SCHEMA_FILE")" '{type:"s",data:[$schema]}' ;;
  SetSchema)
    [[ "$8" == s && "$(cat "$MOCK_IM_FILE")" == rime && "$(cat "$MOCK_STATE_FILE")" == 2 ]]
    if [[ "${MOCK_IGNORE_SCHEMA_SWITCH:-no}" != yes ]]; then
      printf '%s\n' "$9" >"$MOCK_SCHEMA_FILE"
    fi
    ;;
esac
MOCK

cat >"${MOCK_DIR}/systemctl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'systemctl' >>"$MOCK_CALL_LOG"
printf ' %q' "$@" >>"$MOCK_CALL_LOG"
printf '\n' >>"$MOCK_CALL_LOG"
exit 0
MOCK

cat >"${MOCK_DIR}/fcitx5" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'fcitx5' >>"$MOCK_CALL_LOG"
printf ' %q' "$@" >>"$MOCK_CALL_LOG"
printf '\n' >>"$MOCK_CALL_LOG"
MOCK

chmod +x "${MOCK_DIR}/fcitx5-remote" "${MOCK_DIR}/busctl" \
  "${MOCK_DIR}/systemctl" "${MOCK_DIR}/fcitx5"

export MOCK_STATE_FILE="$STATE_FILE"
export MOCK_IM_FILE="$IM_FILE"
export MOCK_RUNNING_FILE="$RUNNING_FILE"
export MOCK_SCHEMA_FILE="$SCHEMA_FILE"
export MOCK_CALL_LOG="$CALL_LOG"
export FCITX_STATUS_FCITX_REMOTE="${MOCK_DIR}/fcitx5-remote"
export FCITX_STATUS_BUSCTL="${MOCK_DIR}/busctl"
export FCITX_STATUS_SYSTEMCTL="${MOCK_DIR}/systemctl"
export FCITX_STATUS_FCITX5="${MOCK_DIR}/fcitx5"

fail() {
  printf 'FAIL: %s\n' "$*" >&2
  exit 1
}

assert_json() {
  local json="$1" expression="$2" label="$3"
  jq -e "$expression" >/dev/null <<<"$json" || fail "$label: $json"
}

status="$($CONTROLLER status)"
assert_json "$status" '.ready == true and .mode == "en" and .inputMethod == "keyboard-us"' \
  "inactive keyboard-us should be English"

printf '2\n' >"$STATE_FILE"
printf 'rime\n' >"$IM_FILE"
status="$($CONTROLLER status)"
assert_json "$status" '.ready == true and .mode == "cn" and .inputMethod == "rime"' \
  "active Rime should be Chinese"

printf '1\n' >"$STATE_FILE"
status="$($CONTROLLER status)"
assert_json "$status" '.ready == true and .mode == "en"' \
  "inactive Rime context should be English"

printf 'no\n' >"$RUNNING_FILE"
status="$($CONTROLLER status)"
assert_json "$status" '.ready == false and .mode == "unknown" and .fcitxRunning == false' \
  "stopped Fcitx should not be reported as English"

printf 'yes\n' >"$RUNNING_FILE"
: >"$CALL_LOG"
"$CONTROLLER" set-mode cn
[[ "$(cat "$IM_FILE")" == rime ]] || fail "Chinese action did not select rime"
[[ "$(cat "$STATE_FILE")" == 2 ]] || fail "Chinese action did not activate Fcitx"
grep -Fqx "fcitx5-remote -s rime" "$CALL_LOG" || fail "Chinese action call missing"
grep -Fqx "fcitx5-remote -o" "$CALL_LOG" || fail "Chinese activation call missing"

: >"$CALL_LOG"
"$CONTROLLER" set-mode en
[[ "$(cat "$IM_FILE")" == keyboard-us ]] || fail "English action did not select keyboard-us"
[[ "$(cat "$STATE_FILE")" == 1 ]] || fail "English action did not deactivate Fcitx"
grep -Fqx "fcitx5-remote -s keyboard-us" "$CALL_LOG" || fail "English action call missing"
grep -Fqx "fcitx5-remote -c" "$CALL_LOG" || fail "English deactivation call missing"

schemas="$($CONTROLLER list-rime-schemas)"
assert_json "$schemas" '
  .current == "rime_ice" and .schemas == [
    {id: "rime_ice", name: "雾凇拼音"},
    {id: "double_pinyin_flypy", name: "小鹤双拼"},
    {id: "missing_metadata", name: "missing_metadata"}
  ]
' "only configured Rime schemas should be listed, with the active schema first"

schemas="$(python3 -S "$PROJECT_DIR/scripts/rime-schema-names.py" rime_ice \
  <<<'["double_pinyin_flypy","rime_ice"]')"
assert_json "$schemas" '.current == "rime_ice" and .schemas == [
  {id: "rime_ice", name: "rime_ice"},
  {id: "double_pinyin_flypy", name: "double_pinyin_flypy"}
]' "without PyYAML the picker should use schema IDs and keep the active one first"

: >"$CALL_LOG"
if "$CONTROLLER" set-rime-schema keyboard-us >/dev/null 2>&1; then
  fail "keyboard layout unexpectedly accepted as a Rime schema"
fi
if grep -Eq 'SetSchema|fcitx5-remote -s' "$CALL_LOG"; then
  fail "invalid schema changed the input method or schema"
fi

"$CONTROLLER" set-rime-schema double_pinyin_flypy
[[ "$(cat "$SCHEMA_FILE")" == double_pinyin_flypy ]] || fail "Rime schema was not selected"
schemas="$($CONTROLLER list-rime-schemas)"
assert_json "$schemas" '.current == "double_pinyin_flypy" and .schemas[0].name == "小鹤双拼"' \
  "newly selected Rime schema should appear first"

if MOCK_IGNORE_SCHEMA_SWITCH=yes "$CONTROLLER" set-rime-schema rime_ice >/dev/null 2>&1; then
  fail "a schema switch ignored by Rime was reported as successful"
fi

: >"$CALL_LOG"
"$CONTROLLER" restart
grep -Fqx \
  "busctl --user call org.fcitx.Fcitx5 /controller org.fcitx.Fcitx.Controller1 Restart" \
  "$CALL_LOG" || fail "D-Bus restart call missing"

: >"$CALL_LOG"
MOCK_BUSCTL_FAIL=yes "$CONTROLLER" restart
grep -Fqx "systemctl --user cat omarchy-fcitx5.service" "$CALL_LOG" \
  || fail "Omarchy service availability check missing"
grep -Fqx "systemctl --user restart omarchy-fcitx5.service" "$CALL_LOG" \
  || fail "Omarchy service restart fallback missing"

if "$CONTROLLER" set-mode invalid >/dev/null 2>&1; then
  fail "invalid mode unexpectedly succeeded"
fi

printf 'All fcitx-statusctl tests passed.\n'
