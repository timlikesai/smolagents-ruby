# smolagents-ruby

Agents that think in Ruby 4.0.

## CRITICAL: Test and Lint Commands

**ALWAYS use rake tasks. NEVER pipe or grep output.**

```bash
rake spec          # Run tests - USE THIS, see full output
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI (rubocop + tests)
rake commit_prep   # Fix + Stage + Verify before commits
```

**FORBIDDEN patterns:**
```bash
# NEVER DO THIS - you lose diagnostic information:
bundle exec rspec ... | grep ...
bundle exec rspec ... | tail ...
bundle exec rspec ... 2>&1 | head ...
bundle exec rubocop ... | grep ...
```

When tests fail, you NEED the full output to diagnose. Filtering discards stack traces, timing info, context, and offense details. **If output is too long:** Read it in chunks, don't filter it away.

---

## Quick Start

```ruby
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :web)
  .as(:researcher)
  .build

result = agent.run("Find the latest Ruby release notes")
```

## Rules

| Rule | Enforcement |
|------|-------------|
| Modules ≤100 lines | RuboCop |
| Methods ≤10 lines | RuboCop |
| Types use `Data.define` in `types/` | RuboCop (custom cop) |
| No `Struct.new` / `OpenStruct` | RuboCop |
| No `sleep` | RuboCop (custom cop) |
| No `Timeout.timeout` | RuboCop (custom cop) |
| No unused code | Delete immediately |
| No deprecation shims | Greenfield project |
| Double quotes always | `"yes"` not `'no'` |
| Endless methods for one-liners | `def name = @name` |

## Architecture

```
lib/smolagents/
├── agents/      # Thin facade over concerns
├── builders/    # Fluent DSL (immutable, derive() returns new instance)
├── concerns/    # Composable behaviors (≤100 lines each, 40+ registered)
├── events/      # Pub/sub with 40+ event types (Emitter + Consumer)
├── executors/   # Sandboxed Ractor execution
├── models/      # LLM adapters (OpenAI, Anthropic, LM Studio)
├── tools/       # Tool base + built-ins
└── types/       # Data.define domain types (80+ types)
```

## Key Patterns

**Before creating new code, check existing concerns** in `lib/smolagents/concerns/registrations.rb`.

- `Concerns::Formatting::*` — Output transformation
- `Concerns::Resilience::*` — Retry, circuit breaker, rate limiting
- `Events::Emitter` + `Events::Consumer` — Composable event participation

**Type definitions go in `types/`, not inline.** Event types registered in `events/registry.rb`.

## Testing

```ruby
model = Smolagents::Testing::MockModel.new(
  responses: ['search(query: "Ruby")', 'final_answer(answer: result)']
)
agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")
expect(model).to be_exhausted
```

See `spec/CLAUDE.md` for detailed test patterns, shared examples, and timing rules.

## Pre-Commit Hook

Checks **staged content** for Lint/Security offenses only. Use `rake commit_prep` to auto-fix, stage, and verify. Always re-stage after fixing.

See **AGENTS.md** for contributor guidance, **PLAN.md** for architecture decisions.
