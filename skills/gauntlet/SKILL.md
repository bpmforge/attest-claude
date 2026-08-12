---
name: Gauntlet
trigger: /gauntlet
description: 'Gauntlet loop — multi-agent quality harness: a lead sets a real reference bar (a named product, test suite, or baseline to match or beat), splits the goal into gradeable units, builders produce artifacts in clean context, and blind fresh-per-round critics grade each artifact against the bar with evidence; failures loop until every unit passes, two rounds stall, or budget runs out. NOT /challenge (verifies factual claims); NOT /review (one-pass verdict) — this rebuilds until the work beats something real.'
agent: gauntlet-lead
arguments:
  - name: goal
    description: What to build or improve until it beats the bar (e.g., "landing page that beats linear.app's", "CSV parser matching papaparse's test suite")
    required: false
  - name: --bar
    description: The exemplar to match or beat — a reference product/screenshot, test suite + threshold, model doc, or measured baseline
    required: false
  - name: --budget
    description: Max rounds (default 5)
    required: false
---

Triggers the **gauntlet-lead** subagent in a forked context.

Multi-agent quality harness (Matt Shumer's gauntlet-loop technique): the LEAD sets a real
reference bar and splits the goal into independently gradeable units; BUILDERS produce artifacts
in clean context; BLIND CRITICS — a fresh context per unit per round, seeing only the artifact,
the bar, and the exemplar — grade with evidence; failures loop back until every unit passes, two
rounds stall, or the budget runs out.

**The two inviolables:** the agent that builds never grades its own work, and a critic that saw a
previous draft never grades the retry. Prior critiques go to the builder as fix input, never to
the next critic.

**The bar must be real:** a named product screen, a test suite + threshold, a model doc, a
measured baseline — written to `docs/gauntlet/BAR_<slug>.md` before round 1. "Make it amazing"
gets `BLOCKED: no real bar`. Aspirational bars are legitimate; uncomparable ones are not.

**Protocol:** `agents/shared/GAUNTLET_LOOP.md` — including boundaries vs `/challenge` (fact-checks
claims), Fix-Verify (closes known defects), and `/design-iterate` (token conformance against our
own spec — cheaper when the bar is internal).

**Outputs:**
- `docs/gauntlet/BAR_<slug>.md` — exemplar, per-criterion checks, budget
- `docs/gauntlet/GAUNTLET_<slug>.md` — round log, PASS evidence, which exit rule fired, below-bar residuals
