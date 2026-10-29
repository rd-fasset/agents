#!/bin/bash
# Copies the scheduled task's prompt to where the Claude app reads it. The app refuses a symlinked
# task file, so this is a plain copy; the git hooks in ../githooks run this after every commit and pull.
# (The /va skill is fine as a symlink: ~/.claude/skills/va -> skill/.)
#
# Install:          bash install.sh
# Also enable hooks: bash install.sh --hooks   (sets core.hooksPath for the agents repo)

set -e
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

install_file() {
  local src="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  # Never write through a symlink: replace it with a real file.
  [ -L "$dest" ] && rm "$dest"
  [ -L "$(dirname "$dest")" ] && { echo "va install: $(dirname "$dest") is a symlink; remove it first." >&2; exit 1; }
  if cmp -s "$src" "$dest"; then
    echo "va install: $dest up to date."
    return
  fi
  cp "$src" "$dest.tmp" && mv "$dest.tmp" "$dest"
  if [ -L "$dest" ] || ! cmp -s "$src" "$dest"; then
    echo "va install: $dest does not match $src after copying." >&2
    exit 1
  fi
  echo "va install: updated $dest."
}

install_file "$HERE/scheduled-task/SKILL.md" "$HOME/.claude/scheduled-tasks/va-check/SKILL.md"

if [ "${1:-}" = "--hooks" ]; then
  git -C "$HERE/.." config core.hooksPath githooks
  echo "va install: git hooks enabled (core.hooksPath=githooks)."
fi
