#!/usr/bin/env bash
# test_helper.bash — Common setup/teardown for agent-session-switcher tests
# Provides isolated tmux socket, stubbed external commands, and helper functions.

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Load bats helpers
load "$(dirname "${BASH_SOURCE[0]}")/../bats/bats-support/load"
load "$(dirname "${BASH_SOURCE[0]}")/../bats/bats-assert/load"
load "$(dirname "${BASH_SOURCE[0]}")/../bats/bats-file/load"

# Isolated tmux socket name per test file (PID-based)
TMUX_SOCKET="ass-test-$$"

# Override tmux to always use isolated socket
tmux() {
    command tmux -L "$TMUX_SOCKET" "$@"
}
export -f tmux

setup_common() {
    # Isolated state/config dirs under BATS_TEST_TMPDIR (auto-cleaned)
    export STATE_DIR="$BATS_TEST_TMPDIR/state"
    export SESSIONS_DIR="$STATE_DIR/sessions"
    export CONFIG_DIR="$BATS_TEST_TMPDIR/config"
    export CONFIG_FILE="$CONFIG_DIR/config.yaml"
    export DEFAULT_CONFIG="$PROJECT_ROOT/tests/fixtures/default-config-test.yaml"

    mkdir -p "$STATE_DIR" "$SESSIONS_DIR" "$CONFIG_DIR"

    # Default test config: uses bash instead of real agent commands
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cp "$PROJECT_ROOT/tests/fixtures/config-minimal.yaml" "$CONFIG_FILE"
    fi

    # Create stub directory and prepend to PATH
    export STUBS_DIR="$BATS_TEST_TMPDIR/stubs"
    mkdir -p "$STUBS_DIR"
    _create_default_stubs
    export PATH="$STUBS_DIR:$PATH"

    # Export tmux socket for subprocesses
    export TMUX_SOCKET
}

teardown_common() {
    # Kill isolated tmux server (ignore errors if already dead)
    command tmux -L "$TMUX_SOCKET" kill-server 2>/dev/null || true
}

# --- Stub creation ---

_create_default_stubs() {
    local cmds=(hyprctl waybar wezterm notify-send pkill rofi fzf alacritty kitty)
    for cmd in "${cmds[@]}"; do
        _stub_command "$cmd"
    done
}

_stub_command() {
    local name="$1"
    local body="${2:-}"
    local stub="$STUBS_DIR/$name"

    cat > "$stub" <<STUB_EOF
#!/usr/bin/env bash
# Stub for $name — logs calls to $STUBS_DIR/${name}.log
echo "\$(date +%s) $name \$*" >> "$STUBS_DIR/${name}.log"
${body}
STUB_EOF
    chmod +x "$stub"
}

# --- Test session helpers ---

_create_test_session() {
    local name="${1:-claude-1}"
    local uuid="${2:-$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid)}"

    # Create tmux session with bash
    tmux new-session -d -s "$name" bash

    # Set UUID option
    tmux set-option -t "$name" @agent_uuid "$uuid"

    # Write initial state
    mkdir -p "$SESSIONS_DIR/$uuid"
    cat > "$SESSIONS_DIR/$uuid/meta" <<EOF
state=idle
agent=claude
idle_since=$(date +%s)
EOF

    echo "$uuid"
}

_read_meta() {
    local uuid="$1"
    local field="$2"
    grep "^${field}=" "$SESSIONS_DIR/$uuid/meta" 2>/dev/null | cut -d= -f2-
}

_write_meta() {
    local uuid="$1"
    local field="$2"
    local value="$3"
    local file="$SESSIONS_DIR/$uuid/meta"

    mkdir -p "$SESSIONS_DIR/$uuid"
    if [[ -f "$file" ]] && grep -q "^${field}=" "$file" 2>/dev/null; then
        sed -i "s|^${field}=.*|${field}=${value}|" "$file"
    else
        echo "${field}=${value}" >> "$file"
    fi
}

_stub_log() {
    local name="$1"
    cat "$STUBS_DIR/${name}.log" 2>/dev/null || echo ""
}

_stub_log_contains() {
    local name="$1"
    local pattern="$2"
    grep -q -- "$pattern" "$STUBS_DIR/${name}.log" 2>/dev/null
}

# Wait for a tmux session to appear (with timeout)
_wait_for_session() {
    local name="$1"
    local timeout="${2:-5}"
    local elapsed=0
    while ! tmux has-session -t "$name" 2>/dev/null; do
        sleep 0.1
        elapsed=$(( elapsed + 1 ))
        if (( elapsed > timeout * 10 )); then
            echo "Timed out waiting for session $name" >&2
            return 1
        fi
    done
}
