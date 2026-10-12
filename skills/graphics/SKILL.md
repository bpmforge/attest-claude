---
name: Graphics
trigger: /graphics
description: 'Interactive graphics — 3D (three.js / React Three Fiber + drei), WebGL/WebGPU and shaders, high-performance 2D canvas (PixiJS, OGL), scroll/timeline scenes, spatial visualizations. Frame budgets per device tier, compressed assets, static/DOM fallbacks, disposal, canvas accessibility. Design, build, or audit. NOT standard charts (frontend-design), NOT drag/drop or node editors (interaction-engineer), NOT game loops (gameplay-engineer).'
agent: graphics-engineer
arguments:
  - name: target
    description: Scene, feature, or URL (e.g., "3D product configurator", "http://localhost:3000/explainer")
    required: false
  - name: --design
    description: Purpose, device tiers + budgets, scene inventory, assets, fallbacks, a11y → docs/design/GRAPHICS.md
    required: false
  - name: --implement
    description: Static fallback first, then the scene one element at a time, with perf + fallback tests
    required: false
  - name: --audit
    description: Throttled frame times, memory over time, WebGL-off / context-loss / reduced-motion / keyboard; findings only
    required: false
---

Triggers the **graphics-engineer** subagent in a forked context.

Owns what renders inside the `<canvas>`: 3D (three.js / React Three Fiber + drei), WebGL/WebGPU shaders, PixiJS/OGL 2D, scroll/timeline scenes, spatial visualizations. Graphics have to earn their place: a flat alternative wins ties.

**Three modes:**

- **`/graphics --design "<scene>"`** — purpose and rejected flat alternative, device tiers with frame/draw-call/memory budgets, scene inventory with keyboard paths, asset pipeline, fallbacks, DOM equivalent → `docs/design/GRAPHICS.md` (+ ADR).
- **`/graphics --implement "<scene>"`** — static/DOM fallback first, then demand rendering, off-screen pause, disposal, tier switching; compressed assets; tests for WebGL-off, remount memory, reduced motion.
- **`/graphics --audit "<url>"`** — throttled-mobile p95 frame time, `renderer.info` and memory over time, forced context loss, WebGL disabled, reduced motion, keyboard → `docs/reviews/GRAPHICS_AUDIT_<slug>_<date>.md`.

**Looks things up:** three.js is 0.x with breaking changes nearly every release; every package and peer set is re-verified (`references/ui-ecosystem-map.md`, Context7, `/api-ground`, the three.js migration guide).

**Gates:** `references/graphics-patterns.md`.
