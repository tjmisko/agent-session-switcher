# Architecture

## Design Principles

1. **Pluggability**: Window managers, terminals, status bars, and pickers are all swappable via configuration. The project ships implementations for common tools but avoids hard coupling.
2. **tmux as source of truth**: Live tmux sessions are the canonical session list. State files are a cache layer for metadata (working/idle, workspace, priority). No persistent manifest.
3. **Compositor-first**: Sessions are managed at the compositor level, not from inside an editor. Editors are tools you open *into* a session, not the other way around.
4. **Convention over configuration**: Sensible defaults (wezterm, hyprland, fzf) with everything overridable.
5. **Keybindings as suggestions**: The project provides example keybinding snippets for each supported WM. Users paste these into their own WM config — the project never sets keybindings directly to avoid clashes.

## State Management

### Runtime State (`$XDG_RUNTIME_DIR/agent-session-switcher/`)

Ephemeral files that track session metadata alongside tmux:

```
active-session              # UUID of the currently focused session
mode                        # "ai" when AI mode is active
waybar-pid                  # Bottom waybar PID
sessions/
  <uuid>/
    meta                    # Key=value metadata:
                            #   state=working|idle|dead
                            #   agent=claude
                            #   idle_since=<epoch>
                            #   dead_since=<epoch>
                            #   workspace=3
                            #   resume_id=<agent-session-id>
                            #   cwd=/path/to/project
    summary                 # Agent-written priority + summary
                            #   PRIORITY: <1-5>
                            #   SUMMARY: <one sentence>
```

### Session Discovery

`state_list_sessions()` reconciles state directories with live tmux sessions:
- Marks orphaned state dirs (no matching tmux session) as `state=dead` with a `dead_since` timestamp
- Bootstraps state for untracked live tmux sessions matching configured agent prefixes
- Revives dead sessions whose tmux sessions have come back
- Returns only UUIDs of currently live sessions

### Key Library Functions

**`lib/config.sh`** — YAML config reader with caching:
- `config_get(key)` — cached lookup, falls back to `default-config.yaml`
- `config_get_default(key, default)` — returns fallback if empty
- `config_get_agent(agent, field)` — agent-specific config
- `config_list_agents()` — all configured agents
- Uses `yq` for YAML parsing, discovers it across common paths

**`lib/state.sh`** — UUID-keyed session state management:
- `state_get_active()` — active UUID, validates against tmux, falls back to first live session
- `state_set_active(uuid)` — writes UUID to `active-session`
- `state_list_sessions()` — reconciled list of live session UUIDs
- `state_read_session(uuid, field)` / `state_write_session(uuid, field, value)` — per-session metadata
- `state_get_cwd(session)` — CWD from tmux pane
- `state_get_agent_type(session)` — matches session name prefix to agent config
- `state_rename_session(old, new)` — renames the tmux session only (UUID and state dir are stable)

### No Manifest

The original design included `manifest.json` for persistent session state across reboots. This was dropped in favor of tmux-as-truth. Boot restore (deferred) will need a different approach if revisited.

## Session Lifecycle

```
agent-session-create [agent] [cwd] [name]
  → generates UUID, creates $SESSIONS_DIR/<uuid>/meta
  → writes launcher script to state dir (avoids tmux quoting issues)
  → spawns tmux session running the launcher
  → sets @agent_uuid tmux option for UUID lookup
  → registers session-closed hook → _agent-session-cleanup $uuid
  → sets AGENT_STATE_DIR via tmux set-environment
  → writes initial state (idle) and sets as active session

agent-session-create --resume $uuid
  → reads resume_id from old session's meta
  → generates new UUID, creates new state dir
  → starts agent with resume flag + inherited resume_id
  → copies summary, inherits workspace and cwd from old session
  → deletes old session's state dir

agent-session-terminal (picker → select → fullscreen attach loop)
  → writes TTY and PID for external control
  → enters AI mode (starts waybar HUD)
  → loops: unfullscreen → fzf picker → select → fullscreen + tmux attach
  → ESC exits loop, cleans up, exits AI mode

agent-session-toggle (Mod+A handler)
  → no terminal: spawn agentTerminal with wrapper
  → fullscreen (in session): detach tmux client via TTY + unfullscreen
  → floating (picker visible): hide to special workspace
  → on special workspace: bring back + reload fzf via --listen

agent-session-cycle (Mod+Up/Down)
  → switches tmux session in-place via tmux switch-client
  → terminal stays fullscreen, no detach/reattach

_agent-session-cleanup $uuid (tmux hook on session close)
  → marks state=dead, writes dead_since timestamp
  → saves CWD to meta for future resume
  → preserves state dir (never deletes — supports resume)
  → resets active session to next live session
  → refreshes waybar
  → exits AI mode if no sessions remain

dismiss (explicit user action, e.g. ctrl-x)
  → calls state_remove_session which rm -rf's the state dir
  → permanently discards session state (no resume possible)
```

## Hooks

Hooks are agent-specific scripts that fire on agent events to update state and refresh the UI.

Currently implemented: `hooks/claude/`
- `prompt-submit` — sets `state=working`, clears `idle_since`, refreshes waybar + workspace colors
- `stop` — sets `state=idle`, writes `idle_since`, refreshes waybar + workspace colors, optional desktop notification

The create script sets `AGENT_STATE_DIR` via `tmux set-environment` so hooks and agents can write summary/priority files.
