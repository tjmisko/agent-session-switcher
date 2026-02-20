# Scripts Reference

## User-Facing Scripts (`bin/`)

### `agent-session-picker`
FZF-based interactive session picker. Launched via keybinding in a floating terminal.

- Color-coded: yellow=working, green=idle (<10min), red=idle (>10min)
- Active session marked with `▸`
- Shows: session name, state, idle duration, CWD
- FZF preview: last 20 lines of session output
- Keybinds: `enter`=attach, `ctrl-n`=create, `ctrl-x`=kill, `ctrl-r`=rename
- Auto-creates first session if none exist
- On select: spawns `agent-session-overlay` in background

### `agent-session-picker-rofi`
Rofi-based alternative picker. Faster rendering, no preview pane.

- Same color coding via Pango/HTML markup
- Loop-based UI with `ctrl+n` (new), `ctrl+x` (kill), `ESC` (cancel)
- Auto-creates first session on empty state
- Debug logging to `/tmp/agent-session-picker-rofi.log`

### `agent-session-overlay`
Opens a session fullscreen on the current workspace.

1. Updates active session state
2. Retrieves or auto-assigns workspace from Hyprland
3. Enters AI mode (starts bottom waybar HUD)
4. Spawns terminal with `tmux attach-session -t <name>`
5. Window class `agent-session-overlay` triggers WM fullscreen rule

### `agent-session-create`
Creates a new agent session.

- Reads agent config (command, prefix, flags, hooks)
- Generates session name with numeric suffix if not provided
- Generates UUID for session tracking
- Builds command args: `<command> --session-id <uuid> --append-system-prompt <prompt>`
- Creates tmux session, registers cleanup hook
- Writes initial state, sets as active

Usage: `agent-session-create [--agent <type>] [--cwd <path>] [--name <name>]`

### `agent-session-queue`
Priority queue view showing sessions sorted by state → priority → idle time.

- Reads `PRIORITY`/`SUMMARY` from session summary files
- Color coded like picker
- Select to set active + jump to workspace
- Launched in floating terminal via keybinding

### `agent-session-cycle`
Cycles through sessions (up/down). Updates active session, jumps to workspace, refreshes waybar.

Usage: `agent-session-cycle up|down`

### `agent-session-jump`
Jumps to the active session's workspace via `hyprctl dispatch workspace`.

### `agent-open-editor`
Opens editor in the active session's CWD.

1. Unfullscreens the overlay window
2. Gets CWD from tmux
3. Spawns editor in new terminal at that CWD
4. Both windows tile side-by-side

### `agent-mode-toggle`
Manages the bottom waybar HUD lifecycle.

- `enter` — starts waybar, writes PID, sets mode=ai
- `exit` — kills waybar, cleans state
- `toggle` — flips
- `refresh` — sends SIGRTMIN+10 to reload

### `agent-waybar-module`
Waybar custom module output (JSON with Pango markup).

- Shows all sessions: `name: state HH:MM:SS`
- Active session bold, working=orange, idle=green, stale=red
- Sets class `has-working` or `all-idle` for CSS styling

## Internal Scripts (`bin/_*`)

### `_agent-session-cleanup`
Called by tmux `session-closed` hook. Idempotent cleanup:
- Removes state file for dead session
- Resets active session pointer
- Refreshes waybar
- Exits AI mode if no sessions remain

### `_agent-session-rename`
Thin wrapper around `state_rename_session()`. Renames tmux session + state file + active pointer. Called from picker with `ctrl-r`.

Usage: `_agent-session-rename <old-name> <new-name>`
