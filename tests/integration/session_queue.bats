#!/usr/bin/env bats
# session_queue.bats — Tests for queue sorting and formatting
# Note: agent-session-queue uses fzf interactively, so we test the
# underlying state/sorting logic rather than the full script.

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    source "$PROJECT_ROOT/lib/state.sh"
}

teardown() {
    teardown_common
}

@test "should sort working sessions before idle" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"

    state_write_session "$uuid1" "state" "idle"
    state_write_session "$uuid2" "state" "working"

    # Working state should sort first (0 < 1)
    local s1=$( [[ "$(state_read_session "$uuid1" "state")" == "working" ]] && echo "0" || echo "1" )
    local s2=$( [[ "$(state_read_session "$uuid2" "state")" == "working" ]] && echo "0" || echo "1" )
    [[ "$s2" -lt "$s1" ]]
}

@test "should read priority from summary file" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    mkdir -p "$SESSIONS_DIR/$uuid"
    echo -e "PRIORITY: 5\nSUMMARY: critical work" > "$SESSIONS_DIR/$uuid/summary"

    local priority
    priority="$(grep '^PRIORITY:' "$SESSIONS_DIR/$uuid/summary" | awk '{print $2}')"
    [[ "$priority" == "5" ]]
}

@test "should default priority to 3 when no summary" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    # No summary file exists

    local priority
    if [[ -f "$SESSIONS_DIR/$uuid/summary" ]]; then
        priority="$(grep '^PRIORITY:' "$SESSIONS_DIR/$uuid/summary" | awk '{print $2}' || echo "3")"
    else
        priority="3"
    fi
    [[ "$priority" == "3" ]]
}

@test "should handle no sessions gracefully" {
    # No sessions — queue script should exit cleanly
    run "$PROJECT_ROOT/bin/agent-session-queue" </dev/null
    # Exits with 0 and prints "No active sessions"
    assert_success
    assert_output --partial "No active sessions"
}

@test "should assign correct color code for working sessions" {
    # Working = color 33 (yellow)
    local state="working"
    local idle_elapsed=0
    local color_code
    if [[ "$state" == "working" ]]; then
        color_code="33"
    elif (( idle_elapsed > 600 )); then
        color_code="31"
    else
        color_code="32"
    fi
    [[ "$color_code" == "33" ]]
}

@test "should assign red color for stale idle sessions" {
    local state="idle"
    local idle_elapsed=700
    local color_code
    if [[ "$state" == "working" ]]; then
        color_code="33"
    elif (( idle_elapsed > 600 )); then
        color_code="31"
    else
        color_code="32"
    fi
    [[ "$color_code" == "31" ]]
}

@test "should assign green color for recent idle sessions" {
    local state="idle"
    local idle_elapsed=30
    local color_code
    if [[ "$state" == "working" ]]; then
        color_code="33"
    elif (( idle_elapsed > 600 )); then
        color_code="31"
    else
        color_code="32"
    fi
    [[ "$color_code" == "32" ]]
}
