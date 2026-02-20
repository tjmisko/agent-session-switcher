#!/usr/bin/env bash
# state.sh — State file read/write helpers

set -euo pipefail

readonly STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/agent-session-switcher"
readonly SESSIONS_DIR="$STATE_DIR/sessions"

state_init() {
    mkdir -p "$STATE_DIR" "$SESSIONS_DIR"
}

state_get_active() {
    local file="$STATE_DIR/active-session"
    [[ -f "$file" ]] && cat "$file" || echo ""
}

state_set_active() {
    local name="$1"
    state_init
    echo "$name" > "$STATE_DIR/active-session"
}

state_get_mode() {
    local file="$STATE_DIR/mode"
    [[ -f "$file" ]] && cat "$file" || echo ""
}

state_set_mode() {
    local mode="$1"
    state_init
    echo "$mode" > "$STATE_DIR/mode"
}

state_get_waybar_pid() {
    local file="$STATE_DIR/waybar-pid"
    [[ -f "$file" ]] && cat "$file" || echo ""
}

state_set_waybar_pid() {
    local pid="$1"
    state_init
    echo "$pid" > "$STATE_DIR/waybar-pid"
}

state_read_session() {
    local name="$1"
    local field="$2"
    local file="$SESSIONS_DIR/$name"

    [[ -f "$file" ]] || return 1
    grep "^${field}=" "$file" 2>/dev/null | cut -d= -f2-
}

state_write_session() {
    local name="$1"
    local field="$2"
    local value="$3"
    local file="$SESSIONS_DIR/$name"

    state_init

    if [[ -f "$file" ]] && grep -q "^${field}=" "$file" 2>/dev/null; then
        sed -i "s|^${field}=.*|${field}=${value}|" "$file"
    else
        echo "${field}=${value}" >> "$file"
    fi
}

state_remove_session() {
    local name="$1"
    rm -f "$SESSIONS_DIR/$name"
}

state_list_sessions() {
    [[ -d "$SESSIONS_DIR" ]] || return 0
    ls -1 "$SESSIONS_DIR" 2>/dev/null
}

state_session_exists() {
    local name="$1"
    [[ -f "$SESSIONS_DIR/$name" ]]
}
