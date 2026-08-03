#!/usr/bin/env bash
#
# Commit and push any local edits to the tmux skill.
#
# Because ~/.claude/skills/tmux symlinks into this repo, editing the skill in
# place leaves the changes sitting in this working tree. This script is meant to
# run unattended on a timer: it notices that drift and pushes it to GitHub.
#
# Safe to run when nothing has changed — it exits without making a commit.

set -euo pipefail

REPO="$HOME/code/tmux-skill-plugin"
LOG="$HOME/.claude/logs/tmux-skill-sync.log"
BRANCH="main"

mkdir -p "$(dirname "$LOG")"
exec >>"$LOG" 2>&1

log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

cd "$REPO" || { log "ERROR: $REPO not found"; exit 1; }

# Only ever touch the skill directory. An unattended push must not pick up
# unrelated edits that happen to be sitting in the working tree.
if [ -z "$(git status --porcelain -- skills/)" ]; then
  exit 0
fi

# Refuse to run from a detached HEAD or a feature branch — pushing either
# unattended would put commits somewhere unexpected.
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$BRANCH" ]; then
  log "SKIP: on '$current_branch', expected '$BRANCH'"
  exit 0
fi

changed=$(git status --porcelain -- skills/ | awk '{print $2}' | xargs -n1 basename | paste -sd', ' -)
log "drift detected: $changed"

git add -- skills/
git commit --quiet -m "Update tmux skill: $changed"

# Rebase after committing, not before: git refuses to rebase with unstaged
# changes present. Bail out rather than leaving a half-finished rebase behind.
git fetch --quiet origin "$BRANCH"
if ! git rebase --quiet "origin/$BRANCH" >/dev/null 2>&1; then
  git rebase --abort 2>/dev/null || true
  log "ERROR: rebase onto origin/$BRANCH failed — commit is local, resolve by hand"
  exit 1
fi

if git push --quiet origin "$BRANCH"; then
  log "pushed $(git rev-parse --short HEAD)"
else
  log "ERROR: push failed — commit is local at $(git rev-parse --short HEAD)"
  exit 1
fi
