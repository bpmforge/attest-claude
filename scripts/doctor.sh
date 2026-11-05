#!/usr/bin/env bash
#
# doctor.sh — post-install self-check for Claude Experts.
#
# Run after ./install.sh (or anytime something feels broken):
#   ~/.claude/scripts/doctor.sh
#
# Exit codes: 0 = healthy, 1 = FAIL items present.

set -u

DIR="${1:-$HOME/.claude}"
PASS=0; WARN=0; FAIL=0

ok()   { printf '  \033[32m[PASS]\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
warn() { printf '  \033[33m[WARN]\033[0m %s\n' "$1"; WARN=$((WARN+1)); }
bad()  { printf '  \033[31m[FAIL]\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }

echo "Claude Experts — doctor"
echo "Checking install at: $DIR"
echo ""

# ── 1. Install structure ────────────────────────────────────────────────
echo "Install structure:"
[ -d "$DIR" ] && ok "install dir exists" || { bad "install dir missing — run ./install.sh"; echo "RESULT: $PASS pass, $WARN warn, $FAIL fail"; exit 1; }
for d in agents skills scripts hooks; do
  [ -d "$DIR/$d" ] && ok "$d/ present" || bad "$d/ missing — re-run ./install.sh"
done

AGENT_COUNT=$(find "$DIR/agents" -maxdepth 1 -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
[ "$AGENT_COUNT" -ge 30 ] && ok "primary agents: $AGENT_COUNT (expect 30+)" || bad "only $AGENT_COUNT primary agents (expect 30+)"

for p in LOOP_PREVENTION CONTEXT_BUDGET BOUNDED_TASK_CONTRACT HANDOFF_TEMPLATES EXECUTOR_SELECTION MODEL_ADAPTER; do
  [ -e "$DIR/agents/shared/$p.md" ] && ok "protocol $p.md present" || bad "agents/shared/$p.md missing"
done

[ -d "$DIR/agents/game" ] && ok "game cluster installed" || warn "agents/game/ missing — re-run ./install.sh for the game-dev experts"
[ -d "$DIR/agents/compact" ] && warn "stale agents/compact/ present (duplicate registrations) — rm -rf $DIR/agents/compact" || ok "no stale compact/ dir"

# Broken symlinks (install symlinks repo files — moving the repo breaks them)
BROKEN=$(find "$DIR/agents" -type l ! -exec test -e {} \; -print 2>/dev/null | wc -l | tr -d ' ')
[ "$BROKEN" -eq 0 ] && ok "no broken agent symlinks" || bad "$BROKEN broken agent symlinks — repo moved/deleted? Re-clone and re-run ./install.sh"

VAL_COUNT=$(find "$DIR/scripts/validators" -name "validate-*.sh" 2>/dev/null | wc -l | tr -d ' ')
[ "$VAL_COUNT" -ge 40 ] && ok "validators: $VAL_COUNT (expect 40+)" || warn "validators: $VAL_COUNT (expect 40+) — re-run ./install.sh"

TI_COUNT=$(find "$DIR/scripts/test" -name "*.mjs" 2>/dev/null | wc -l | tr -d ' ')
[ "$TI_COUNT" -ge 5 ] && ok "test-impact scripts: $TI_COUNT (map/select/ledger/resolve/common)" || warn "test-impact scripts: $TI_COUNT (expect 5) — validate-tests.sh falls back to full runs; re-generate from attest"

HOOK_COUNT=$(find "$DIR/hooks" -type f 2>/dev/null | wc -l | tr -d ' ')
[ "$HOOK_COUNT" -ge 5 ] && ok "hooks: $HOOK_COUNT installed" || warn "hooks: $HOOK_COUNT (expect 9)"

# ── 2. Runtime ──────────────────────────────────────────────────────────
echo ""
echo "Runtime:"
if command -v claude >/dev/null 2>&1; then
  ok "claude CLI: $(claude --version 2>/dev/null | head -1)"
else
  bad "claude CLI not found — install: https://claude.com/claude-code"
fi
command -v node >/dev/null 2>&1 && ok "node: $(node --version)" || warn "node missing (build-agents tooling needs it)"
command -v git  >/dev/null 2>&1 && ok "git present" || bad "git missing"
command -v semgrep >/dev/null 2>&1 && ok "semgrep: $(semgrep --version 2>/dev/null | head -1)" || warn "semgrep missing — security scans degraded (brew install semgrep)"
[ -d "$DIR/.semgrep" ] && ok "custom semgrep rules installed" || warn "$DIR/.semgrep missing — re-run ./install.sh"

# ── 3. MCP servers ──────────────────────────────────────────────────────
echo ""
echo "MCP servers (claude mcp list):"
if command -v claude >/dev/null 2>&1; then
  MCPS=$(claude mcp list 2>/dev/null || true)
  if [ -n "$MCPS" ]; then
    for m in memory code-search context7; do
      echo "$MCPS" | grep -qi "$m" && ok "MCP: $m registered" || warn "MCP: $m not registered (see docs/MCP_GUIDE.md)"
    done
    # Node-built servers: probe initialize with the registered command. A server built
    # under a pinned Node (.nvmrc) does not load under another major on PATH.
    for m in memory code-search; do
      echo "$MCPS" | grep -qi "$m" || continue
      cmdline=$(claude mcp get "$m" 2>/dev/null | grep -iE '^ *(command|args)' | tr '\n' ' ' | sed -E 's/ *(Command|Args): */ /g; s/^ +//')
      bin=$(printf '%s' "$cmdline" | awk '{print $1}'); entry=$(printf '%s' "$cmdline" | awk '{print $2}')
      [ -n "$entry" ] && [ -f "$entry" ] || continue
      if printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"doctor","version":"1"}}}' \
         | "$bin" "$entry" 2>/dev/null | head -c 2000 | grep -q '"serverInfo"'; then
        ok "MCP: $m responds to initialize ($("$bin" -v 2>/dev/null))"
      else
        sdir=$(dirname "$entry"); while [ "$sdir" != "/" ] && [ ! -f "$sdir/package.json" ]; do sdir=$(dirname "$sdir"); done
        pin=""; for f in .nvmrc .node-version; do [ -f "$sdir/$f" ] && pin=$(tr -d 'v \n\r' < "$sdir/$f"); done
        if [ -n "$pin" ] && [ "$("$bin" -p 'process.versions.node.split(".")[0]' 2>/dev/null)" != "${pin%%.*}" ]; then
          bad "MCP: $m does not respond — server pins Node $pin but is registered with $bin ($("$bin" -v 2>/dev/null)); re-run ./install.sh"
        else
          bad "MCP: $m registered but does not respond — try: $bin $entry"
        fi
      fi
    done
  else
    warn "claude mcp list returned nothing — MCPs unregistered or CLI needs auth"
  fi
fi

# ── Code-analysis tools ─────────────────────────────────────────────────
echo ""
echo "Code-analysis tools (optional — agents fall back to grep):"
TOOLS_PRESENT=0; TOOLS_TOTAL=0
for tool in semgrep knip ts-prune jscpd vulture radon lizard staticcheck trufflehog; do
  TOOLS_TOTAL=$((TOOLS_TOTAL+1))
  if command -v "$tool" >/dev/null 2>&1; then ok "$tool present"; TOOLS_PRESENT=$((TOOLS_PRESENT+1)); fi
done
if [ "$TOOLS_PRESENT" -lt "$TOOLS_TOTAL" ]; then
  warn "$TOOLS_PRESENT/$TOOLS_TOTAL analysis tools present — run scripts/check-tools.sh, or ./install.sh --tools to add the easy ones"
fi

# ── Summary ─────────────────────────────────────────────────────────────
echo ""
echo "RESULT: $PASS pass, $WARN warn, $FAIL fail"
if [ "$FAIL" -gt 0 ]; then
  echo "Status: BROKEN — fix [FAIL] items above."
  exit 1
elif [ "$WARN" -gt 0 ]; then
  echo "Status: FUNCTIONAL — [WARN] items are optional features."
else
  echo "Status: HEALTHY"
fi
exit 0
