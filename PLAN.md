# smolagents-ruby Project Plan

> **When updating this file:** Remove completed sections, consolidate history, keep it lean.
> The plan should be actionable, not archival. If work is done, collapse it to a single line in Completed.

Delightfully simple agents that think in Ruby.

See [ARCHITECTURE.md](ARCHITECTURE.md) for vision, patterns, and examples.

---

## Principles

- **Ship it**: Working software over perfect architecture
- **Simple first**: If it needs explanation, simplify it
- **Test everything**: No feature without tests
- **Delete unused code**: If nothing calls it, remove it
- **Cops guide development**: Fix the code, don't disable the cop

---

## Current Status

**What works:**
- CodeAgent - writes Ruby code, executes tools, returns answers
- ToolAgent - uses JSON tool calling format (renamed from ToolCallingAgent)
- Builder DSL - `Smolagents.code.model{}.tools().build` or `Smolagents.tool...`
- Models - OpenAI, Anthropic, LiteLLM adapters
- Tools - base class, registry, 10+ built-ins
- ToolResult - chainable, pattern-matchable
- Executors - Ruby sandbox, Docker, Ractor isolation
- Sandboxes - Sandbox base, CodeSandbox, ToolSandbox hierarchy
- Event system - Thread::Queue, Emitter/Consumer pattern
- Ruby 4.0 idioms enforced via RuboCop

**Coverage:**
- Code: 93.58% (threshold: 80%)
- Docs: 97.31% (target: 95%)
- Tests: 2980 total, 0 failures

**RuboCop Metrics (at defaults, 0 offenses):**
| Cop | Current | Offenses | Status |
|-----|---------|----------|--------|
| LineLength | 120 | 0 | ✅ |
| CyclomaticComplexity | 7 | 0 | ✅ |
| PerceivedComplexity | 8 | 0 | ✅ |
| MethodLength | 10 | 0 | ✅ |
| AbcSize | 17 | 0 | ✅ |
| ClassLength | 100 | 0 | ✅ |
| ModuleLength | 100 | 0 | ✅ |

---

## Active Work: P2 - DSL Enhancements & Release Prep

> **Goal:** Prepare for 1.0 release with enhanced DSLs.

### Module Architecture (Completed)

Concerns consolidated into cohesive subdirectories:

| Subdirectory | Contents | Status |
|--------------|----------|--------|
| `concerns/resilience/` | retry_policy, retryable, circuit_breaker, rate_limiter | ✅ |
| `concerns/reliability/` | model_fallback, reliability_events, retry_execution, health_routing, reliability_notifications | ✅ |
| `concerns/parsing/` | json, xml, html | ✅ |
| `concerns/execution/` | code_execution, step_execution, tool_execution | ✅ |
| `concerns/sandbox/` | ruby_safety, sandbox_methods | ✅ |
| `concerns/monitoring/` | monitorable, auditable | ✅ |
| `concerns/react_loop/` | ReAct loop decomposed | ✅ |
| `concerns/model_health/` | health checks, discovery, thresholds | ✅ |
| `concerns/request_queue/` | queue operations, worker | ✅ |

### Builder Decomposition (Future)

Split large builders when need arises:

| Target | Current LOC | Status |
|--------|-------------|--------|
| `builders/agents/` | agent_builder (500) | Backlog |
| `builders/models/` | model_builder (787) | Backlog |

### Ruby 4.0 Metaprogramming Patterns

#### Pattern 1: Concern Composer DSL

Create a declarative way to compose concerns:

```ruby
module Concerns
  module CompositionDSL
    def composes(*modules)
      modules.each { |m| include(m) }
    end

    def extends_with(*modules)
      modules.each { |m| extend(m) }
    end
  end
end

# Usage:
module Concerns::Resilience
  extend CompositionDSL
  composes Retryable, CircuitBreaker, RateLimiter
end
```

#### Pattern 2: Method Delegation via Data.define

Leverage Data.define's `with` for immutable builders:

```ruby
# Current (verbose)
def with_config(**kwargs)
  self.class.new(agent_type:, configuration: configuration.merge(kwargs))
end

# Ruby 4.0 (using Data.define's built-in with)
def max_steps(n) = with(configuration: configuration.merge(max_steps: n))
```

#### Pattern 3: Pattern Matching in Step Dispatch

Expand pattern matching for cleaner control flow:

```ruby
# Current (conditional)
if step.is_final_answer
  return step.action_output
elsif step.error
  handle_error(step.error)
end

# Ruby 4.0 pattern matching
case step
in ActionStep[is_final_answer: true, action_output:]
  action_output
in ActionStep[error:] unless error.nil?
  handle_error(error)
in PlanningStep[plan:]
  execute_plan(plan)
end
```

#### Pattern 4: Anonymous Block Forwarding

Leverage `&` shorthand throughout:

```ruby
# Current
def on_error(&block)
  on(Events::Error, &block)
end

# Ruby 4.0
def on_error(&) = on(Events::Error, &)
```

### DSL Ideas (from research)

1. **Model Benchmark DSL** - Declarative model capability testing with profiles (:quick, :thorough, :production)
2. **Agent Composition DSL** - Multi-modal agents with capability routing (text, image, audio)
3. **Memory DSL** - Composable memory strategies (sliding window, persistence, semantic indexing)
4. **Event/Callback DSL** - Pattern-matchable events with lifecycle hooks
5. **Configuration Profiles** - Environment-aware settings with inheritance

---

## P2 - Release

- [ ] README with getting started guide
- [ ] Gemspec complete
- [ ] CHANGELOG
- [ ] Version 1.0.0

---

## Backlog

| Item | Notes |
|------|-------|
| Sandbox DSL builder | Composable sandbox configuration like agent builders |
| Split agent_types.rb | 660 LOC, split into focused files by domain |
| ToolResult private helpers | Mark `deep_freeze`, `chain` as `@api private` |
| URL normalization | IPv4-mapped IPv6, IDN encoding edge cases |
| Shared RSpec examples | DRY up test patterns via shared_examples_for |
| Ractor-based tool execution | Move tool execution to Ractor for isolation |

---

## Completed

| Date | Item |
|------|------|
| 2026-01-15 | **P2.2 Complete**: sandbox/, monitoring/ consolidation; P1.7 error redaction + outcome states unified |
| 2026-01-15 | **P2.1 Complete**: Concern consolidation - resilience/, reliability/, parsing/, execution/ subdirectories |
| 2026-01-14 | **P1.8 Complete**: RuboCop defaults campaign - all 91 offenses fixed (0 remaining) |
| 2026-01-14 | Module splits: http/, security/, react_loop/, model_health/, openai/, anthropic/, tool/, result/, testing/ |
| 2026-01-14 | TracePoint executor fix: path filtering for sandbox-only operation counting |
| 2026-01-14 | Logging subscriber DSL with pattern-matchable events |
| 2026-01-14 | Ractor refactoring: Sandbox hierarchy (Sandbox→CodeSandbox/ToolSandbox), RactorSerialization concern |
| 2026-01-14 | Renamed ToolCallingAgent→ToolAgent, :tool_calling→:tool for naming symmetry |
| 2026-01-14 | P1.7: AgentType utilities extracted, AST depth limit (100), cloud metadata blocklist expanded |
| 2026-01-14 | P1.6: RuboCop metrics - CC→7, AbcSize→22, MethodLength→15, LineLength→120 (0 offenses) |
| 2026-01-14 | P1.5: All Lint/Style/RSpec cops enabled and passing |
| 2026-01-14 | Ruby 4.0 idioms enforced (hash shorthand, endless methods, Data.define, pattern matching) |
| 2026-01-13 | YARD documentation 97.31% |
| 2026-01-13 | Event system simplification (603 → 100 LOC), dead code removal (~860 LOC) |
| 2026-01-12 | Agent persistence, DSL.Builder, Model reliability, Telemetry |

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Events, not callbacks | Events are data (testable). Callbacks are behavior. |
| Thread::Queue | Stdlib. `pop` blocks without polling. |
| Forward-only | Delete unused code. No backwards compatibility. |
| Ractors for execution only | HTTP is I/O-bound, threads work fine |
| No API key serialization | Security - keys at load time |
| Cops guide development | Fix code, don't disable cops |
| Sandbox inheritance | CodeSandbox/ToolSandbox share behavior via Sandbox base class |
| Agent/Sandbox naming symmetry | CodeAgent↔CodeSandbox, ToolAgent↔ToolSandbox |
| Nested concern subdirectories | Group related concerns (react_loop/, resilience/, reliability/) |
| Concern entry point pattern | Main mixin requires + composes sub-modules |
| Builder facades | Keep simple API, delegate to specialized builders |
