# attest-claude

Expert agent system for [Claude Code](https://claude.ai/code) — 39 primary expert agents + 31 cluster specialists (security, code-review, performance, onboarding, game dev), 27 skills, a 4-mode SDLC workflow, full git lifecycle management, and 55 automated validators that enforce quality gates at every phase.

**Not sure which command to run? Just describe your goal:** `/guide` is the front door — it routes any plain-English goal ("securely check all my source and help fix the issues", "this codebase is unfamiliar", "harden before launch") to the right expert and drives the workflow, always offering the next step.

Sibling project: [`attest`](https://github.com/bpmforge/attest) — same experts for OpenCode (any LLM). This repo's agents, references, and validators are generated from it.

## Install

**Starting from a fresh machine?** You need `git` to clone this, so that one step
is on you — everything after it the installer offers to install for you (Node,
`jq`, compilers, MCP servers).

```bash
# fresh WSL / Ubuntu / Debian
sudo apt-get update && sudo apt-get install -y git curl ca-certificates

# Fedora / RHEL:  sudo dnf install -y git curl ca-certificates
# Arch:           sudo pacman -S --noconfirm git curl ca-certificates
# Alpine:         sudo apk add git curl ca-certificates
# macOS:          git ships with the Xcode command line tools (xcode-select --install)
```

Then:

```bash
git clone https://github.com/bpmforge/attest-claude.git
cd attest-claude
./install.sh
```

That gives you **`main`** — the newest state, which can contain work landed since the last release.

**To install a specific release instead** (pick the version from [Releases](https://github.com/bpmforge/attest-claude/releases)):

```bash
git clone --branch v3.1.25 --depth 1 https://github.com/bpmforge/attest-claude.git
cd attest-claude
./install.sh
```

Or, in a clone you already have:

```bash
git fetch --tags
git checkout v3.1.25   # prints a "detached HEAD" notice — that is expected
./install.sh
```

**`main` vs a tag:** `main` moves with every push; a tag (`v3.1.25`) always points at the same commit. Use a tag when you want a fixed state; use `main` for the newest work. The "detached HEAD" notice is normal and installing works fine — you only need a branch if you intend to edit: `git checkout -b my-fix v3.1.25`. Go back to the latest with `git checkout main && git pull`.

This repo is generated from [attest](https://github.com/bpmforge/attest) and its tags track that repo's, so `v3.1.25` here is the Claude build of attest `v3.1.25`.

Symlinks agents, skills, hooks, references, and scripts into `~/.claude/` and registers the MCP servers. Useful flags: `--yes` (non-interactive), `--compact` (compact agent variants for 32k local models), `--tools` (install the optional code-analysis tools — semgrep, knip, vulture, mmdc, …), `--no-memory`, `--no-code-search`, `--no-playwright-search`. Requires macOS, Linux, or WSL2.

**Verify the install:**

```bash
~/.claude/scripts/doctor.sh         # structure, symlinks, deps, MCP registration → Status: HEALTHY
~/.claude/scripts/check-tools.sh    # which optional analysis tools are present (add: --install)
```

## Update

One command, from your existing checkout:

```bash
./install.sh --update
```

It fetches releases, moves this checkout to the newest one, reinstalls, and tells you what it moved from and to. Works whether you're on `main` or pinned to an older tag, and it's safe to run when you're already current. Follow with `doctor.sh`.

It stops without changing anything if you have uncommitted edits to tracked files, and shows you which — so it can't quietly discard your work. (Untracked files are left alone.)

Prefer to track `main` by hand? `git pull && ./install.sh --yes` still works — but note `git pull` is a silent no-op if you're on a tag, which is exactly the trap `--update` avoids.

## First command

```
/guide                                       # describe any goal in plain English
/sdlc init my-project "short description"     # or go straight to a workflow
```

| You say | Runs |
|---------|------|
| "I don't know where to start / what can this do?" | `/guide` |
| "build a new app" | `/sdlc init` |
| "build a game" | `/sdlc init --game` |
| "understand this codebase" | `/sdlc onboard` |
| "add X feature" | `/sdlc feature` |
| "review / audit / find gaps / make it better" | `/sdlc improve` |
| "securely check my source and help fix it" | `/security --fix` |
| "is there code nothing uses?" | `/review-code` (dead-code dimension) |
| "verify the UI at localhost:3000" | `/ui-verify` |

## What's included

| Category | Count |
|----------|-------|
| Primary agents | 34 |
| Security micro-agents | 9 |
| Code-review micro-agents | 8 |
| Performance micro-agents | 6 |
| SDLC onboard specialists | 4 |
| Game-dev cluster | 4 |
| **Total agents** | **65** |
| Skills | 26 |
| Shared protocols | 17 |
| Validators | 55 |
| MCPs (auto-installed) | 4 |

## Highlights

- **`/guide` concierge** — front door that routes any goal to the right expert.
- **Security find-and-fix** — `/security --fix` drives a verified loop (fix → re-scan to confirm closed via `scripts/fix-verify.mjs`).
- **8-dimension code health** including a dead-code/stub/unused-export detector.
- **Deterministic scaffolding** — `run-plan.mjs` (DAG runner), `fix-verify.mjs` (re-verify gate), `mermaid-fix.mjs` + render-validated diagrams.
- **Any LLM** — tier detection, compact agent variants (install with `--compact`), capability-probed delegation.

## Docs

- [docs/SETUP.md](docs/SETUP.md) — **start here**: prerequisites, embedding models, env vars, troubleshooting
- [docs/USERGUIDE.md](docs/USERGUIDE.md) — how to invoke each expert
- [docs/FEATURES.md](docs/FEATURES.md) — full agent, skill, validator, and protocol catalog
- [docs/MCP_GUIDE.md](docs/MCP_GUIDE.md) — MCP configuration (`claude mcp add` / `.mcp.json`)
- [docs/SDLC_GUIDE.md](docs/SDLC_GUIDE.md) — SDLC workflow, phases, git model
- [Releases](https://github.com/bpmforge/attest-claude/releases) — release notes for each version (the per-release detail lives in the annotated tag; `CHANGELOG.md` covers 1.x only)

## License

[Apache License 2.0](LICENSE) — Copyright 2026 Bradford Matthews.
