---
name: Design Iterate
trigger: /design-iterate
description: 'Claude-Design-style visual iteration loop — render the running UI, screenshot at 375/768/1440, critique against docs/design/tokens.json and design principles, apply fixes, re-capture until clean (cap 3 iterations). Also extracts a token baseline from an existing codebase (--sync) and audits real logged-in browsers (--real). NOT a one-pass review — use /ux --review for findings-only; NOT functional conformance — use /ui-verify.'
agent: design-iterator
arguments:
  - name: target
    description: URL or screen to iterate on (e.g., "http://localhost:3000/checkout", "settings page")
    required: false
  - name: --sync
    description: Extract an observed token baseline from an existing codebase into docs/design/tokens.json (only when none exists)
    required: false
  - name: --real
    description: Capture + critique a real logged-in browser session (findings only, no fixes) via references/real-browser-bridge.md tiers
    required: false
---

Triggers the **design-iterator** subagent in a forked context.

The closed render→screenshot→critique→fix→re-verify loop that makes a running UI match its design
system — code edits and rendered pixels in one feedback cycle, the property that makes
Claude-Design-style tools work.

**Three modes:**

- **`/design-iterate "<target>"`** (default) — ground in `docs/design/tokens.json` → render → capture mobile/tablet/desktop → deterministic token-lint + vision critique → apply smallest fixes → re-capture until no P0/P1 remains or the 3-iteration cap hits.
- **`/design-iterate --sync`** — extract the *observed* design system from an existing codebase + running app into `docs/design/tokens.json` (`provenance: extracted-baseline`) + `docs/design/TOKEN_DRIFT.md`. Only when no tokens.json exists — authored systems from design-system-lead always win.
- **`/design-iterate --real "<url>"`** — capture + critique a real logged-in browser (findings only, no fixes): persistent profile → playwright-mcp `--extension` mode → CDP attach → claude-in-chrome, per `references/real-browser-bridge.md`. Read-only; login/CAPTCHA hands off to the human.

**Code and pixels in one loop:** a fix is not done when the code is edited — it is done when a fresh screenshot shows it closed. Every finding is grounded: screenshot path + viewport + element + cited token/principle. No vibes.

**Outputs:**
- default → `docs/design/ITERATION_LOG.md` + `docs/screenshots/design-iterate/iter-N/`
- `--sync` → `docs/design/tokens.json` + `docs/design/TOKEN_DRIFT.md`
- `--real` → `docs/design/DESIGN_AUDIT_LIVE.md`
