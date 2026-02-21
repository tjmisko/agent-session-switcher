#!/usr/bin/env bats
# session_picker.bats — Tests for picker list output and action helper

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

# --- Picker action helper ---

@test "should kill live session via action helper" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    "$PROJECT_ROOT/bin/_agent-session-picker-action" kill "$uuid"

    # Session should be gone from tmux
    run tmux has-session -t "claude-1"
    assert_failure
}

@test "should dismiss dead session via action helper" {
    local uuid="dead-session-uuid"
    state_write_session "$uuid" "state" "dead"
    state_write_session "$uuid" "agent" "claude"

    "$PROJECT_ROOT/bin/_agent-session-picker-action" kill "$uuid"

    # State dir should be removed
    [[ ! -d "$SESSIONS_DIR/$uuid" ]]
}

@test "should exit gracefully with no args" {
    run "$PROJECT_ROOT/bin/_agent-session-picker-action"
    assert_success
}

@test "should exit gracefully with missing uuid" {
    run "$PROJECT_ROOT/bin/_agent-session-picker-action" kill
    assert_success
}

# --- Preview helper ---

@test "should show meta for dead sessions in preview" {
    local uuid="preview-dead-uuid"
    state_write_session "$uuid" "state" "dead"
    state_write_session "$uuid" "agent" "claude"
    mkdir -p "$SESSIONS_DIR/$uuid"
    echo -e "PRIORITY: 3\nSUMMARY: test summary" > "$SESSIONS_DIR/$uuid/summary"

    run "$PROJECT_ROOT/bin/_agent-session-picker-preview" "$uuid"
    assert_success
}

@test "should show pane output for live sessions in preview" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    run "$PROJECT_ROOT/bin/_agent-session-picker-preview" "$uuid"
    assert_success
}
