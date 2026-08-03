# Writer-Local Mode

Full pane management inside an existing tmux session. `$TMUX_PANE` is your anchor — all targeting flows from it.

## Precondition

```bash
if [ -z "$TMUX_PANE" ]; then
  echo "ABORT: \$TMUX_PANE empty. Background Claude jobs inherit \$TMUX but not \$TMUX_PANE — tmux defaults targeting to the user's active pane (wrong window). Use writer-remote.md with an explicit -t target."
  exit 1
fi
```

Do not proceed past this check without a non-empty `$TMUX_PANE`.

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
MY_WIN_IDX=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}')
```

### Step 2: Create a Helper Window

**Never split inside Claude's window.** Splitting and then killing a sibling pane resizes Claude's pane mid-render (SIGWINCH), producing ghost input frames. Instead, create a new window in the same session.

Name helper windows with a `[cc]` prefix so the user can identify Claude-driven windows at a glance (e.g., `[cc] mix test`, `[cc] server`).

```bash
# Create helper window — [cc] prefix marks it as Claude-driven
HELPER_NAME="[cc] mix test"   # use a descriptive label for what's running
NEW_WIN_IDX=$(tmux new-window -t "$MY_SESSION" -P -F '#{window_index}' -n "$HELPER_NAME" "zsh")
# Stable pane id — pane index is always 1 in a fresh window
NEW_ID=$(tmux display-message -t "$MY_SESSION:$NEW_WIN_IDX.1" -p '#{pane_id}')
```

The helper window is visible in the status bar (prefixed `[cc]`) but doesn't affect Claude's window geometry — no SIGWINCH, no ghost frames.

For multiple helpers (test runner + server), create additional named windows with the same pattern:
```bash
NEW_WIN_IDX_2=$(tmux new-window -t "$MY_SESSION" -P -F '#{window_index}' -n "[cc] server" "zsh")
NEW_ID_2=$(tmux display-message -t "$MY_SESSION:$NEW_WIN_IDX_2.1" -p '#{pane_id}')
```

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

**REQUIRED** — kill every helper window you created before finishing.

Kill by window index (not pane), since the whole window is yours:

```bash
# Verify output is from your helper before killing
tmux capture-pane -t "$NEW_ID" -p -J -S -5

# Kill the helper window — never kills Claude's window
tmux kill-window -t "$MY_SESSION:$NEW_WIN_IDX"
```

**Self-kill safety**: never kill the window containing `$TMUX_PANE`. Verify:

```bash
MY_WIN_IDX=$(tmux display-message -t "$TMUX_PANE" -p '#{window_index}')
if [ "$NEW_WIN_IDX" = "$MY_WIN_IDX" ]; then
  echo "ERROR: refusing to kill own window"
else
  tmux kill-window -t "$MY_SESSION:$NEW_WIN_IDX"
fi
```

## Quick Reference

| Action | Command |
|---|---|
| Precondition | `[ -z "$TMUX_PANE" ] && { echo "ABORT: bg job, no \$TMUX_PANE"; exit 1; }` |
| Detect location | `tmux display-message -t "$TMUX_PANE" -p '#{session_name}:#{window_index}.#{pane_index}'` |
| Create helper window | `NEW_WIN_IDX=$(tmux new-window -t "$MY_SESSION" -P -F '#{window_index}' -n "[cc] label" "zsh")` |
| Get stable pane id | `NEW_ID=$(tmux display-message -t "$MY_SESSION:$NEW_WIN_IDX.1" -p '#{pane_id}')` |
| List windows | `tmux list-windows -t "$MY_SESSION" -F '#{window_index}: #{window_name}'` |
| Send command | `tmux send-keys -t "$NEW_ID" -l -- 'command'` then `tmux send-keys -t "$NEW_ID" Enter` |
| Send Ctrl+C | `tmux send-keys -t "$NEW_ID" C-c` |
| Send Escape | `tmux send-keys -t "$NEW_ID" Escape` |
| Capture output | `tmux capture-pane -t "$NEW_ID" -p -J -S -500` |
| Kill helper window | `tmux kill-window -t "$MY_SESSION:$NEW_WIN_IDX"` (verify not own window first) |
