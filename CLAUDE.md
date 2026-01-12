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

**tool_pipeline.rb** - Declarative composition DSL
- Chain tools with static/dynamic arguments
- DSL syntax: `step :tool_name, arg: value do |prev| {...} end`
- Transform steps for data manipulation
- Detailed execution results with timing

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

### Test Patterns

- Mock tools with `instance_double`
- Use `webmock` for HTTP stubbing
- Refinements require `using` at file scope in specs
- 1174 tests covering all components
- Pre-commit hook runs RuboCop on staged files

## Code Style

- RuboCop for linting
- Follow existing patterns: OOP, idiomatic Ruby
- Type documentation via YARD
- Use `Data.define` for immutable value objects
- Prefer composition over inheritance
- Method chaining for fluent APIs
