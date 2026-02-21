#!/usr/bin/env bats
# mode_toggle.bats — Tests for agent-mode-toggle

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    source "$PROJECT_ROOT/lib/state.sh"

    # Stub waybar — detach from parent FDs so bats' `run` doesn't hang
    _stub_command "waybar" '(sleep 300 </dev/null >/dev/null 2>&1 &)'
}

teardown() {
    # Kill any background waybar stubs
    local pid
    pid="$(cat "$STATE_DIR/waybar-pid" 2>/dev/null || echo "")"
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi
    teardown_common
}

@test "enter should set mode=ai" {
    run "$PROJECT_ROOT/bin/agent-mode-toggle" enter
    assert_success

    run state_get_mode
    assert_output "ai"
}

@test "enter should write waybar-pid" {
    "$PROJECT_ROOT/bin/agent-mode-toggle" enter

    local pid
    pid="$(state_get_waybar_pid)"
    [[ -n "$pid" ]]
}

@test "exit should clear mode and waybar-pid files" {
    # Enter first
    state_set_mode "ai"
    state_set_waybar_pid "99999"

    run "$PROJECT_ROOT/bin/agent-mode-toggle" exit
    assert_success

    [[ ! -f "$STATE_DIR/mode" ]]
    [[ ! -f "$STATE_DIR/waybar-pid" ]]
}

@test "toggle should flip from empty to ai" {
    run "$PROJECT_ROOT/bin/agent-mode-toggle" toggle
    assert_success

    run state_get_mode
    assert_output "ai"
}

@test "toggle should flip from ai to off" {
    state_set_mode "ai"
    state_set_waybar_pid "99999"

    run "$PROJECT_ROOT/bin/agent-mode-toggle" toggle
    assert_success

    [[ ! -f "$STATE_DIR/mode" ]]
}

@test "refresh should not crash without waybar running" {
    run "$PROJECT_ROOT/bin/agent-mode-toggle" refresh
    assert_success
}

@test "should reject invalid action" {
    run "$PROJECT_ROOT/bin/agent-mode-toggle" invalid
    assert_failure
    assert_output --partial "Usage:"
}
