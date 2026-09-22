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
readonly CALL_LOG="${TEST_DIR}/calls"

cleanup() {
  rm -rf -- "$TEST_DIR"
}
trap cleanup EXIT

mkdir -p "$MOCK_DIR"
printf '1\n' >"$STATE_FILE"
printf 'keyboard-us\n' >"$IM_FILE"
printf 'yes\n' >"$RUNNING_FILE"
: >"$CALL_LOG"

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
[[ "${MOCK_BUSCTL_FAIL:-no}" != yes ]]
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
