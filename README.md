# smolagents-ruby

[![Gem Version](https://img.shields.io/gem/v/smolagents.svg)](https://rubygems.org/gems/smolagents)
[![CI](https://github.com/timlikesai/smolagents-ruby/actions/workflows/ci.yml/badge.svg)](https://github.com/timlikesai/smolagents-ruby/actions/workflows/ci.yml)
[![Coverage](https://img.shields.io/badge/coverage-94%25-brightgreen.svg)](https://github.com/timlikesai/smolagents-ruby)
[![Ruby](https://img.shields.io/badge/ruby-4.0%2B-red.svg)](https://www.ruby-lang.org/)
[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](LICENSE)

**Agents that think in Ruby code.**

An idiomatic Ruby library for building AI agents with sensible defaults and deep customization. Security-first design with sandboxed execution, rich eventing, and composable concerns.

## Philosophy

- **Simple by default** — One line for common cases, full control when you need it
- **Security-first** — AST validation, method blocking, sandboxed execution
- **Event-driven** — 30+ events for observability, logging, and control flow
- **Ruby 4.0 idioms** — `Data.define`, pattern matching, endless methods
- **100/10 rule** — Modules ≤100 lines, methods ≤10 lines

## Quick Start

```ruby
require 'smolagents'

# One-shot execution
result = Smolagents.agent
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .run("What is 2 + 2?")

puts result.output  # => "4"

# With tools
result = Smolagents.agent
  .model { Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile") }
  .tools(:search, :web)
  .run("Find the latest Ruby release")
```

## Installation

```ruby
# Gemfile
gem 'smolagents'
gem 'ruby-openai', '~> 7.0'     # For OpenAI, OpenRouter, Groq, local servers
gem 'anthropic', '~> 0.4'       # For Anthropic (optional)
```

## The DSL

Three composable atoms:

```ruby
.model { }        # WHAT thinks (required)
.tools(...)       # WHAT it uses (optional)
.as(:persona)     # HOW it behaves (optional)
```

### Models

Local or cloud — your choice:

```ruby
# Local servers (recommended for development)
model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b")
model = Smolagents::OpenAIModel.ollama("llama3")

# Cloud APIs
model = Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile")
model = Smolagents::OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
model = Smolagents::AnthropicModel.new(model_id: "claude-sonnet-4-5-20251101")
```

Blocks enable lazy instantiation — the model isn't created until needed, deferring API key validation and connection setup.

### Tools

Built-in toolkits expand automatically:

```ruby
.tools(:search)    # => [:duckduckgo_search, :wikipedia_search]
.tools(:web)       # => [:visit_webpage]
.tools(:research)  # => [:search + :web combined]
```

Custom tools:

```ruby
class WeatherTool < Smolagents::Tool
  self.tool_name = "weather"
  self.description = "Get weather for a location"
  self.inputs = { city: { type: "string", description: "City name" } }
  self.output_type = "string"

  def execute(city:)
    "Sunny, 72F in #{city}"
  end
end

result = Smolagents.agent
  .model { my_model }
  .tools(WeatherTool.new)
  .run("What's the weather in Tokyo?")
```

### Events

Observe and control agent execution:

```ruby
result = Smolagents.agent
  .model { my_model }
  .tools(:search)
  .on(:tool_call) { |e| puts "-> #{e.tool_name}" }
  .on(:tool_complete) { |e| puts "<- #{e.result}" }
  .on(:step_complete) { |e| puts "Step #{e.step_number} done" }
  .run("Search for something")
```

30+ events cover the full agent lifecycle: planning, tool execution, memory, errors, and more.

### Reusable Agents

Use `.build` when you need multiple runs:

```ruby
agent = Smolagents.agent
  .model { my_model }
  .tools(:search)
  .as(:researcher)
  .build

agent.run("First task")
agent.run("Second task")
```

### Fiber Execution

For interactive workflows with bidirectional control:

```ruby
fiber = Smolagents.agent
  .model { my_model }
  .run_fiber("Find Ruby 4.0 features")

loop do
  result = fiber.resume
  case result
  in Smolagents::Types::ActionStep => step
    puts "Step #{step.step_number}: #{step.observations}"
  in Smolagents::Types::RunResult => final
    puts final.output
    break
  end
end
```

### Multi-Agent Teams

```ruby
researcher = Smolagents.agent.as(:researcher).model { m }.build
analyst = Smolagents.agent.tools(:data).model { m }.build

team = Smolagents.team
  .model { my_model }
  .agent(researcher, as: "researcher")
  .agent(analyst, as: "analyst")
  .coordinate("Research the topic, then analyze")
  .build

result = team.run("Analyze Ruby adoption trends")
```

## Security

Code executes in a sandboxed environment with multiple defense layers:

- **AST Validation** — Ripper-based analysis blocks dangerous patterns before execution
- **Method Blocking** — `eval`, `system`, `exec`, `fork`, `require` blocked at runtime
- **Clean Room** — Execution in `BasicObject` sandbox with whitelisted methods only
- **Resource Limits** — Operation counter prevents infinite loops and runaway execution

See [SECURITY.md](SECURITY.md) for details.

## Testing

MockModel enables fast, deterministic tests:

```ruby
model = Smolagents::Testing::MockModel.new(
  responses: ['result = search(query: "Ruby")', 'final_answer(answer: result)']
)
agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby info")
expect(model).to be_exhausted
```

Run tests:

```bash
bundle exec rake spec       # Full test suite
bundle exec rake spec_fast  # Exclude slow tests
bundle exec rake ci         # Full CI (lint + spec + doctest)
```

## Advanced Features

- **Planning** — `.planning` enables pre-action reasoning
- **Self-refinement** — `.refine(max_iterations:)` for iterative improvement
- **Evaluation** — `.evaluate(on: :each_step)` for metacognition
- **Memory** — `.memory(budget:, strategy:)` for context management
- **Spawn restrictions** — `.can_spawn(allow: [...])` for security policies

## Status

6577 tests, 94.46% coverage, 0 RuboCop offenses.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Apache License 2.0 — see [LICENSE](LICENSE).

---

Inspired by [HuggingFace smolagents](https://github.com/huggingface/smolagents).
