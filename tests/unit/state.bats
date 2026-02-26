#!/usr/bin/env bats
# state.bats — Tests for lib/state.sh (UUID-keyed state management)

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

# Helper: run state functions that depend on config in a fresh subshell
# (associative arrays don't survive bats' `run` subshell)
_run_state() {
    local func="$1"
    shift
    bash -c "
        set -euo pipefail
        export STATE_DIR='$STATE_DIR'
        export SESSIONS_DIR='$SESSIONS_DIR'
        export CONFIG_DIR='$CONFIG_DIR'
        export CONFIG_FILE='$CONFIG_FILE'
        export DEFAULT_CONFIG='$DEFAULT_CONFIG'
        export TMUX_SOCKET='$TMUX_SOCKET'
        tmux() { command tmux -L \"\$TMUX_SOCKET\" \"\$@\"; }
        export -f tmux
        source '$PROJECT_ROOT/lib/config.sh'
        source '$PROJECT_ROOT/lib/state.sh'
        set +o pipefail
        $func \"\$@\"
    " -- "$@"
}

# --- Active session ---

@test "should set and get active session UUID" {
    state_set_active "test-uuid-123"
    run cat "$STATE_DIR/active-session"
    assert_success
    assert_output "test-uuid-123"
}

@test "should return empty when no active session set" {
    run _run_state state_get_active
    assert_success
    assert_output ""
}

@test "should fallback when active session is dead" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"

    state_set_active "dead-uuid-no-session"

    # Use set +o pipefail to avoid SIGPIPE from head -1 inside state_get_active
    local result
    result="$(_run_state state_get_active 2>/dev/null)" || true
    [[ -n "$result" ]]
    [[ "$result" == "$uuid1" || "$result" == "$uuid2" ]]
}

# --- Mode ---

@test "should set and get mode" {
    state_set_mode "ai"
    run state_get_mode
    assert_success
    assert_output "ai"
}

@test "should return empty when mode not set" {
    run state_get_mode
    assert_success
    assert_output ""
}

# --- Waybar PID ---

@test "should set and get waybar pid" {
    state_set_waybar_pid "12345"
    run state_get_waybar_pid
    assert_success
    assert_output "12345"
}

@test "should return empty when waybar pid not set" {
    run state_get_waybar_pid
    assert_success
    assert_output ""
}

# --- Session meta ---

@test "should write and read session field" {
    local uuid="test-uuid-write"
    state_write_session "$uuid" "state" "idle"

    run state_read_session "$uuid" "state"
    assert_success
    assert_output "idle"
}

@test "should update existing session field" {
    local uuid="test-uuid-update"
    state_write_session "$uuid" "state" "idle"
    state_write_session "$uuid" "state" "working"

    run state_read_session "$uuid" "state"
    assert_success
    assert_output "working"
}

@test "should write and read multiple fields" {
    local uuid="test-uuid-multi"
    state_write_session "$uuid" "state" "idle"
    state_write_session "$uuid" "agent" "claude"
    state_write_session "$uuid" "idle_since" "1700000000"

    run state_read_session "$uuid" "state"
    assert_output "idle"

    run state_read_session "$uuid" "agent"
    assert_output "claude"

    run state_read_session "$uuid" "idle_since"
    assert_output "1700000000"
}

@test "should fail when reading nonexistent session" {
    run state_read_session "nonexistent-uuid" "state"
    assert_failure
}

@test "should remove session directory" {
    local uuid="test-uuid-remove"
    state_write_session "$uuid" "state" "dead"
    assert_file_exists "$SESSIONS_DIR/$uuid/meta"

    state_remove_session "$uuid"
    assert_file_not_exists "$SESSIONS_DIR/$uuid/meta"
    [[ ! -d "$SESSIONS_DIR/$uuid" ]]
}

# --- UUID lookups ---

@test "should find UUID by session name" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    run state_find_uuid "claude-1"
    assert_success
    assert_output "$uuid"
}

@test "should get session name by UUID" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    run state_get_name "$uuid"
    assert_success
    assert_output "claude-1"
}

@test "should return empty for unknown UUID" {
    run state_get_name "nonexistent-uuid-xyz"
    assert_success
    assert_output ""
}

@test "should return empty UUID for unknown session name" {
    run state_find_uuid "nonexistent-session"
    assert_success
    assert_output ""
}

# --- Session discovery ---

@test "should list live sessions" {
    local uuid1
    uuid1="$(_create_test_session "claude-1")"
    local uuid2
    uuid2="$(_create_test_session "claude-2")"

    run _run_state state_list_sessions
    assert_success
    assert_line "$uuid1"
    assert_line "$uuid2"
}

@test "should exclude non-agent tmux sessions" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    tmux new-session -d -s "regular-session" bash

    run _run_state state_list_sessions
    assert_success
    assert_line "$uuid"
    refute_line --partial "regular"
}

@test "should mark orphaned state dirs as dead" {
    local orphan_uuid="orphan-uuid-123"
    state_write_session "$orphan_uuid" "state" "idle"
    state_write_session "$orphan_uuid" "agent" "claude"

    _run_state state_list_sessions >/dev/null

    run state_read_session "$orphan_uuid" "state"
    assert_output "dead"
}

@test "should bootstrap untracked live sessions" {
    tmux new-session -d -s "claude-1" bash
    local uuid="bootstrap-uuid-123"
    tmux set-option -t "claude-1" @agent_uuid "$uuid"

    _run_state state_list_sessions >/dev/null

    run state_read_session "$uuid" "state"
    assert_success
    assert_output "idle"
}

@test "should revive dead sessions that reappear" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    _write_meta "$uuid" "state" "dead"

    _run_state state_list_sessions >/dev/null

    run state_read_session "$uuid" "state"
    assert_output "idle"
}

# --- Helpers ---

@test "should detect agent type from session prefix" {
    run _run_state state_get_agent_type "claude-1"
    assert_success
    assert_output "claude"
}

@test "should detect aider agent type from prefix" {
    run _run_state state_get_agent_type "aider-1"
    assert_success
    assert_output "aider"
}

@test "should return unknown for unmatched prefix" {
    run _run_state state_get_agent_type "random-session"
    assert_success
    assert_output "unknown"
}

@test "should get CWD from tmux session" {
    _create_test_session "claude-1"

    run state_get_cwd "claude-1"
    assert_success
    [[ -n "$output" ]]
}

@test "should rename session preserving UUID" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    state_rename_session "claude-1" "claude-renamed"

    run state_get_name "$uuid"
    assert_success
    assert_output "claude-renamed"
}

@test "should check session existence" {
    _create_test_session "claude-1"

    run state_session_exists "claude-1"
    assert_success

    run state_session_exists "nonexistent"
    assert_failure
}
