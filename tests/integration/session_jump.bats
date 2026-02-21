#!/usr/bin/env bats
# session_jump.bats — Tests for agent-session-jump

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

@test "should error when no active session" {
    run "$PROJECT_ROOT/bin/agent-session-jump"
    assert_failure
    assert_output --partial "No active session"
}

@test "should error when no workspace set" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    run "$PROJECT_ROOT/bin/agent-session-jump"
    assert_failure
    assert_output --partial "No workspace set"
}

@test "should call hyprctl dispatch with correct workspace" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"
    state_write_session "$uuid" "workspace" "5"

    run "$PROJECT_ROOT/bin/agent-session-jump"
    assert_success

    # Verify stub was called with correct args
    _stub_log_contains "hyprctl" "dispatch workspace 5"
}
