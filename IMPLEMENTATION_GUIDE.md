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
│   ├── agent-session-terminal      # Wrapper: picker + session attach loop (runs in agentTerminal)
│   ├── agent-session-toggle        # Mod+A handler: spawn/detach/hide/show
│   ├── agent-session-picker        # FZF session picker (--select mode for terminal)
│   ├── agent-session-picker-rofi   # Rofi session picker
│   ├── agent-session-create        # Create new session (--resume UUID for dead sessions)
│   ├── agent-session-cycle         # Cycle sessions (tmux switch-client in-place)
│   ├── agent-session-jump          # Focus agentTerminal window
│   ├── agent-session-queue         # Priority queue view
│   ├── agent-mode-toggle           # Spawns/kills bottom waybar
│   ├── agent-open-editor           # Opens editor in session CWD
│   ├── agent-waybar-module         # Waybar custom module script
│   ├── _agent-session-cleanup      # Internal: marks state=dead (preserves dir)
│   ├── _agent-session-rename       # Internal: tmux rename only (UUID stable)
│   ├── _agent-session-picker-action # Internal: kill/dismiss helper for fzf picker
│   ├── _agent-session-picker-preview # Internal: preview helper for fzf picker
│   └── _agent-debug                # Diagnostic tool for session state issues
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

## State Model (UUID-Keyed)

All session state is keyed on a **UUID** stored as a tmux user option (`@agent_uuid`), not the session name. This makes state resilient to tmux renames and enables dead-session resume.

### Layout

```
$XDG_RUNTIME_DIR/agent-session-switcher/
├── active-session          # Contains UUID of the active session
├── mode                    # "ai" when waybar HUD is active
├── waybar-pid              # PID of bottom waybar instance
└── sessions/
    └── <uuid>/
        ├── meta            # key=value: state, agent, idle_since, dead_since, workspace, resume_id, cwd
        └── summary         # Agent-written: PRIORITY: N / SUMMARY: text
```

### Session Lifecycle

1. **Create**: `agent-session-create` generates a UUID, creates `$SESSIONS_DIR/<uuid>/meta`, spawns the tmux session, then sets `tmux set-option -t $name @agent_uuid $uuid`. The `session-closed` hook is registered with the UUID.
2. **Discover**: `_tmux_agent_sessions()` lists tmux sessions matching configured prefixes, then queries each for its `@agent_uuid` via `tmux show-options`. Returns `uuid|name` pairs.
3. **Reconcile**: `state_list_sessions()` compares live `uuid|name` pairs against state dirs. Orphaned dirs (no matching live session) are marked `state=dead`. Untracked live sessions get bootstrapped.
4. **Cleanup**: When a tmux session closes, `_agent-session-cleanup $uuid` marks the state dir `state=dead` with a `dead_since` timestamp. The dir is **preserved** for resume — never deleted by cleanup.
5. **Resume**: `agent-session-create --resume $uuid` reads `resume_id` from the dead session's meta, starts a new tmux session with `claude --resume $resume_id`, inherits workspace/cwd/summary, then deletes the old state dir.
6. **Dismiss**: Explicit user action (ctrl-x on a dead session in the picker) calls `state_remove_session` which `rm -rf`s the state dir.

### UUID Lookup

The `@agent_uuid` tmux user option is the link between a live tmux session and its state dir. Lookups use `tmux show-option -t $session -v @agent_uuid` with a fallback parser for older tmux versions. The `#{@agent_uuid}` format string in `list-sessions -F` also works on tmux 3.x+ but is not relied upon — per-session queries are used instead for portability.

### Key Invariants

- **tmux is truth for liveness**: A session is "live" if and only if its tmux session exists.
- **UUID is truth for identity**: Renaming a tmux session doesn't affect state. `state_rename_session()` is just `tmux rename-session`.
- **Dead != deleted**: Dead sessions persist on disk until explicitly dismissed or resumed.
- **Active pointer is a UUID**: `$STATE_DIR/active-session` contains a UUID, not a session name.

## How It Works (Summary)

1. **Create**: `agent-session-create` spawns a tmux session, assigns a UUID via `@agent_uuid`, registers cleanup hooks, writes state to `$SESSIONS_DIR/<uuid>/meta`
2. **Toggle (Mod+A)**: `agent-session-toggle` spawns/detaches/hides/shows a single `agentTerminal` window
3. **Pick**: `agent-session-terminal` runs inside the terminal, looping between fzf picker (floating) and tmux attach (fullscreen)
4. **Attach**: Selecting a session fullscreens the terminal and attaches tmux; Mod+A detaches and returns to picker
5. **Edit**: `agent-open-editor` unfullscreens the `agentTerminal` and tiles an editor beside it
6. **Navigate**: `agent-session-cycle` switches tmux session in-place (no detach/reattach); `agent-session-jump` focuses the terminal window
7. **Monitor**: Bottom waybar HUD shows all sessions with state/timing; hooks update on agent events
8. **Cleanup**: tmux session-closed hook triggers `_agent-session-cleanup $uuid` which marks `state=dead` (preserves dir for resume)

For detailed documentation, see:
- **[Architecture & State](docs/architecture.md)** — state files, session lifecycle, hooks, design principles
- **[Scripts Reference](docs/scripts.md)** — what each script does, usage, keybindings
- **[Configuration](docs/configuration.md)** — config.yaml reference, adding agents, priority guidelines
- **[Integration Guide](docs/integration.md)** — WM keybindings, waybar, neovim, terminal setup

## Current Status

### Implemented
- UUID-keyed state model with `@agent_uuid` tmux session option
- Dead session preservation and resume via `claude --resume`
- `stop` hook captures `session_id` from Claude's JSON payload as `resume_id`
- Core session lifecycle: create, attach, cleanup, rename, resume
- FZF and Rofi pickers with live + dead/resumable session sections
- Single-window terminal with picker + attach loop
- Mod+A toggle: spawn/detach/hide/show
- Editor jump with unfullscreen + tiling
- Session cycling via tmux switch-client (in-place, no detach/reattach)
- Priority queue view sorted by state/priority/idle time
- Bottom waybar HUD with Pango markup
- AI mode toggle (waybar lifecycle)
- Claude hooks (prompt-submit, stop) with UUID-based state updates
- Workspace color CSS generation
- Neovim floating terminal integration
- Config system with yq caching and defaults fallback
- State reconciliation (tmux as source of truth, UUID as identity)
- `_agent-debug` diagnostic script
- install.sh

### Open Work

**Terminal abstraction**: Currently has per-terminal flag logic hardcoded in scripts. Should be config-driven — read terminal from `defaults.terminal` (falling back to `$TERMINAL` env var) and use a terminal adapter pattern instead of inline conditionals.

**Keybinding decoupling**: `integration/hyprland.conf` should be example snippets only, not sourced directly. Users copy bindings into their own WM config. Document this clearly.

**Additional pickers**: Architecture supports arbitrary pickers (wofi, dmenu). Add implementations as needed.

**Boot restore** (deferred): No persistent manifest. If revisited, needs a different approach than the original manifest.json design.

**Additional WM support**: i3/sway integration is stubbed but not tested.

### Known Issues

**`claude` requires an interactive PTY**: `tmux new-session -d` runs the command in a detached session. The `claude` CLI needs an interactive terminal to stay alive — it exits immediately if it detects no PTY (e.g., when launched from a non-interactive context). Sessions must be created from an environment where tmux can allocate a PTY (a real terminal, WM keybind that spawns a terminal, etc.). In environments without a PTY (CI, SSH without `-t`, sandboxed subprocesses), sessions will be created and immediately die, appearing as dead/resumable in the picker. This is correct behavior — the cleanup hook preserves them for resume.

## Verification Checklist

1. Create session → `$SESSIONS_DIR/<uuid>/meta` exists with `state=idle`, `@agent_uuid` set in tmux
2. Mod+A → spawns floating terminal with fzf picker
3. Select session → terminal goes fullscreen, tmux attached
4. Mod+A while fullscreen → detaches, unfullscreens, picker shown
5. Mod+A while picker visible → hides to special workspace
6. Mod+A while hidden → brings back, fzf list refreshes
7. ctrl-n in picker → creates session, list refreshes, new session visible
8. Mod+Up/Down → switches tmux session in-place (no window change)
9. Mod+F4 → focuses agentTerminal window
10. Mod+E → unfullscreens agentTerminal, opens editor beside it
11. `hyprctl clients -j | jq '.[].class'` → only one `agentTerminal` window ever
12. Rename tmux session externally → state persists, picker shows new name
13. Kill session → `state=dead` in meta, dir preserved, picker shows dimmed
14. Kill last session → AI mode exits, waybar cleans up
15. Queue view sorted by priority + state
16. Bottom bar: working=orange, idle=green, stale=red, active=bold
17. `install.sh` adds to PATH, creates default user config

## Testing

### Standard Tests

```bash
bats tests/unit/ tests/integration/
```

Runs all unit and integration tests. Tests use isolated tmux sockets and temporary directories — no system state is affected.

### Window Manager Tests

```bash
RUN_WM_TESTS=1 bats tests/wm/
```

Requires a live Hyprland session. Tests window rules, workspace dispatch, and fullscreen overlay behavior. Skipped by default.
