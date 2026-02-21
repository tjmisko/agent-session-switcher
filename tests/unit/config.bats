#!/usr/bin/env bats
# config.bats — Tests for lib/config.sh

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
}

teardown() {
    teardown_common
}

# Helper: run config functions in a subshell that sources config.sh fresh
_run_config_get() {
    bash -c "
        export CONFIG_DIR='$CONFIG_DIR'
        export CONFIG_FILE='$CONFIG_FILE'
        export DEFAULT_CONFIG='$DEFAULT_CONFIG'
        source '$PROJECT_ROOT/lib/config.sh'
        config_get '$1'
    "
}

_run_config_get_default() {
    bash -c "
        export CONFIG_DIR='$CONFIG_DIR'
        export CONFIG_FILE='$CONFIG_FILE'
        export DEFAULT_CONFIG='$DEFAULT_CONFIG'
        source '$PROJECT_ROOT/lib/config.sh'
        config_get_default '$1' '$2'
    "
}

@test "should read default agent from config" {
    run _run_config_get "defaults.agent"
    assert_success
    assert_output "claude"
}

@test "should read agent prefix" {
    run _run_config_get "agents.claude.session_prefix"
    assert_success
    assert_output "claude-"
}

@test "should list all configured agents" {
    run bash -c "
        export CONFIG_DIR='$CONFIG_DIR'
        export CONFIG_FILE='$CONFIG_FILE'
        export DEFAULT_CONFIG='$DEFAULT_CONFIG'
        source '$PROJECT_ROOT/lib/config.sh'
        config_list_agents
    "
    assert_success
    assert_line "claude"
    assert_line "aider"
    assert_line "cursor"
}

@test "should fallback to default-config.yaml when key missing from user config" {
    cat > "$CONFIG_FILE" <<'EOF'
defaults:
  agent: claude
agents:
  claude:
    command: bash
    session_prefix: "claude-"
EOF

    run _run_config_get "defaults.terminal"
    assert_success
    assert_output "wezterm"
}

@test "should return cached value on repeated reads" {
    # Test cache by reading same key twice in same process
    run bash -c "
        export CONFIG_DIR='$CONFIG_DIR'
        export CONFIG_FILE='$CONFIG_FILE'
        export DEFAULT_CONFIG='$DEFAULT_CONFIG'
        source '$PROJECT_ROOT/lib/config.sh'
        config_get 'defaults.agent' >/dev/null
        # Overwrite config
        echo 'defaults:' > '$CONFIG_FILE'
        echo '  agent: modified' >> '$CONFIG_FILE'
        # Should still return cached value
        config_get 'defaults.agent'
    "
    assert_success
    assert_output "claude"
}

@test "should return fallback from config_get_default" {
    run _run_config_get_default "nonexistent.key" "fallback_value"
    assert_success
    assert_output "fallback_value"
}

@test "should return empty string for nonexistent key without default" {
    run _run_config_get "totally.nonexistent.deep.key"
    assert_success
    assert_output ""
}

@test "should create config from default when missing" {
    rm -f "$CONFIG_FILE"
    run bash -c "
        export CONFIG_DIR='$CONFIG_DIR'
        export CONFIG_FILE='$CONFIG_FILE'
        export DEFAULT_CONFIG='$DEFAULT_CONFIG'
        source '$PROJECT_ROOT/lib/config.sh'
        _config_ensure
        [[ -f '$CONFIG_FILE' ]]
    "
    assert_success
}
