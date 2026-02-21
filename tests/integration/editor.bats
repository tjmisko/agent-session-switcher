#!/usr/bin/env bats
# editor.bats — Tests for agent-open-editor (stubbed WM)

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
    run "$PROJECT_ROOT/bin/agent-open-editor"
    assert_failure
    assert_output --partial "No active session"
}

@test "should call terminal with correct CWD" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    "$PROJECT_ROOT/bin/agent-open-editor"

    # Verify wezterm stub was called with --cwd
    _stub_log_contains "wezterm" "--cwd"
}

@test "should call hyprctl to unfullscreen" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    "$PROJECT_ROOT/bin/agent-open-editor"

    _stub_log_contains "hyprctl" "dispatch fullscreen"
}
