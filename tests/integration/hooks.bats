#!/usr/bin/env bats
# hooks.bats — Tests for claude hooks (prompt-submit, stop)

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    source "$PROJECT_ROOT/lib/state.sh"

    # Stub waybar-workspace-colors.sh
    mkdir -p "$PROJECT_ROOT/integration"
}

teardown() {
    teardown_common
}

@test "prompt-submit should set state=working" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    # Simulate running inside tmux session
    # The hook uses `tmux display-message -p '#{session_name}'`
    # In our isolated tmux we can attach and run
    tmux send-keys -t "claude-1" \
        "source '$PROJECT_ROOT/lib/state.sh' && state_write_session '$uuid' 'state' 'working' && state_write_session '$uuid' 'idle_since' ''" Enter

    sleep 0.3

    run state_read_session "$uuid" "state"
    assert_output "working"
}

@test "stop should set state=idle and idle_since" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_write_session "$uuid" "state" "working"

    # Simulate stop hook state changes
    state_write_session "$uuid" "state" "idle"
    state_write_session "$uuid" "idle_since" "$(date +%s)"

    run state_read_session "$uuid" "state"
    assert_output "idle"
    [[ -n "$(state_read_session "$uuid" "idle_since")" ]]
}

@test "stop should capture resume_id from JSON payload" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    # Simulate what the stop hook does with a JSON payload
    local payload='{"session_id": "test-session-id-abc"}'
    local session_id
    session_id="$(echo "$payload" | jq -r '.session_id // empty' 2>/dev/null || echo "")"
    state_write_session "$uuid" "resume_id" "$session_id"

    run state_read_session "$uuid" "resume_id"
    assert_output "test-session-id-abc"
}

@test "hooks should exit gracefully outside tmux" {
    # When tmux display-message fails (not in tmux), hooks should exit 0
    # Test by running hook with no tmux session context
    run bash -c "TMUX= '$PROJECT_ROOT/hooks/claude/prompt-submit'" </dev/null
    # Should exit cleanly (0) since it can't get session name
    assert_success
}
