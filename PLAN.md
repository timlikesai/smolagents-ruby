# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

---

## Current Status

| Metric | Value | Status |
|--------|-------|--------|
| Ruby Version | 4.0 | Target |
| RSpec Tests | 6134 | Passing |
| Line Coverage | 93.6% | Met |
| RuboCop Offenses | 26 | Metrics only |
| Executors | LocalRuby, Ractor | Simplified |

---

## Recent Completions

### Concurrency Architecture Audit ✓

Comprehensive analysis of Fiber/Thread/Ractor usage:

| Primitive | Purpose | Correctness |
|-----------|---------|-------------|
| **Fiber** | Cooperative control flow (agent ↔ consumer) | ✓ Fixed context detection |
| **Thread** | Background I/O, parallel tools, async events | ✓ Proper mutex usage |
| **Ractor** | Memory-isolated code execution | ✓ Message-passing IPC |

**Bug Fixed:** `tools/tool/execution.rb` was using fiber-local storage (`Thread.current[]`) while fiber context was set with thread-local storage (`thread_variable_set`). Now consistent.

### Docker Removal ✓

Simplified execution model to Ruby-only:

| Before | After |
|--------|-------|
| 3 executors (LocalRuby, Docker, Ractor) | 2 executors (LocalRuby, Ractor) |
| Multi-language (Ruby, Python, JS, TS) | Ruby only |
| Container orchestration | Native Ractor isolation |
| ~500ms container startup | ~20ms Ractor startup |

### Self-Documenting Infrastructure ✓

| System | API |
|--------|-----|
| Events | `Smolagents.events`, `Smolagents.event(:name)`, `Smolagents.event_docs` |
| Concerns | `Smolagents.concerns`, `Smolagents.concern(:name)`, `Smolagents.concern_graph` |
| Builders | `.summary`, `.available_methods`, `.ready_to_build?` |

### Concern Decomposition ✓

Split large concerns into focused sub-modules:
- Control → FiberControl, SyncHandler, RequestHandlers
- Repetition → Detection, Similarity, Guidance
- RetryPolicy → Configs, Backoff, Execution

---

## Architecture (Ruby 4.0)

### Execution Model

```
Agent (Fiber for control flow)
    │
    ▼
Code Executor
    │
    ├── LocalRuby (fast, BasicObject sandbox)
    │   └── ~0ms overhead
    │   └── TracePoint ops limit
    │   └── Same-process isolation
    │
    └── Ractor (secure, memory isolation)
        └── ~20ms overhead
        └── Message-passing for tools
        └── Full memory separation
```

### Concurrency Primitives

```ruby
# Fiber: Control flow (yield steps, request input)
Fiber.new { agent_loop }.resume

# Thread: Background work
Thread.new { async_event_queue }

# Ractor: Code sandboxing
Ractor.new(code) { |c| sandbox.eval(c) }

# Thread-local (shared across Fibers)
Thread.current.thread_variable_set(:key, value)

# Fiber-local (per-Fiber)
Thread.current[:key] = value
```

---

## Next Up

### 1. Ruby 4.0 Idiom Polish

Ensure consistent use of Ruby 4.0 patterns:

| Pattern | Where | Status |
|---------|-------|--------|
| `it` numbered parameter | Blocks | Audit needed |
| Endless methods | Simple accessors | In use |
| Pattern matching | Control flow | In use |
| Data.define | All value types | In use |

### 2. Remaining Metrics Violations

26 RuboCop offenses remain (all Metrics):

| File | Issue | Action |
|------|-------|--------|
| `testing/matchers/*.rb` | Method complexity | Accept (matcher DSL) |
| `events/registry.rb` | Module length | Consider split |
| `concerns.rb` | Block length | Consider split |

### 3. API Ergonomics

| Improvement | Example |
|-------------|---------|
| Shorter model config | `.model(:openai, "gpt-4")` vs `.model { OpenAI.new(...) }` |
| Tool categories in DSL | `.tools(:search, :web)` already works |
| Executor selection | `.sandbox(:ractor)` for explicit choice |

---

## Backlog

### Research-Backed Features (Blocked on Polish)

| Feature | Research | Improvement |
|---------|----------|-------------|
| Pre-Act Planning | arXiv:2505.09970 | 70% |
| Self-Refine | arXiv:2303.17651 | 20% |
| STRATUS Checkpointing | NeurIPS 2025 | 150% |
| Dynamic Tools | ToolMaker, TOOLFLOW | Context-aware |

### Deferred (Lacking Evidence)

| Item | Reason |
|------|--------|
| Multi-language execution | Removed Docker, Ruby-only focus |
| StateSnapshot | Overhead without proven value |
| Debate Pattern | Only 3% improvement |
| GraphRAG | Complex, low priority |

---

## Principles

- **Ruby 4.0 Only** - No backwards compatibility
- **Simple by Default** - One line for common cases
- **100/10 Rule** - Modules ≤100 lines, methods ≤10 lines
- **Test Everything** - MockModel for fast deterministic tests
- **Forward Only** - Delete unused code, no legacy shims
- **Ractor for Security** - Memory isolation for untrusted code
