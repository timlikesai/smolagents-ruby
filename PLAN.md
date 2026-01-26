# EDAA Implementation Plan

**Branch:** feature/tool-future-lazy-eval
**Updated:** 2026-01-26

---

## Status Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Foundation (events, work queue) | ✅ Complete |
| 2 | Multi-Model Support | ✅ Complete |
| 3 | Parallel Sub-Agents | ✅ Complete |
| 4 | Event-Driven Orchestration | ✅ Complete |
| 5 | Code Quality & Hardening | ✅ Complete |
| 6 | Documentation | Not Started |
| 7 | Multi-Model Infrastructure Gaps | ✅ Complete |
| 8 | Live Infrastructure Testing | ✅ Validated |

**Test Suite:** 14,500+ examples, 95.8% coverage, ~5s parallel

---

## What's Left

### Phase 6: Documentation

1. **YARD docs** for all DSL builder methods
2. **Guides** for multi-model agents, parallel agents, events
3. **Benchmarks** and performance profiling
4. **Two-layer future system** explanation (AgentFuture vs RactorLazy::ToolFuture)
5. **Event handler patterns** and error handling guidance

### Priority 3: Advanced Features (Optional)

| Feature | Description | Effort |
|---------|-------------|--------|
| Cost tracking | Budget limits and token accounting | ~150 lines |
| Checkpoint/resume | Save and restore agent state | ~300 lines |
| Cluster discovery | Auto-discover models across servers | ~400 lines |

---

## Completed Work

### Phase 7: Multi-Model Infrastructure Gaps

Added capabilities needed for distributed multi-model agents.

**Quick Wins (P1):**
- `base_url()` method on ModelBuilder for remote servers
- MockModel failure injection for testing resilience
- Event sequence numbers for ordering

**Core Improvements (P2):**
- Parallel execution control in TeamBuilder (`.parallel()`, `.then()`)
- Custom model purposes (any symbol: `:triage`, `:vision`, etc.)
- Health check model verification (`verify_model: true`)
- Tool access to model pool (`inject_models: [:vision]`)

### Phase 8: Live Infrastructure Testing

Validated multi-model agents on real distributed infrastructure.

**Bug Fixed:** `with_retry` method conflict where configuration shadowed execution. Now detects usage pattern and delegates appropriately.

**Infrastructure Validated:**

| Machine | Role | Models |
|---------|------|--------|
| LLaMA Ultra | Fast + Reasoning | gpt-oss-20b-MXFP4, Qwen3-Coder-30B |
| MacBook Pro M4 | Workers | glm-4.7-flash-mlx@8bit, nemotron-3-nano |
| Mac Studio | Fallback | openai/gpt-oss-20b, glm-4.7-flash-mlx |

**Test Results:**
- **Tiered reasoning:** Agent correctly computed 2+2=4
- **Research swarm:** Synthesized coherent answer about Ruby Ractor API

---

## Multi-Model Agent Experiments

Located in `experiments/multi_model_agents/` with 84 passing tests.

### Architecture Patterns

| Pattern | Flow | Use Case |
|---------|------|----------|
| Tiered | Query → Fast → Complex? → Big | Cost optimization |
| Swarm | Coordinator → [Researchers] → Synthesizer | Deep research |
| Pipeline | Vision → Description → Reasoning | Multimodal |
| Learning | Execute → Evaluate → Reflect → Apply | Self-improvement |

### Experiment Files

| File | Pattern | Tests |
|------|---------|-------|
| `04_tiered_reasoning.rb` | Fast triage → Big reasoning | 14 |
| `05_research_swarm.rb` | Parallel research + synthesis | 18 |
| `06_visual_analysis_pipeline.rb` | Vision → Reasoning | 18 |
| `07_self_improving_agent.rb` | Meta-learning | 18 |
| `09_distributed_analyst.rb` | Combined system | 16 |

### Live Test Runners

```bash
# Test tiered reasoning with real infrastructure
ruby experiments/multi_model_agents/run_tiered_test.rb

# Test research swarm with real infrastructure
ruby experiments/multi_model_agents/run_research_swarm_test.rb
```

---

## Quick Reference

```bash
rake spec          # Run tests in parallel (~5s)
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

### Custom RuboCop Cops

| Cop | Purpose |
|-----|---------|
| NoSleep | Prevent blocking sleep calls |
| NoTimeoutBlock | Prevent Timeout.timeout |
| NoBusyWait | Prevent busy-wait loops |
| PreferDataDefine | Use Data.define for types |
| TypeLocationRule | Types must be in types/ |
