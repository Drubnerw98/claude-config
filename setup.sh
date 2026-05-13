#!/usr/bin/env bash
# Symlink CLAUDE.md and skills from this repo into ~/.claude/.
# Existing files are backed up first so nothing is silently overwritten.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
BACKUP_DIR="$CLAUDE_DIR/backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$CLAUDE_DIR/skills"

backup_if_present() {
  local target="$1"
  if [ -e "$target" ] || [ -L "$target" ]; then
    mkdir -p "$BACKUP_DIR"
    mv "$target" "$BACKUP_DIR/"
    echo "  backed up: $target -> $BACKUP_DIR/"
  fi
}

link() {
  local src="$1"
  local dst="$2"
  ln -s "$src" "$dst"
  echo "  linked: $dst -> $src"
}

echo "Setting up Claude Code config from $REPO_DIR"
echo

echo "CLAUDE.md:"
backup_if_present "$CLAUDE_DIR/CLAUDE.md"
link "$REPO_DIR/CLAUDE.md" "$CLAUDE_DIR/CLAUDE.md"
echo

echo "Skills:"
for skill_dir in "$REPO_DIR/skills"/*/; do
  [ -d "$skill_dir" ] || continue
  name="$(basename "$skill_dir")"
  backup_if_present "$CLAUDE_DIR/skills/$name"
  link "$skill_dir" "$CLAUDE_DIR/skills/$name"
done

echo
if [ -d "$BACKUP_DIR" ]; then
  echo "Existing files were backed up to: $BACKUP_DIR"
fi
echo "Done. Restart Claude Code to pick up the new config."
