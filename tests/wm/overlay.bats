#!/usr/bin/env bats
# overlay.bats — Story 1: picker → select → fullscreen overlay
# Requires Hyprland compositor. Skips automatically otherwise.

setup() {
    load "../helpers/test_helper"
    load "../helpers/wm_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    skip_without_hyprland
    source "$PROJECT_ROOT/lib/state.sh"
}

teardown() {
    close_window_by_class "agent-session-overlay"
    teardown_common
}

@test "[WM] should create fullscreen overlay window" {
    # Create session
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    # Dispatch overlay
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10

    # Assert window exists with correct class
    assert_window_class_exists "agent-session-overlay"

    # Assert fullscreen
    assert_window_fullscreen "agent-session-overlay"
}

@test "[WM] should update active-session and mode state files" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10

    # Assert state files
    run cat "$STATE_DIR/active-session"
    assert_output "$uuid"

    run state_get_mode
    assert_output "ai"
}

@test "[WM] should clean up overlay window on close" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10

    close_window_by_class "agent-session-overlay"
    wait_for_window_gone "agent-session-overlay" 5
}
