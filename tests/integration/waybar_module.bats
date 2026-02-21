#!/usr/bin/env bats
# waybar_module.bats — Tests for agent-waybar-module output

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

@test "should output empty JSON when no sessions" {
    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    assert_output '{"text": "", "class": "empty"}'
}

@test "should output valid JSON with sessions" {
    _create_test_session "claude-1"

    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    # Validate it's parseable JSON
    echo "$output" | jq . >/dev/null
}

@test "should include pango markup in output" {
    _create_test_session "claude-1"

    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    assert_output --partial "<span"
    assert_output --partial "</span>"
}

@test "should bold active session" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_set_active "$uuid"

    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    assert_output --partial "weight='bold'"
}

@test "should set class has-working when session is working" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_write_session "$uuid" "state" "working"

    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    assert_output --partial '"class": "has-working"'
}

@test "should set class all-idle when no sessions working" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_write_session "$uuid" "state" "idle"

    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    assert_output --partial '"class": "all-idle"'
}

@test "should use orange color for working sessions" {
    local uuid
    uuid="$(_create_test_session "claude-1")"
    state_write_session "$uuid" "state" "working"

    run "$PROJECT_ROOT/bin/agent-waybar-module"
    assert_success
    assert_output --partial "#f0a050"
}
