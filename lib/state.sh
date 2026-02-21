#!/usr/bin/env bash
# state.sh — UUID-keyed state helpers
# tmux is the single source of truth for session liveness.
# State is stored at $SESSIONS_DIR/<uuid>/meta (key=value).
# Dead sessions are preserved for resume support.

set -euo pipefail

STATE_DIR="${STATE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/agent-session-switcher}"
SESSIONS_DIR="${SESSIONS_DIR:-$STATE_DIR/sessions}"

# Source config for prefix lookup (guard against re-sourcing)
_STATE_LIB_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
if ! declare -f config_get >/dev/null 2>&1; then
    source "$_STATE_LIB_DIR/config.sh"
fi

state_init() {
    mkdir -p "$STATE_DIR" "$SESSIONS_DIR"
}

# --- Active session (stores UUID) ---

state_get_active() {
    local file="$STATE_DIR/active-session"
    if [[ ! -f "$file" ]]; then
        echo ""
        return
    fi

    local active
    active="$(cat "$file")"

    if [[ -z "$active" ]]; then
        echo ""
        return
    fi

    # If active UUID has no live tmux session, fallback to first live
    local name
    name="$(state_get_name "$active")"
    if [[ -z "$name" ]]; then
        local first_uuid
        first_uuid="$(_tmux_agent_sessions | head -1 | cut -d'|' -f1)"
        if [[ -n "$first_uuid" ]]; then
            echo "$first_uuid" > "$file"
            echo "$first_uuid"
        else
            rm -f "$file"
            echo ""
        fi
        return
    fi

    echo "$active"
}

state_set_active() {
    local uuid="$1"
    state_init
    echo "$uuid" > "$STATE_DIR/active-session"
}

# --- Mode / waybar ---

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

# --- Session state files (UUID-keyed directories) ---

state_read_session() {
    local uuid="$1"
    local field="$2"
    local file="$SESSIONS_DIR/$uuid/meta"

    [[ -f "$file" ]] || return 1
    grep "^${field}=" "$file" 2>/dev/null | cut -d= -f2-
}

state_write_session() {
    local uuid="$1"
    local field="$2"
    local value="$3"
    local dir="$SESSIONS_DIR/$uuid"
    local file="$dir/meta"

    state_init
    mkdir -p "$dir"

    if [[ -f "$file" ]] && grep -q "^${field}=" "$file" 2>/dev/null; then
        sed -i "s|^${field}=.*|${field}=${value}|" "$file"
    else
        echo "${field}=${value}" >> "$file"
    fi
}

state_remove_session() {
    local uuid="$1"
    rm -rf "${SESSIONS_DIR:?}/$uuid"
}

state_session_exists() {
    local name="$1"
    tmux has-session -t "$name" 2>/dev/null
}

# --- UUID <-> name lookups ---

# Query a single session's @agent_uuid option (robust across tmux versions)
_tmux_get_uuid() {
    local session="$1"
    # show-option (singular) with -v returns just the value; fall back to parsing
    local val
    val="$(tmux show-option -t "$session" -v @agent_uuid 2>/dev/null)" && { echo "$val"; return; }
    # Older tmux: show-options (plural) without -v, parse "key value"
    val="$(tmux show-options -t "$session" @agent_uuid 2>/dev/null | awk '{gsub(/"/, "", $2); print $2}')"
    echo "$val"
}

state_get_name() {
    local uuid="$1"
    tmux has-session 2>/dev/null || { echo ""; return; }

    local session_name
    while IFS= read -r session_name; do
        [[ -n "$session_name" ]] || continue
        local sess_uuid
        sess_uuid="$(_tmux_get_uuid "$session_name")"
        if [[ "$sess_uuid" == "$uuid" ]]; then
            echo "$session_name"
            return
        fi
    done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null)
    echo ""
}

state_find_uuid() {
    local name="$1"
    _tmux_get_uuid "$name"
}

# --- tmux-based session discovery ---

_tmux_agent_sessions() {
    local prefixes=()
    local agent

    for agent in $(config_list_agents); do
        local prefix
        prefix="$(config_get_agent "$agent" "session_prefix")"
        if [[ -n "$prefix" ]]; then
            prefixes+=("$prefix")
        fi
    done

    if [[ ${#prefixes[@]} -eq 0 ]]; then
        return 0
    fi

    # No tmux server -> no sessions
    tmux has-session 2>/dev/null || return 0

    # Build grep pattern from prefixes
    local pattern
    pattern="$(printf '%s\|' "${prefixes[@]}")"
    pattern="${pattern%\\|}"  # remove trailing \|

    # Get sessions matching prefix, then look up UUID for each
    local session_name
    while IFS= read -r session_name; do
        [[ -n "$session_name" ]] || continue
        local uuid
        uuid="$(_tmux_get_uuid "$session_name")"
        if [[ -n "$uuid" ]]; then
            echo "${uuid}|${session_name}"
        fi
    done < <(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "^\\(${pattern}\\)" || true)
}

state_list_sessions() {
    state_init

    # 1. Get live agent sessions from tmux (uuid|name pairs)
    local live_pairs
    live_pairs="$(_tmux_agent_sessions)"

    # 2. Collect live UUIDs
    local -A live_uuids=()
    local pair
    while IFS= read -r pair; do
        [[ -n "$pair" ]] || continue
        local uuid="${pair%%|*}"
        live_uuids["$uuid"]=1
    done <<< "$live_pairs"

    # 3. Mark orphaned state dirs as dead
    if [[ -d "$SESSIONS_DIR" ]]; then
        local dir
        for dir in "$SESSIONS_DIR"/*/; do
            [[ -d "$dir" ]] || continue
            local dir_uuid
            dir_uuid="$(basename "$dir")"
            if [[ -z "${live_uuids[$dir_uuid]+x}" ]]; then
                local current_state
                current_state="$(state_read_session "$dir_uuid" "state" 2>/dev/null || echo "")"
                if [[ "$current_state" != "dead" ]]; then
                    state_write_session "$dir_uuid" "state" "dead"
                    state_write_session "$dir_uuid" "dead_since" "$(date +%s)"
                fi
            fi
        done
    fi

    # 4. Bootstrap state for untracked live sessions
    local uuid name
    while IFS='|' read -r uuid name; do
        [[ -n "$uuid" ]] || continue
        if [[ ! -f "$SESSIONS_DIR/$uuid/meta" ]]; then
            local agent_type
            agent_type="$(state_get_agent_type "$name")"
            state_write_session "$uuid" "state" "idle"
            state_write_session "$uuid" "agent" "$agent_type"
            state_write_session "$uuid" "idle_since" "$(date +%s)"
        elif [[ "$(state_read_session "$uuid" "state" 2>/dev/null)" == "dead" ]]; then
            # Session came back to life
            state_write_session "$uuid" "state" "idle"
            state_write_session "$uuid" "idle_since" "$(date +%s)"
        fi
    done <<< "$live_pairs"

    # 5. Return live UUIDs
    while IFS='|' read -r uuid name; do
        [[ -n "$uuid" ]] || continue
        echo "$uuid"
    done <<< "$live_pairs"
}

state_list_dead_sessions() {
    state_init

    # Get live UUIDs for exclusion
    local -A live_uuids=()
    local pair
    while IFS= read -r pair; do
        [[ -n "$pair" ]] || continue
        local uuid="${pair%%|*}"
        live_uuids["$uuid"]=1
    done < <(_tmux_agent_sessions)

    # Scan state dirs for dead sessions
    if [[ -d "$SESSIONS_DIR" ]]; then
        local dir
        for dir in "$SESSIONS_DIR"/*/; do
            [[ -d "$dir" ]] || continue
            local dir_uuid
            dir_uuid="$(basename "$dir")"
            # Skip live sessions
            [[ -z "${live_uuids[$dir_uuid]+x}" ]] || continue
            # Return if dead or orphaned
            local state
            state="$(state_read_session "$dir_uuid" "state" 2>/dev/null || echo "")"
            if [[ "$state" == "dead" || -z "$state" ]]; then
                echo "$dir_uuid"
            fi
        done
    fi
}

# --- Helpers ---

state_get_cwd() {
    local session="$1"
    tmux display-message -t "$session" -p '#{pane_current_path}' 2>/dev/null || echo "$HOME"
}

state_get_agent_type() {
    local session="$1"
    local agent

    for agent in $(config_list_agents); do
        local prefix
        prefix="$(config_get_agent "$agent" "session_prefix")"
        if [[ -n "$prefix" && "$session" == "${prefix}"* ]]; then
            echo "$agent"
            return
        fi
    done

    echo "unknown"
}

state_rename_session() {
    local old="$1"
    local new="$2"
    # Just rename the tmux session — UUID and state dir are stable
    tmux rename-session -t "$old" "$new" || return 1
}
