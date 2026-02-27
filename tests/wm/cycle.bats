#!/usr/bin/env bats
# cycle.bats — Cycle switches tmux session in-place
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

@test "[WM] should cycle through sessions and update active" {
    local name1 name2 uuid1 uuid2

    name1="$("$PROJECT_ROOT/bin/agent-session-create")"
    uuid1="$(tmux show-option -t "$name1" -v @agent_uuid)"

    name2="$("$PROJECT_ROOT/bin/agent-session-create")"
    uuid2="$(tmux show-option -t "$name2" -v @agent_uuid)"

    local initial_active
    initial_active="$(cat "$STATE_DIR/active-session")"

    # Cycle up
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-cycle up"
    sleep 1

    local after_cycle
    after_cycle="$(cat "$STATE_DIR/active-session")"
    [[ "$after_cycle" != "$initial_active" ]]
}

@test "[WM] should wrap around when cycling past last session" {
    local name1 name2 uuid1 uuid2

    name1="$("$PROJECT_ROOT/bin/agent-session-create")"
    uuid1="$(tmux show-option -t "$name1" -v @agent_uuid)"

    name2="$("$PROJECT_ROOT/bin/agent-session-create")"
    uuid2="$(tmux show-option -t "$name2" -v @agent_uuid)"

    # Get sorted UUIDs
    mapfile -t sorted < <(printf '%s\n' "$uuid1" "$uuid2" | sort)
    # Set active to last sorted
    state_set_active "${sorted[1]}"

    # Cycle up should wrap to first
    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-cycle up"
    sleep 1

    local active
    active="$(cat "$STATE_DIR/active-session")"
    [[ "$active" == "${sorted[0]}" ]]
}

@test "[WM] should cycle down in reverse" {
    local name1 name2 uuid1 uuid2

    name1="$("$PROJECT_ROOT/bin/agent-session-create")"
    uuid1="$(tmux show-option -t "$name1" -v @agent_uuid)"

    name2="$("$PROJECT_ROOT/bin/agent-session-create")"
    uuid2="$(tmux show-option -t "$name2" -v @agent_uuid)"

    mapfile -t sorted < <(printf '%s\n' "$uuid1" "$uuid2" | sort)
    state_set_active "${sorted[0]}"

    hyprctl dispatch exec "$PROJECT_ROOT/bin/agent-session-cycle down"
    sleep 1

    local active
    active="$(cat "$STATE_DIR/active-session")"
    [[ "$active" == "${sorted[1]}" ]]
}
