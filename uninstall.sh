#!/bin/bash
#
# Uninstall attest-claude from ~/.claude/
#
# Removes symlinks and copies created by install.sh.
# Does NOT remove settings.json hooks or CLAUDE.md sections —
# those need manual cleanup if desired.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="$HOME/.claude"

echo ""
echo "Uninstalling attest-claude..."
echo ""

# ─── 1. Remove agent symlinks ───
echo "Removing agents..."
count=0
for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -f "$agent" ] || continue
  target="$CLAUDE_HOME/agents/$(basename "$agent")"
  if [ -L "$target" ]; then
    rm "$target"
    count=$((count + 1))
  fi
done
echo "  $count agent symlinks removed"

# ─── 2. Remove skill symlinks ───
echo "Removing skills..."
count=0
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  target="$CLAUDE_HOME/skills/$skill_name/SKILL.md"
  if [ -L "$target" ]; then
    rm "$target"
    rmdir "$CLAUDE_HOME/skills/$skill_name" 2>/dev/null || true
    count=$((count + 1))
  fi
done
echo "  $count skill symlinks removed"

# ─── 3. Remove reference symlinks ───
echo "Removing references..."
count=0
for ref in "$SCRIPT_DIR/references/"*.md; do
  [ -f "$ref" ] || continue
  target="$CLAUDE_HOME/agents/$(basename "$ref")"
  if [ -L "$target" ]; then
    rm "$target"
    count=$((count + 1))
  fi
done
echo "  $count reference symlinks removed"

# ─── 4. Remove hook copies ───
echo "Removing hooks..."
count=0
for hook in "$SCRIPT_DIR/hooks/"*; do
  [ -f "$hook" ] || continue
  target="$CLAUDE_HOME/hooks/$(basename "$hook")"
  if [ -f "$target" ]; then
    rm "$target"
    count=$((count + 1))
  fi
done
echo "  $count hooks removed"

# ─── 5. Remove install path marker ───
rm -f "$CLAUDE_HOME/.experts-install-path"

echo ""
echo "Uninstall complete."
echo ""
echo "NOTE: settings.json hooks and CLAUDE.md expert section were NOT removed."
echo "Edit these manually if you want to remove them:"
echo "  $CLAUDE_HOME/settings.json"
echo "  $CLAUDE_HOME/CLAUDE.md"
echo ""
