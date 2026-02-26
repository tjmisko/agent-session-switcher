#!/usr/bin/env bats
# hooks.bats — Tests for claude hooks (prompt-submit, stop)

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    source "$PROJECT_ROOT/lib/state.sh"

    # Stub agent-mode-toggle (called by hooks for waybar refresh)
    _stub_command "agent-mode-toggle"
}

teardown() {
    teardown_common
}

# Helper: run a command inside an isolated tmux session and wait for completion
_run_in_session() {
    local session="$1"
    shift
    local cmd="$*"

    # Use a sentinel file to detect when the command finishes
    local sentinel="$BATS_TEST_TMPDIR/sentinel-$$-$RANDOM"

    tmux send-keys -t "$session" "$cmd; echo done > '$sentinel'" Enter

    local elapsed=0
    while [[ ! -f "$sentinel" ]]; do
        sleep 0.1
        elapsed=$(( elapsed + 1 ))
        if (( elapsed > 50 )); then
            echo "Timed out waiting for command in session $session" >&2
            return 1
        fi
    done
}

@test "prompt-submit hook should set state=working" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    # Run the actual prompt-submit hook inside the tmux session
    _run_in_session "claude-1" \
        "STATE_DIR='$STATE_DIR' SESSIONS_DIR='$SESSIONS_DIR' CONFIG_DIR='$CONFIG_DIR' CONFIG_FILE='$CONFIG_FILE' DEFAULT_CONFIG='$DEFAULT_CONFIG' '$PROJECT_ROOT/hooks/claude/prompt-submit'"

    run state_read_session "$uuid" "state"
    assert_output "working"

    # idle_since should be cleared
    run state_read_session "$uuid" "idle_since"
    assert_output ""
}

@test "stop hook should set state=idle and write idle_since" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_write_session "$uuid" "state" "working"
    state_write_session "$uuid" "idle_since" ""

    # Run the actual stop hook (with empty stdin)
    _run_in_session "claude-1" \
        "echo '' | STATE_DIR='$STATE_DIR' SESSIONS_DIR='$SESSIONS_DIR' CONFIG_DIR='$CONFIG_DIR' CONFIG_FILE='$CONFIG_FILE' DEFAULT_CONFIG='$DEFAULT_CONFIG' '$PROJECT_ROOT/hooks/claude/stop'"

    run state_read_session "$uuid" "state"
    assert_output "idle"

    local idle_since
    idle_since="$(state_read_session "$uuid" "idle_since")"
    [[ -n "$idle_since" ]]
    # Should be a recent epoch timestamp
    [[ "$idle_since" =~ ^[0-9]+$ ]]
}

@test "prompt-submit hook should exit gracefully outside tmux" {
    # Run hook outside of tmux context (TMUX unset)
    run bash -c "TMUX= STATE_DIR='$STATE_DIR' SESSIONS_DIR='$SESSIONS_DIR' CONFIG_DIR='$CONFIG_DIR' CONFIG_FILE='$CONFIG_FILE' DEFAULT_CONFIG='$DEFAULT_CONFIG' '$PROJECT_ROOT/hooks/claude/prompt-submit'" </dev/null
    assert_success
}

@test "stop hook should exit gracefully outside tmux" {
    run bash -c "echo '' | TMUX= STATE_DIR='$STATE_DIR' SESSIONS_DIR='$SESSIONS_DIR' CONFIG_DIR='$CONFIG_DIR' CONFIG_FILE='$CONFIG_FILE' DEFAULT_CONFIG='$DEFAULT_CONFIG' '$PROJECT_ROOT/hooks/claude/stop'"
    assert_success
}
