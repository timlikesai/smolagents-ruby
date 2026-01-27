# EDAA Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-26

---

## Status Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1-5 | Foundation, Multi-Model, Parallel Agents, Orchestration, Quality | ✅ Complete |
| 6 | Documentation | **Not Started** |
| 7-10 | Infrastructure Gaps, Live Testing, Experiments, Events | ✅ Complete |

**Test Suite:** 1788 examples, 95.7% coverage, ~6s parallel

---

## What's Left

### Phase 6: Documentation (Priority)

| Task | Description | Status |
|------|-------------|--------|
| YARD docs | All DSL builder methods | Not Started |
| Multi-model guide | Building agents with multiple models | Not Started |
| Parallel agents guide | Sub-agent spawning patterns | Not Started |
| Event patterns guide | Subscription, emission, error handling | Not Started |
| Future system docs | AgentFuture vs RactorLazy::ToolFuture | Not Started |
| Benchmarks | Performance profiling and baselines | Not Started |
| Overnight experiments | `docs/overnight_experiments.md` | ✅ Done |

### Optional Advanced Features

| Feature | Description | Effort |
|---------|-------------|--------|
| Cost tracking | Budget limits and token accounting | ~150 lines |
| Trace context | Add trace_id/span_id to events | ~100 lines |
| Event logger | Built-in JSONL consumer for events | ~150 lines |
| Public MockTool | Expose testing tools for experiments | ~50 lines |
| Cluster discovery | Auto-discover models across servers | ~400 lines |

---

## Architecture Reference

### Event System

Two composable modules:
- `Events::Emitter` - Emit events (models, tools, agents)
- `Events::Consumer` - Subscribe to events (observers, agents)

```ruby
# Symbol-based emission
emit :step_complete, step_number: 1, outcome: :success

# Block-based timing (auto-captures duration_ms)
result = emit(:model_generate_completed, model_id: "gpt-4") { api.call }

# Category subscriptions
on_tools { |e| ... }       # All tool_* events
on_lifecycle { |e| ... }   # step_complete, task_complete
on_errors { |e| ... }      # error, rate_limit, request_failed
on_models { |e| ... }      # model_generate_*, model_changed
on_agents { |e| ... }      # agent_launch, agent_progress, agent_complete
```

### Multi-Model Patterns

| Pattern | Flow | Use Case |
|---------|------|----------|
| Tiered | Query → Fast → Complex? → Big | Cost optimization |
| Swarm | Coordinator → [Researchers] → Synthesizer | Deep research |
| Pipeline | Vision → Description → Reasoning | Multimodal |
| Learning | Execute → Evaluate → Reflect → Apply | Self-improvement |

---

## Quick Reference

```bash
rake spec          # Run tests in parallel (~6s)
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI (lint + tests + doctest)
rake commit_prep   # Fix + Stage + Verify
```

### DSL Examples

```ruby
# Multi-model agent
Smolagents.agent
  .model(:execution) { fast_model }
  .model(:planning) { big_model }
  .tools(:search, :calculate)
  .planning(interval: 5)
  .build

# Remote server connection
Smolagents.model(:openai)
  .base_url("http://llama-ultra.local:1234/v1")
  .id("gpt-oss-20b-MXFP4")
  .with_health_check(cache_for: 30, verify_model: true)
  .with_retry(max_attempts: 3)
  .with_fallback { backup_model }
  .build

# Team with parallel execution
Smolagents.team
  .agent(researcher1, as: "broad")
  .agent(researcher2, as: "deep")
  .agent(synthesizer, as: "synth")
  .parallel(:broad, :deep)
  .then(:synth)
  .build
```

### Live Experiments

```bash
ruby experiments/live/run.rb --list      # List experiments
ruby experiments/live/run.rb --health    # Check infrastructure
ruby experiments/live/run.rb model_comparison  # Run specific
```

---

## Completed Work Summary

<details>
<summary>Click to expand completed phases</summary>

### Phases 1-5: Foundation
- Event system with 75 event types
- Multi-model support with purpose-based selection
- Parallel sub-agents with Ractor isolation
- Event-driven orchestration
- Code quality with custom RuboCop cops

### Phase 7: Infrastructure Gaps
- `base_url()` for remote servers
- MockModel failure injection
- Parallel execution in TeamBuilder
- Custom model purposes
- Health check verification

### Phase 8: Live Testing
- Validated on 3-machine distributed infrastructure
- Fixed `with_retry` method conflict
- Tiered reasoning and research swarm tested

### Phase 9: Experiment Framework
- `experiments/live/` with runner, logger, definitions
- model_comparison, code_generation, multi_model_patterns experiments
- 85.7% pass rate on model_comparison

### Phase 10: Event Completeness
- 22 components with Emitter, 4 with Consumer
- All lifecycle, planning, goal, health, execution events wired
- No logger calls for observability (events only)
- No `warn` statements (emit_error used)

</details>

---

## RuboCop Cops

| Cop | Purpose |
|-----|---------|
| NoSleep | Prevent blocking sleep calls |
| NoTimeoutBlock | Prevent Timeout.timeout |
| NoBusyWait | Prevent busy-wait loops |
| PreferDataDefine | Use Data.define for types |
| TypeLocationRule | Types must be in types/ |
