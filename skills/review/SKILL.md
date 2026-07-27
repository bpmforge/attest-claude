---
name: Review
trigger: /review
description: 'Multi-pass cross-expert review with per-pass confidence scoring — coordinates code-reviewer + security-auditor + performance-engineer in parallel, only delivers a verdict when all 3 score ≥ 7.'
arguments:
  - name: target
    description: File, directory, or git diff to review
    required: false
  - name: --pass
    description: Run a single pass (security, performance, correctness, style)
    required: false
---

# Review Skill

Perform a structured, multi-pass code review on the specified target. If no target is given, review staged changes (`git diff --cached`). If nothing is staged, review the most recent commit.

**Each pass is independently confidence-scored.** The final verdict is only delivered when every pass scores ≥ 7 on its coverage. See "Pass Confidence Loop" below.

## Commands

### `/review [target]`

Run all 4 passes on the target (file, directory, or git diff).

**Examples:**
```
/review src/                    # Review entire src directory
/review src/auth/login.ts       # Review a single file
/review                         # Review staged changes or last commit
```

### `/review --pass <pass-name> [target]`

Run a single pass for focused analysis.

**Examples:**
```
/review --pass security src/
/review --pass performance src/db/
/review --pass correctness src/utils/parser.ts
/review --pass style src/
```

---

## Review Passes

### Pass 1: Security (P0 — Must fix before merge)

Look for:
- **Injection vulnerabilities** — SQL injection (raw queries with string interpolation), XSS (unescaped user input in HTML/JSX), command injection (shell exec with user data)
- **Authentication/authorization gaps** — missing auth checks on protected endpoints, broken access control, privilege escalation paths
- **Sensitive data exposure** — hardcoded secrets, API keys, passwords, tokens in source code; PII in logs
- **Insecure dependencies** — known CVEs in imported packages
- **CORS misconfiguration** — overly permissive origins
- **Rate limiting** — missing on public-facing endpoints

### Pass 2: Performance (P1 — Should fix before merge)

Look for:
- **N+1 query patterns** — queries inside loops, missing eager loading/joins
- **Missing database indexes** — queries filtering on unindexed columns
- **Unnecessary re-renders** (React) — missing memo, inline objects/functions in JSX, missing dependency arrays
- **Memory leaks** — unclosed connections, event listeners not cleaned up, unbounded caches
- **Large payload sizes** — fetching full records when only IDs needed, missing pagination
- **Blocking operations** — sync I/O in async contexts, CPU-heavy work on event loop

### Pass 3: Correctness (P1 — Should fix before merge)

Look for:
- **Off-by-one errors** — array indexing, loop bounds, pagination offsets
- **Null/undefined handling** — missing null checks, optional chaining needed, unchecked array access
- **Race conditions** — shared mutable state, concurrent access without locks, TOCTOU bugs
- **Error handling gaps** — unhandled promise rejections, swallowed exceptions, missing try/catch on I/O
- **Edge cases** — empty arrays, empty strings vs null, zero values, negative numbers, Unicode
- **Type mismatches** — implicit coercion, wrong generics, `any` hiding real types

### Pass 4: Style & Maintainability (P2 — Fix soon)

Look for:
- **Naming consistency** — camelCase vs snake_case mixing, unclear abbreviations, misleading names
- **Dead code** — unused imports, unreachable branches, commented-out code
- **Missing types/interfaces** — `any` types, untyped function parameters, missing return types
- **Code duplication** — copy-pasted logic that should be a shared function
- **Unclear logic** — complex conditionals without explanation, magic numbers, implicit dependencies
- **Function size** — functions doing too many things, deeply nested control flow

---

## Pass Confidence Loop (Asymmetric — Easy to Fail, Harder to Pass)

After each of the 4 passes above, rate that pass's confidence on **coverage** (how thoroughly it inspected the target) and **signal** (how actionable its findings are).

**Thresholds:**
- **Score < 5** on any pass = **automatic fail** — surface to user immediately with the specific gap. Do NOT deliver the review.
- **Score 5-6** = revise that pass (up to 3 iterations: re-scan with different patterns, read more files, check edge cases)
- **Score ≥ 7** = pass accepted

**Loop per pass:**

1. Run the pass against the target
2. Rate Coverage (1-10): "Did I examine every file/function that this pass cares about?"
3. Rate Signal (1-10): "Are my findings specific and actionable, or vague?"
4. If Coverage or Signal < 5: STOP. Surface to user: "Pass [N: name] is at [X] confidence on [Coverage|Signal] because [specific gap]. I need [specific info or more scope]."
5. If Coverage or Signal is 5-6: identify the gap, revise the pass (re-scan, re-read, add targeted patterns), re-rate. Max 3 revisions.
6. If all 4 passes score ≥ 7, proceed to the Output Format section.

**Running the 4 passes in parallel (Claude Code / OpenCode):**
- Claude Code: delegate each pass to a subagent via the Agent tool (security-auditor, performance-engineer, code-reviewer for correctness+style). Spawn all in one message.
- OpenCode: use the `task` tool — one call per pass with `agent=security-auditor`, `agent=performance-engineer`, `agent=code-reviewer`. Wait for all to return, then aggregate.

**Verifier isolation:** Each pass evaluates ONLY the code — do not let findings from one pass bias another. When aggregating, treat each pass's output as independent evidence.

---

## Output Format

For each finding, report:

```
[SEVERITY] file:line — description
  Suggestion: how to fix
```

**Severity levels:**
- **CRITICAL** — Must fix before merge (security vulnerabilities, data loss risks)
- **HIGH** — Should fix before merge (bugs, performance issues, correctness errors)
- **MEDIUM** — Fix soon (maintainability, moderate style issues)
- **LOW** — Nice to have (minor style, micro-optimization)

### Summary

After all passes, output a severity count summary with per-pass confidence:

```
Review Summary
  CRITICAL:  2
  HIGH:      5
  MEDIUM:    8
  LOW:       3
  Total:    18

Pass Confidence Scores (must all be ≥ 7):
  Security:     Coverage 8 / Signal 9  ✓
  Performance:  Coverage 7 / Signal 8  ✓
  Correctness:  Coverage 9 / Signal 7  ✓
  Style:        Coverage 8 / Signal 8  ✓

Verdict: CHANGES REQUESTED (2 critical issues must be resolved)
```

**Verdict rules:**
- If any pass scored < 7 on Coverage or Signal: `REVIEW INCOMPLETE — [pass name] confidence gap` (do not deliver verdict; surface the gap instead)
- If CRITICAL > 0: `CHANGES REQUESTED`
- If HIGH > 3: `CHANGES REQUESTED`
- If only MEDIUM/LOW: `APPROVED with suggestions`
- If no findings and all passes ≥ 7: `APPROVED`

---

## Checklist Reference

Use this checklist to ensure comprehensive coverage:

### Security
- [ ] No SQL injection (parameterized queries used)
- [ ] No XSS (output properly escaped)
- [ ] No command injection (no shell exec with user input)
- [ ] Auth checks on all protected endpoints
- [ ] Secrets not hardcoded
- [ ] CORS properly configured
- [ ] Rate limiting on public endpoints

### Performance
- [ ] No N+1 queries
- [ ] Database queries have appropriate indexes
- [ ] Large lists are paginated
- [ ] No unnecessary data fetching
- [ ] Async operations properly awaited

### Correctness
- [ ] Edge cases handled (empty arrays, null, undefined)
- [ ] Error responses have appropriate status codes
- [ ] Validation on all user input
- [ ] Transactions used for multi-step DB operations
- [ ] Race conditions considered for shared state

### Tests
- [ ] New code has tests
- [ ] Tests cover happy path and error cases
- [ ] No test pollution (tests are independent)
- [ ] Mocks cleaned up after tests

### Style
- [ ] Consistent naming (camelCase, PascalCase as appropriate)
- [ ] No commented-out code
- [ ] Functions are focused (single responsibility)
- [ ] Types/interfaces defined for complex objects

---

## Integration with SDLC

When invoked from `/sdlc review [target]`, the review automatically includes:
- Current task context (which TASK-XXX is being implemented)
- Requirements being addressed (FR-XXX, US-XXX from TASKS.md)
- Architecture constraints from ARCHITECTURE.md

When invoked from `/gate review --task TASK-XXX`, the review focuses specifically on the task's deliverable files and checks them against the task's acceptance criteria.
