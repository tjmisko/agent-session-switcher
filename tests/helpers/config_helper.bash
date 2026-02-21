#!/usr/bin/env bash
# config_helper.bash — Test config generators

write_test_config() {
    local config_file="${CONFIG_FILE:-$BATS_TEST_TMPDIR/config/config.yaml}"
    mkdir -p "$(dirname "$config_file")"

    cat > "$config_file" <<'EOF'
defaults:
  agent: claude
  terminal: wezterm
  editor: nvim
  window_manager: hyprland
  picker: rofi

agents:
  claude:
    command: bash
    session_prefix: "claude-"
    hooks: true
  aider:
    command: bash
    session_prefix: "aider-"
    hooks: false
  cursor:
    command: bash
    session_prefix: "cursor-"
    hooks: false
EOF
}

write_custom_agent_config() {
    local agent_name="$1"
    local prefix="$2"
    local config_file="${CONFIG_FILE:-$BATS_TEST_TMPDIR/config/config.yaml}"
    mkdir -p "$(dirname "$config_file")"

    cat > "$config_file" <<EOF
defaults:
  agent: $agent_name
  terminal: wezterm
  editor: nvim
  window_manager: hyprland
  picker: rofi

agents:
  $agent_name:
    command: bash
    session_prefix: "${prefix}"
    hooks: false
EOF
}
