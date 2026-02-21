#!/usr/bin/env bats
# session_cleanup.bats — Tests for _agent-session-cleanup

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

@test "should mark session dead and write dead_since" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    tmux kill-session -t "claude-1" 2>/dev/null || true

    run "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid"
    assert_success

    run state_read_session "$uuid" "state"
    assert_output "dead"
    [[ -n "$(state_read_session "$uuid" "dead_since")" ]]
}

@test "should be idempotent" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    tmux kill-session -t "claude-1" 2>/dev/null || true

    "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid"
    run "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid"
    assert_success

    run state_read_session "$uuid" "state"
    assert_output "dead"
}

@test "should handle missing UUID gracefully" {
    run "$PROJECT_ROOT/bin/_agent-session-cleanup" ""
    assert_success
}

@test "should handle nonexistent UUID gracefully" {
    run "$PROJECT_ROOT/bin/_agent-session-cleanup" "nonexistent-uuid-xyz"
    assert_success
}
