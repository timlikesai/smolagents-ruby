# smolagents-ruby

Highly-testable agents that think in Ruby 4.0.

## DSL

```ruby
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .tools(:search, :web)
  .as(:researcher)
  .planning
  .build

result = agent.run("Find the latest Ruby release notes")
```

**Builder methods:** `.model { }` (required), `.tools(...)`, `.tool(:name, "desc") { }`, `.as(:persona)`, `.memory(budget:, strategy:)`, `.planning`, `.can_spawn(allow: [...])`, `.refine(max_iterations:)`, `.evaluate(on: :each_step)`

## Rules

- **100/10**: Modules ≤100 lines, methods ≤10 lines. RuboCop enforces.
- **Ruby 4.0**: `Data.define` for types, pattern matching for flow, endless methods for simple ops
- **Test everything**: MockModel for fast deterministic tests

## Ruby 4.0 Patterns

```ruby
# Data.define with deconstruct_keys for pattern matching
Message = Data.define(:role, :content) do
  def deconstruct_keys(_) = { role:, content: }
end

# Endless methods, predicate naming
def success? = state == :success
def model_id = @model&.model_id || "unknown"

# Pattern matching
case step
in ActionStep[tool_calls:] if tool_calls.any? then execute_tools(tool_calls)
in FinalAnswerStep[answer:] then return answer
end
```

## Commands

```bash
rake commit_prep   # FIX → STAGE → VERIFY (before every commit!)
rake spec          # Run tests
rake spec_fast     # Tests excluding slow/integration
rake check         # lint + spec
```

**Pre-commit hooks check STAGED content**, not files. Always `rake commit_prep`.

## Testing

```ruby
model = Smolagents::Testing::MockModel.new(responses: ['result = search(query: "Ruby")', 'final_answer(answer: result)'])
agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")
expect(model).to be_exhausted
```

## Tools

```ruby
class WeatherTool < Smolagents::Tool
  name "weather"
  description "Get weather. Use when: need current conditions. Do NOT use: forecasts. Returns: Hash."
  inputs city: { type: "string", description: "City name" }
  output_type "object"
  def execute(city:) = fetch_weather(city)
end
```

Tool descriptions: 3+ sentences, include "Use when" / "Do NOT use", describe return format, NO examples.

## Architecture

```
lib/smolagents/
├── agents/      # Thin facade
├── builders/    # Fluent DSL
├── concerns/    # Composable behaviors (≤100 lines each)
├── events/      # Event system with registry
├── executors/   # Sandboxed code execution
├── models/      # LLM adapters (OpenAI, Anthropic)
├── tools/       # Tool base + built-ins
└── types/       # Data.define domain types
```

## Status

6492 tests, 93.93% coverage, 2 RuboCop offenses. See **PLAN.md** for work items.
