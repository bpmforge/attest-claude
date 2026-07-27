---
name: Security Audit
trigger: /security
description: 'OWASP audit, threat modeling, CVE/dependency scanning. Supports --quick (default, ~10 min) and --deep (Ralph Wiggum: exhaustive OWASP x SAST rules x iterative attack chain, ~45-90 min). SAST runs on Opengrep + in-house bpm-rulepacks (never license-restricted registry rules). Proactive: before production deploys, after auth changes, new user-input handling, or adding dependencies. NOT for code quality — use /review-code.'
context: fork
agent: security-auditor
arguments:
  - name: target
    description: What to audit (file, directory, or "full" for entire project)
    required: false
  - name: --quick
    description: Phases 1-3 only (default). Automated scan + one-pass OWASP. ~10 min.
    required: false
  - name: --deep
    description: Ralph Wiggum loop. Every OWASP category iterated to confidence >= 7, every custom semgrep rule file walked, iterative attack-chain until stable. Blocks until scripts/validators/validate-phase-gate.sh security-deep exits clean. ~45-90 min.
    required: false
  - name: --fix
    description: After auditing, drive a verified fix loop — build a fix backlog (CRITICAL+HIGH default), dispatch coding-agent to remediate, then re-scan to confirm each finding is actually closed (FIX_VERIFY_LOOP). Skips dead-code findings; flags auth/crypto/input fixes for human review. Combine with --deep.
    required: false
  - name: --owasp
    description: Run OWASP Top 10 check against the codebase
    required: false
  - name: --deps
    description: Audit dependencies for known vulnerabilities
    required: false
  - name: --threat-model
    description: Generate a STRIDE threat model for the system
    required: false
  - name: --secrets
    description: Scan for hardcoded secrets, API keys, credentials
    required: false
---

Triggers the **security-auditor** subagent in a forked context.

The auditor performs professional security assessments following OWASP, NIST,
and industry-standard penetration testing frameworks.

**Capabilities:**
- OWASP Top 10 systematic assessment (A01-A10)
- Secret scanning (API keys, tokens, credentials in source)
- Dependency audit (CVE checks, outdated packages)
- STRIDE threat modeling with risk ratings
- Auth/authz flow analysis
- `--fix`: verified remediation loop (audit → fix backlog → coding-agent → re-scan to confirm closed)

**Output:** Structured findings report with severity levels
(CRITICAL / HIGH / MEDIUM / LOW / INFO), file:line locations,
impact assessment, and specific remediation steps.
