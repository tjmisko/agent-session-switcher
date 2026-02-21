#!/usr/bin/env bats
# session_cycle.bats — Tests for agent-session-cycle

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

@test "should cycle up to next session" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"
    state_set_active "$uuid1"

    run "$PROJECT_ROOT/bin/agent-session-cycle" up
    assert_success

    local active
    active="$(cat "$STATE_DIR/active-session")"
    [[ "$active" != "$uuid1" ]]
}

@test "should cycle down to previous session" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"
    state_set_active "$uuid2"

    run "$PROJECT_ROOT/bin/agent-session-cycle" down
    assert_success

    local active
    active="$(cat "$STATE_DIR/active-session")"
    [[ "$active" != "$uuid2" ]]
}

@test "should wrap around when cycling" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"

    # Get sorted UUIDs to know the order
    mapfile -t sorted < <(printf '%s\n' "$uuid1" "$uuid2" | sort)
    state_set_active "${sorted[1]}"

    # Cycling up from last should wrap to first
    "$PROJECT_ROOT/bin/agent-session-cycle" up

    local active
    active="$(cat "$STATE_DIR/active-session")"
    [[ "$active" == "${sorted[0]}" ]]
}

@test "should not crash with zero sessions" {
    run "$PROJECT_ROOT/bin/agent-session-cycle" up
    assert_success
}

@test "should not crash with one session" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    run "$PROJECT_ROOT/bin/agent-session-cycle" up
    assert_success

    run cat "$STATE_DIR/active-session"
    assert_output "$uuid"
}
