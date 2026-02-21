#!/usr/bin/env bats
# jump.bats — Story 3: jump to active session workspace
# Requires Hyprland compositor.

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

@test "[WM] should jump to session workspace from different workspace" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    # Attach overlay (records workspace)
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10
    sleep 1

    local session_workspace
    session_workspace="$(state_read_session "$uuid" "workspace")"

    # Switch to workspace 1
    hyprctl dispatch workspace 1
    sleep 0.5
    assert_workspace "1"

    # Jump should switch back
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-jump"
    sleep 1

    assert_workspace "$session_workspace"
}

@test "[WM] should stay on same workspace if already there" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10
    sleep 1

    local session_workspace
    session_workspace="$(state_read_session "$uuid" "workspace")"

    # Already on session workspace — jump should be a no-op
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-jump"
    sleep 0.5

    assert_workspace "$session_workspace"
}
