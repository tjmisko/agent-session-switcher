# Agent Session Switcher

## Context

tmux AI sessions are first-class citizens managed at the compositor level, with editors as tools you jump into when needed. Designed as an open-source project supporting any CLI-based AI agent.

## Design Goals

- **Pluggable**: Window managers, terminals, status bars, and pickers are all swappable via config
- **tmux as truth**: Live tmux sessions are the canonical session list; state files cache metadata
- **Compositor-first**: Sessions managed at WM level, not from inside an editor
- **Keybindings as suggestions**: Example snippets for each WM; users paste into their own config

## Locations

| Purpose | Path |
|---------|------|
| Project repo | `~/Projects/agent-session-switcher/` |
| User config | `~/.config/agent-session-switcher/config.yaml` |
| Runtime state | `$XDG_RUNTIME_DIR/agent-session-switcher/` |

## Project Structure

```
agent-session-switcher/
├── bin/                            # Core scripts (add to PATH)
│   ├── agent-session-picker        # FZF session picker
│   ├── agent-session-picker-rofi   # Rofi session picker
│   ├── agent-session-overlay       # Fullscreen session attachment
│   ├── agent-session-create        # Create new session
│   ├── agent-session-cycle         # Cycle active session + jump workspace
│   ├── agent-session-jump          # Jump to active session workspace
│   ├── agent-session-queue         # Priority queue view
│   ├── agent-mode-toggle           # Spawns/kills bottom waybar
│   ├── agent-open-editor           # Opens editor in session CWD
│   ├── agent-waybar-module         # Waybar custom module script
│   ├── _agent-session-cleanup      # Internal: tmux hook cleanup
│   └── _agent-session-rename       # Internal: rename session
├── hooks/                          # Agent hooks (agent-specific)
│   └── claude/
│       ├── prompt-submit           # state=working, signal waybar
│       └── stop                    # state=idle, write summary, signal waybar
├── waybar/                         # Bottom HUD bar
│   ├── config.jsonc
│   └── style.css
├── integration/                    # Example snippets (copy into your config)
│   ├── hyprland.conf               # Hyprland keybinding examples
│   ├── i3.conf                     # i3 keybinding examples
│   ├── waybar-workspace-colors.sh  # Top-bar workspace coloring script
│   └── waybar-import.css           # Auto-generated workspace color CSS
├── lua/                            # Neovim plugin
│   └── agent-sessions/
│       └── init.lua
├── lib/                            # Shared library functions
│   ├── config.sh                   # YAML config reader (yq + caching)
│   └── state.sh                    # State management (tmux reconciliation)
├── docs/                           # Detailed documentation
│   ├── architecture.md             # State management, design, lifecycle
│   ├── scripts.md                  # Per-script reference
│   ├── configuration.md            # Config file reference
│   └── integration.md              # WM, terminal, waybar, nvim setup
├── default-config.yaml             # Default config shipped with project
└── install.sh                      # PATH setup, user config creation
```

## How It Works (Summary)

1. **Create**: `agent-session-create` spawns a tmux session with an agent command, registers cleanup hooks, writes state
2. **Pick**: A configurable picker (fzf, rofi, wofi, dmenu) lists sessions color-coded by status
3. **Attach**: `agent-session-overlay` opens the session fullscreen; WM window rules handle layout
4. **Edit**: `agent-open-editor` unfullscreens the overlay and tiles an editor beside it
5. **Navigate**: `agent-session-cycle` rotates sessions; `agent-session-jump` returns to active workspace
6. **Monitor**: Bottom waybar HUD shows all sessions with state/timing; hooks update on agent events
7. **Cleanup**: tmux session-closed hook triggers `_agent-session-cleanup` for automatic teardown

For detailed documentation, see:
- **[Architecture & State](docs/architecture.md)** — state files, session lifecycle, hooks, design principles
- **[Scripts Reference](docs/scripts.md)** — what each script does, usage, keybindings
- **[Configuration](docs/configuration.md)** — config.yaml reference, adding agents, priority guidelines
- **[Integration Guide](docs/integration.md)** — WM keybindings, waybar, neovim, terminal setup

## Current Status

### Implemented
- Core session lifecycle: create, attach, cleanup, rename
- FZF and Rofi pickers with color coding and inline actions
- Fullscreen overlay with WM window rules
- Editor jump with unfullscreen + tiling
- Session cycling and workspace jumping
- Priority queue view sorted by state/priority/idle time
- Bottom waybar HUD with Pango markup
- AI mode toggle (waybar lifecycle)
- Claude hooks (prompt-submit, stop) with state updates
- Workspace color CSS generation
- Neovim floating terminal integration
- Config system with yq caching and defaults fallback
- State reconciliation (tmux as source of truth)
- install.sh

### Open Work

**Terminal abstraction**: Currently has per-terminal flag logic hardcoded in scripts. Should be config-driven — read terminal from `defaults.terminal` (falling back to `$TERMINAL` env var) and use a terminal adapter pattern instead of inline conditionals.

**Keybinding decoupling**: `integration/hyprland.conf` should be example snippets only, not sourced directly. Users copy bindings into their own WM config. Document this clearly.

**Additional pickers**: Architecture supports arbitrary pickers (wofi, dmenu). Add implementations as needed.

**Boot restore** (deferred): No persistent manifest. If revisited, needs a different approach than the original manifest.json design.

**Additional WM support**: i3/sway integration is stubbed but not tested.

## Verification Checklist

1. Picker → select → fullscreen overlay attached to session
2. No sessions → auto-creates, bottom bar appears
3. Editor opens tiled beside unfullscreened overlay in correct CWD
4. Jump returns to active session's workspace
5. Cycle rotates sessions, workspace follows, bottom bar updates
6. Queue view sorted by priority + state
7. Bottom bar: working=orange, idle=green, stale=red, active=bold
8. Agent writes summary + priority, displayed in queue
9. Nvim picker + context sending works
10. New agent in config.yaml works with picker/HUD
11. `install.sh` adds to PATH, creates default user config
