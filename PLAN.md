# smolagents-ruby Project Plan

Delightfully simple agents that think in Ruby.

See [ARCHITECTURE.md](ARCHITECTURE.md) for vision, patterns, and examples.

---

## Principles

- **Ship it**: Working software over perfect architecture
- **Simple first**: If it needs explanation, simplify it
- **Test everything**: No feature without tests
- **Delete unused code**: If nothing calls it, remove it

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
- 2131 tests passing, 87.95% coverage

---

## P0 - Simplify & Wire Event System ✅ COMPLETE

**Problem:** 603 LOC event infrastructure that emits to nowhere.

**Decision:** Keep events (not callbacks). Simplify to ~100 LOC. Wire it up.

| Delete | LOC | Replacement |
|--------|-----|-------------|
| EventQueue class | 219 | Thread::Queue (stdlib) |
| Mappings (legacy aliases) | 105 | Nothing |
| Priority/scheduling | ~90 | YAGNI |
| Rate limit helpers | ~30 | Move to concerns |

| Add | LOC |
|-----|-----|
| Queue initialization in Agent | ~5 |
| connect_to wiring | ~5 |
| drain_events in ReActLoop | ~10 |

**Result:** 603 LOC → ~100 LOC. Events actually fire.

- [x] Delete EventQueue class, use Thread::Queue
- [x] Simplify Mappings module (removed legacy aliases)
- [x] Simplify Emitter to ~47 LOC
- [x] Simplify Consumer to ~58 LOC
- [x] Wire: Agent creates queue, connects emitters, drains after steps (already done via Monitorable + ReActLoop)
- [x] Test: 39 event tests + react_loop event tests passing

---

## P0 - Delete Dead Code ✅ PARTIAL

Deep analysis found some code was actually used. Deleted only truly unused code.

### Concerns - Deleted (141 LOC)

| Concern | LOC | Status |
|---------|-----|--------|
| Measurable | 106 | ✅ Deleted |
| Streamable | 35 | ✅ Deleted |

### Concerns - Kept (actually used)

| Concern | Used By |
|---------|---------|
| ModelReliability | Model classes for retry/fallback |
| ModelHealth | Model health checks |
| RequestQueue | Model request queuing |
| CircuitBreaker | Api concern |
| Resilience | Model reliability |
| Auditable | Api concern |
| Retryable | Api concern |
| Mcp | MCP tools |
| SandboxMethods | Executors |
| GemLoader | Optional gem loading |

### Tools - Deleted (368 LOC)

| Item | LOC | Status |
|------|-----|--------|
| ToolCollection | 198 | ✅ Deleted |
| MCPToolCollection | 170 | ✅ Deleted |

Registry kept - used by tool lookup system.

### Types - Deleted (~350 LOC)

| Type | LOC | Status |
|------|-----|--------|
| Goal + GoalDynamic | ~210 | ✅ Deleted |
| AgentResult | ~140 | ✅ Deleted |

**Total deleted:** ~860 LOC of truly unused code

---

## P1 - Test Coverage

Current: 87% code coverage, 70% documentation coverage

- [ ] Test all public methods in core classes
- [ ] Add integration tests: agent.run() end-to-end
- [ ] Document public API with examples

---

## P2 - Release

- [ ] README with getting started guide
- [ ] Gemspec complete
- [ ] CHANGELOG
- [ ] Version 1.0.0

---

## Completed Work

| Date | Item |
|------|------|
| 2026-01-13 | P0 Event Simplification - deleted EventQueue (219 LOC), simplified Emitter/Consumer/Mappings |
| 2026-01-13 | P0 Dead Code Removal - deleted ~860 LOC: Measurable, Streamable, ToolCollection, MCPToolCollection, Goal, AgentResult |
| 2026-01-13 | Deep Analysis - identified architecture is 90% complete, needs wiring |
| 2026-01-12 | Agent Persistence - `agent.save(path)` / `Agent.from_folder(path, model:)` |
| 2026-01-12 | DSL.Builder Framework - `builder_method` DSL, `.help`, `.freeze!` |
| 2026-01-12 | Model Reliability - `.with_retry`, `.with_fallback`, `.with_health_check` |
| 2026-01-12 | Telemetry - Instrumentation, LoggingSubscriber, OTel integration |

---

## Backlog (Deferred)

| Item | Notes |
|------|-------|
| HuggingFace Inference API | Use LiteLLM instead |
| Amazon Bedrock Support | Use LiteLLM instead |
| Local Model Auto-Detection | Nice-to-have |
| Data Pipeline DSL | May overlap with existing Pipeline |

---

## Coverage

- **Code:** 87.95% (threshold: 80%)
- **Docs:** 70% (target: 90%)
- **Tests:** 2131 total, 42 pending (integration tests requiring live models/Docker/Ractor)

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| Events, not callbacks | Events are data (testable, replayable). Callbacks are behavior (timing-dependent). |
| Thread::Queue for events | Stdlib. `pop` blocks without polling. No custom EventQueue needed. |
| Delete 34% of codebase | Forward-only. If nothing calls it, remove it. |
| Ractors for code execution only | Model HTTP calls are I/O-bound, threads work fine |
| No API key serialization | Security - keys provided at load time |
