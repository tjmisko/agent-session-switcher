#!/usr/bin/env bats
# session_create.bats — Tests for agent-session-create

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
}

teardown() {
    teardown_common
}

@test "should create tmux session with auto-numbered name" {
    run "$PROJECT_ROOT/bin/agent-session-create"
    assert_success
    assert_output "claude-1"
    tmux has-session -t "claude-1"
}

@test "should set @agent_uuid option on tmux session" {
    "$PROJECT_ROOT/bin/agent-session-create" >/dev/null
    run tmux show-option -t "claude-1" -v @agent_uuid
    assert_success
    [[ -n "$output" ]]
    # UUID format check (basic)
    [[ "$output" =~ ^[a-f0-9-]+$ ]]
}

@test "should write state files" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    assert_file_exists "$SESSIONS_DIR/$uuid/meta"
    run _read_meta "$uuid" "state"
    assert_output "idle"
    run _read_meta "$uuid" "agent"
    assert_output "claude"
    [[ -n "$(_read_meta "$uuid" "idle_since")" ]]
}

@test "should set AGENT_STATE_DIR environment in tmux" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    run tmux show-environment -t "$name" AGENT_STATE_DIR
    assert_success
    assert_output "AGENT_STATE_DIR=$SESSIONS_DIR/$uuid"
}

@test "should set as active session" {
    local name
    name="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid
    uuid="$(tmux show-option -t "$name" -v @agent_uuid)"

    run cat "$STATE_DIR/active-session"
    assert_success
    assert_output "$uuid"
}

@test "should auto-increment session number" {
    "$PROJECT_ROOT/bin/agent-session-create" >/dev/null
    run "$PROJECT_ROOT/bin/agent-session-create"
    assert_success
    assert_output "claude-2"
}

@test "should create with specified agent type" {
    run "$PROJECT_ROOT/bin/agent-session-create" aider
    assert_success
    assert_output "aider-1"
    tmux has-session -t "aider-1"
}

@test "should create with specified CWD" {
    local tmpdir
    tmpdir="$(mktemp -d)"
    run "$PROJECT_ROOT/bin/agent-session-create" claude "$tmpdir"
    assert_success
    # Verify tmux session was started in that dir
    local cwd
    cwd="$(tmux display-message -t "claude-1" -p '#{pane_current_path}')"
    [[ "$cwd" == "$tmpdir" ]]
    rmdir "$tmpdir"
}

@test "should register session-closed hook" {
    "$PROJECT_ROOT/bin/agent-session-create" >/dev/null
    run tmux show-hooks -t "claude-1"
    assert_success
    assert_output --partial "_agent-session-cleanup"
}

@test "should handle resume mode" {
    # Create first session
    local name1
    name1="$("$PROJECT_ROOT/bin/agent-session-create")"
    local uuid1
    uuid1="$(tmux show-option -t "$name1" -v @agent_uuid)"

    # Write resume data to first session
    _write_meta "$uuid1" "resume_id" "test-resume-id"
    _write_meta "$uuid1" "workspace" "3"
    _write_meta "$uuid1" "cwd" "/tmp"

    # Kill first session's tmux (simulate death)
    tmux kill-session -t "$name1" 2>/dev/null || true

    # Resume
    run "$PROJECT_ROOT/bin/agent-session-create" --resume "$uuid1"
    assert_success
    local new_name="$output"
    local new_uuid
    new_uuid="$(tmux show-option -t "$new_name" -v @agent_uuid)"

    # Old state dir should be gone
    [[ ! -d "$SESSIONS_DIR/$uuid1" ]]
    # New session should have inherited workspace
    run _read_meta "$new_uuid" "workspace"
    assert_output "3"
}
