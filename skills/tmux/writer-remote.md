# Writer-Remote Mode

For use outside tmux (`$TMUX` is unset). Create and manage detached tmux sessions.

## Workflow

### Step 1: Create a Detached Session

```bash
tmux new-session -d -s claude-work "zsh"
```

This creates a session named `claude-work` with one window and one pane running zsh.

### Step 2: Run Commands

Before sending, verify the pane state. See **"Pre-Send Verification"** in the parent SKILL.md.

```bash
# Send a command
tmux send-keys -t "claude-work:1.1" -l -- 'mix test'
tmux send-keys -t "claude-work:1.1" Enter
```

### Step 3: Add More Panes/Windows

Use `-P -F` to capture the new pane's identity directly from the split:

```bash
# Split the existing pane — -P prints the new pane's info
NEW_PANE=$(tmux split-window -h -t "claude-work:1.1" -P -F '#{session_name}:#{window_index}.#{pane_index}' "zsh")
echo "$NEW_PANE"  # e.g., claude-work:1.2

# Or create a new window
tmux new-window -t "claude-work" "zsh"
```

Do NOT use `list-panes` to discover the new pane — that requires guessing which pane is new and gets it wrong when multiple panes exist.

### Step 4: Wait and Capture

See **"Waiting for Pane Idle"** in the parent SKILL.md for the full pattern. Prefer the `pane_current_command` method.

```bash
# Capture output
tmux capture-pane -t "claude-work:1.1" -p -J -S -500
```

### Step 5: Clean Up

Kill the entire session when done:

```bash
tmux kill-session -t "claude-work"
```

Or kill individual panes:

```bash
tmux kill-pane -t "claude-work:1.2"
```

### Step 6: Tell User How to Attach

If the user wants to interact with the session directly:

```bash
tmux attach -t claude-work
```

## Quick Reference

| Action | Command |
|---|---|
| Create session | `tmux new-session -d -s NAME "zsh"` |
| List sessions | `tmux list-sessions` |
| List panes | `tmux list-panes -t "NAME:1" -F '#{pane_index}: cmd=#{pane_current_command} id=#{pane_id}'` |
| Send command | `tmux send-keys -t "NAME:W.P" -l -- 'command'` then `tmux send-keys -t "NAME:W.P" Enter` |
| Send Ctrl+C | `tmux send-keys -t "NAME:W.P" C-c` |
| Capture output | `tmux capture-pane -t "NAME:W.P" -p -J -S -500` |
| Kill pane | `tmux kill-pane -t "NAME:W.P"` |
| Kill session | `tmux kill-session -t NAME` |
| Attach (for user) | `tmux attach -t NAME` |
