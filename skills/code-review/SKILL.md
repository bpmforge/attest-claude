---
name: Code Review
trigger: /review-code
description: 'Code-health audit — complexity, duplication, error handling, type invariants, patterns, naming, comment accuracy, dead/unutilized code. Four modes: --review (full pass), --debt (tech-debt catalog), --consolidate (DRY + error-handling consolidation), --patterns (cross-codebase consistency). NOT for security vulns (/security) or performance profiling (/perf).'
agent: code-reviewer
arguments:
  - name: target
    description: File, directory, or git diff to review (optional, defaults to full codebase)
    required: false
  - name: --review
    description: Default — full 9-dimension health pass → docs/reviews/CODE_REVIEW_<date>.md
    required: false
  - name: --debt
    description: Tech-debt catalog sorted by leverage → docs/reviews/TECH_DEBT_<date>.md
    required: false
  - name: --consolidate
    description: DRY + error-handling consolidation proposals → docs/reviews/CONSOLIDATION_<date>.md
    required: false
  - name: --patterns
    description: Cross-codebase pattern consistency audit → docs/reviews/PATTERNS_<date>.md
    required: false
---

Triggers the **code-reviewer** subagent.

Reviews code for **code health** — maintainability, patterns, tech debt, complexity, duplication, error handling, type invariants, naming, and comment accuracy. Distinct from security audit (vulnerabilities) and performance profiling (use `/security` and `/perf`).

**The 9 dimensions scored on every `--review`:**
1. Complexity (function/file length, nesting, cyclomatic)
2. Duplication / DRY (copy-paste ratio, missing abstractions)
3. Error Handling (silent failures, broad catches, missing context)
4. Type Safety & Invariants (illegal states unrepresentable)
5. Pattern Consistency (consistency with codebase idioms)
6. Naming Quality (intent-revealing, booleans-as-questions)
7. Comment Accuracy (comments match code behavior)
8. Dead / Unutilized Code (stubs, never-called functions, unused exports, orphan files, disconnected pipelines)
9. Tech-Stack Compliance (every dependency in TECH_STACK.md; no new tech introduced outside the design)

**Outputs:**
- `--review` → `docs/reviews/CODE_REVIEW_<date>.md` (Health Dashboard + findings + verdict)
- `--debt` → `docs/reviews/TECH_DEBT_<date>.md` (prioritized debt register)
- `--consolidate` → `docs/reviews/CONSOLIDATION_<date>.md` (DRY + error-handling refactor proposals)
- `--patterns` → `docs/reviews/PATTERNS_<date>.md` (cross-codebase drift audit)

**Reference:** `references/code-health-checklist.md` (read at start of every invocation). Confidence-scored findings (suppress <75), verbatim code quotes, asymmetric gate-loop (< 5 = fail, ≥ 7 = pass).
