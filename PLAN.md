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
| 9 | Live Experiment Framework | ✅ Built |

**Test Suite:** 14,500+ examples, 95.8% coverage, ~5s parallel

---

## Recent Additions

### LLM Trace Logging (2026-01-26)

Added `TracedModel` wrapper for debugging and failure analysis:

```ruby
# Automatically wraps models in experiment runner
traced = TracedModel.new(model)
result = traced.generate(messages)
traces = traced.drain_traces  # Full prompt/response capture
```

**Captures:**
- Full message history sent to models
- Raw response content with tool calls
- Token usage and latency per call
- Error types and messages

**Analysis Tool:**
```bash
ruby experiments/live/analyze.rb <log_dir>
```

**Key Finding:** Many experiment failures are infrastructure issues (server 500 errors), not model capability problems. Trace logging helps distinguish these.

### Reliability Improvements (2026-01-26)

Fixed several issues causing experiment failures:

1. **Server 500 errors now retriable**
   - Added `Faraday::ServerError` to default retriable errors
   - Enhanced `retriable?` to check HTTP status codes (408, 429, 500, 502, 503, 504)

2. **Per-endpoint circuit breakers**
   - Previously all OpenAI models shared "openai_api" circuit
   - Now each endpoint gets unique circuit name (e.g., "openai_c21f969b")
   - Prevents failures on one endpoint from blocking all others

**Results improvement:**
- Before: 164 server errors, 44% pass rate (code_generation)
- After: 0 error traces, 90.5% pass rate (model_comparison)

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

### Phase 9: Live Experiment Framework

Built comprehensive experiment runner for overnight/batch testing.

**Location:** `experiments/live/`

**Components:**
- `lib/infrastructure.rb` - Model factories for all 3 machines
- `lib/experiment.rb` - Experiment definition DSL
- `lib/experiment_logger.rb` - JSONL logging with crash safety
- `lib/runner.rb` - Execution engine with event capture
- `definitions/*.rb` - Experiment definitions

**Available Experiments:**

| Experiment | Models | Tasks | Purpose |
|------------|--------|-------|---------|
| `model_comparison` | fast_20b, coder_30b, utility | 7 | Compare model capabilities |
| `code_generation` | coder, reasoning, fast | 6 | Test code writing/debugging |
| `multi_model_patterns` | tiered, baselines | 6 | Test orchestration patterns |

**First Run Results (model_comparison):**
- 63 tasks, 54 passed (85.7%)
- coder_30b (Qwen3-Coder-30B): fastest, most reliable
- fast_20b (gpt-oss-20b): solid all-around
- utility (LFM2.5-1.2B): struggles with complex tasks (expected)

**Usage:**
```bash
ruby experiments/live/run.rb --list      # List experiments
ruby experiments/live/run.rb --health    # Check infrastructure
ruby experiments/live/run.rb model_comparison  # Run specific
ruby experiments/live/run.rb             # Run all
```

---

## Suggested Improvements

### High Value Enhancements

| Enhancement | Description | Impact |
|-------------|-------------|--------|
| Token tracking | Capture actual token counts from API responses | Cost analysis |
| Result persistence | SQLite/JSON store for cross-run analysis | Trend tracking |
| Overnight supervisor | Process management with crash recovery | Reliability |
| HTML report generator | Visual summary of experiment results | Usability |
| Slack/webhook notifications | Alert on completion or failure | Monitoring |

### Architecture Improvements

| Area | Current | Suggested |
|------|---------|-----------|
| Health checks | Per-request | Background polling with circuit breaker |
| Model selection | Manual | Auto-select based on task complexity |
| Logging | JSONL files | Structured logging + OpenTelemetry |
| Parallelism | Sequential models | Concurrent model testing |

### New Experiment Ideas

1. **Stress testing** - High volume concurrent requests
2. **Failover scenarios** - Kill endpoints mid-task
3. **Long-running tasks** - Multi-hour research projects
4. **Memory pressure** - Test with constrained contexts
5. **Model ensemble** - Vote across multiple models

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
