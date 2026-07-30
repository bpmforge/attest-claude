#!/bin/bash
#
# Install attest-claude globally for all Claude Code sessions
#
# Symlinks agents, skills, hooks, and references into ~/.claude/
# so they're available in every project. Edits to this repo
# automatically update the installed files (symlinks).
#

set -e

# Platform preflight — supported: macOS, Linux, WSL. NOT supported: native Windows.
case "$(uname -s)" in
  Darwin|Linux) ;;  # supported
  MINGW*|MSYS*|CYGWIN*)
    echo "ERROR: Native Windows (Git Bash / MSYS / Cygwin) is not supported." >&2
    echo "" >&2
    echo "Please install WSL2 and run the installer from inside your WSL shell:" >&2
    echo "  https://learn.microsoft.com/en-us/windows/wsl/install" >&2
    echo "" >&2
    echo "Then from inside WSL:" >&2
    echo "  git clone https://github.com/bpmforge/attest-claude.git" >&2
    echo "  cd attest-claude && ./install.sh" >&2
    exit 2
    ;;
  *)
    echo "WARNING: unrecognized platform $(uname -s). Proceeding anyway." >&2
    ;;
esac

if grep -qi microsoft /proc/version 2>/dev/null; then
  echo "Detected: Windows Subsystem for Linux (WSL). Proceeding."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_HOME="$HOME/.claude"

# ─── Node version check ───────────────────────────────────────────────────────
# MCPs require Node 20–24 (LTS). Older versions lack required APIs; Node 25+
# are pre-release and may have native module incompatibilities (better-sqlite3).
check_node_version() {
  # Load nvm if available (it's a shell function, not a binary)
  # shellcheck disable=SC1090
  [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" --no-use 2>/dev/null || true

  if ! command -v node &>/dev/null; then
    echo ""
    echo "  ⚠️  node not found."
    _offer_nvm_install
    return
  fi

  local version major
  version=$(node --version 2>/dev/null | tr -d 'v')
  major=$(echo "$version" | cut -d. -f1)

  if [ "$major" -ge 20 ] && [ "$major" -le 24 ] 2>/dev/null; then
    echo "  Node $version ✓"
    return
  fi

  echo ""
  if [ "$major" -lt 20 ] 2>/dev/null; then
    echo "  ⚠️  Node $version is too old — MCPs require Node 20+ (better-sqlite3 native bindings)."
  else
    echo "  ⚠️  Node $version is a pre-release/unsupported version — recommend Node 24 LTS for compatibility."
  fi

  _offer_nvm_switch "$major"
}

_offer_nvm_install() {
  if [ ! -t 0 ]; then
    echo "     Install Node 20+ then re-run install.sh."
    return
  fi
  printf "  Install NVM and Node 24 LTS now? [Y/n]: "
  read -r yn </dev/tty
  yn="${yn:-Y}"
  case "$yn" in [Yy]*)
    echo "  Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash 2>&1 | tail -3
    # shellcheck disable=SC1090
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" 2>/dev/null || true
    nvm install 24 && nvm use 24 && nvm alias default 24
    echo "  Node $(node --version) active via NVM ✓"
    ;;
  *)
    echo "  Skipping — MCPs will be unavailable until Node 20+ is installed."
    ;;
  esac
}

_offer_nvm_switch() {
  local current_major="$1"
  if [ ! -t 0 ]; then
    echo "     Run: nvm install 24 && nvm use 24"
    return
  fi
  printf "  Switch to Node 24 LTS via NVM? [Y/n]: "
  read -r yn </dev/tty
  yn="${yn:-Y}"
  case "$yn" in [Yy]*)
    # shellcheck disable=SC1090
    [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" 2>/dev/null || true
    if command -v nvm &>/dev/null; then
      nvm install 24 2>&1 | tail -2
      nvm use 24
      nvm alias default 24
      echo "  Node $(node --version) active via NVM ✓"
    else
      echo "  NVM not found — installing it first..."
      curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash 2>&1 | tail -3
      # shellcheck disable=SC1090
      [ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh" 2>/dev/null || true
      nvm install 24 && nvm use 24 && nvm alias default 24
      echo "  Node $(node --version) active via NVM ✓"
    fi
    ;;
  *)
    echo "  Skipping — continuing with Node $current_major (may cause build failures)."
    ;;
  esac
}

echo ""
echo -n "Checking Node version... "
check_node_version
# ─────────────────────────────────────────────────────────────────────────────
INSTALL_PWS=true
INSTALL_PLAYWRIGHT_MCP=true
INSTALL_MEMORY=true
INSTALL_CODE_SEARCH=true
INTERACTIVE=false

for arg in "$@"; do
  case $arg in
    --no-playwright-search) INSTALL_PWS=false ;;
    --no-playwright-mcp)    INSTALL_PLAYWRIGHT_MCP=false ;;
    --no-memory)            INSTALL_MEMORY=false ;;
    --tools)                INSTALL_TOOLS=true ;;
    --compact)               COMPACT_AGENTS=true ;;
    --no-code-search)       INSTALL_CODE_SEARCH=false ;;
    --yes|-y)               INTERACTIVE=false ;;  # accept all defaults non-interactively
    --help|-h)
      echo "attest-claude — Installation"
      echo ""
      echo "Usage:"
      echo "  ./install.sh                 Interactive — prompts for optional MCPs"
      echo "  ./install.sh --yes           Accept all defaults (non-interactive)"
      echo "  ./install.sh --no-memory     Skip bpm-memory-mcp"
      echo "  ./install.sh --no-code-search  Skip bpm-code-search-mcp"
      echo "  ./install.sh --no-playwright-search  Skip playwright-search"
      echo "  ./install.sh --no-playwright-mcp     Skip playwright-mcp"
      exit 0
      ;;
  esac
done

# ─── Interactive prompts (when run with no flags from a terminal) ───
if [ $# -eq 0 ] && [ -t 0 ]; then
  echo ""
  echo "attest-claude v1.4.0 — Installation"
  echo "====================================="
  echo ""
  echo "Core install (always): agents, skills, shared protocols, hooks, scripts, semgrep rules"
  echo ""
  echo "Optional MCPs:"
  echo ""

  prompt_yn() {
    local msg="$1" default="$2" varname="$3"
    local yn
    printf "  %s [%s]: " "$msg" "$default"
    read -r yn </dev/tty
    yn="${yn:-$default}"
    case "$yn" in
      [Yy]*) eval "$varname=true" ;;
      [Nn]*) eval "$varname=false" ;;
      *)     eval "$varname=$( [ "$default" = "Y" ] && echo true || echo false )" ;;
    esac
  }

  prompt_yn "Install bpm-memory-mcp (cross-session project memory)?" "Y" INSTALL_MEMORY
  prompt_yn "Install bpm-code-search-mcp (semantic code search + symbol index)?" "Y" INSTALL_CODE_SEARCH
  prompt_yn "Install playwright-mcp (browser automation + screenshots)?" "Y" INSTALL_PLAYWRIGHT_MCP
  prompt_yn "Install playwright-search (web research MCP)?" "Y" INSTALL_PWS
  echo ""
fi

echo ""
echo "Installing attest-claude..."
echo "Source: $SCRIPT_DIR"
echo "Target: $CLAUDE_HOME"
echo ""

# Create directories
mkdir -p "$CLAUDE_HOME/agents"
mkdir -p "$CLAUDE_HOME/hooks"

# ─── 1. Symlink agents ───
echo "Installing agents..."
count=0
for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -f "$agent" ] || continue
  ln -sf "$agent" "$CLAUDE_HOME/agents/$(basename "$agent")"
  count=$((count + 1))
done

# Symlink micro-agent subdirectories (security/, code-review/, performance/, sdlc/, test/)
for subdir in security code-review performance sdlc test game; do
  if [ -d "$SCRIPT_DIR/agents/$subdir" ]; then
    mkdir -p "$CLAUDE_HOME/agents/$subdir"
    for f in "$SCRIPT_DIR/agents/$subdir/"*.md; do
      [ -f "$f" ] || continue
      ln -sf "$f" "$CLAUDE_HOME/agents/$subdir/$(basename "$f")"
      count=$((count + 1))
    done
    # Recurse one level (e.g. sdlc/onboard/)
    for nested in "$SCRIPT_DIR/agents/$subdir/"*/; do
      [ -d "$nested" ] || continue
      nested_name=$(basename "$nested")
      mkdir -p "$CLAUDE_HOME/agents/$subdir/$nested_name"
      for f in "$nested"*.md; do
        [ -f "$f" ] || continue
        ln -sf "$f" "$CLAUDE_HOME/agents/$subdir/$nested_name/$(basename "$f")"
        count=$((count + 1))
      done
    done
  fi
done
echo "  $count agents installed (including micro-agent clusters)"

# Compact agent overlay (tier=small environments) — copies, not symlinks,
# so the overlay survives even though full agents are symlinked.
if [ "${COMPACT_AGENTS:-false}" = "true" ]; then
  if [ -d "$SCRIPT_DIR/dist/compact-agents" ]; then
    overlaid=0
    for f in "$SCRIPT_DIR"/dist/compact-agents/*.md; do
      rm -f "$CLAUDE_HOME/agents/$(basename "$f")"
      cp "$f" "$CLAUDE_HOME/agents/$(basename "$f")"
      overlaid=$((overlaid + 1))
    done
    echo "  Overlaid $overlaid compact agent variants (tier=small)"
  else
    echo "  WARNING: --compact requested but dist/compact-agents/ missing — run: node scripts/build-agents.mjs --compact"
  fi
fi

# Remove stale compact dir from older installs (it registered 23 duplicate agents)
if [ -d "$CLAUDE_HOME/agents/compact" ]; then
  rm -rf "$CLAUDE_HOME/agents/compact"
  echo "  Removed stale agents/compact/ (old layout — duplicate registrations)"
fi

# ─── 2. Symlink skills ───
echo "Installing skills..."
count=0
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  skill_name=$(basename "$skill_dir")
  mkdir -p "$CLAUDE_HOME/skills/$skill_name"
  if [ -f "$skill_dir/SKILL.md" ]; then
    ln -sf "$skill_dir/SKILL.md" "$CLAUDE_HOME/skills/$skill_name/SKILL.md"
    count=$((count + 1))
  fi
done
echo "  $count skills installed"

# ─── 3. Symlink references into agents dir ───
# Agents Read files from ~/.claude/agents/ — references go there too
echo "Installing references..."
count=0
for ref in "$SCRIPT_DIR/references/"*.md; do
  [ -f "$ref" ] || continue
  ln -sf "$ref" "$CLAUDE_HOME/agents/$(basename "$ref")"
  count=$((count + 1))
done
echo "  $count reference files installed"

# ─── 3b. Symlink agents/shared/ — agent prompts reference this path ───
echo "Installing shared agent docs..."
mkdir -p "$CLAUDE_HOME/agents/shared"
shared_count=0
for shared in "$SCRIPT_DIR/agents/shared/"*.md; do
  [ -f "$shared" ] || continue
  ln -sf "$shared" "$CLAUDE_HOME/agents/shared/$(basename "$shared")"
  shared_count=$((shared_count + 1))
done
echo "  $shared_count shared docs installed (LOOP_PREVENTION, BOUNDED_TASK_CONTRACT, etc.)"

# ─── 3c. Symlink exemplars/ — gold-standard artifact formats for HANDOFFs ───
echo "Installing exemplars..."
mkdir -p "$CLAUDE_HOME/exemplars"
ex_count=0
for ex in "$SCRIPT_DIR/exemplars/"*.md; do
  [ -f "$ex" ] || continue
  ln -sf "$ex" "$CLAUDE_HOME/exemplars/$(basename "$ex")"
  ex_count=$((ex_count + 1))
done
echo "  $ex_count exemplars installed (ERD, sequence diagram, finding, manifest, ADR, gap report)"

# ─── 4. Symlink scripts ───
echo "Installing scripts..."
mkdir -p "$CLAUDE_HOME/scripts"
count=0
for script in "$SCRIPT_DIR/scripts/"*.sh "$SCRIPT_DIR/scripts/"*.mjs; do
  [ -f "$script" ] || continue
  ln -sf "$script" "$CLAUDE_HOME/scripts/$(basename "$script")"
  chmod +x "$script"
  count=$((count + 1))
done
echo "  $count scripts installed"

# ─── 4a. Symlink scripts/validators/ — doctor.sh and phase gates expect these ───
mkdir -p "$CLAUDE_HOME/scripts/validators"
val_count=0
for v in "$SCRIPT_DIR/scripts/validators/"*.sh; do
  [ -f "$v" ] || continue
  ln -sf "$v" "$CLAUDE_HOME/scripts/validators/$(basename "$v")"
  chmod +x "$v"
  val_count=$((val_count + 1))
done
echo "  $val_count validators installed"

# ─── 4b. Install Semgrep custom rules ───
echo "Installing Semgrep custom rules..."
if [ -d "$SCRIPT_DIR/.semgrep" ]; then
  rm -rf "$CLAUDE_HOME/.semgrep"
  ln -sf "$SCRIPT_DIR/.semgrep" "$CLAUDE_HOME/.semgrep"
  rule_count=$(grep -r '^\s*- id:' "$SCRIPT_DIR/.semgrep/" 2>/dev/null | wc -l | tr -d ' ')
  file_count=$(find "$SCRIPT_DIR/.semgrep" -name '*.yml' | wc -l | tr -d ' ')
  echo "  $rule_count rules in $file_count rulesets linked → $CLAUDE_HOME/.semgrep/"
else
  echo "  No .semgrep/ directory found — skipping"
fi

# ─── 5. Copy hooks (scripts need to be executable, not symlinks) ───
echo "Installing hooks..."
count=0
for hook in "$SCRIPT_DIR/hooks/"*; do
  [ -f "$hook" ] || continue
  cp "$hook" "$CLAUDE_HOME/hooks/$(basename "$hook")"
  chmod +x "$CLAUDE_HOME/hooks/$(basename "$hook")"
  count=$((count + 1))
done
echo "  $count hooks installed"

# ─── 5. Update settings.json with hook configuration ───
SETTINGS="$CLAUDE_HOME/settings.json"
if [ -f "$SETTINGS" ]; then
  # Check if our hooks are already configured
  if grep -q "block-env-write" "$SETTINGS" 2>/dev/null; then
    echo "  Hook configuration already present in settings.json"
  else
    echo "  NOTE: You may need to manually add hook entries to $SETTINGS"
    echo "  See the hooks/ directory for available hook scripts"
  fi
else
  echo "  WARNING: $SETTINGS not found — create it to configure hooks"
fi

# ─── 6. Update CLAUDE.md ───
CLAUDE_MD="$CLAUDE_HOME/CLAUDE.md"
if grep -q "## Expert System" "$CLAUDE_MD" 2>/dev/null; then
  echo "  Expert System section already exists in CLAUDE.md"
else
  cat >> "$CLAUDE_MD" << 'EXPERT_SECTION'

---

## Expert System

This Claude Code installation includes the expert system with 10 specialist agents.

### Available Experts

| Command | Expert | Domain |
|---------|--------|--------|
| `/security` | Security Auditor | OWASP, threat modeling, vulnerability scanning |
| `/research` | Researcher | Investigation, source evaluation, comparison |
| `/test-expert` | Test Engineer | Playwright, vitest, test strategy, coverage |
| `/dba` | Database Architect | Schema, migrations, query optimization |
| `/ux` | UX Engineer | Workflows, components, WCAG accessibility |
| `/devops` | SRE | Runbooks, CI/CD, monitoring, incident response |
| `/containers` | Container Ops | Podman/Docker, compose, debugging |
| `/review-code` | Code Reviewer | Quality, patterns, tech debt |
| `/perf` | Performance Engineer | Profiling, benchmarks, optimization |
| `/api-design` | API Designer | REST/GraphQL, contracts, versioning |

### How Experts Work

Each expert: Understands → Researches → Plans → Executes → Verifies → Reports.
Experts use `memory: project` to build institutional knowledge across sessions.
EXPERT_SECTION
  echo "  Added Expert System section to CLAUDE.md"
fi

# ─── 7. Store install path ───
echo "$SCRIPT_DIR" > "$CLAUDE_HOME/.experts-install-path"

# ─── 8. bpm-memory-mcp MCP ───
if [ "$INSTALL_MEMORY" = true ]; then
echo ""
echo "Setting up bpm-memory-mcp MCP (cross-session project memory)..."

MEMORY_DIR="${CLAUDE_MEMORY_DIR:-$HOME/Code/bpm-memory-mcp}"
MEMORY_SERVER="${CLAUDE_MEMORY_PATH:-$MEMORY_DIR/mcp/memory-server/dist/index.js}"
MEMORY_REPO="https://github.com/bpmforge/bpm-memory-mcp.git"

if ! command -v node &>/dev/null; then
  echo "  ⚠️  node not found — skipping bpm-memory-mcp"
else
  # Clone if not present
  if [ ! -d "$MEMORY_DIR/.git" ]; then
    echo "  Cloning bpm-memory-mcp → $MEMORY_DIR ..."
    mkdir -p "$(dirname "$MEMORY_DIR")"
    if git clone --quiet --depth 1 "$MEMORY_REPO" "$MEMORY_DIR"; then
      echo "    cloned ✓"
    else
      echo "    ⚠️  clone failed — check network. Memory MCP will be skipped."
      MEMORY_SERVER=""
    fi
  else
    (cd "$MEMORY_DIR" && git pull --ff-only --quiet 2>/dev/null) && echo "  bpm-memory-mcp up to date" || true
  fi

  # Build if binary missing or source is newer
  if [ -n "$MEMORY_SERVER" ] && { [ ! -f "$MEMORY_SERVER" ] || [ "$MEMORY_DIR/mcp/memory-server/src/index.ts" -nt "$MEMORY_SERVER" ]; }; then
    echo "  Building bpm-memory-mcp..."
    (cd "$MEMORY_DIR" && npm install --silent && npm run build --silent) 2>&1 | tail -3
    if [ -f "$MEMORY_SERVER" ]; then
      echo "    build ✓"
    else
      echo "    ⚠️  build failed — run manually: cd $MEMORY_DIR && npm install && npm run build"
      MEMORY_SERVER=""
    fi
  fi

  # Register with Claude Code
  if [ -n "$MEMORY_SERVER" ] && [ -f "$MEMORY_SERVER" ]; then
    if command -v claude &>/dev/null; then
      if claude mcp list 2>/dev/null | grep -q "^memory"; then
        echo "  bpm-memory-mcp MCP already registered"
      else
        claude mcp add memory node "$MEMORY_SERVER" 2>&1 | head -3
        echo "  Registered bpm-memory-mcp MCP (user-level)"
      fi
    else
      echo "  Claude Code CLI not on PATH — to register run:"
      echo "    claude mcp add memory node $MEMORY_SERVER"
    fi
  fi
fi
fi  # INSTALL_MEMORY

# ─── 9. playwright-mcp (LLM-agnostic browser automation + screenshots) ───
echo ""
echo "Setting up playwright-mcp (browser automation, screenshots, E2E testing)..."

INSTALL_PLAYWRIGHT_MCP=true
for arg in "$@"; do
  [ "$arg" = "--no-playwright-mcp" ] && INSTALL_PLAYWRIGHT_MCP=false
done

if [ "$INSTALL_PLAYWRIGHT_MCP" = true ]; then
  if ! command -v node &>/dev/null; then
    echo "  ⚠️  node not found — skipping playwright-mcp"
  elif command -v claude &>/dev/null; then
    if claude mcp list 2>/dev/null | grep -q "^playwright[[:space:]]"; then
      echo "  playwright-mcp already registered"
    else
      claude mcp add playwright -- npx -y @playwright/mcp@latest 2>&1 | head -3
      echo "  Registered playwright-mcp (user-level)"
      echo "  First use will auto-install Chromium (~170MB). To pre-install:"
      echo "    npx playwright install chromium"
    fi
  else
    echo "  Claude Code CLI not on PATH — to register playwright-mcp run:"
    echo "    claude mcp add playwright -- npx -y @playwright/mcp@latest"
  fi
else
  echo "  Skipping playwright-mcp (--no-playwright-mcp set)"
fi

# ─── 10. bpm-code-search-mcp ───
if [ "$INSTALL_CODE_SEARCH" = true ]; then
echo ""
echo "Setting up bpm-code-search-mcp (semantic code search + symbol index)..."

CODE_SEARCH_DIR="${BPM_CODE_SEARCH_DIR:-$HOME/Code/bpm-code-search-mcp}"
CODE_SEARCH_BIN="$CODE_SEARCH_DIR/dist/index.js"
CODE_SEARCH_REPO="https://github.com/bpmforge/bpm-code-search-mcp.git"

if ! command -v node &>/dev/null; then
  echo "  ⚠️  node not found — skipping bpm-code-search-mcp"
else
  # Clone if not present
  if [ ! -d "$CODE_SEARCH_DIR/.git" ]; then
    echo "  Cloning bpm-code-search-mcp → $CODE_SEARCH_DIR ..."
    mkdir -p "$(dirname "$CODE_SEARCH_DIR")"
    if git clone --quiet --depth 1 "$CODE_SEARCH_REPO" "$CODE_SEARCH_DIR"; then
      echo "    cloned ✓"
    else
      echo "    ⚠️  clone failed — check network. Code search MCP will be skipped."
      CODE_SEARCH_BIN=""
    fi
  else
    (cd "$CODE_SEARCH_DIR" && git pull --ff-only --quiet 2>/dev/null) && echo "  bpm-code-search-mcp up to date" || true
  fi

  # Build if binary missing or source is newer
  if [ -n "$CODE_SEARCH_BIN" ] && { [ ! -f "$CODE_SEARCH_BIN" ] || [ "$CODE_SEARCH_DIR/src/index.ts" -nt "$CODE_SEARCH_BIN" ]; }; then
    echo "  Building bpm-code-search-mcp..."
    (cd "$CODE_SEARCH_DIR" && npm install --silent && npm run build --silent) 2>&1 | tail -3
    if [ -f "$CODE_SEARCH_BIN" ]; then
      echo "    build ✓"
    else
      echo "    ⚠️  build failed — run manually: cd $CODE_SEARCH_DIR && npm install && npm run build"
      CODE_SEARCH_BIN=""
    fi
  fi

  # Register with Claude Code
  if [ -n "$CODE_SEARCH_BIN" ] && [ -f "$CODE_SEARCH_BIN" ]; then
    if command -v claude &>/dev/null; then
      if claude mcp list 2>/dev/null | grep -q "^code-search"; then
        echo "  bpm-code-search-mcp already registered"
      else
        claude mcp add code-search node "$CODE_SEARCH_BIN" 2>&1 | head -3
        echo "  Registered bpm-code-search-mcp (user-level)"
      fi
    else
      echo "  Claude Code CLI not on PATH — to register run:"
      echo "    claude mcp add code-search node $CODE_SEARCH_BIN"
    fi
  fi
fi
fi  # INSTALL_CODE_SEARCH

# ─── 8. playwright-search MCP setup ───
if [ "$INSTALL_PWS" = true ]; then
  echo ""
  echo "Setting up playwright-search MCP (multi-engine web research + page extraction)..."

  PWS_DIR="${PLAYWRIGHT_SEARCH_DIR:-$HOME/.local/share/playwright-search}"
  PWS_REPO="https://github.com/bpmforge/playwright-search.git"

  if ! command -v node &>/dev/null; then
    echo "  ⚠️  node not found — skipping playwright-search MCP install"
    echo "     Install Node 20+ then re-run, or pass --no-playwright-search to silence this"
  else
    if [ -d "$PWS_DIR/.git" ]; then
      echo "  playwright-search already cloned at $PWS_DIR"
      (cd "$PWS_DIR" && git pull --ff-only --quiet) 2>/dev/null \
        && echo "    pulled latest" \
        || echo "    skipped pull (uncommitted changes or not on main branch)"
    else
      echo "  Cloning $PWS_REPO -> $PWS_DIR ..."
      mkdir -p "$(dirname "$PWS_DIR")"
      if git clone --quiet --depth 1 "$PWS_REPO" "$PWS_DIR"; then
        echo "    cloned ✓"
      else
        echo "    ⚠️  clone failed — check network / repo URL"
        INSTALL_PWS=false
      fi
    fi

    if [ "$INSTALL_PWS" = true ]; then
      if [ ! -f "$PWS_DIR/dist/mcp.js" ] || [ "$PWS_DIR/src/mcp.ts" -nt "$PWS_DIR/dist/mcp.js" ]; then
        echo "  Building playwright-search (also installs Chromium ~170MB the first time)..."
        (cd "$PWS_DIR" && npm install --silent && npm run build --silent) 2>&1 | tail -3
        if [ -f "$PWS_DIR/dist/mcp.js" ]; then
          echo "    build ✓"
        else
          echo "    ⚠️  build failed — run manually: cd $PWS_DIR && npm install && npm run build"
          INSTALL_PWS=false
        fi
      else
        echo "  Build is current"
      fi
    fi

    if [ "$INSTALL_PWS" = true ]; then
      # Prefer `claude mcp add` if the CLI is on PATH; otherwise show manual instructions
      if command -v claude &>/dev/null; then
        if claude mcp list 2>/dev/null | grep -q "playwright-search"; then
          echo "  playwright-search MCP already registered with Claude Code"
        else
          claude mcp add playwright-search node "$PWS_DIR/dist/mcp.js" 2>&1 | head -3
          echo "  Registered with Claude Code (user-level)"
        fi
      else
        echo "  Claude Code CLI not on PATH — to register the MCP run:"
        echo ""
        echo "    claude mcp add playwright-search node $PWS_DIR/dist/mcp.js"
        echo ""
        echo "  …or add to a project's .mcp.json:"
        echo ''
        echo '    {'
        echo '      "mcpServers": {'
        echo '        "playwright-search": {'
        echo '          "command": "node",'
        echo "          \"args\": [\"$PWS_DIR/dist/mcp.js\"]"
        echo '        }'
        echo '      }'
        echo '    }'
        echo ''
      fi
    fi
  fi
else
  echo ""
  echo "Skipping playwright-search MCP (--no-playwright-search set)"
fi

echo ""
echo "Installation complete!"
echo ""
echo "Files installed:"
echo "  ~/.claude/agents/              (primary agents + references + micro-agent clusters)"
echo "  ~/.claude/skills/*/SKILL.md    (skill triggers)"
echo "  ~/.claude/scripts/*.sh         (audit + utility scripts)"
echo "  ~/.claude/.semgrep/            (custom rules, 11 languages)"
echo "  ~/.claude/hooks/*              (automation scripts)"
echo "  ~/.claude/CLAUDE.md            (updated with expert docs)"
echo ""
echo "MCPs registered:"
[ -f "${MEMORY_SERVER:-}" ]     && echo "  memory          — cross-session project memory  (bpm-memory-mcp)"
[ -f "${CODE_SEARCH_BIN:-}" ]   && echo "  code-search     — semantic search + symbol index (bpm-code-search-mcp)"
[ "$INSTALL_PLAYWRIGHT_MCP" = true ] && echo "  playwright      — browser automation + screenshots (playwright-mcp)"
[ "$INSTALL_PWS" = true ] && [ -f "$PWS_DIR/dist/mcp.js" ] \
                            && echo "  playwright-search — web research + page extraction"
echo ""
echo "All expert commands are now available in Claude Code sessions."
echo ""
echo "Optional: Install community Semgrep rule sources for deep security audits:"
echo "  $SCRIPT_DIR/scripts/update-semgrep-rules.sh              Clone Trail of Bits, elttam, GitLab, 0xdea rules"
echo "  $SCRIPT_DIR/scripts/update-semgrep-rules.sh --bump       Pull latest + write .semgrep/community-rules.lock"
echo "  $SCRIPT_DIR/scripts/update-semgrep-rules.sh --verify     Verify cached rules match pinned commits"
echo "  $SCRIPT_DIR/scripts/semgrep-full-audit.sh                Run full audit with all community + framework rules"
echo "  $SCRIPT_DIR/scripts/semgrep-full-audit.sh --fast         CI-tier scan (< 60s)"
echo "  $SCRIPT_DIR/scripts/semgrep-full-audit.sh --autofix      OPT-IN autofix (LOW/WARNING only, refuses HIGH/CRITICAL)"
echo "  Custom gap-filler rules: ~/.claude/.semgrep/ (186 rules, 11 languages)"
echo "  Community rules cache:   ~/.semgrep/rules/"
echo ""

echo ""
if [ "${INSTALL_TOOLS:-false}" = true ]; then
  bash "$SCRIPT_DIR/scripts/check-tools.sh" --install
else
  bash "$SCRIPT_DIR/scripts/check-tools.sh"
fi
