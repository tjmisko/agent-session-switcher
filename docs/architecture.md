# Architecture

## Design Principles

1. **Pluggability**: Window managers, terminals, status bars, and pickers are all swappable via configuration. The project ships implementations for common tools but avoids hard coupling.
2. **tmux as source of truth**: Live tmux sessions are the canonical session list. State files are a cache layer for metadata (working/idle, workspace, priority). No persistent manifest.
3. **Compositor-first**: Sessions are managed at the compositor level, not from inside an editor. Editors are tools you open *into* a session, not the other way around.
4. **Convention over configuration**: Sensible defaults (wezterm, hyprland, fzf) with everything overridable.
5. **Keybindings as suggestions**: The project provides example keybinding snippets for each supported WM. Users paste these into their own WM config — the project never sets keybindings directly to avoid clashes.

## State Management

### Runtime State (`$XDG_RUNTIME_DIR/agent-session-switcher/`)

Ephemeral files that match the tmux lifecycle:

```
active-session              # Name of currently focused session
mode                        # "ai" when AI mode is active
waybar-pid                  # Bottom waybar PID
sessions/
  <session-name>            # Per-session state file:
                            #   state=working|idle
                            #   idle_since=<epoch>
                            #   agent=claude
                            #   workspace=3
  <session-name>/
    summary                 # Agent-written priority + summary
                            #   PRIORITY: <1-5>
                            #   SUMMARY: <one sentence>
```

### Session Discovery

`state_list_sessions()` reconciles state files with live tmux sessions:
- Removes state files for dead tmux sessions
- Creates state files for new tmux sessions matching configured agent prefixes
- Returns only sessions that exist in both tmux and state

### Key Library Functions

**`lib/config.sh`** — YAML config reader with caching:
- `config_get(key)` — cached lookup, falls back to `default-config.yaml`
- `config_get_default(key, default)` — returns fallback if empty
- `config_get_agent(agent, field)` — agent-specific config
- `config_list_agents()` — all configured agents
- Uses `yq` for YAML parsing, discovers it across common paths

**`lib/state.sh`** — Session state management:
- `state_get_active()` — active session, validates against tmux, falls back
- `state_set_active(name)` — marks session active
- `state_list_sessions()` — reconciled session list
- `state_read_session(name, field)` / `state_write_session(name, field, value)`
- `state_get_cwd(session)` — CWD from tmux pane
- `state_get_agent_type(session)` — matches prefix to config
- `state_rename_session(old, new)` — renames tmux session + state

### No Manifest

The original design included `manifest.json` for persistent session state across reboots. This was dropped in favor of tmux-as-truth. Boot restore (deferred) will need a different approach if revisited.

## Session Lifecycle

```
agent-session-create
  → tmux new-session with agent command
  → registers session-closed hook → _agent-session-cleanup
  → writes initial state file
  → sets as active session

agent-session-overlay (on picker select)
  → updates active session
  → assigns workspace
  → enters AI mode (starts waybar HUD)
  → spawns overlay terminal attached to tmux session

_agent-session-cleanup (tmux hook on session close)
  → removes state file
  → resets active session
  → refreshes waybar
  → exits AI mode if no sessions remain
```

## Hooks

Hooks are agent-specific scripts that fire on agent events to update state and refresh the UI.

Currently implemented: `hooks/claude/`
- `prompt-submit` — sets `state=working`, clears `idle_since`, refreshes waybar + workspace colors
- `stop` — sets `state=idle`, writes `idle_since`, refreshes waybar + workspace colors, optional desktop notification

Hooks export `AGENT_STATE_DIR` so agents can write summary/priority files.
