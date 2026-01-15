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
- Code: 92.89% (threshold: 80%)
- Docs: 97.31% (target: 95%)
- Tests: 2979 total, 0 failures, 66 pending

---

## Active Work: P1.6 - RuboCop Metrics Refactoring

> **Goal:** Achieve RuboCop defaults. Ruby code should be magical, expressive, concise, beautiful.

### Current State (0 offenses)

| Cop | Current | Default | Status |
|-----|---------|---------|--------|
| LineLength | 120 | 120 | ✅ Default |
| MethodLength | 15 | 10 | 🔄 Next target: 12 |
| AbcSize | 22 | 17 | 🔄 Next target: 20 |
| CyclomaticComplexity | 7 | 7 | ✅ Default |
| PerceivedComplexity | 16 | 7 | 🔄 Next target |
| ClassLength | 220 | 100 | 🔄 |
| ModuleLength | 220 | 100 | 🔄 |

### Next Steps

1. **MethodLength 15 → 12** - Continue extract method refactoring
2. **AbcSize 22 → 20** - Reduce assignment/branch/condition counts
3. **PerceivedComplexity 16 → 10** - Simplify nested conditionals

### Completed (P1.6)

- [x] LineLength: 180 → 120 (default)
- [x] CyclomaticComplexity: 16 → 7 (default) - Pattern matching, lookup tables, extracted helpers
- [x] AbcSize: 54 → 22
- [x] MethodLength: 47 → 15
- [x] ParameterLists: 13 → 5 (via CountKeywordArgs: false)
- [x] Constants moved out of Data.define blocks (Lint/ConstantDefinitionInBlock)

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
| 2026-01-14 | P1.6: CyclomaticComplexity 16→7 (default), AbcSize 54→22, MethodLength 47→15, LineLength 180→120 |
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
