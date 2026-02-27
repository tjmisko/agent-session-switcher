#!/usr/bin/env bats
# jump.bats — Focus agentTerminal window
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

@test "[WM] should focus agentTerminal window" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"

    # Spawn terminal
    "$PROJECT_ROOT/bin/agent-session-toggle"
    wait_for_window "agentTerminal" 10

    # Switch to another workspace
    hyprctl dispatch workspace 1
    sleep 0.5

    # Jump should focus the terminal
    "$PROJECT_ROOT/bin/agent-session-jump"
    sleep 0.5

    # Terminal should be focused
    local focused_class
    focused_class="$(hyprctl activewindow -j | jq -r '.class')"
    [[ "$focused_class" == "agentTerminal" ]]
}
