---
name: tmux
description: Control CLI applications running in tmux panes - launch programs, send input, capture output, and manage interactive sessions. Use when needing to run commands in separate panes, interact with CLI tools, or execute long-running processes in the background.
model: sonnet
effort: high
---

# tmux - Pane Management with Raw tmux Commands

No external dependencies. All commands use raw `tmux` directly.

## Mode Selection

1. **Read-only request** (watch, read, monitor, check, capture) → read `observer.md`
2. **Run commands or manage panes:**
   - `$TMUX` set AND `$TMUX_PANE` non-empty → read `writer-local.md`
   - `$TMUX` set AND `$TMUX_PANE` empty → **background job**: you are not inside an interactive tmux client. `tmux` commands without `-t` (or with `-t ""`) default to whatever pane the user is currently focused on, which is almost always a different window. Refuse to split blind. Either (a) require an explicit `session:window.pane` target supplied by the caller / discovered from `tmux ls`, or (b) fall back to `writer-remote.md` patterns. Never invoke `tmux split-window -t "$TMUX_PANE"` in this state.
   - `$TMUX` unset → read `writer-remote.md`

Check at the top of every writer flow:

```bash
if [ -n "$TMUX" ] && [ -z "$TMUX_PANE" ]; then
  echo "ABORT: \$TMUX set but \$TMUX_PANE empty (background job). Pass explicit -t <session>:<window>.<pane> target."
  exit 1
fi
```

## Shared Rules (Apply to ALL Modes)

### Targeting Mandate

**Every `tmux` command MUST use `-t` with an explicit target.** Never rely on default targeting — it hits the *active* pane (whatever the user is looking at), not yours.

```bash
# WRONG: targets whatever pane the user is looking at
tmux display-message -p '#{window_index}'

# RIGHT: targets YOUR pane
tmux display-message -t "$TMUX_PANE" -p '#{window_index}'
```

### Pane Identification Format

Always use full `session:window.pane` format for pane references (e.g., `main:2.3`). When reporting panes to the user, use this format.

### Window Isolation

- Each Claude session owns exactly one window
- NEVER send commands to panes in other windows
- NEVER reuse an existing pane you didn't create — always split a new one

### `!` Escaping

Zsh escapes `!` to `\!`, silently breaking bang functions (`Repo.get!`) and inequality operators (`!=`). Workarounds:
- Use non-bang alternatives (`Repo.get` instead of `Repo.get!`)
- For filters with `!=`, write to a file and pipe in
- For Elixir, use `not Decimal.equal?(a, b)` instead of `a != b`

### Waiting for Pane Idle

Use `pane_current_command` to detect when a command finishes — not md5 checksums. The md5 approach fails on long-running commands because output keeps changing until the command finishes, then the loop has already timed out.

Every wait loop MUST have a timeout. When the loop expires, capture the pane and decide what to do — don't silently fall through or retry blindly.

**Primary method** — poll `pane_current_command` until it returns to the shell (`zsh`, `bash`) or REPL (`iex`, `python3`, etc.):

```bash
EXPECTED="zsh"  # or "iex", "python3", etc.
TIMEOUT=60      # seconds
INTERVAL=3
TIMED_OUT=true
for i in $(seq 1 $((TIMEOUT / INTERVAL))); do
  CMD=$(tmux display-message -t "PANE" -p '#{pane_current_command}')
  if [ "$CMD" = "$EXPECTED" ]; then TIMED_OUT=false; break; fi
  sleep "$INTERVAL"
done
if [ "$TIMED_OUT" = true ]; then
  echo "TIMEOUT: pane still showing '$CMD' after ${TIMEOUT}s"
  tmux capture-pane -t "PANE" -p -J -S -5
fi
```

**Wrapper commands** — `kubectl exec`, `ssh`, `docker exec`, etc. run a REPL inside a remote process. tmux only sees the top-level command (`kubectl`, `ssh`, `docker`), not what's running inside. `pane_current_command` never changes, so the primary method hangs forever. Use prompt-matching instead.

**Fallback** — for wrapper commands or when you don't know the expected command name, grep the last few lines for a known prompt pattern:

```bash
PROMPT_PATTERN="^iex\\("  # or "^>>>", "❯"
TIMEOUT=60
INTERVAL=3
TIMED_OUT=true
for i in $(seq 1 $((TIMEOUT / INTERVAL))); do
  if tmux capture-pane -t "PANE" -p -S -3 | grep -qE "$PROMPT_PATTERN"; then TIMED_OUT=false; break; fi
  sleep "$INTERVAL"
done
if [ "$TIMED_OUT" = true ]; then
  echo "TIMEOUT: prompt pattern not found after ${TIMEOUT}s"
  tmux capture-pane -t "PANE" -p -J -S -5
fi
```

Common prompt patterns:
- IEx: `^iex\(`
- Python: `^>>>`
- Shell prompt: `❯` or `\$\s*$`

**Last resort** — md5 checksum on the last few lines. Use only when you can't predict the prompt:

```bash
TIMEOUT=60
INTERVAL=3
PREV=""
TIMED_OUT=true
for i in $(seq 1 $((TIMEOUT / INTERVAL))); do
  CURR=$(tmux capture-pane -t "PANE" -p -S -3 | md5)
  if [ "$CURR" = "$PREV" ]; then TIMED_OUT=false; break; fi
  PREV="$CURR"; sleep "$INTERVAL"
done
if [ "$TIMED_OUT" = true ]; then
  echo "TIMEOUT: pane output still changing after ${TIMEOUT}s"
  tmux capture-pane -t "PANE" -p -J -S -5
fi
```

Key points:
- Every loop MUST set `TIMEOUT` appropriate to the expected duration
- On timeout, always capture the pane and report what you see — don't retry the same loop
- `pane_current_command` is the fastest and most reliable — use it when the command runs directly in the pane
- For wrapper commands (`kubectl exec`, `ssh`, `docker exec`), always use prompt-matching
- Always scope `-S` to a small number of lines (`-S -3` to `-S -5`) — full buffer md5 is unreliable

### Pre-Send Verification

Before every `send-keys`, capture the last line of the target pane and confirm it shows the expected prompt. REPLs can time out or crash, dropping the pane back to zsh — sending REPL syntax to a shell prompt causes zsh to execute it as shell commands.

```bash
LAST_LINE=$(tmux capture-pane -t "PANE" -p -S -1)
```

Check `LAST_LINE` against the expected prompt pattern for the session type:
- IEx: `^iex\(`
- Python: `^>>>`
- Shell: `❯` or `\$\s*$`

**Hard rule: if the prompt doesn't match, STOP. Don't send.** Diagnose what happened — capture more context with `-S -5`, check `pane_current_command`, and restart the REPL if needed.

### Large Output Flooding

Commands producing hundreds of lines flood the capture buffer.
- Start small — `LIMIT 5`, `head -20`
- Redirect to file: `command > /tmp/output.json`
- Parse with `jq`, `grep`, or `wc -l` on the file

### Pane Base Index

The tmux config sets `pane-base-index 1`. Panes start at `.1` — `.0` does not exist. Always discover actual pane IDs before sending commands.

### Cleanup

Kill every pane you created before finishing. No orphaned panes. Verify ownership with `capture-pane` before killing — if output doesn't match what you sent, leave it alone.
