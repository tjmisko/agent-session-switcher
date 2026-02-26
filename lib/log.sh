#!/usr/bin/env bash
# log.sh — Structured logging for agent-session-switcher

LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-switcher/logs"

log_init() {
    mkdir -p "$LOG_DIR"
}

log_msg() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s [%s] [%s] %s\n' "$timestamp" "$level" "$component" "$message" \
        >> "$LOG_DIR/agent-session-switcher.log"
}

log_env() {
    local component="$1"
    log_msg DEBUG "$component" "TERM=${TERM:-unset}"
    log_msg DEBUG "$component" "TMUX=${TMUX:-unset}"
    log_msg DEBUG "$component" "DISPLAY=${DISPLAY:-unset}"
    log_msg DEBUG "$component" "CLAUDECODE=${CLAUDECODE:-unset}"
    log_msg DEBUG "$component" "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset}"
}
