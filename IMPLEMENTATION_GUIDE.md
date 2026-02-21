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
│   ├── agent-session-picker        # FZF session picker (live + dead sections)
│   ├── agent-session-picker-rofi   # Rofi session picker (live + dead sections)
│   ├── agent-session-overlay       # Fullscreen session attachment
│   ├── agent-session-create        # Create new session (--resume UUID for dead sessions)
│   ├── agent-session-cycle         # Cycle active session + jump workspace
│   ├── agent-session-jump          # Jump to active session workspace
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
2. **Pick**: A configurable picker (fzf, rofi) lists live sessions and dead/resumable sessions (dimmed). Enter on live attaches; enter on dead resumes.
3. **Attach**: `agent-session-overlay` resolves the UUID to a tmux session name, then opens fullscreen; WM window rules handle layout
4. **Edit**: `agent-open-editor` unfullscreens the overlay and tiles an editor beside it
5. **Navigate**: `agent-session-cycle` rotates sessions; `agent-session-jump` returns to active workspace
6. **Monitor**: Bottom waybar HUD shows all sessions with state/timing; hooks update on agent events
7. **Cleanup**: tmux session-closed hook triggers `_agent-session-cleanup $uuid` which marks `state=dead` (preserves dir for resume)

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
- Fullscreen overlay with WM window rules
- Editor jump with unfullscreen + tiling
- Session cycling and workspace jumping
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
2. Picker → select → fullscreen overlay attached to session
3. No sessions → auto-creates, bottom bar appears
4. Rename tmux session externally → state persists, picker shows new name
5. Kill session → `state=dead` in meta, dir preserved, picker shows dimmed
6. Select dead session → resumes conversation, new tmux session created
7. Dismiss dead session (ctrl-x) → state dir deleted
8. Kill last session → AI mode exits, waybar cleans up
9. Editor opens tiled beside unfullscreened overlay in correct CWD
10. Jump returns to active session's workspace
11. Cycle rotates sessions, workspace follows, bottom bar updates
12. Queue view sorted by priority + state
13. Bottom bar: working=orange, idle=green, stale=red, active=bold
14. Agent writes summary + priority, displayed in queue
15. Nvim picker + context sending works
16. New agent in config.yaml works with picker/HUD
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
