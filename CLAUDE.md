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
  .with_health_check(cache_for: 5)
  .prefer_healthy
  .build                              # → Model
```

### Multi-Model Agents

```ruby
# Different models for different purposes
Smolagents.agent
  .model(:execution) { fast_model }   # Quick tasks
  .model(:planning) { big_model }     # Complex reasoning
  .model(:evaluation) { fast_model }  # Self-checks
  .tools(:search, :calculate)
  .planning(interval: 5)              # Replan with big model
  .evaluation(enabled: true)
  .build
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
- `Events::Emitter` + `Events::Consumer` — Composable event participation

**Type definitions go in `types/`, not inline in concerns.**

## Event-Driven Architecture

Two modules composed for different needs:

| Module | Use Case | Lines |
|--------|----------|-------|
| `Events::Emitter` | Emit events (models, tools, agents) | ~160 |
| `Events::Consumer` | Subscribe to events (observers, agents) | ~200 |

```ruby
# Components that emit AND subscribe include both
class MyAgent
  include Smolagents::Events::Emitter
  include Smolagents::Events::Consumer

  def initialize
    on_lifecycle { |e| track(e) }        # Category subscription
    on(:error) { |e| alert(e) }          # Single event
  end

  def run(task)
    emit :step_complete, step_number: 1  # Symbol-based emit
    emit(:model_generate_completed) { api.call }  # Block captures duration_ms
  end
end

# Emit-only for simpler components
class MyTool
  include Smolagents::Events::Emitter

  def execute
    emit :tool_call, tool_name: name, args: args
  end
end
```

**Key principle:** No instrumentation—everything is event-driven. Subscribe to events, don't wrap code.

See **AGENTS.md** for contributor guidance, **PLAN.md** for architecture decisions.

---

## Development Recipes

### Adding a Concern

Concerns are the primary unit of composition. Each is a module ≤100 lines.

```
1. Create: lib/smolagents/concerns/my_feature.rb
2. Register: lib/smolagents/concerns/registrations.rb
3. Spec: spec/smolagents/concerns/my_feature_spec.rb
4. Include in agent/model/tool as needed
```

```ruby
# lib/smolagents/concerns/my_feature.rb
module Smolagents
  module Concerns
    module MyFeature
      def my_method
        emit :my_event, data: "value"  # if Events::Emitter included
      end
    end
  end
end
```

Register in `concerns/registrations.rb`:
```ruby
r.register :my_feature,
           Smolagents::Concerns::MyFeature,
           category: :agents,                    # or :resilience, :tools, etc.
           dependencies: %i[events_emitter],     # optional
           provides: %i[my_method],
           description: "One-line description"
```

### Adding a Type

Types use `Data.define` (enforced by RuboCop). Always immutable.

```ruby
# lib/smolagents/types/my_config.rb
module Smolagents
  module Types
    MyConfig = Data.define(:name, :threshold, :enabled) do
      def self.default = new(name: "default", threshold: 0.5, enabled: true)
      def enabled? = enabled
      def with_threshold(val) = with(threshold: val)
    end
  end
end
```

Spec with shared examples:
```ruby
RSpec.describe Smolagents::Types::MyConfig do
  subject(:config) { described_class.default }
  it_behaves_like "a frozen type"
  it_behaves_like "a data type"
  it_behaves_like "a type with predicates", :enabled?
end
```

### Adding a Builder Method

Builders are immutable — every method returns a new instance.

```ruby
# In lib/smolagents/builders/agent_builder.rb (or a concern thereof)
def my_option(value)
  validate_my_option!(value)          # optional
  derive(my_option: value)            # derive() returns new builder with updated config
end
```

Spec with shared examples:
```ruby
it_behaves_like "a builder configuration method",
  method: :my_option, config_key: :my_option, value: 42
```

### Adding a Tool

```ruby
# lib/smolagents/tools/my_tool.rb
module Smolagents
  module Tools
    class MyTool < Tool
      self.tool_name = "my_tool"
      self.description = "What this tool does"
      self.inputs = { query: { type: "string", description: "The query" } }
      self.output_type = "string"

      def execute(query:)
        # Implementation
      end
    end
  end
end
```

Register in `lib/smolagents/tools.rb` so it resolves from symbol `:my_tool`.

### Adding an Event Type

```ruby
# In lib/smolagents/events/registry.rb
register :my_event,
         category: :lifecycle,
         fields: { data: "Description of data field" },
         description: "When this event fires"
```

Emit via: `emit :my_event, data: value`

---

## Test Patterns

### MockModel (Thread-Safe, FIFO Queue)

```ruby
# Basic: queue responses in order
model = Smolagents::Testing::MockModel.new
model.queue_code_action('calculate(expression: "2+2")')
model.queue_final_answer("4")

# Fluent aliases
model.returns_code('search(query: "Ruby")').answers("42")

# Resilience testing
model.fail_then_succeed(2, then_respond: "ok", with: RuntimeError)

# Assert
expect(model).to be_exhausted
expect(model).to have_received_calls(2)
expect(model).to have_seen_system_prompt
```

### Factories (Globally Available)

```ruby
build_mock_model(responses: [...])    # MockModel with responses
build_test_tool(name: "calc")         # Anonymous tool subclass
build_test_agent(model:, tools:)      # Agent with defaults
build_action_step(step_number: 1)     # ActionStep Data.define
```

### Shared Examples

| Example | Use For |
|---------|---------|
| `"a frozen type"` | Any Data.define type |
| `"a data type"` | Type with to_h support |
| `"an immutable builder"` | Builder method immutability |
| `"a builder configuration method"` | Builder setter (method:, config_key:, value:) |
| `"a valid tool"` | Tool class validation |
| `"an executor"` | Executor implementations |
| `"a model"` | Model implementations |

### Timing Enforcement

- Default: 120ms per test, 200ms for `:slow` tag
- Concurrency/threading tests: tag with `:slow`
- Agent execution tests: tag with `:slow`
- Suite limit: 20s total

---

## Ruby 4.0 Conventions

| Convention | Example |
|------------|---------|
| Endless methods | `def name = @name.to_s` |
| Hash shorthand | `{name:, age:}` not `{name: name}` |
| `Data.define` | Never `Struct.new` or `OpenStruct` |
| Double quotes | `"always"` not `'never'` |
| No `frozen_string_literal` | Ruby 4.0 freezes by default |
| `it` parameter | `users.map { it.name }` (single-line) |

## Pre-Commit Hook

The hook checks **staged content** for Lint/Security offenses only.
Use `rake commit_prep` to auto-fix, stage, and verify before committing.
RuboCop checks files on disk; the hook checks git's staged version. Always re-stage after fixing.
