# attest-claude

Expert system for Claude Code. Contains subagent definitions, skill triggers, reference documents, and hooks.

## GENERATED CONTENT — read before editing

`agents/`, `references/`, `scripts/validators/`, `dist/compact-agents/`,
`scripts/build-agents.mjs`, and `scripts/run-plan.mjs` are **generated** from
the canonical source in `../attest` by its
`npm run build:claude`. Do NOT edit those files here — edit the canonical
source (or `build/overrides/claude/` for runtime-flavored docs) and rebuild.
`GENERATED_FILES.txt` lists every generated file. Per-target files owned by
THIS repo: `skills/`, `hooks/`, `docs/`, `install.sh`, `uninstall.sh`,
`scripts/doctor.sh`, README, CHANGELOG, this file.

## Structure
- `agents/` — Subagent system prompts (markdown with YAML frontmatter)
- `skills/` — Thin skill triggers that invoke agents
- `references/` — Supporting documents agents Read at runtime
- `hooks/` — Shell/Python scripts for pre/post tool-use automation

## Conventions
- Agent frontmatter: name, description, tools, model, memory, maxTurns
- Skill frontmatter: name, trigger, description, agent, arguments
- Reference files: Plain markdown, no frontmatter
- Hooks: Executable scripts, receive JSON on stdin, exit 2 to block

## Installation
Run `./install.sh` to symlink into `~/.claude/`. Run `./uninstall.sh` to remove.
