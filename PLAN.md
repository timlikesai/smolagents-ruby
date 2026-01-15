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

### DSL Ideas (from research)

1. **Model Benchmark DSL** - Declarative model capability testing with profiles (:quick, :thorough, :production)
2. **Agent Composition DSL** - Multi-modal agents with capability routing (text, image, audio)
3. **Memory DSL** - Composable memory strategies (sliding window, persistence, semantic indexing)
4. **Event/Callback DSL** - Pattern-matchable events with lifecycle hooks
5. **Configuration Profiles** - Environment-aware settings with inheritance

### Remaining P1.7 Items

#### Error Message Redaction (MEDIUM)
**File:** `lib/smolagents/executors/ruby.rb`
**Fix:** Apply `Security::SecretRedactor.redact()` to all error messages.

#### Unify Outcome States (LOW)
**Files:** `types/outcome.rb`, `types/execution_outcome.rb`
**Fix:** Add `:final_answer` to `Outcome::ALL` and `Outcome::TERMINAL`.

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
| Split agent_types.rb | Optional: 654 LOC, could split into focused files |
| Concerns subdirectory organization | Group concerns into `resilience/`, `http/`, `model_management/` |
| ToolResult private helpers | Mark `deep_freeze`, `chain` as `@api private` |
| URL normalization | IPv4-mapped IPv6, IDN encoding edge cases |
| Shared RSpec examples | DRY up test patterns |

---

## Completed

| Date | Item |
|------|------|
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
