#!/usr/bin/env bash
# install.sh — Add agent-session-switcher to PATH and create user config

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/agent-session-switcher"
BIN_DIR="$SCRIPT_DIR/bin"

echo "Agent Session Switcher — Install"
echo "================================"
echo

# Create user config if missing
if [[ ! -f "$CONFIG_DIR/config.yaml" ]]; then
    mkdir -p "$CONFIG_DIR"
    cp "$SCRIPT_DIR/default-config.yaml" "$CONFIG_DIR/config.yaml"
    echo "Created config: $CONFIG_DIR/config.yaml"
else
    echo "Config exists: $CONFIG_DIR/config.yaml"
fi

# Make all bin scripts executable
chmod +x "$BIN_DIR"/*
echo "Made bin/ scripts executable"

# Make hooks executable
find "$SCRIPT_DIR/hooks" -type f -exec chmod +x {} \;
echo "Made hooks executable"

# Make integration scripts executable
chmod +x "$SCRIPT_DIR/integration/"*.sh 2>/dev/null || true

# Add to PATH via shell profile
path_line="export PATH=\"$BIN_DIR:\$PATH\""
added_to_path=false

for profile in "$HOME/.bashrc" "$HOME/.zshrc"; do
    if [[ -f "$profile" ]]; then
        if ! grep -qF "$BIN_DIR" "$profile"; then
            echo "" >> "$profile"
            echo "# Agent Session Switcher" >> "$profile"
            echo "$path_line" >> "$profile"
            echo "Added to PATH in $profile"
            added_to_path=true
        else
            echo "PATH already configured in $profile"
            added_to_path=true
        fi
    fi
done

if ! $added_to_path; then
    echo
    echo "Add this to your shell profile:"
    echo "  $path_line"
fi

echo
echo "Next steps:"
echo "  1. Restart your shell or run: source ~/.bashrc"
echo "  2. Add to hyprland.conf: source = $SCRIPT_DIR/integration/hyprland.conf"
echo "  3. Add to nvim config: vim.opt.rtp:prepend('$SCRIPT_DIR')"
echo "     require('agent-sessions').setup()"
echo
echo "Done!"
