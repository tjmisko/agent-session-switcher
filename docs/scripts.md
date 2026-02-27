# Scripts Reference

## User-Facing Scripts (`bin/`)

### `agent-session-terminal`
Wrapper process that runs inside the single `agentTerminal` window. Loops between the fzf picker (floating) and tmux attach (fullscreen).

1. Writes TTY and PID to state dir for external control
2. Enters AI mode (starts bottom waybar HUD)
3. Shows fzf picker — blocks until selection or ESC
4. On select: goes fullscreen, attaches tmux session (blocks until detach)
5. On detach: unfullscreens, loops back to picker
6. ESC exits the loop, cleans up state, exits AI mode

### `agent-session-toggle`
Mod+A handler. 4-state toggle for the `agentTerminal` window:

1. **No terminal** — spawns `agent-session-terminal` in a floating wezterm window
2. **Fullscreen (in session)** — detaches tmux client via TTY, unfullscreens
3. **Floating (picker visible)** — hides to Hyprland special workspace
4. **On special workspace** — brings back, triggers fzf reload via `--listen` HTTP POST

### `agent-session-picker`
FZF-based interactive session picker.

- Color-coded: yellow=working, green=idle (<10min), red=idle (>10min)
- Active session marked with `▸`
- Shows: session name, state, idle duration, CWD
- FZF preview: last 20 lines of session output
- Keybinds: `enter`=attach, `ctrl-n`=create+reload, `ctrl-x`=kill, `ctrl-r`=rename

Flags:
- `--list` — print session list (for fzf reload)
- `--select` — run picker, print selected UUID to stdout (used by `agent-session-terminal`)
- `--fzf-listen PORT` — enable fzf's `--listen` on the given port

### `agent-session-picker-rofi`
Rofi-based alternative picker. Faster rendering, no preview pane.

- Same color coding via Pango/HTML markup
- Loop-based UI with `ctrl+n` (new), `ctrl+x` (kill), `ESC` (cancel)
- Switches tmux session via `tmux switch-client` to the wrapper's TTY

### `agent-session-create`
Creates a new agent session.

- Reads agent config (command, prefix, flags, hooks)
- Generates session name with numeric suffix if not provided
- Generates UUID for session tracking
- Builds command args: `<command> --session-id <uuid> --append-system-prompt <prompt>`
- Creates tmux session, registers cleanup hook
- Writes initial state, sets as active

Usage: `agent-session-create [agent] [cwd] [name]`

### `agent-session-queue`
Priority queue view showing sessions sorted by state → priority → idle time.

- Reads `PRIORITY`/`SUMMARY` from session summary files
- Color coded like picker
- Select to set active + jump to workspace
- Launched in floating terminal via keybinding

### `agent-session-cycle`
Cycles through sessions (up/down). Switches tmux session in-place via `tmux switch-client` — the terminal stays fullscreen, no detach/reattach.

Usage: `agent-session-cycle up|down`

### `agent-session-jump`
Focuses the `agentTerminal` window via `hyprctl dispatch focuswindow`.

### `agent-open-editor`
Opens editor in the active session's CWD.

1. Unfullscreens the `agentTerminal` window (by class)
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
Called by tmux `session-closed` hook. Marks session state=dead, writes dead_since timestamp. Preserves state dir for resume.
- Marks session `state=dead` with `dead_since` timestamp
- Resets active session pointer if it was the active session
- Refreshes waybar
- Exits AI mode if no sessions remain

### `_agent-session-rename`
Thin wrapper around `state_rename_session()`. Renames tmux session only. UUID and state dir are stable — no state migration needed. Called from picker with `ctrl-r`.

Usage: `_agent-session-rename <old-name> <new-name>`
