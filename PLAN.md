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
- ToolCallingAgent - uses JSON tool calling format
- Builder DSL - `Smolagents.code.model{}.tools().build`
- Models - OpenAI, Anthropic, LiteLLM adapters
- Tools - base class, registry, 10+ built-ins
- ToolResult - chainable, pattern-matchable
- Executors - Ruby sandbox, Docker, Ractor isolation
- Event system - Thread::Queue, Emitter/Consumer pattern
- Ruby 4.0 idioms enforced via RuboCop
- Custom cops for event-driven architecture

**Coverage:**
- Code: 92.35% (threshold: 80%)
- Docs: 97.31% (target: 95%)
- Tests: 2979 total, 66 pending

---

## Active Work: P1.6 - RuboCop Metrics Refactoring

> **Goal:** Achieve RuboCop defaults. Ruby code should be magical, expressive, concise, beautiful.

**Total: 278 offenses → 0**

### Current State

| Cop | Limit | Default | Offenses | Target |
|-----|-------|---------|----------|--------|
| MethodLength | 47 | 10 | 119 | 0 |
| AbcSize | 54 | 17 | 71 | 0 |
| CyclomaticComplexity | 16 | 7 | 40 | 0 |
| PerceivedComplexity | 16 | 7 | 23 | 0 |
| ClassLength | 210 | 100 | 9 | 0 |
| ModuleLength | 200 | 100 | 16 | 0 |

### Ruby 4.0 Patterns to Apply

| Pattern | Impact | Example |
|---------|--------|---------|
| **Endless methods** | -2 lines/method | `def name = @name.to_s` |
| **Pattern matching** | -5 CC/method | `case data in {type:} then ...` |
| **Guard clauses** | -2 CC/method | `return unless valid?` |
| **Extract method** | -10 lines/method | Long method → focused helpers |
| **Data.define** | -5 AbcSize | Hash building → immutable type |
| **Hash#slice/except** | -3 AbcSize | Manual key selection → one call |

### Phase 1: Pattern Matching (High CC Methods)
**Target:** 40 CyclomaticComplexity offenses → 0

| File | Method | CC | Strategy |
|------|--------|----|----|
| types/agent_types.rb:221 | `initialize` | 16 | Pattern match on value types |
| utilities/prompts.rb:100 | `generate` | 15 | Pattern match on format options |
| types/agent_types.rb:430 | `initialize` | 12 | Pattern match on value types |
| testing/model_benchmark.rb:100 | `aggregate_results` | 12 | Pattern match on result types |
| types/steps.rb:154 | `extract_reasoning_from_raw` | 12 | Pattern match on response structure |

### Phase 2: Extract Method (Long Methods)
**Target:** 119 MethodLength offenses → 0

| File | Method | Lines | Strategy |
|------|--------|-------|----------|
| concerns/model_health.rb:215 | `perform_health_check` | 46 | Extract `build_*_status` helpers |
| testing/model_benchmark.rb:100 | `aggregate_results` | 35 | Extract aggregation helpers |
| utilities/prompts.rb:100 | `generate` | 34 | Extract section builders |
| tools/tool.rb:285 | `call` | 31 | Extract validation + execution |
| tools/managed_agent.rb:257 | `execute` | 31 | Extract delegation helpers |
| builders/agent_builder.rb:518 | `build` | 25 | Extract resolved_* helpers |

### Phase 3: Module Decomposition
**Target:** 16 ModuleLength offenses → 0

| Module | Lines | Extract To |
|--------|-------|------------|
| ModelBuilder | 200 | `ModelBuilder::LocalModels`, `ModelBuilder::Reliability` |
| ModelReliability | 177 | `Concerns::RetryLogic`, `Concerns::CircuitBreaker` |
| RubySafety | 160 | `Concerns::CodeValidator`, `Concerns::SafetyChecker` |
| ModelHealth | 148 | `Concerns::HealthCheck`, `Concerns::ModelDiscovery` |

### Phase 4: Class Decomposition
**Target:** 9 ClassLength offenses → 0

| Class | Lines | Extract To |
|-------|-------|------------|
| RactorOrchestrator | 208 | `RactorPool`, `AgentSpawner` |
| SearchTool | 194 | Provider-specific classes |
| RactorExecutor | 164 | `IsolatedExecution`, `ToolRactor` |

### Progress Tracking

- [ ] Phase 1: Pattern matching (CC: 16 → 7)
- [ ] Phase 2: Extract method (MethodLength: 47 → 10)
- [ ] Phase 3: Module decomposition (ModuleLength: 200 → 100)
- [ ] Phase 4: Class decomposition (ClassLength: 210 → 100)
- [ ] Final: All metrics at defaults

### Completed

- [x] ParameterLists: 13 → 5 (via CountKeywordArgs: false)
- [x] Gemspec/DevelopmentDependencies: disabled → enabled
- [x] Limits tightened to actual codebase maximums

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
| HuggingFace Inference API | Use LiteLLM instead |
| Amazon Bedrock Support | Use LiteLLM instead |
| Local Model Auto-Detection | Nice-to-have |

---

## Completed

| Date | Item |
|------|------|
| 2026-01-14 | P1.6 Phase 1: Naming cops enabled (8 fixes: `n`→`count`, `get_*`→accessors, `has_*?`→predicates) |
| 2026-01-14 | P1.5 Complete: All RSpec cops enabled (VerifiedDoubles, MessageSpies, ContextWording, etc.) |
| 2026-01-14 | P1.5 Phase 1: MissingSuper, DuplicateBranch, MultilineBlockChain, PredicateMethod, LeakyConstantDeclaration |
| 2026-01-14 | Ruby 4.0 idioms via RuboCop (565 hash shorthand, endless methods, Data.define) |
| 2026-01-14 | Custom cops: NoSleep, NoTimingAssertion, NoTimeoutBlock, PreferDataDefine |
| 2026-01-13 | YARD documentation 97.31% (10,950 lines) |
| 2026-01-13 | P0.5 Deduplication - outcomes, events, validation, collections |
| 2026-01-13 | P0 Event simplification - 603 LOC → ~100 LOC |
| 2026-01-13 | P0 Dead code removal - ~860 LOC deleted |
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
