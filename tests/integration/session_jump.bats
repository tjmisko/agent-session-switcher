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

@test "should call hyprctl focuswindow with agentTerminal class" {
    run "$PROJECT_ROOT/bin/agent-session-jump"
    assert_success

    _stub_log_contains "hyprctl" "dispatch focuswindow class:agentTerminal"
}
