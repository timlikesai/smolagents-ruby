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

When tests fail, you NEED the full output to diagnose. Filtering discards:
- Stack traces showing where failures occur
- Timing information for performance debugging
- Context about what ran before a failing test
- RuboCop offense details and locations

**If output is too long:** Read it in chunks, don't filter it away.

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

## DSL Reference

### AgentBuilder

```ruby
Smolagents.agent
  .model { Model }                    # Required: LLM instance
  .tools(:search, :web)               # Tool symbols or instances
  .tool(:name, "desc") { |args| }     # Inline tool
  .as(:researcher)                    # Persona (alias: .persona)
  .max_steps(10)                      # Step limit
  .instructions("Be concise")         # Custom system prompt
  .planning(interval: 3)              # Replanning every N steps
  .memory(budget: 50_000)             # Token budget
  .evaluation(enabled: true)          # Self-evaluation
  .refine(max_iterations: 3)          # Self-refinement
  .can_spawn(max_depth: 2)            # Enable sub-agents
  .managed_agent(agent, as: "helper") # Static sub-agent
  .on(:step_complete) { |e| }         # Event subscription
  .build                              # → Agent
```

### ModelBuilder

```ruby
Smolagents.model(:openai)
  .id("gpt-4")
  .temperature(0.7)
  .with_retry(max_attempts: 3)
  .with_fallback { backup_model }
  .with_circuit_breaker(threshold: 5)
  .build                              # → Model
```

### TeamBuilder

```ruby
Smolagents.team
  .model { coordinator }
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .coordinate("Research then write")
  .build                              # → Agent (coordinator)
```

## Rules

| Rule | Enforcement |
|------|-------------|
| Modules ≤100 lines | RuboCop |
| Methods ≤10 lines | RuboCop |
| Types use `Data.define` | Convention |
| No unused code | Delete immediately |
| No deprecation shims | Greenfield project |

## Commands

```bash
rake spec          # Run tests in parallel (~7s)
rake spec_fast     # Skip slow/integration tests
rake ci            # Full CI (rubocop + tests)
rake commit_prep   # Fix + Stage + Verify before commits
```

## Testing

```ruby
model = Smolagents::Testing::MockModel.new(
  responses: ['search(query: "Ruby")', 'final_answer(answer: result)']
)
agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")
expect(model).to be_exhausted
```

## Architecture

```
lib/smolagents/
├── agents/      # Thin facade over concerns
├── builders/    # Fluent DSL (immutable)
├── concerns/    # Composable behaviors (≤100 lines each)
├── events/      # Pub/sub with 40+ event types
├── executors/   # Sandboxed Ractor execution
├── models/      # LLM adapters (OpenAI, Anthropic)
├── tools/       # Tool base + built-ins
└── types/       # Data.define domain types (80+ types)
```

## Key Patterns

**Before creating new code, check existing concerns:**

- `Concerns::Formatting::*` — Output transformation
- `Concerns::Resilience::*` — Retry, circuit breaker, rate limiting
- `Events::Emitter` / `Events::Consumer` — Pub/sub

**Type definitions go in `types/`, not inline in concerns.**

See **AGENTS.md** for contributor guidance, **PLAN.md** for architecture decisions.
