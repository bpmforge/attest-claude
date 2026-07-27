---
name: Gate
trigger: /gate
description: 'SDLC phase gate — runs the automated validators for the current phase and reports gaps. Use after completing all deliverables for a phase. Wraps scripts/validators/validate-phase-gate.sh.'
---

# Gate Skill

Control phase transitions and approvals in the SDLC workflow.

## Automated validators (v0.15.0+)

Every `/gate check` and `/gate approve` now runs the Wave 3 validator suite via:

```bash
./scripts/validators/validate-phase-gate.sh <phase>
```

Phase arguments:

| Invocation | Phase arg |
|------------|-----------|
| Mode 1 phase N | `phase-<N>` (0-5) |
| Mode 2 deep | `onboard-deep` |
| `/security --deep` | `security-deep` |

Exit codes:
- `0` = all validators clean, gate passes
- `1` = one or more gaps (read JSON gap list on stdout)
- `2` = validator itself errored

The validator replaces subjective "read the file, rate completeness 1-10" with deterministic coverage checks (`scripts/validators/validate-architecture.sh`, `validate-owasp.sh`, `validate-api-coverage.sh`, `validate-erd-coverage.sh`, `validate-sequence-coverage.sh`, `validate-inventory.sh`).

Do not second-guess the validator. If it says clean, gate passes. If it says gap, close the gap -- do not override.

See `scripts/validators/README.md` for the full validator contract.

---

## Legacy confidence-loop flow (still used for unvalidatable artifacts)

For artifacts validators cannot check mechanically (narratives, research summaries), the legacy confidence-loop flow below remains in effect.

## Memory Integration

Gate decisions are critical project history. All approvals and bypasses are stored in memory for:
- **Audit trail** - Why was Phase 2 approved?
- **Cross-session context** - Recall gate history after compaction
- **Decision recovery** - What was the bypass reason?

### On Gate Approval

```
memory_store({
  content: "GATE APPROVED: Phase [N] ([Phase Name]). Documents validated: [list]. Approved by: @user",
  type: "decision",
  confidence: 1.0,
  citation: "docs/[phase-folder]/"
})
```

### On Gate Bypass

```
memory_store({
  content: "GATE BYPASS: Phase [N] bypassed. Reason: [reason]. Missing docs: [list]. Action required: [backfill plan]",
  type: "decision",
  confidence: 0.7
})
```

### On Task Verification

```
memory_store({
  content: "TASK VERIFIED: [TASK-XXX] at [confidence]% confidence. Issues: [if any]",
  type: "fact",
  confidence: 0.9,
  citation: "[primary deliverable file]"
})
```

---

## Commands

### `/gate check [--phase N]`

Check if a phase gate is satisfied.

**Examples:**
```
/gate check           # Check current phase
/gate check --phase 2 # Check specific phase
```

**Gate Requirements by Phase:**

| Phase | Requirements |
|-------|-------------|
| 0 | None (starting point) |
| 1 | Phase 0 documents exist and are approved |
| 2 | Phase 1 documents exist and are approved |
| 3 | Phase 2 documents exist and are approved |
| 4 | Phase 3 documents exist and are approved |

**Output (satisfied):**
```
Gate Check: Phase 2

Prerequisites (Phase 1):
  SCOPE.md exists (44 lines)
  RISKS.md exists (50 lines)
  CONSTRAINTS.md exists (26 lines)
  USER_PERSONAS.md exists (78 lines)
  Phase 1 approved on 2026-01-08

Gate Status: OPEN

Ready to run: /sdlc run --phase 2
```

**Output (not satisfied):**
```
Gate Check: Phase 2

Prerequisites (Phase 1):
  SCOPE.md exists (44 lines)
  RISKS.md missing
  CONSTRAINTS.md exists (26 lines)
  USER_PERSONAS.md exists (78 lines)
  Phase 1 not approved

Gate Status: BLOCKED

Required actions:
  1. Run: /sdlc run --phase 1 to generate RISKS.md
  2. Run: /gate approve --phase 1 after review
```

---

### `/gate approve [--phase N]`

Mark a phase as approved (human sign-off).

**Examples:**
```
/gate approve           # Approve current phase
/gate approve --phase 1 # Approve specific phase
```

**Actions:**
1. Validate all documents for the phase exist
2. Run validation checks
3. If valid, update CLAUDE.md:
   ```markdown
   ## Phase Approvals
   | Phase | Status | Approved By | Date |
   |-------|--------|-------------|------|
   | 1 | Approved | @user | 2026-01-08 |
   ```
4. Report approval status

**Output:**
```
Gate Approval: Phase 1

Validating Phase 1 documents...

  SCOPE.md: Valid (44 lines)
  RISKS.md: Valid (50 lines)
  CONSTRAINTS.md: Valid (26 lines)
  USER_PERSONAS.md: Valid (78 lines)

Phase 1 Approved

CLAUDE.md updated.
Gate to Phase 2 is now OPEN.

Next: Run /sdlc run --phase 2
```

---

### `/gate bypass [--reason "<reason>"]`

Emergency bypass for a blocked gate (logged).

**Examples:**
```
/gate bypass --reason "Urgent fix needed, will backfill docs"
```

**Warning:** This should be used sparingly. All bypasses are logged.

**Actions:**
1. Log the bypass with timestamp and reason
2. Temporarily allow code edits
3. Add warning to CLAUDE.md:
   ```markdown
   ## Warnings
   - **GATE BYPASS** (2026-01-08): Phase 3 bypassed. Reason: "Urgent fix needed"
     - Documents still required: ARCHITECTURE.md, DATABASE.md
   ```

**Output:**
```
Gate Bypass Activated

Phase 3 gate has been bypassed.
Reason: "Urgent fix needed, will backfill docs"

This has been logged in CLAUDE.md.

Warning: The following documents are still required:
  - docs/3-design/ARCHITECTURE.md
  - docs/3-design/DATABASE.md
  - docs/3-design/TECH_STACK.md

Code editing is now allowed, but please complete
the missing documents as soon as possible.

To restore normal gate enforcement:
  /gate restore
```

---

### `/gate restore`

Restore normal gate enforcement after a bypass.

**Actions:**
1. Re-enable gate enforcement hook
2. Update CLAUDE.md to show bypass is resolved

---

### `/gate history`

Show gate approval and bypass history.

**Output:**
```
Gate History: [Project Name]

Phase 0 (Ideation)
  Approved: 2026-01-08 10:30

Phase 1 (Planning)
  Approved: 2026-01-08 14:15

Phase 2 (Requirements)
  Bypassed: 2026-01-08 16:00
    Reason: "Hotfix for production issue"
  Restored: 2026-01-08 18:30
  Approved: 2026-01-08 19:00

Phase 3 (Design)
  Pending

Phase 4 (Implementation)
  Locked
```

---

### `/gate verify --task TASK-XXX`

Verify a task is complete with confidence scoring. **(Added 2026-01-16)**

**Examples:**
```
/gate verify --task TASK-018
/gate verify --task TASK-001
```

**Actions:**
1. Read task definition from TASKS.md
2. Check all deliverable files exist
3. Run acceptance criteria commands
4. Calculate confidence score
5. Update TASKS.md with status + confidence
6. Update PROGRESS.md summary

**Output:**
```
Task Verification: TASK-018

Task: React App Scaffold
Requirements: FR-001

Deliverables:
  frontend/package.json exists
  frontend/src/App.tsx exists
  frontend/src/main.tsx exists
  frontend/vite.config.ts exists

Acceptance Criteria:
  npm run build: SUCCESS (430KB bundle)
  npm run test: NO TESTS FOUND
  npm run lint: PASS

Confidence Calculation:
  - Deliverables: 100% (4/4)
  - Build: PASS
  - Tests: MISSING (-20%)
  - Lint: PASS

Confidence Score: 75%

TASKS.md updated:
  TASK-018 | Done | 75% | 2026-01-16

Recommendation:
  Add tests to reach High confidence
```

---

### `/gate progress-check`

Mid-implementation progress verification. **(Added 2026-01-16)**

Run this every 5 tasks or at least once per session.

**Output:**
```
Implementation Progress Check

TASKS.md Analysis:
  Total Tasks: 54
  Done: 24 (44%)
  Partial: 2 (4%)
  Pending: 28 (52%)

Confidence Distribution:
  High (90%+):    8 tasks
  Medium (70-89%): 14 tasks
  Low (50-69%):    2 tasks
  Unscored:         2 tasks

PROGRESS.md Sync:
  Summary matches TASKS.md
  Last updated: 2026-01-16

Unverified Tasks (need /gate verify):
  - TASK-006: Request/Response Capture
  - TASK-008: WebSocket Layer

Orphan Code Check:
  3 files not linked to any task:
    - frontend/src/components/Tooltip.tsx
    - frontend/src/components/SearchInput.tsx
    - frontend/src/pages/Decoder.tsx

Actions Required:
  1. Run /gate verify for unverified tasks
  2. Link orphan code to tasks or create new tasks
```

---

### `/gate approve --phase 4` (Updated)

Phase 4 approval has additional requirements:

**Phase 4 Specific Checks:**
1. All P0 tasks at High confidence (90%+)
2. All P1 tasks at Medium or higher (70%+)
3. Requirement coverage >= 80%
4. No unverified "Done" tasks
5. No orphan code (all code linked to tasks)

**Output (blocked):**
```
Gate Approval: Phase 4

Checking Phase 4 completion criteria...

P0 Tasks:
  18/20 at High confidence
  TASK-011: Passive Scanner at 55%
  TASK-012: Authorization Testing at Pending

P1 Tasks:
  12/14 at Medium or higher
  TASK-029: Notes at Pending (P1 - acceptable)

Requirement Coverage:
  FR-XXX: 45/63 (71%) Below 80%
  US-XXX: 38/63 (60%) Below 80%

Unverified Tasks:
  4 tasks marked Done without verification

Gate Status: BLOCKED

Required actions:
  1. Complete TASK-011 to High confidence
  2. Complete TASK-012
  3. Implement remaining FR-XXX requirements
  4. Run /gate verify on unverified tasks
```

---

## Gate Philosophy

Gates exist to ensure:

1. **Quality**: Documents are complete before moving forward
2. **Traceability**: Requirements flow through to implementation
3. **Human Oversight**: Key decisions require approval
4. **Documentation**: The project has proper records

Gates are NOT meant to block progress indefinitely. If you're blocked:
- Use `/gate check` to see what's missing
- Use `/sdlc run` to generate missing documents
- Use `/gate bypass` only for emergencies

## Integration with Hooks

The gate system works with the hooks configured in `~/.claude/settings.json`:

**Verification Loop Hooks** (active during Phase 4):
- `format-on-edit.sh` — auto-formats files after Edit/Write
- `lint-on-edit.sh` — lints JS/TS/Python files after Edit/Write
- `type-check-on-edit.sh` — TypeScript type checking after Edit/Write
- `security-scanner.py` — detects hardcoded secrets after Edit/Write
- `test-on-stop.sh` — runs test suite on Stop, blocks if tests fail
- `block-dangerous.py` — blocks destructive commands (rm -rf /, DROP TABLE, force push)
- `commit-validator.sh` — enforces Conventional Commits format

Gate verify now considers hook output when calculating confidence scores:
- If `test-on-stop.sh` is active and tests pass: +10% confidence
- If `format-on-edit.sh` is active (code is auto-formatted): +5% confidence
- If `security-scanner.py` found no issues: +5% confidence

---

### `/gate review --task TASK-XXX`

Combined verify + review that runs task verification AND a focused code review on the task's deliverables.

**Examples:**
```
/gate review --task TASK-018
/gate review --task TASK-019
```

**Actions:**
1. Run `/gate verify --task TASK-XXX` (check deliverables, acceptance criteria, confidence)
2. Identify all files created/modified for this task
3. Run `/review` on those files (all 4 passes: security, performance, correctness, style)
4. Combine results into a single report
5. Update TASKS.md with review status

**Output:**
```
Gate Review: TASK-018

-- Verification --
  Deliverables: 4/4 present
  Build: PASS
  Tests: 12 passing
  Confidence: 90%

-- Code Review --
  Pass 1 (Security):     0 findings
  Pass 2 (Performance):  1 MEDIUM
  Pass 3 (Correctness):  0 findings
  Pass 4 (Style):        2 LOW

  Review Summary:
    CRITICAL: 0 | HIGH: 0 | MEDIUM: 1 | LOW: 2
    Verdict: APPROVED with suggestions

-- Combined Result --
  Task Status: Done
  Confidence: 90%
  Review: APPROVED with suggestions

  TASKS.md updated.
```

---

### Review Complete Gate (Phase 4 Approval)

Before Phase 4 can be approved (`/gate approve --phase 4`), the following additional checks are enforced:

1. **Review coverage** — All P0 tasks must have been reviewed via `/review` or `/gate review`
2. **No unresolved CRITICAL findings** — Any CRITICAL review findings must be addressed
3. **Verification loop active** — hooks must be configured (`test-on-stop.sh`, `format-on-edit.sh` at minimum)

**Phase 4 gate check output includes:**
```
Review Gate:
  Hooks active: format-on-edit, lint-on-edit, type-check, security-scanner, test-on-stop
  P0 tasks reviewed: 18/18
  Unresolved CRITICAL findings: 1 (TASK-011: SQL injection in user query)
  P1 tasks reviewed: 10/14 (acceptable)

  Review Gate Status: BLOCKED (resolve CRITICAL findings)
```
