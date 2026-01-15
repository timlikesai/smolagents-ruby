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
- Ruby 4.0 idioms enforced via RuboCop (0 offenses)

**Coverage:**
- Code: 92.82% (threshold: 80%)
- Docs: 97.31% (target: 95%)
- Tests: 2980 total, 0 failures

**RuboCop Metrics (0 offenses):**
| Cop | Current | Default | Status |
|-----|---------|---------|--------|
| LineLength | 120 | 120 | ✅ |
| CyclomaticComplexity | 7 | 7 | ✅ |
| MethodLength | 15 | 10 | 🔄 |
| AbcSize | 22 | 17 | 🔄 |
| PerceivedComplexity | 16 | 8 | 🔄 |

---

## Active Work: P1.7 - Code Consolidation & Security

> **Goal:** Reduce duplication, improve organization, harden security.

### Remaining Items

#### Error Message Redaction (MEDIUM)
**File:** `lib/smolagents/executors/ruby.rb`

**Problem:** Error messages may contain secrets from failed API calls.

**Fix:** Apply `Security::SecretRedactor.redact()` to all error messages before returning.

#### Unify Outcome States (LOW)
**Files:** `types/outcome.rb`, `types/execution_outcome.rb`

**Problem:** `:final_answer` predicate exists but not in `Outcome::ALL` constants.

**Fix:** Add `:final_answer` to `Outcome::ALL` and `Outcome::TERMINAL`, or document why it's separate.

### Test Coverage (MEDIUM PRIORITY)

12 concerns lack dedicated test files (37.5% of concerns):

| Concern | Lines | Risk | Priority |
|---------|-------|------|----------|
| `sandbox_methods.rb` | 78 | High - security critical | 1 |
| `html.rb` | 77 | Medium - Nokogiri wrapper | 2 |
| `xml.rb` | 91 | Medium - RSS/Atom parsing | 3 |
| `json.rb` | 59 | Low - thin wrapper | 4 |
| `result_formatting.rb` | 100+ | Low - output formatting | 5 |
| `results.rb` | 100+ | Low - result mapping | 6 |
| `retryable.rb` | 35 | Low - simple retry | 7 |
| `api.rb` | 52 | Medium - composition | 8 |
| `api_key.rb` | 76 | Medium - key handling | 9 |
| `gem_loader.rb` | ? | Low - dynamic loading | 10 |
| `tool_schema.rb` | 72 | Low - JSON schema | 11 |
| `managed_agents.rb` | ? | Medium - orchestration | 12 |

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
| Split agent_types.rb | Optional: 654 LOC, could split into focused files |
| Concerns subdirectory organization | Group 32 concerns into `resilience/`, `http/`, `model_management/` |
| ToolResult private helpers | Mark `deep_freeze`, `chain` as `@api private` |
| URL normalization | IPv4-mapped IPv6, IDN encoding edge cases |
| Shared RSpec examples | DRY up test patterns |
| MethodLength 15 → 10 | Continue extract method refactoring |
| AbcSize 22 → 17 | Reduce assignment/branch/condition counts |
| PerceivedComplexity 16 → 8 | Simplify nested conditionals |

---

## Completed

| Date | Item |
|------|------|
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
