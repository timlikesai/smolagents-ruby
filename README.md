# smolagents-ruby

<p align="center">
  <img src="https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/smolagents/smolagents.png" alt="Hugging Face mascot as James Bond" width=400px>
</p>

<p align="center">
  <strong>Agents that think in Ruby code!</strong>
</p>

<p align="center">
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-Apache%202.0-blue.svg"></a>
  <a href="https://rubygems.org/gems/smolagents"><img alt="Gem Version" src="https://img.shields.io/gem/v/smolagents.svg"></a>
</p>

---

Agents that write Ruby code to solve problems. Built with an expressive DSL for defining agents, tools, and multi-agent teams using idiomatic Ruby patterns.

## Quick Start

```ruby
require 'smolagents'

# One-shot execution (no .build needed)
result = Smolagents.agent
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
  .run("What is 2 + 2?")

puts result.output
# => "4"

# With cloud API (OpenAI, OpenRouter, etc.)
result = Smolagents.agent
  .model {
    Smolagents::OpenAIModel.new(
      model_id: "gpt-4-turbo",
      api_key: ENV.fetch("OPENAI_API_KEY")
    )
  }
  .tools(:search)
  .run("Find the latest Ruby release")
```

**Why blocks?** Blocks enable lazy instantiation - the model isn't created until needed. This defers API key validation and connection setup, surfacing errors at run time rather than definition time.

## Installation

```ruby
# Gemfile
gem 'smolagents'
gem 'ruby-openai', '~> 7.0'     # For OpenAI, OpenRouter, Groq, local servers
gem 'anthropic', '~> 0.4'       # For Anthropic (optional)
```

## The DSL

Build agents with three composable atoms:

```ruby
.model { }        # WHAT thinks (required)
.tools(...)       # WHAT it uses (optional)
.as(:persona)     # HOW it behaves (optional)
```

### Basic Examples

```ruby
# Pick your model - local or cloud
model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b")        # Local
model = Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile")  # Groq (fast)
model = Smolagents::OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")  # OpenRouter

# One-shot execution - .build is optional
result = Smolagents.agent
  .model { model }
  .run("What is 2 + 2?")

# With tools
result = Smolagents.agent
  .model { model }
  .tools(:search, :web)
  .run("Find info about Ruby 4.0")

# Reusable agent - use .build when you need multiple runs
agent = Smolagents.agent
  .model { model }
  .tools(:search)
  .as(:researcher)
  .build

agent.run("First task")
agent.run("Second task")
```

### Toolkits

Predefined tool groups that expand automatically:

```ruby
.tools(:search)    # => [:duckduckgo_search, :wikipedia_search]
.tools(:web)       # => [:visit_webpage]
.tools(:data)      # => [:ruby_interpreter]
.tools(:research)  # => [:search + :web combined]
```

### Event Handlers

```ruby
result = Smolagents.agent
  .model { my_model }
  .tools(:search)
  .on(:tool_call) { |e| puts "-> #{e.tool_name}" }
  .on(:tool_complete) { |e| puts "<- #{e.result}" }
  .on(:step_complete) { |e| puts "Step #{e.step_number} done" }
  .run("Search for something")
```

## Custom Tools

```ruby
class WeatherTool < Smolagents::Tool
  self.tool_name = "weather"
  self.description = "Get weather for a location"
  self.inputs = { city: { type: "string", description: "City name" } }
  self.output_type = "string"

  def execute(city:)
    # Your implementation
    "Sunny, 72F in #{city}"
  end
end

result = Smolagents.agent
  .model { my_model }
  .tools(WeatherTool.new)
  .run("What's the weather in Tokyo?")
```

## Models

### Why Blocks?

Blocks enable **lazy instantiation** - the model isn't created until `.run` (or `.build`) is called:

```ruby
# Model created lazily when .run is called
result = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .run("Hello!")

# Equivalent explicit form
agent = Smolagents.agent
  .model { OpenAIModel.lm_studio("gemma-3n-e4b") }
  .build  # model created here
agent.run("Hello!")
```

Lazy instantiation defers connection setup and API key validation until needed. If validation fails, errors surface at run time, not when you're just defining the agent.

### Creating Models

Three equivalent ways:

```ruby
# 1. Class method shortcuts (simplest for local servers)
model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b")

# 2. Builder with presets (for customization)
model = Smolagents.model(:lm_studio).id("gemma-3n-e4b").build

# 3. Full builder (most flexible)
model = Smolagents.model(:openai)
  .id("gpt-4")
  .api_key(ENV['OPENAI_API_KEY'])
  .temperature(0.7)
  .build
```

### Local Models (Recommended for Development)

```ruby
# LM Studio (port 1234)
model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b")
# or: Smolagents.model(:lm_studio).id("gemma-3n-e4b").build

# Ollama (port 11434)
model = Smolagents::OpenAIModel.ollama("gemma-3n-e4b")
# or: Smolagents.model(:ollama).id("gemma-3n-e4b").build

# llama.cpp (port 8080)
model = Smolagents::OpenAIModel.llama_cpp("model-name")

# vLLM (port 8000)
model = Smolagents::OpenAIModel.vllm("model-name")

# Custom endpoint
model = Smolagents.model(:lm_studio)
  .id("gemma-3n-e4b")
  .at(host: "192.168.1.5", port: 1234)
  .build
```

### Cloud APIs

All providers use their respective `*_API_KEY` environment variable by default.

```ruby
# OpenAI - https://platform.openai.com/docs
model = Smolagents::OpenAIModel.new(
  model_id: "gpt-4-turbo",
  api_key: ENV['OPENAI_API_KEY']
)

# OpenRouter (100+ models) - https://openrouter.ai/docs
model = Smolagents::OpenAIModel.openrouter("anthropic/claude-3.5-sonnet")
model = Smolagents::OpenAIModel.openrouter("google/gemini-2.5-flash")

# Groq (fast inference) - https://console.groq.com/docs
model = Smolagents::OpenAIModel.groq("llama-3.3-70b-versatile")

# Together AI - https://docs.together.ai
model = Smolagents::OpenAIModel.together("meta-llama/Llama-3.3-70B-Instruct-Turbo")

# Fireworks AI - https://docs.fireworks.ai
model = Smolagents::OpenAIModel.fireworks("accounts/fireworks/models/llama-v3-70b-instruct")

# DeepInfra - https://deepinfra.com/docs
model = Smolagents::OpenAIModel.deepinfra("meta-llama/Meta-Llama-3.1-70B-Instruct")

# Anthropic (native client) - https://docs.anthropic.com
model = Smolagents::AnthropicModel.new(
  model_id: "claude-sonnet-4-5-20251101",
  api_key: ENV['ANTHROPIC_API_KEY']
)
```

## Fiber Execution

For interactive workflows with bidirectional control:

```ruby
# Works directly on builder (no .build needed)
fiber = Smolagents.agent
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b") }
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

## Multi-Agent Teams

```ruby
researcher = Smolagents.agent.with(:researcher).model { m }.build
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

Code executes in a sandboxed environment:

- **AST Validation**: Ripper-based analysis blocks dangerous patterns
- **Method Blocking**: `eval`, `system`, `exec`, `fork`, `require` blocked
- **Clean Room**: Execution in `BasicObject` with whitelisted methods
- **Resource Limits**: Operation counter prevents infinite loops

## Testing

```ruby
bundle exec rspec
```

## License

Apache License 2.0 - see [LICENSE](LICENSE).

Ruby port of [HuggingFace smolagents](https://github.com/huggingface/smolagents).
