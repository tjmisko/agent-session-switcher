#!/usr/bin/env bash
# config.sh — YAML config reader using yq with caching

set -euo pipefail

CONFIG_DIR="${CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-session-switcher}"
CONFIG_FILE="${CONFIG_FILE:-$CONFIG_DIR/config.yaml}"
DEFAULT_CONFIG="${DEFAULT_CONFIG:-$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/default-config.yaml}"

declare -A _config_cache 2>/dev/null || true

# Resolve yq to an absolute path at source time so scripts work
# even when launched from environments that don't source .bashrc
# (e.g., Hyprland keybind → wezterm → script)
YQ="$(command -v yq 2>/dev/null || echo "")"
if [[ -z "$YQ" ]]; then
    for candidate in "$HOME/.local/bin/yq" /usr/local/bin/yq /usr/bin/yq; do
        if [[ -x "$candidate" ]]; then
            YQ="$candidate"
            break
        fi
    done
fi

if [[ -z "$YQ" ]]; then
    echo "agent-session-switcher: yq not found. Install with: pip install yq" >&2
    exit 1
fi

_config_ensure() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        mkdir -p "$CONFIG_DIR"
        cp "$DEFAULT_CONFIG" "$CONFIG_FILE"
    fi
}

config_get() {
    local key="$1"

    if [[ -n "${_config_cache[$key]+x}" ]]; then
        echo "${_config_cache[$key]}"
        return
    fi

    _config_ensure

    local value
    value="$("$YQ" -r ".$key // \"\"" "$CONFIG_FILE" 2>/dev/null)"

    if [[ -z "$value" ]]; then
        value="$("$YQ" -r ".$key // \"\"" "$DEFAULT_CONFIG" 2>/dev/null)"
    fi

    _config_cache["$key"]="$value"
    echo "$value"
}

config_get_default() {
    local key="$1"
    local default="${2:-}"

    local value
    value="$(config_get "$key")"

    if [[ -z "$value" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

config_get_agent() {
    local agent="$1"
    local field="$2"
    config_get "agents.$agent.$field"
}

config_list_agents() {
    _config_ensure
    {
        "$YQ" -r '.agents | keys | .[]' "$CONFIG_FILE" 2>/dev/null
        "$YQ" -r '.agents | keys | .[]' "$DEFAULT_CONFIG" 2>/dev/null
    } | sort -u
}
