# Writer-Local Mode

Full pane management inside an existing tmux session. `$TMUX_PANE` is your anchor — all targeting flows from it.

## Workflow

### Step 1: Detect Your Window

On the **first tmux call in a conversation**, detect your location:

```bash
tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index} | #{window_width}x#{window_height}'
```

Save your **session name**, **window index**, and **pane index**. All subsequent commands target panes within this window only.

Build your window target:

```bash
MY_WINDOW=$(tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}')
```

### Step 2: Split Your Window

Always create a new pane via split. Always target `$TMUX_PANE` so the split happens in your window regardless of user focus.

**Always split with `zsh`** — if you split with a command directly and it errors, the pane closes immediately and you lose all output.

Choose orientation based on window dimensions:
- **Landscape** (`width > height * 2.5`): `-h` (vertical split)
- **Portrait/square**: `-v` (horizontal split)

```bash
# Split in YOUR window
tmux split-window -h -t "$TMUX_PANE" "zsh"
```

Discover the new pane:

```bash
tmux list-panes -t "$MY_WINDOW" -F '#{pane_index}: cmd=#{pane_current_command} id=#{pane_id} active=#{pane_active}'
```

Save the new pane's full target (e.g., `main:2.3`) for all subsequent commands.

If you need multiple panes (test runner + server), split again using `-t "$TMUX_PANE"`.

### Step 3: Run Commands

Before sending, verify the pane state. See **"Pre-Send Verification"** in the parent SKILL.md.

Use `send-keys` with literal mode (`-l`) for safe text delivery. Always append `Enter` separately.

```bash
# Send a command to the new pane
tmux send-keys -t "main:2.3" -l -- 'mix test test/my_test.exs'
tmux send-keys -t "main:2.3" Enter
```

Why `-l --`:
- `-l` disables key name lookup (prevents `C-c` from becoming Ctrl+C)
- `--` stops option parsing (prevents text starting with `-` from being parsed as flags)

To send special keys (Ctrl+C, Escape), use `send-keys` *without* `-l`:

```bash
# Interrupt a running process
tmux send-keys -t "main:2.3" C-c

# Send Escape
tmux send-keys -t "main:2.3" Escape
```

### Step 4: Wait for Completion

See **"Waiting for Pane Idle"** in the parent SKILL.md for the full pattern. Prefer the `pane_current_command` method.

### Step 5: Capture Output

```bash
# Capture visible output plus scrollback (joined lines)
tmux capture-pane -t "main:2.3" -p -J -S -500
```

Flags:
- `-p` — print to stdout (instead of paste buffer)
- `-J` — join wrapped lines
- `-S -500` — start 500 lines back in scrollback

### Step 6: Clean Up

**REQUIRED** — kill every pane you created before finishing.

```bash
# Verify the pane is still yours
tmux capture-pane -t "main:2.3" -p -J -S -20

# If output matches what you sent, kill it
tmux kill-pane -t "main:2.3"
```

**Self-kill safety**: never kill `$TMUX_PANE` — that's your own pane. Before killing, verify:

```bash
TARGET="main:2.3"
if [ "$TARGET" = "$TMUX_PANE" ]; then
  echo "ERROR: refusing to kill own pane"
else
  tmux kill-pane -t "$TARGET"
fi
```

Note: `$TMUX_PANE` uses the `%N` format (e.g., `%17`), not `session:window.pane`. To compare properly:

```bash
TARGET_ID=$(tmux display-message -t "main:2.3" -p '#{pane_id}')
if [ "$TARGET_ID" = "$TMUX_PANE" ]; then
  echo "ERROR: refusing to kill own pane"
else
  tmux kill-pane -t "main:2.3"
fi
```

## Quick Reference

| Action | Command |
|---|---|
| Detect location | `tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}'` |
| Split horizontal | `tmux split-window -h -t "$TMUX_PANE" "zsh"` |
| Split vertical | `tmux split-window -v -t "$TMUX_PANE" "zsh"` |
| List panes | `tmux list-panes -t "$MY_WINDOW" -F '#{pane_index}: cmd=#{pane_current_command} id=#{pane_id}'` |
| Send command | `tmux send-keys -t "PANE" -l -- 'command'` then `tmux send-keys -t "PANE" Enter` |
| Send Ctrl+C | `tmux send-keys -t "PANE" C-c` |
| Send Escape | `tmux send-keys -t "PANE" Escape` |
| Capture output | `tmux capture-pane -t "PANE" -p -J -S -500` |
| Kill pane | `tmux kill-pane -t "PANE"` (verify ownership first) |
