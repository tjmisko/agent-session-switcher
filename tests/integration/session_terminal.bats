#!/usr/bin/env bats
# session_terminal.bats — Tests for agent-session-terminal (stubbed WM)

setup() {
    load "../helpers/test_helper"
    load "../helpers/config_helper"
    setup_common
    write_test_config
    source "$PROJECT_ROOT/lib/state.sh"

    # Stub hyprctl
    _stub_command "hyprctl" ''
    # Stub curl for fzf --listen reload
    _stub_command "curl" ''
}

teardown() {
    teardown_common
}

@test "should write agent-tty to state dir" {
    local uuid
    uuid="$(_create_test_session "claude-1")"

    # Stub fzf to return the session selection then exit
    _stub_command "fzf" 'echo "▸ claude-1   idle     00:00:05 ~/proj '"$uuid"'"'

    # Stub tmux attach to return immediately (simulates detach)
    _stub_command "tmux" 'case "$1" in attach-session) return 0 ;; *) command tmux -L "$TMUX_SOCKET" "$@" ;; esac'

    # Run terminal in background, kill after state file appears
    "$PROJECT_ROOT/bin/agent-session-terminal" &
    local pid=$!
    sleep 1

    assert_file_exists "$STATE_DIR/agent-tty"
    assert_file_exists "$STATE_DIR/terminal-pid"

    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
}
