# tmux-skill

A Claude Code skill for controlling CLI applications running in tmux panes. Launch programs, send input, capture output, and manage interactive sessions — all from Claude Code.

## Features

- **Three operating modes** selected automatically based on context:
  - **Observer** — read-only pane monitoring (capture output, list panes, query properties)
  - **Writer-Local** — full pane management inside an existing tmux session
  - **Writer-Remote** — session creation and management from outside tmux
- Safe pane targeting with explicit `-t` on every command
- Window isolation — each Claude session owns exactly one window
- Built-in wait loops for command completion detection
- Automatic cleanup of created panes

## Install

### As a Claude Code plugin

```bash
# Clone the repo
git clone https://github.com/kylesanclemente/tmux-skill-plugin.git

# Copy the skill into your Claude Code skills directory
cp -r tmux-skill-plugin/skills/tmux ~/.claude/skills/
```

### Required permissions

Add to your `~/.claude/settings.json`:

```json
{
  "permissions": {
    "allow": [
      "Bash(tmux:*)"
    ]
  }
}
```

## How it works

The skill automatically selects a mode based on your request and environment:

1. **Read-only requests** (watch, read, monitor, check, capture) use Observer mode
2. **Run/manage commands:**
   - Inside tmux (`$TMUX` is set) uses Writer-Local mode
   - Outside tmux (`$TMUX` is unset) uses Writer-Remote mode

## License

MIT
