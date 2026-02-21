#!/usr/bin/env bats
# session_overlay.bats — Tests for agent-session-overlay (stubbed WM)

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    source "$PROJECT_ROOT/lib/state.sh"

    # Stub hyprctl to return workspace JSON
    _stub_command "hyprctl" 'if [[ "$1" == "activeworkspace" ]]; then echo "{\"id\": 3}"; fi'
}

teardown() {
    teardown_common
}

@test "should error when no session specified and no active session" {
    run "$PROJECT_ROOT/bin/agent-session-overlay"
    assert_failure
    assert_output --partial "No session specified"
}

@test "should error when specified session does not exist" {
    run "$PROJECT_ROOT/bin/agent-session-overlay" "nonexistent-session"
    assert_failure
    assert_output --partial "does not exist"
}

@test "should set active session and write workspace" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    run "$PROJECT_ROOT/bin/agent-session-overlay" "claude-1"
    assert_success

    run cat "$STATE_DIR/active-session"
    assert_output "$uuid"
}

@test "should call terminal with correct tmux attach args" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    "$PROJECT_ROOT/bin/agent-session-overlay" "claude-1"

    _stub_log_contains "wezterm" "agent-session-overlay"
    _stub_log_contains "wezterm" "tmux attach-session -t claude-1"
}
