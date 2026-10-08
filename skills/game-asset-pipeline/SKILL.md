---
name: game-asset-pipeline
description: 'Deterministic post-process tooling for generated pixel-art sprite batches: lattice/pixel-snapper cleanup, transparency de-fringing, sprite-sheet packing with a portable atlas manifest. Pairs with agents/game/game-asset-pipeline.md, which owns generation + engine-specific import; this skill is the deterministic middle of that loop.'
---

# game-asset-pipeline — post-process scripts for generated sprite batches

Three deterministic Node.js scripts, one per stage of the post-generation
pipeline. Each is a pure-function library plus a small CLI; none of them call
a model — that's the job of `agents/game/game-asset-pipeline.md` (gen and
engine-specific import).

**Where the scripts live:** they ship in the
[attest](https://github.com/bpmforge/attest) repo under
`skills/game-asset-pipeline/scripts/`, not in this one. They depend on the
`sharp` npm package, which attest's `package.json` provides and this repo has
no `package.json` to install. To use them, clone attest and run `npm install`
there; attest's `skills/game-asset-pipeline/README.md` has the algorithm
detail and the atlas JSON schema. If no attest checkout is available, say so
and stop at the agent's gen and import steps rather than inventing the scripts.

| Script (in attest) | Stage | What it does |
|---|---|---|
| `pixel-snap.mjs` | post-process (lattice) | Snaps a soft/anti-aliased gen image onto an explicit pixel grid via dominant-color-per-cell voting; optional palette quantization + nearest-neighbor upscale preview. |
| `transparency-cleanup.mjs` | post-process (matte) | Threshold + un-premultiply alpha cleanup — kills background-bleed fringe pixels, de-fringes real sprite edges. |
| `sprite-sheet-pack.mjs` | sprite-sheet / engine import | Deterministic shelf-packs a batch of sprite PNGs into one sheet + emits a TexturePacker-hash-format atlas JSON (Phaser/PixiJS-native; convertible to Godot/Unity import formats by existing engine-side tooling). |

## Usage

From the root of an attest checkout (`S=skills/game-asset-pipeline/scripts`):

```bash
node $S/pixel-snap.mjs gen.png --grid 32x32 --palette 16 --upscale 4 --out sprite.snapped.png
node $S/transparency-cleanup.mjs sprite.snapped.png --out sprite.cleaned.png
node $S/sprite-sheet-pack.mjs ./batch/ --out sheet.png --json sheet.json
```

Chain them per asset in a batch, then pack the whole cleaned batch in one
`sprite-sheet-pack.mjs` call — packing is the one stage that operates on the
batch as a unit rather than one sprite at a time.

The scripts' tests run in attest:
`node --test 'skills/game-asset-pipeline/scripts/tests/*.test.mjs'`.
