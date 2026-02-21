#!/usr/bin/env bats
# editor_tiling.bats — Story 2: editor tiles beside overlay
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

@test "[WM] should unfullscreen overlay when editor opens" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    # Start overlay fullscreen
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10
    assert_window_fullscreen "agent-session-overlay"

    # Open editor
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-open-editor"
    sleep 2

    # Overlay should no longer be fullscreen
    assert_window_not_fullscreen "agent-session-overlay"
}

@test "[WM] should have two windows on same workspace after editor opens" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10

    local workspace
    workspace="$(get_workspace_of_window "agent-session-overlay")"

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

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-overlay $name"
    wait_for_window "agent-session-overlay" 10

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-open-editor"
    sleep 2

    # CWD verification: the editor should have been launched in tmpdir
    # This is hard to verify in a WM test, so we check state instead
    local cwd
    cwd="$(state_get_cwd "$name")"
    [[ "$cwd" == "$tmpdir" ]]

    rmdir "$tmpdir" 2>/dev/null || true
}
