#!/usr/bin/env bash
# manifest.sh — Persistent manifest JSON read/write using jq

set -euo pipefail

readonly MANIFEST_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-switcher"
readonly MANIFEST_FILE="$MANIFEST_DIR/manifest.json"

manifest_init() {
    mkdir -p "$MANIFEST_DIR"
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        echo '{"sessions":{}}' > "$MANIFEST_FILE"
    fi
}

manifest_add() {
    local name="$1"
    local agent="$2"
    local uuid="$3"
    local cwd="$4"
    local workspace="${5:-}"

    manifest_init

    local tmp
    tmp="$(mktemp)"
    jq --arg name "$name" \
       --arg agent "$agent" \
       --arg uuid "$uuid" \
       --arg cwd "$cwd" \
       --arg ws "$workspace" \
       '.sessions[$name] = {agent: $agent, uuid: $uuid, cwd: $cwd, workspace: ($ws | if . == "" then null else tonumber end)}' \
       "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
}

manifest_remove() {
    local name="$1"
    manifest_init

    local tmp
    tmp="$(mktemp)"
    jq --arg name "$name" 'del(.sessions[$name])' "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
}

manifest_get() {
    local name="$1"
    local field="$2"
    manifest_init

    jq -r --arg name "$name" --arg field "$field" \
        '.sessions[$name][$field] // empty' "$MANIFEST_FILE"
}

manifest_list() {
    manifest_init
    jq -r '.sessions | keys[]' "$MANIFEST_FILE" 2>/dev/null
}

manifest_get_all() {
    local name="$1"
    manifest_init
    jq -r --arg name "$name" '.sessions[$name] // empty' "$MANIFEST_FILE"
}

manifest_update() {
    local name="$1"
    local field="$2"
    local value="$3"

    manifest_init

    local tmp
    tmp="$(mktemp)"
    jq --arg name "$name" \
       --arg field "$field" \
       --arg value "$value" \
       '.sessions[$name][$field] = $value' \
       "$MANIFEST_FILE" > "$tmp" && mv "$tmp" "$MANIFEST_FILE"
}
