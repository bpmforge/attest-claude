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

# ─── 4b. Remove every other link install.sh made ───
# Steps 1-4 predate the agent sub-clusters, agents/shared/, exemplars/,
# scripts/ (+ validators/) and .semgrep — an uninstall left ~100 script links
# and the exemplars behind. Rather than mirror each install step, remove every
# symlink under ~/.claude that points into THIS checkout: that is exactly what
# install.sh created, and never touches a user's own files.
echo "Removing remaining attest-claude links..."
count=0
for area in agents skills exemplars scripts; do
  [ -d "$CLAUDE_HOME/$area" ] || continue
  while IFS= read -r link; do
    case "$(readlink "$link")" in
      "$SCRIPT_DIR"/*) rm "$link"; count=$((count + 1)) ;;
    esac
  done < <(find "$CLAUDE_HOME/$area" -type l 2>/dev/null)
done
if [ -L "$CLAUDE_HOME/.semgrep" ]; then
  case "$(readlink "$CLAUDE_HOME/.semgrep")" in
    "$SCRIPT_DIR"/*) rm "$CLAUDE_HOME/.semgrep"; count=$((count + 1)) ;;
  esac
fi
echo "  $count links removed"

# --compact overlays are copies, not links.
if [ -d "$SCRIPT_DIR/dist/compact-agents" ]; then
  for f in "$SCRIPT_DIR"/dist/compact-agents/*.md; do
    target="$CLAUDE_HOME/agents/$(basename "$f")"
    [ -f "$target" ] && [ ! -L "$target" ] && rm "$target"
  done
fi

# Directories install.sh created and left empty (rmdir never removes content).
for area in agents skills exemplars scripts; do
  [ -d "$CLAUDE_HOME/$area" ] || continue
  find "$CLAUDE_HOME/$area" -mindepth 1 -depth -type d -empty -exec rmdir {} \; 2>/dev/null || true
  rmdir "$CLAUDE_HOME/$area" 2>/dev/null || true
done

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
