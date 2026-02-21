#!/usr/bin/env bats
# session_lifecycle.bats — Full lifecycle: create → hooks → cleanup

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

@test "should transition idle → working → idle via state writes" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    run state_read_session "$uuid" "state"
    assert_output "idle"

    state_write_session "$uuid" "state" "working"
    run state_read_session "$uuid" "state"
    assert_output "working"

    state_write_session "$uuid" "state" "idle"
    run state_read_session "$uuid" "state"
    assert_output "idle"
}

@test "should mark dead on tmux kill via cleanup script" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    # Run cleanup directly (simulating hook)
    tmux kill-session -t "claude-1" 2>/dev/null || true
    "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid"

    run state_read_session "$uuid" "state"
    assert_output "dead"
    [[ -n "$(state_read_session "$uuid" "dead_since")" ]]
}

@test "should clear active when last session dies" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    tmux kill-session -t "claude-1" 2>/dev/null || true
    "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid"

    [[ ! -f "$STATE_DIR/active-session" ]]
}

@test "should promote next session when active dies" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"
    state_set_active "$uuid1"

    tmux kill-session -t "claude-1" 2>/dev/null || true
    "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid1"

    run cat "$STATE_DIR/active-session"
    assert_success
    assert_output "$uuid2"
}

@test "should preserve state dir for resume after death" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    tmux kill-session -t "claude-1" 2>/dev/null || true
    "$PROJECT_ROOT/bin/_agent-session-cleanup" "$uuid"

    # State dir should still exist (for resume)
    assert_file_exists "$SESSIONS_DIR/$uuid/meta"
    run state_read_session "$uuid" "state"
    assert_output "dead"
}
