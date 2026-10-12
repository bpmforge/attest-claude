---
name: Interaction
trigger: /interaction
description: 'Interaction engineering — drag-and-drop and sortable cards, Kanban, resizable panels, dashboard/layout editors (dnd-kit, Puck), node canvases (React Flow), command palettes, undo/redo, layout persistence as validated JSON, keyboard + single-pointer alternatives, reduced motion. Spec it, build it, or audit it. NOT visual polish (frontend-design), NOT flows/WCAG-wide review (ux-engineer), NOT agent/generative UI (agent-ui-engineer).'
agent: interaction-engineer
arguments:
  - name: target
    description: Screen, feature, or URL (e.g., "kanban board", "http://localhost:3000/dashboard")
    required: false
  - name: --spec
    description: Write the interaction contract to docs/design/INTERACTIONS.md
    required: false
  - name: --implement
    description: Source components, build to the contract, Playwright-verify each gesture
    required: false
  - name: --audit
    description: Exercise mouse/keyboard/touch/reduced-motion/failure paths; findings only
    required: false
---

Triggers the **interaction-engineer** subagent in a forked context.

Owns how an interface *behaves*: drag/sort/resize, layout editors, node canvases, command palettes, undo/redo, and layout persistence as versioned, schema-validated JSON.

**Three modes:**

- **`/interaction --spec "<screen>"`** — inventory every interactive element, pick the smallest layer (dnd-kit / Puck / React Flow / resizable / cmdk), write the contract → `docs/design/INTERACTIONS.md`.
- **`/interaction --implement "<screen>"`** — source components (`references/component-sourcing.md`), exact-pin and ground library APIs, build one interaction at a time, add round-trip + Playwright gesture tests.
- **`/interaction --audit "<url>"`** — mouse, keyboard-only, touch (375 px), reduced motion, forced save failure, Escape mid-gesture → `docs/reviews/INTERACTION_AUDIT_<slug>_<date>.md` (P0–P3, every finding cites a gate + evidence).

**Looks things up, never builds from memory:** re-verifies library status from `references/ui-ecosystem-map.md` (`npm view`, `gh api`), grounds APIs per `references/library-adoption-protocol.md` (Context7 → installed types → `/api-ground`), web research via WebSearch/WebFetch with the year in the query.

**Gates:** `references/interaction-patterns.md` — every drag has a keyboard path and a single-pointer alternative, Escape restores, layout JSON round-trips, reduced motion has a variant.
