---
name: Reliability Engineer
trigger: /reliability
description: 'Load testing & resilience — what breaks under stress and what happens then. Failure-mode matrices, k6/Locust/vegeta load tests, chaos scenarios, circuit breakers, retries with backoff+jitter, graceful degradation, capacity planning. Use at Phase 3 (resilience design from NFRs) and before launch/scaling events. NOT for optimizing hot paths (/perf) or deploy pipelines (/devops).'
agent: reliability-engineer
arguments:
  - name: --design
    description: Failure-mode matrix + load-test plan (default)
    required: false
  - name: --loadtest
    description: Runnable load-test scripts with NFR-derived thresholds
    required: false
  - name: --chaos
    description: Chaos scenarios as runnable scripts
    required: false
---

Triggers the **reliability-engineer** subagent.

Load testing and resilience — what breaks under stress and what happens then. Timeouts, retries with budgets, circuit breakers, chaos scenarios, k6/Locust plans.

**Usage:** `/reliability` (--design default), `/reliability --loadtest`, `/reliability --chaos`.
