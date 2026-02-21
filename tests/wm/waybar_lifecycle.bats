#!/usr/bin/env bats
# waybar_lifecycle.bats — Story 5: bottom waybar appears/disappears with AI mode
# Requires Hyprland compositor.

setup() {
    load "../helpers/test_helper"
    load "../helpers/wm_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    skip_without_hyprland
    # Remove waybar stub so real waybar runs
    rm -f "$STUBS_DIR/waybar"
    source "$PROJECT_ROOT/lib/state.sh"
}

teardown() {
    # Ensure waybar is stopped
    "$PROJECT_ROOT/bin/agent-mode-toggle" exit 2>/dev/null || true
    teardown_common
}

@test "[WM] should start waybar on mode enter and PID is alive" {
    [[ ! -f "$STATE_DIR/waybar-pid" ]]

    "$PROJECT_ROOT/bin/agent-mode-toggle" enter
    sleep 1

    # PID file exists
    assert_file_exists "$STATE_DIR/waybar-pid"

    # PID is alive
    local pid
    pid="$(cat "$STATE_DIR/waybar-pid")"
    kill -0 "$pid" 2>/dev/null

    # Mode is ai
    run state_get_mode
    assert_output "ai"
}

@test "[WM] should kill waybar on mode exit and PID is dead" {
    "$PROJECT_ROOT/bin/agent-mode-toggle" enter
    sleep 1

    local pid
    pid="$(cat "$STATE_DIR/waybar-pid")"

    "$PROJECT_ROOT/bin/agent-mode-toggle" exit
    sleep 1

    # PID should be dead
    ! kill -0 "$pid" 2>/dev/null

    # Mode file should be gone
    [[ ! -f "$STATE_DIR/mode" ]]
}
