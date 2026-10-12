---
name: UX Expert
trigger: /ux
description: 'Design direction, UX workflows, component architecture, WCAG 2.2 accessibility, live-environment design review. Use when designing new interfaces, reviewing PR UI changes, or auditing accessibility.'
agent: ux-engineer
arguments:
  - name: task
    description: What to design or review (e.g., "redesign settings page", "review PR 234", "audit dashboard")
    required: false
  - name: --design
    description: Greenfield mode — produce DESIGN_PRINCIPLES.md + STYLE_GUIDE.md + UX_SPEC.md
    required: false
  - name: --review
    description: Live design review — 7-phase methodology with triage matrix (Blocker/High/Medium/Nit)
    required: false
  - name: --audit
    description: WCAG 2.2 Level AA accessibility audit only
    required: false
  - name: --research
    description: Design research — cited references from shipped products, patterns extracted, directions checked against the stack → docs/design/REFERENCES.md
    required: false
  - name: --flows
    description: User workflow diagrams only (no code, no style guide)
    required: false
---

Triggers the **ux-engineer** subagent in a forked context.

Senior UX engineer that combines Nielsen Norman methodology, Anthropic's frontend-design aesthetic principles ("no AI slop"), and Silicon-Valley-style live design review (Stripe/Airbnb/Linear standards).

**Three modes:**

- **`/ux --design`** (greenfield) — pick a bold aesthetic direction, write design principles + style guide + UX spec. Invoked by `sdlc-lead` during Phase 3 for UI-bearing projects.
- **`/ux --research "<screen or job>"`** — study how shipped products and runnable open-source apps solve the same job (references/design-research-protocol.md): 5–8 cited, captured, annotated references → patterns → 2–3 stack-checked directions in `docs/design/REFERENCES.md`. Also the first step of `--design` for major screens.
- **`/ux --review`** (PR / existing UI) — 7-phase live review: Interaction → Responsive → Visual → A11y → Robustness → Code Health → Content. Uses Playwright MCP if available, falls back to script or static. Blocker/High/Medium/Nit triage.
- **`/ux --audit`** (WCAG) — focused accessibility audit against WCAG 2.2 Level AA.

**Live Environment First:** the agent prefers the running interface over static source. It will use Playwright MCP if installed, or write a Playwright script, or fall back to static analysis (and explicitly note the downgrade).

**Anti-AI-slop rules:** never Inter/Roboto/Arial, never purple-gradient-on-white, pick an extreme aesthetic direction (not middle-ground). Reference: `references/design-review-checklist.md`.

**Outputs:**
- `--design` → `docs/design/DESIGN_PRINCIPLES.md`, `docs/design/STYLE_GUIDE.md`, `docs/design/UX_SPEC.md`
- `--review` → `docs/UX_REVIEW.md` + screenshots
- `--audit` → `docs/ACCESSIBILITY_AUDIT.md`
