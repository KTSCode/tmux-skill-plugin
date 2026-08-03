# Observer Mode

Read-only pane interaction. No `send-keys`, no `split-window`, no `kill-pane`.

## Allowed Commands

- `capture-pane` — read output from a pane
- `list-panes` — list panes with status info
- `display-message` — query pane/window/session properties

## All Commands Require `-t`

```bash
# Capture output from a specific pane (joined, with scrollback)
tmux capture-pane -t "main:2.3" -p -J -S -500

# List panes in a specific window
tmux list-panes -t "main:2" -F '#{pane_index}: cmd=#{pane_current_command} id=#{pane_id} active=#{pane_active}'

# Query a property of a specific pane
tmux display-message -t "main:2.1" -p '#{pane_current_command}'
```

## Inside tmux

Use `$TMUX_PANE` to scope to your own window:

```bash
# Get your window target
MY_WINDOW=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}')

# List panes in your window
tmux list-panes -t "$MY_WINDOW" -F '#{pane_index}: cmd=#{pane_current_command} id=#{pane_id}'

# Capture a sibling pane
tmux capture-pane -t "${MY_WINDOW}.2" -p -J -S -500
```

## Outside tmux

Requires explicit `session:window.pane` target — no `$TMUX_PANE` available.

```bash
# List all sessions
tmux list-sessions

# List panes in a specific session/window
tmux list-panes -t "main:1" -F '#{pane_index}: cmd=#{pane_current_command} id=#{pane_id}'

# Capture output
tmux capture-pane -t "main:1.2" -p -J -S -500
```
