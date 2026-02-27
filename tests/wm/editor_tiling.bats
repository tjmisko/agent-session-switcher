#!/usr/bin/env bats
# editor_tiling.bats — Editor tiles beside agentTerminal
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
    close_agent_terminal
    teardown_common
}

@test "[WM] should unfullscreen agentTerminal when editor opens" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"

    # Spawn and wait for terminal
    "$PROJECT_ROOT/bin/agent-session-toggle"
    wait_for_window "agentTerminal" 10

    # Fullscreen it manually (simulates being in a session)
    hyprctl dispatch fullscreen 1
    sleep 0.5
    assert_window_fullscreen "agentTerminal"

    # Open editor
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-open-editor"
    sleep 2

    # agentTerminal should no longer be fullscreen
    assert_window_not_fullscreen "agentTerminal"
}

@test "[WM] should have two windows on same workspace after editor opens" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"

    "$PROJECT_ROOT/bin/agent-session-toggle"
    wait_for_window "agentTerminal" 10

    local workspace
    workspace="$(get_workspace_of_window "agentTerminal")"

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-open-editor"
    sleep 2

    # At least 2 windows on the workspace
    local count
    count="$(hyprctl clients -j | jq "[.[] | select(.workspace.id == $workspace)] | length")"
    (( count >= 2 ))
}

@test "[WM] should open editor in session CWD" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create" claude "$tmpdir")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    "$PROJECT_ROOT/bin/agent-session-toggle"
    wait_for_window "agentTerminal" 10

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-open-editor"
    sleep 2

    local cwd
    cwd="$(state_get_cwd "$name")"
    [[ "$cwd" == "$tmpdir" ]]

    rmdir "$tmpdir" 2>/dev/null || true
}
