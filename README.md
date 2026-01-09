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

A complete Ruby port of the [HuggingFace smolagents](https://github.com/huggingface/smolagents) Python library. Build powerful AI agents that write and execute Ruby code to accomplish tasks.

## Features

✨ **Simplicity**: Clean, idiomatic Ruby code with minimal abstractions. Core agent logic fits in ~1,000 lines.

🧑‍💻 **Code Agents**: Agents write their actions in Ruby code (not just "agents used to write code"). Secure sandboxed execution environment.

🤖 **Model Agnostic**: Works with any LLM:
- OpenAI, Anthropic, Google via official client gems
- LiteLLM for access to 100+ model providers
- Local models via Ollama or compatible APIs

🛠️ **Powerful Tools**: 10 built-in tools plus easy custom tool creation:
- Web search (DuckDuckGo, Google, Brave API)
- Wikipedia search
- Webpage content extraction
- Speech-to-text transcription
- Ruby code interpreter
- Custom tool DSL

🔒 **Secure Execution**: Sandboxed Ruby code executor with:
- AST-based code validation
- Dangerous method blocking
- Resource limits
- Clean room execution environment

## Installation

Add to your Gemfile:

```ruby
gem 'smolagents'
```

Or install directly:

```bash
gem install smolagents
```

## Quick Start

```ruby
require 'smolagents'

# Create a model (OpenAI example)
model = Smolagents::OpenAIModel.new(
  model_id: "gpt-4",
  api_key: ENV['OPENAI_API_KEY']
)

# Get default tools
tools = [
  Smolagents::DefaultTools.get("web_search"),
  Smolagents::DefaultTools.get("final_answer")
]

# Create and run an agent
agent = Smolagents::CodeAgent.new(
  tools: tools,
  model: model,
  max_steps: 10
)

result = agent.run("What is the weather in Paris today?")
puts result.output
```

## Agent Types

### CodeAgent

Writes and executes Ruby code to accomplish tasks. Best for complex multi-step reasoning.

```ruby
agent = Smolagents::CodeAgent.new(
  tools: tools,
  model: model,
  max_steps: 10
)

result = agent.run("Find the average temperature in Paris over the last week")
```

### ToolCallingAgent

Uses JSON-based tool calling. Better for smaller models.

```ruby
agent = Smolagents::ToolCallingAgent.new(
  tools: tools,
  model: model,
  max_steps: 10
)

result = agent.run("Search for Ruby programming tutorials")
```

## Built-in Tools

All 10 default tools from the Python version are included:

| Tool | Name | Description |
|------|------|-------------|
| FinalAnswerTool | `final_answer` | Returns final answer and exits agent loop |
| RubyInterpreterTool | `ruby_interpreter` | Execute Ruby code in sandbox |
| UserInputTool | `user_input` | Get input from user during execution |
| WebSearchTool | `web_search` | DuckDuckGo/Bing web search |
| DuckDuckGoSearchTool | `duckduckgo_search` | Dedicated DuckDuckGo search with rate limiting |
| GoogleSearchTool | `google_search` | Google search via SerpAPI or Serper |
| ApiWebSearchTool | `api_web_search` | Generic API search (defaults to Brave) |
| VisitWebpageTool | `visit_webpage` | Fetch and convert webpages to markdown |
| WikipediaSearchTool | `wikipedia_search` | Search Wikipedia API |
| SpeechToTextTool | `transcriber` | Transcribe audio via OpenAI Whisper or AssemblyAI |

### Using Default Tools

```ruby
# Get a single tool
search_tool = Smolagents::DefaultTools.get("web_search")

# Get all tools
all_tools = Smolagents::DefaultTools.all

# Get specific tools
tools = [
  Smolagents::DefaultTools.get("web_search"),
  Smolagents::DefaultTools.get("wikipedia_search"),
  Smolagents::DefaultTools.get("final_answer")
]
```

## Creating Custom Tools

### Using the Tool DSL

```ruby
calculator = Smolagents::Tools.define_tool(
  "calculator",
  description: "Performs basic arithmetic operations",
  inputs: {
    "expression" => {
      "type" => "string",
      "description" => "Mathematical expression to evaluate (e.g., '2 + 2')"
    }
  },
  output_type: "number"
) do |expression:|
  eval(expression).to_f
rescue StandardError => e
  "Error: #{e.message}"
end
```

### Subclassing Tool

```ruby
class WeatherTool < Smolagents::Tool
  self.tool_name = "weather"
  self.description = "Get current weather for a city"
  self.inputs = {
    "city" => {
      "type" => "string",
      "description" => "City name"
    }
  }
  self.output_type = "string"

  def forward(city:)
    # Your weather API logic here
    "The weather in #{city} is sunny and 72°F"
  end
end
```

## Supported Models

### OpenAI

```ruby
model = Smolagents::OpenAIModel.new(
  model_id: "gpt-4",
  api_key: ENV['OPENAI_API_KEY']
)
```

### Anthropic

```ruby
model = Smolagents::AnthropicModel.new(
  model_id: "claude-3-5-sonnet-20241022",
  api_key: ENV['ANTHROPIC_API_KEY']
)
```

### LiteLLM (100+ providers)

```ruby
model = Smolagents::LiteLLMModel.new(
  model_id: "ollama/llama3.1",
  api_base: "http://localhost:11434"
)
```

### Local/Custom APIs

```ruby
model = Smolagents::OpenAIModel.new(
  model_id: "local-model",
  api_key: "not-needed",
  api_base: "http://localhost:1234/v1"
)
```

## Advanced Features

### Streaming

```ruby
agent.run("Analyze this data", stream: true) do |step|
  case step
  when Smolagents::ActionStep
    puts "Step #{step.step_number}: #{step.observations}"
  when Smolagents::ActionOutput
    puts "Output: #{step.output}"
  end
end
```

### Custom System Prompts

```ruby
agent = Smolagents::CodeAgent.new(
  tools: tools,
  model: model,
  system_prompt: "You are a helpful assistant that always uses tools..."
)
```

### Memory Management

```ruby
# Access agent memory
agent.memory.steps.each do |step|
  puts step.to_h
end

# Reset memory between runs
agent.run("First task", reset: true)
agent.run("Second task", reset: false)  # Keeps previous context
```

### Callbacks

```ruby
agent.step_callbacks.register(:step_start) do |step, monitor|
  puts "Starting step #{step.step_number}"
end

agent.step_callbacks.register(:step_complete) do |step, monitor|
  puts "Completed step #{step.step_number}"
  puts "Tokens used: #{monitor.total_tokens}"
end
```

## Ruby-Specific Features

### Pattern Matching

```ruby
case result
in { output: String => output, state: :success }
  puts "Success: #{output}"
in { state: :error, error: error }
  puts "Error: #{error}"
end
```

### Data Classes

```ruby
# Built on Ruby 3.2+ Data.define
message = Smolagents::ChatMessage.user("Hello!")
message.role  # => :user
message.content  # => "Hello!"
```

### Concerns (Mixins)

```ruby
class MyAgent < Smolagents::MultiStepAgent
  include Smolagents::Concerns::Retryable
  include Smolagents::Concerns::Monitorable
end
```

## Testing

Run the test suite:

```bash
bundle exec rspec
```

The project includes 502 tests covering:
- All 10 default tools with HTTP mocking
- Sandboxed code execution security
- Agent execution flows
- Model integrations
- Memory management
- Error handling

## Examples

Check the `examples/` directory for complete working examples:

- `openai_compatible_apis.rb` - Using OpenAI-compatible APIs
- `ruby_features.rb` - Ruby-specific features and idioms

## Architecture

```
lib/smolagents/
├── smolagents.rb              # Main entry point
├── version.rb
├── errors.rb                  # Exception hierarchy
├── data_types.rb              # Core data structures (Data.define)
├── chat_message.rb
├── memory.rb                  # Agent memory and step tracking
├── tools/
│   ├── tool.rb                # Base Tool class
│   ├── tool_dsl.rb            # define_tool method
│   └── tool_collection.rb
├── default_tools/             # 10 built-in tools
├── models/
│   ├── model.rb               # Base Model class
│   ├── openai_model.rb
│   ├── anthropic_model.rb
│   └── litellm_model.rb
├── agents/
│   ├── multi_step_agent.rb    # Base agent with ReAct loop
│   ├── code_agent.rb          # Executes Ruby code
│   └── tool_calling_agent.rb  # JSON tool calls
└── executors/
    ├── local_ruby_executor.rb # Sandboxed Ruby execution
    └── docker_executor.rb     # Container-based (optional)
```

## Security

The `LocalRubyExecutor` provides multiple security layers:

- **AST Validation**: Ripper-based syntax tree analysis blocks dangerous methods
- **Blocked Methods**: `eval`, `system`, `exec`, `fork`, `require`, `load`, `binding`, etc.
- **Clean Room**: Execution in `BasicObject` with whitelisted methods only
- **Resource Limits**: Maximum operations counter prevents infinite loops
- **Output Capture**: Controlled stdout/stderr capture

## Contributing

Contributions are welcome! This is a complete port of the Python smolagents library to Ruby.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`bundle exec rspec`)
4. Commit your changes (`git commit -am 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

Apache License 2.0 - see [LICENSE](LICENSE) file for details.

This is a Ruby port of [HuggingFace smolagents](https://github.com/huggingface/smolagents), originally created by the HuggingFace team.

## Acknowledgments

- Original Python library: [HuggingFace smolagents](https://github.com/huggingface/smolagents)
- Inspired by the vision of small, efficient agentic AI systems
- Built with ❤️ for the Ruby community
