# Configuration

## User Config Location

`~/.config/agent-session-switcher/config.yaml`

Created from `default-config.yaml` on first run or via `install.sh`.

## Config Reference

```yaml
defaults:
  agent: claude                       # Default agent when creating sessions
  terminal: wezterm                   # Terminal emulator (wezterm, alacritty, kitty)
  editor: nvim                        # Editor for agent-open-editor
  window_manager: hyprland            # WM for dispatch commands (hyprland, i3, sway)
  picker: rofi                         # Session picker (fzf, rofi, wofi, dmenu)

agents:
  claude:
    command: claude                   # CLI command to launch
    resume_flag: "--resume"           # Flag for resuming dead sessions
    session_prefix: "claude-"         # tmux session name prefix
    session_id_flag: "--session-id"   # Flag for UUID-based session tracking
    system_prompt_flag: "--append-system-prompt"  # Flag for injecting system prompt
    hooks: true                       # Whether hooks/ scripts fire for this agent
  aider:
    command: aider
    session_prefix: "aider-"
    hooks: false
  cursor:
    command: cursor
    session_prefix: "cursor-"
    hooks: false

# Injected into agent system prompt (for agents that support it)
system_prompt_additions: |
  After each response, write a one-line status summary and priority to
  the file at $AGENT_STATE_DIR/summary. Format:
  PRIORITY: <1-5>
  SUMMARY: <one sentence describing current state and next action needed>

priority_rules: |
  Projects under ~/Projects/ are highest priority.
  Configuration and dotfile changes are low priority.
  Failing tests or blocked work is always critical.
```

## Adding a New Agent

Add an entry under `agents:` in your config:

```yaml
agents:
  my-agent:
    command: my-agent-cli
    session_prefix: "myagent-"
    hooks: false
```

The agent will appear in pickers and can be selected with `--agent my-agent`.

If the agent supports hooks, set `hooks: true` and create `hooks/my-agent/prompt-submit` and `hooks/my-agent/stop`.

## Priority Guidelines

Priority values (1-5) written by agents to their summary file:

| Priority | Level    | Example                                     |
|----------|----------|---------------------------------------------|
| 5        | Critical | ~/Projects work that is blocked/failing     |
| 4        | High     | Active feature work in ~/Projects           |
| 3        | Normal   | Routine changes, refactoring                |
| 2        | Low      | Configuration, dotfiles                     |
| 1        | Minimal  | Documentation, cosmetic changes             |
