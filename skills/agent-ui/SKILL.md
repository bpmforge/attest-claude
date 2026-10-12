---
name: Agent UI
trigger: /agent-ui
description: 'Agent and generative UI — human-in-the-loop approvals, tool-call and trace views, streaming/cancel/retry states, persistent editable artifacts, runtime-generated UI from a typed component catalog (catalog → JSON spec → validate → render), sandboxing. Selects and grounds CopilotKit / AG-UI / assistant-ui / json-render. NOT prompts/evals (llm-integration-engineer), NOT LLM security audit (owasp-llm-checker).'
agent: agent-ui-engineer
arguments:
  - name: target
    description: Feature or URL (e.g., "deploy approval flow", "http://localhost:3000/chat")
    required: false
  - name: --design
    description: Action classification, output→surface map, catalog, state matrix → docs/design/AGENT_UI.md
    required: false
  - name: --implement
    description: Build approvals, streaming states, trace view, validated generative renderer with tests
    required: false
  - name: --audit
    description: Approve/reject/timeout, tool failure, cancel, malicious output, keyboard; findings only
    required: false
---

Triggers the **agent-ui-engineer** subagent in a forked context.

Builds the surfaces where a person works with an AI agent: see what it is doing, approve what matters, edit what it produced, recover when it fails. Chat is one input, not the product.

**Three modes:**

- **`/agent-ui --design "<feature>"`** — classify every tool (read / reversible / irreversible-external), map outputs to surfaces, define the component catalog and async-state matrix, name trust boundaries → `docs/design/AGENT_UI.md` (+ ADR for CopilotKit / AG-UI / assistant-ui / json-render choice).
- **`/agent-ui --implement "<feature>"`** — approvals → streaming/cancel/error states → trace panel → catalog + validated renderer; deterministic tests on a stubbed agent stream.
- **`/agent-ui --audit "<url>"`** — approval approve/edit/reject/timeout, tool failure, cancel mid-stream, malicious model output, keyboard-only → `docs/reviews/AGENT_UI_AUDIT_<slug>_<date>.md`.

**Looks things up:** this ecosystem renames, archives, and shuts down projects monthly — every framework is re-verified on the day it is recommended (`references/ui-ecosystem-map.md` lookup recipes, Context7, `/api-ground`).

**Gates:** `references/agent-ui-patterns.md` — the UI (not the prompt) decides what needs approval, no model HTML in the app origin, Stop aborts the request, approvals time out to rejected.
