#!/usr/bin/env bats
# install.bats — Tests for install.sh in isolated HOME

setup() {
    load "../helpers/test_helper"
    setup_common

    # Create isolated HOME
    export HOME="$BATS_TEST_TMPDIR/fakehome"
    mkdir -p "$HOME"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    export CONFIG_DIR="$XDG_CONFIG_HOME/agent-session-switcher"
    export CONFIG_FILE="$CONFIG_DIR/config.yaml"
}

teardown() {
    teardown_common
}

@test "should create config from default" {
    run "$PROJECT_ROOT/install.sh"
    assert_success
    assert_file_exists "$XDG_CONFIG_HOME/agent-session-switcher/config.yaml"
}

@test "should not overwrite existing config" {
    mkdir -p "$XDG_CONFIG_HOME/agent-session-switcher"
    echo "custom: true" > "$XDG_CONFIG_HOME/agent-session-switcher/config.yaml"

    "$PROJECT_ROOT/install.sh"

    run cat "$XDG_CONFIG_HOME/agent-session-switcher/config.yaml"
    assert_output "custom: true"
}

@test "should add PATH to .bashrc" {
    touch "$HOME/.bashrc"
    "$PROJECT_ROOT/install.sh"

    run cat "$HOME/.bashrc"
    assert_output --partial "agent-session-switcher"
    assert_output --partial "PATH"
}

@test "should be idempotent with PATH addition" {
    touch "$HOME/.bashrc"
    "$PROJECT_ROOT/install.sh"
    "$PROJECT_ROOT/install.sh"

    # Count PATH lines — should only appear once
    local count
    count="$(grep -c "Agent Session Switcher" "$HOME/.bashrc")"
    [[ "$count" -eq 1 ]]
}

@test "should create state directory" {
    "$PROJECT_ROOT/install.sh"
    assert_dir_exists "$XDG_STATE_HOME/agent-session-switcher"
}
