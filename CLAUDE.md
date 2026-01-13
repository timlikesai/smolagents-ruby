# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`smolagents-ruby` is a Ruby port of HuggingFace's lightweight agent library. Agents write Ruby code to call tools or orchestrate other agents. The key differentiator is that `CodeAgent` writes actions as Ruby code snippets (rather than JSON tool calls), enabling loops, conditionals, and multi-tool calls in a single step.

## Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec                    # All tests
bundle exec rspec spec/smolagents/   # Specific directory
bundle exec rspec -fd                # Formatted output

# Code quality
bundle exec rubocop                  # Lint
bundle exec rubocop -a               # Auto-fix
```

## Architecture

### Core Components (lib/smolagents/)

**agents/** - Agent implementations
- `MultiStepAgent` - Abstract base class with ReAct loop
- `CodeAgent` - Writes actions as Ruby code, executes via `LocalRubyExecutor`
- `ToolCallingAgent` - Uses JSON tool-calling format (standard LLM function calling)

**models/** - LLM wrappers
- `Model` - Abstract base
- `OpenAIModel` - OpenAI-compatible APIs
- `AnthropicModel` - Anthropic Claude APIs
- `LiteLLMModel` - 100+ LLM providers via LiteLLM

**tools/** - Tool system
- `Tool` - Base class; subclass and implement `execute()` method
- `ToolCollection` - Groups tools from various sources
- `Tools.define_tool` - Create tools from blocks

**memory.rb** - Conversation/step tracking
- `AgentMemory` - Stores all steps
- `ActionStep`, `TaskStep`, `PlanningStep`, `FinalAnswerStep` - Step types
- `ToolCall` - Represents a single tool invocation

### Ruby-Specific Architectural Components

**tool_result.rb** - Chainable, Enumerable tool results
- All tool calls return `ToolResult` objects
- Supports method chaining: `results.select {...}.sort_by(:key).take(5).pluck(:field)`
- Pattern matching: `case result in ToolResult[data: Array] ...`
- Multiple output formats: `as_markdown`, `as_table`, `as_json`
- Composition: `result1 | result2` (union), `result1 + result2` (concat)

**lazy_tool_result.rb** - Streaming/lazy evaluation
- Page-by-page fetching for large result sets
- Memory efficient: only fetches what's needed
- Thread-safe with Mutex
- Factory methods: `from_array`, `from_enumerator`

**refinements.rb** - Fluent API extensions (lexically scoped)
- String: `"query".search`, `"url".visit`, `"expr".calculate`
- Array: `data.to_tool_result`, `data.transform(ops)`
- Hash: `hash.dig_path("a.b[0].c")`, `hash.query(path)`

### Tool Result Wrapping

The `Tool#call` method automatically wraps results in `ToolResult`:

```ruby
# In Tool base class
def call(*args, wrap_result: true, **kwargs)
  result = execute(**kwargs)
  wrap_result ? wrap_in_tool_result(result, kwargs) : result
end
```

Use `wrap_result: false` to get raw output when needed.

### Agent Flow

1. Task added to `agent.memory`
2. ReAct loop: Memory -> Model generates response -> Parse code/tool calls -> Execute -> Observations back to memory
3. Loop until `final_answer()` called or `max_steps` reached
4. Returns output from `final_answer`

### Creating Tools

```ruby
# Subclass approach
class MyTool < Smolagents::Tool
  self.tool_name = "my_tool"
  self.description = "What this tool does"
  self.inputs = {
    "param" => { "type" => "string", "description" => "Parameter description" }
  }
  self.output_type = "string"

  def execute(param:)
    "Result: #{param}"  # Automatically wrapped in ToolResult
  end
end

# DSL approach
my_tool = Smolagents::Tools.define_tool(
  "my_tool",
  description: "What this tool does",
  inputs: { "param" => { "type" => "string", "description" => "Parameter" } },
  output_type: "string"
) do |param:|
  "Result: #{param}"
end
```

### Input Types

Supported: `string`, `boolean`, `integer`, `number`, `image`, `audio`, `array`, `object`, `any`, `null`

### Persistence

Agents can be saved to disk and loaded later:

```ruby
# Save agent (API keys never serialized)
agent.save("./my_agent", metadata: { version: "1.0" })

# Load agent (model must be provided)
loaded = Smolagents::Agents::Agent.from_folder("./my_agent", model: new_model)
```

Key files: `lib/smolagents/persistence/` - AgentManifest, ModelManifest, ToolManifest, DirectoryFormat, Serializable

### Telemetry and Instrumentation

All major operations emit instrumentation events that can be captured:

```ruby
# Enable logging subscriber for visibility
Smolagents::Telemetry::LoggingSubscriber.enable(level: :debug)

# Or OpenTelemetry integration
Smolagents::Telemetry::OTel.enable(service_name: "my-agent")

# Or custom subscriber
Smolagents::Telemetry::Instrumentation.subscriber = ->(event, payload) {
  puts "#{event}: #{payload[:duration]}s"
}
```

Events emitted:
- `smolagents.agent.run` - Full agent task execution
- `smolagents.agent.step` - Individual ReAct loop step
- `smolagents.model.generate` - LLM API call
- `smolagents.tool.call` - Tool execution
- `smolagents.executor.execute` - Code execution

RunResult provides timing breakdown:
```ruby
result = agent.run("task")
puts result.summary      # Human-readable timing breakdown
puts result.duration     # Total seconds
puts result.step_timings # Per-step timing details
```

### Test Patterns

- Mock tools with `instance_double`
- Use `webmock` for HTTP stubbing
- Refinements require `using` at file scope in specs
- 1656 tests covering all components
- Pre-commit hook runs RuboCop on staged files
- Integration tests: `LIVE_MODEL_TESTS=1 bundle exec rspec spec/integration/`

## Code Style

- RuboCop for linting
- Follow existing patterns: OOP, idiomatic Ruby
- Type documentation via YARD
- Use `Data.define` for immutable value objects
- Prefer composition over inheritance
- Method chaining for fluent APIs

## Ruby 4.0 Concurrency Patterns

This codebase targets **Ruby 4.0 only**. Follow these patterns for all concurrent code:

### Thread::Queue for Message Passing
```ruby
# Preferred: Thread::Queue for producer-consumer patterns
queue = Thread::Queue.new
producer = Thread.new { queue.push(data) }
consumer = Thread.new { result = queue.pop }  # Blocks until data available

# Poison pill pattern for shutdown
queue.push(nil)  # Signal worker to stop
```

### Synchronization
```ruby
# Use Mutex only for protecting shared mutable state
mutex = Mutex.new
mutex.synchronize { shared_state << item }

# Prefer immutable data with Data.define
Result = Data.define(:value, :timestamp) do
  def expired? = Time.now - timestamp > 60
end
```

### Testing Concurrent Code
```ruby
# NEVER use sleep() in tests - use Thread::Queue for synchronization
started = Thread::Queue.new
allow_complete = Thread::Queue.new

thread = Thread.new do
  started.push(:ready)      # Signal start
  allow_complete.pop        # Block until signaled
  do_work
end

started.pop                 # Wait for thread to start
allow_complete.push(:go)    # Release thread
thread.join
```

### Key Principles
- **No polling loops** - use blocking Queue#pop instead
- **No sleep() in tests** - eliminates flakiness
- **Message passing over shared state** - safer, more composable
- **Immutable Data.define** - thread-safe by design
- **Thread::Queue for coordination** - handles synchronization internally
