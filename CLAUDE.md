# smolagents-ruby

Delightfully simple agents that think in Ruby.

## The Vision

Build agents that feel native to Ruby. Not a Python port—a Ruby-first design using `Data.define`, pattern matching, and fluent APIs. The interface should be so obvious that documentation feels redundant.

**What we're building:**
```ruby
agent = Smolagents.code
  .model { OpenAIModel.new(model_id: "gpt-4") }
  .tools(:web_search, :visit_webpage)
  .build

result = agent.run("Find the latest Ruby release notes")
# Agent writes Ruby code, executes tools, returns answer
```

That's it. An agent, some tools, a task, a result.

## Principles

**Simple by Default**
The common case should be one line. Configuration is for when you need it, not before. If a feature requires explanation, simplify the feature.

**Ruby Idioms**
`Data.define` for immutable types. Pattern matching for control flow. Endless methods for simple operations. Blocks for configuration. This isn't Ruby-flavored Python—it's Ruby.

**Forward Only**
No backwards compatibility. When something improves, adopt it everywhere. When code is unused, delete it. The codebase moves forward as a unit.

**Test Everything**
Every public method has a test. Tests run in under 10 seconds. If tests are slow, fix the code, not the timeout.

## What We Build

```
lib/smolagents/
├── agents/        # CodeAgent (Ruby) and ToolCallingAgent (JSON)
├── builders/      # Fluent configuration DSL
├── models/        # LLM adapters (OpenAI, Anthropic, LiteLLM)
├── tools/         # Tool base class + built-ins
├── executors/     # Sandboxed code execution
└── types/         # Data.define for domain concepts
```

**Core abstractions:**
- `Agent` - Runs tasks using a model and tools
- `Model` - Talks to LLMs (OpenAI, Anthropic, local)
- `Tool` - Something an agent can use
- `ToolResult` - What a tool returns (chainable)

That's the entire conceptual model. Everything else is implementation detail.

## The Interface

**Building agents:**
```ruby
# Minimal
agent = Smolagents.code.model { my_model }.build

# With tools
agent = Smolagents.code
  .model { my_model }
  .tools(:web_search, :calculator)
  .max_steps(10)
  .build

# Tool-calling style (JSON instead of code)
agent = Smolagents.tool_calling
  .model { my_model }
  .tools(:web_search)
  .build
```

**Running tasks:**
```ruby
result = agent.run("What's the weather in Tokyo?")
# => "The current weather in Tokyo is 22°C and sunny."

# Access details if needed
result.output       # The answer
result.steps        # What the agent did
result.token_usage  # How many tokens used
```

**Creating tools:**
```ruby
class WeatherTool < Smolagents::Tool
  name "weather"
  description "Get current weather for a city"
  inputs city: { type: "string", description: "City name" }
  output_type "string"

  def execute(city:)
    fetch_weather(city)
  end
end
```

**Chaining results:**
```ruby
result = search_tool.call(query: "Ruby conferences 2024")
  .select { |r| r[:date] > Date.today }
  .map { |r| r[:title] }
  .take(5)
```

## Ruby 4.0 Patterns

**Data.define for immutable types:**
```ruby
ToolCall = Data.define(:id, :name, :arguments) do
  def to_s = "#{name}(#{arguments.map { |k,v| "#{k}: #{v}" }.join(', ')})"
end
```

**Pattern matching for control flow:**
```ruby
case step
in ActionStep[tool_calls:] if tool_calls.any?
  execute_tools(tool_calls)
in FinalAnswerStep[answer:]
  return answer
end
```

**Endless methods for simple operations:**
```ruby
def success? = state == :success
def name = @name.to_s.freeze
```

## Testing

```bash
bundle exec rspec              # All tests (<10s)
bundle exec rspec spec/file:42 # Single example
bundle exec rubocop -A         # Lint + autofix
```

Tests should be fast. If they're slow:
- HTTP calls → WebMock stubs
- Sleep in code → Remove it
- Heavy setup → Lazy initialization

## Project Tracking

Work items and decisions live in **PLAN.md**. That's the single source of truth.

## What We Avoid

- Over-abstraction before need
- Configuration without use cases
- Features without tests
- Complexity without justification
- Python idioms in Ruby clothes
