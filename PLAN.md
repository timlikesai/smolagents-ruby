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
- Code: 92.33% (threshold: 80%)
- Docs: 97.31% (target: 95%)
- Tests: 2982 total, 68 pending

---

## Active Work: P1.5 - RuboCop Re-enablement

**Philosophy:** Cops guide development. When a cop catches something, fix the underlying code.

### Phase 1: Quick Wins (18 offenses)

| Cop | Offenses | Why Fix |
|-----|----------|---------|
| `Lint/MissingSuper` | 1 | Potential bug - subclasses should call super |
| `Lint/DuplicateBranch` | 6 | Use pattern matching to eliminate duplicates |
| `Style/MultilineBlockChain` | 5 | Extract to named methods |
| `Naming/PredicateMethod` | 1 | Ruby idiom - `valid?` not `is_valid?` |
| `RSpec/LeakyConstantDeclaration` | 5 | Use `stub_const` or anonymous classes |

- [ ] Enable `Lint/MissingSuper` and fix
- [ ] Enable `Lint/DuplicateBranch` and refactor with pattern matching
- [ ] Enable `Style/MultilineBlockChain` and extract methods
- [ ] Enable `Naming/PredicateMethod` and rename
- [ ] Enable `RSpec/LeakyConstantDeclaration` and fix specs

### Phase 2: Test Doubles (160 offenses)

| Cop | Offenses | Why Fix |
|-----|----------|---------|
| `RSpec/StubbedMock` | 15 | Clarify intent - pure stub or pure mock |
| `RSpec/AnyInstance` | 37 | Smell - refactor to DI or instance doubles |
| `RSpec/VerifiedDoubles` | 108 | Catches interface mismatches |

- [ ] Enable `RSpec/StubbedMock` and clarify intentions
- [ ] Enable `RSpec/AnyInstance` and refactor to DI
- [ ] Enable `RSpec/VerifiedDoubles` incrementally

### Phase 3: Complexity Reduction

| Metric | Current | Target | Offenses |
|--------|---------|--------|----------|
| `Metrics/AbcSize` | 55 | 25 | ~25 |
| `Metrics/MethodLength` | 50 | 20 | ~20 |
| `Metrics/ParameterLists` | 13 | 6 | ~8 |

**Forces use of:** Data.define configs, Builder pattern, pattern matching, SRP methods.

- [ ] Lower `Metrics/AbcSize` to 35 → 25
- [ ] Lower `Metrics/MethodLength` to 30 → 20
- [ ] Lower `Metrics/ParameterLists` to 8 → 6

### Keep Disabled

| Cop | Reason |
|-----|--------|
| `Style/Documentation` | YARD handles this |
| `Naming/*ParameterName` | Short names fine in blocks |
| `RSpec/ContextWording` | Stylistic preference |
| `RSpec/MultipleMemoizedHelpers` | Sometimes needed |
| `RSpec/DescribeClass` | Integration specs |

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
