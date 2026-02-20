#!/usr/bin/env bash
# config.sh — YAML config reader using yq with caching

set -euo pipefail

readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-session-switcher"
readonly CONFIG_FILE="$CONFIG_DIR/config.yaml"
readonly DEFAULT_CONFIG="$(dirname "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")")/default-config.yaml"

declare -A _config_cache 2>/dev/null || true

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
    value="$(yq -r ".$key // empty" "$CONFIG_FILE" 2>/dev/null)"

    if [[ -z "$value" ]]; then
        value="$(yq -r ".$key // empty" "$DEFAULT_CONFIG" 2>/dev/null)"
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
    yq -r '.agents | keys | .[]' "$CONFIG_FILE" 2>/dev/null
}
