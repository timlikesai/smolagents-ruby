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

A Ruby port of [HuggingFace's smolagents](https://github.com/huggingface/smolagents) with an expressive DSL for building AI agents. Define agents, tools, and multi-agent teams using idiomatic Ruby patterns.

## Quick Start

```ruby
require 'smolagents'

# Build an agent with a local model (recommended)
agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0") }
  .tools(:web_search, :visit_webpage, :final_answer)
  .max_steps(10)
  .build

result = agent.run("What are the latest Ruby 4.0 features?")
puts result.output
```

## Installation

```ruby
# Gemfile
gem 'smolagents'
gem 'ruby-openai', '~> 7.0'     # For OpenAI
gem 'ruby-anthropic', '~> 0.4'  # For Anthropic (optional)
```

## The DSL

smolagents-ruby provides a rich DSL for expressing agents declaratively.

### Agent Builder

Build agents with a fluent, chainable API:

```ruby
# Code agent that writes Ruby to solve problems
agent = Smolagents.agent(:code)
  .model { Smolagents::OpenAIModel.lm_studio("gpt-oss-120b-mxfp4") }
  .tools(:web_search, :wikipedia_search, :final_answer)
  .max_steps(15)
  .planning(interval: 3)
  .on(:after_step) { |step:, monitor:| puts "Step #{step.step_number}: #{monitor.duration}s" }
  .build

# Tool-calling agent for simpler tasks
agent = Smolagents.agent(:tool_calling)
  .model { Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0") }
  .tools(:duckduckgo_search, :final_answer)
  .build
```

### Custom Tools

Define tools with a clean DSL:

```ruby
# Block-based tool definition
calculator = Smolagents::Tools.define_tool(
  "calculator",
  description: "Evaluate mathematical expressions",
  inputs: { expression: { type: "string", description: "Math expression" } },
  output_type: "number"
) { |expression:| eval(expression).to_f }

# Class-based with configure block
class WeatherTool < Smolagents::Tool
  self.tool_name = "weather"
  self.description = "Get weather for a location"
  self.inputs = { city: { type: "string", description: "City name" } }
  self.output_type = "string"

  configure do
    timeout 10
    cache_ttl 300
  end

  def execute(city:)
    # API call here
    "Sunny, 72F in #{city}"
  end
end
```

### Multi-Agent Teams

Coordinate specialized agents with the team builder:

```ruby
# Create specialized agents
researcher = Smolagents.agent(:tool_calling)
  .tools(:web_search, :visit_webpage)
  .build

analyst = Smolagents.agent(:code)
  .tools(:ruby_interpreter)
  .build

# Build a coordinated team
team = Smolagents.team
  .model { my_model }
  .agent(researcher, as: "researcher")
  .agent(analyst, as: "analyst")
  .coordinate("Research the topic, then analyze the data")
  .max_steps(20)
  .build

result = team.run("Analyze trends in Ruby adoption over the last 5 years")
```

### Tool Subclassing with DSL

Built-in tools support configuration DSL for subclassing:

```ruby
# Customize VisitWebpageTool settings
class CompactWebpageTool < Smolagents::VisitWebpageTool
  configure do
    max_length 5_000   # Truncate at 5KB
    timeout 10         # 10 second timeout
  end
end

# Customize search behavior
class FastSearchTool < Smolagents::DuckDuckGoSearchTool
  configure do
    max_results 3
    timeout 5
  end
end

# Create managed agent wrappers
class ResearcherTool < Smolagents::ManagedAgentTool
  configure do
    name "researcher"
    description "Expert at finding and summarizing information"
    prompt_template <<~PROMPT
      You are a research specialist called '%<name>s'.
      Your task: %<task>s
      Be thorough and cite sources.
    PROMPT
  end
end
```

## Built-in Tools

| Tool | Description |
|------|-------------|
| `final_answer` | Return final result and exit |
| `ruby_interpreter` | Execute Ruby in secure sandbox |
| `web_search` | DuckDuckGo web search |
| `duckduckgo_search` | DuckDuckGo with rate limiting |
| `google_search` | Google via SerpAPI/Serper |
| `visit_webpage` | Fetch and convert to markdown |
| `wikipedia_search` | Wikipedia API search |
| `transcriber` | Audio transcription (Whisper/AssemblyAI) |
| `user_input` | Interactive user prompts |

```ruby
# Get tools by name
tools = [
  Smolagents::DefaultTools.get("web_search"),
  Smolagents::DefaultTools.get("final_answer")
]

# Or use symbols in the builder
agent = Smolagents.agent(:code)
  .tools(:web_search, :wikipedia_search, :final_answer)
  .build
```

## Callbacks and Monitoring

Register callbacks for observability:

```ruby
agent = Smolagents.agent(:code)
  .model { my_model }
  .tools(:web_search, :final_answer)
  .on(:before_step) { |step_number:| puts "Starting step #{step_number}" }
  .on(:after_step) { |step:, monitor:|
    puts "Completed in #{monitor.duration.round(2)}s"
    puts "Metrics: #{monitor.metrics}"
  }
  .on(:after_task) { |result:| puts "Final state: #{result.state}" }
  .on(:on_tokens_tracked) { |usage:| puts "Tokens: #{usage.total_tokens}" }
  .build
```

## Models

### Local Models (Recommended)

```ruby
# LM Studio - Recommended for development
model = Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")  # Fast, balanced
model = Smolagents::OpenAIModel.lm_studio("gpt-oss-20b-mxfp4")     # Complex reasoning
model = Smolagents::OpenAIModel.lm_studio("gpt-oss-120b-mxfp4")    # Best quality

# llama.cpp - Direct server
model = Smolagents::OpenAIModel.llama_cpp("nemotron-3-nano-30b-a3b-iq4_nl")

# Ollama
model = Smolagents::OpenAIModel.ollama("gemma-3n-e4b-it-q8_0")

# Or configure manually
model = Smolagents::OpenAIModel.new(
  model_id: "gpt-oss-20b-mxfp4",
  api_base: "http://localhost:1234/v1",
  api_key: "not-needed"
)
```

### Anthropic (Claude 4.5)

```ruby
model = Smolagents::AnthropicModel.new(
  model_id: "claude-sonnet-4-5-20251101",
  api_key: ENV['ANTHROPIC_API_KEY']
)
```

### Google (Gemini 3)

```ruby
model = Smolagents::LiteLLMModel.new(
  model_id: "gemini/gemini-3-pro",
  api_key: ENV['GOOGLE_API_KEY']
)
```

## ToolResult: Chainable Results

All tool calls return `ToolResult` objects with fluent APIs:

```ruby
results = search_tool.call(query: "Ruby programming")

# Chain operations
titles = results
  .select { |r| r[:score] > 0.5 }
  .sort_by(:score, descending: true)
  .take(5)
  .pluck(:title)

# Pattern matching
case results
in Smolagents::ToolResult[data: Array => items]
  puts "Found #{items.count} results"
in Smolagents::ToolResult[error?: true]
  puts "Search failed"
end

# Multiple output formats
results.as_markdown  # For LLM context
results.as_table     # ASCII table
results.as_json      # JSON string
```

## Agent Persistence

Save and load agents (API keys never serialized):

```ruby
# Save agent configuration
agent.save("./agents/researcher", metadata: { version: "1.0" })

# Load with a new model instance
loaded = Smolagents::Agents::Agent.from_folder(
  "./agents/researcher",
  model: Smolagents::OpenAIModel.lm_studio("gemma-3n-e4b-it-q8_0")
)
```

## Security

The `LocalRubyExecutor` sandbox provides:

- **AST Validation**: Ripper-based analysis blocks dangerous patterns
- **Method Blocking**: `eval`, `system`, `exec`, `fork`, `require` blocked
- **Clean Room**: Execution in `BasicObject` with whitelisted methods
- **Resource Limits**: Operation counter prevents infinite loops

```ruby
# Configure sandbox via DSL
class SafeInterpreter < Smolagents::RubyInterpreterTool
  sandbox do
    timeout 5
    max_operations 10_000
    authorized_imports %w[json time uri]
  end
end
```

## Documentation

Generate API documentation with YARD:

```bash
bundle exec rake doc        # Generate docs to doc/
bundle exec rake doc:open   # Generate and open in browser
bundle exec rake doc:server # Live reload server
```

## Testing

```bash
bundle exec rspec  # 1825 tests covering all components
```

## Examples

See `examples/` for complete working examples:

- `agent_patterns.rb` - Agent builder patterns and callbacks
- `custom_tools.rb` - Creating tools with the DSL
- `multi_agent_teams.rb` - Coordinating agent teams
- `local_models.rb` - Using local LLM servers

## License

Apache License 2.0 - see [LICENSE](LICENSE).

Ruby port of [HuggingFace smolagents](https://github.com/huggingface/smolagents).
