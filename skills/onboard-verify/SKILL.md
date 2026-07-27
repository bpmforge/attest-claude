---
name: Onboard Verify
trigger: /onboard-verify
description: 'Ralph Wiggum deep-onboard: Step D3 — run all onboard validators and report uncovered inventory rows. Thin wrapper over scripts/validators/validate-phase-gate.sh onboard-deep.'
agent: sdlc-lead
---

# Onboard Verify

Runs every onboard-relevant validator and reports which inventory rows are uncovered. Does NOT produce new artifacts — verification only.

**Usage:**
- `/onboard-verify` — verify the current project
- `/onboard-verify <path>` — verify a specific project root

## What it runs

```bash
./scripts/validators/validate-phase-gate.sh onboard-deep
```

Which chains:

- `validate-inventory.sh` — every INVENTORY row has an artifact
- `validate-architecture.sh` — 6 diagram types, Mermaid valid, HLA overview
- `validate-erd-coverage.sh` — tables in code appear in ERD
- `validate-sequence-coverage.sh` — P0 flows have sequence diagrams

## Output

A gap table listing any uncovered rows. If no gaps: loop is closed and the user can mark onboarding complete.
