---
name: Analytics Architect
trigger: /analytics
description: 'Telemetry/instrumentation design — RED/USE/golden-signals selection, metrics catalog, event taxonomy, SLO-derived alerts, dashboard design. Use at Phase 3 or when nobody can answer "is it working?" in production. NOT for deploying the stack (/devops) or spend (/cost).'
agent: analytics-architect
arguments:
  - name: --spec
    description: Produce docs/OBSERVABILITY.md (default)
    required: false
  - name: --events
    description: Product event taxonomy
    required: false
  - name: --dashboards
    description: Dashboard plan
    required: false
---

Triggers the **analytics-architect** subagent.

Telemetry and instrumentation design — RED/USE/golden signals, event taxonomy, observability spec, dashboards. Use at design time or when nobody can answer whether prod is healthy.

**Usage:** `/analytics` (--spec default), `/analytics --events`, `/analytics --dashboards`.
