# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

`smolagents-ruby` is a **Ruby 4.0 reimagining** of HuggingFace's smolagents library. This is not just a port—we leverage Ruby 4.0's features (Data.define, pattern matching, Ractors) to create a more powerful, idiomatic agent framework.

**Key differentiator**: `CodeAgent` writes actions as Ruby code snippets (rather than JSON tool calls), enabling loops, conditionals, and multi-tool calls in a single step.

## Core Principles

### Forward-Only Development

We do **not** maintain backwards compatibility. This codebase evolves forward:
- No legacy method shims
- No fallback code paths for old patterns
- No re-exports for "backwards compatibility"
- Delete unused code completely

### Event-Driven Architecture

The system is designed around **events and message passing**, not polling or sleeping:
- Use `Thread::Queue` for coordination, not `sleep()`
- Use callbacks and instrumentation for observability
- Use blocking operations (`queue.pop`) instead of polling loops

### Sleep/Timeout Policy

**SLEEP IS FORBIDDEN. TIMEOUT IS FORBIDDEN.** (in application code)

These patterns introduce:
- Security vulnerabilities (timing attacks)
- Extended test times
- Developer wait time
- Non-deterministic behavior

**Exceptions** (system boundaries only):
- HTTP connection timeouts (Faraday) - external boundary
- Docker container execution limits - safety limit
- Executor code timeouts - prevent runaway user code

**Known violations requiring refactoring** (see Refactoring Notes below):
- `rate_limiter.rb` - uses sleep for throttling
- `model_reliability.rb` - uses sleep for retry backoff
- `speech_to_text.rb` - polling loop with sleep
- `browser.rb` - wait loop with sleep

## Commands

```bash
# Install dependencies
bundle install

# Run tests
bundle exec rspec                    # All tests (1825 examples)
bundle exec rspec spec/smolagents/   # Specific directory
bundle exec rspec -fd                # Formatted output

# Code quality
bundle exec rubocop                  # Lint
bundle exec rubocop -A               # Auto-fix

# Documentation
bundle exec yard doc                 # Generate docs
bundle exec yard server --reload     # Live doc server
```

## CRITICAL: Commit Policy

**NEVER use `git commit --no-verify` or skip pre-commit hooks.**

The pre-commit hook runs RuboCop to ensure code quality. If a commit is blocked:

1. **Read the offense report** - Understand what needs to be fixed
2. **Fix the issues** - Address each offense (run `rubocop -A` for auto-fixes)
3. **Commit again** - Only commit when all checks pass

The verification steps are there to **instruct you to fix problems**, not to be bypassed.

## Architecture

### Directory Structure

```
lib/smolagents/
├── agents/          # Agent implementations (Code, ToolCalling)
├── builders/        # DSL builders (AgentBuilder, ModelBuilder, TeamBuilder)
├── concerns/        # Mixins (35 focused modules)
├── config/          # Configuration management
├── executors/       # Code execution (Ruby, Docker, Ractor)
├── http/            # HTTP utilities and UserAgent
├── logging/         # Structured logging (AgentLogger)
├── models/          # LLM wrappers (OpenAI, Anthropic, LiteLLM)
├── orchestrators/   # Multi-agent coordination
├── persistence/     # Agent save/load
├── security/        # PromptSanitizer, SecretRedactor
├── telemetry/       # Instrumentation, OTel, LoggingSubscriber
├── testing/         # Model benchmarking framework
├── tools/           # Tool system (23 built-in tools)
├── types/           # Data.define types (steps, outcomes, messages)
├── utilities/       # PatternMatching, Prompts, Comparison
├── dsl.rb           # DSL.Builder factory
├── errors.rb        # Error hierarchy
└── pipeline.rb      # Composable tool pipelines
```

### DSL Entry Points

```ruby
# Agent builder - fluent, immutable, validated
agent = Smolagents.agent(:code)
  .model { OpenAIModel.lm_studio("gemma-3n") }
  .tools(:web_search, :final_answer)
  .max_steps(10)
  .on(:after_step) { |step:| puts step }
  .build

# Model builder - with reliability features
model = Smolagents.model(:openai)
  .id("gpt-4")
  .api_key(ENV["KEY"])
  .with_retry(max_attempts: 3)
  .with_fallback { backup_model }
  .build

# Team builder - multi-agent composition
team = Smolagents.team
  .model { my_model }
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .coordinate("Research then write")
  .build

# Pipeline - composable tool chains
result = Smolagents.run(:search, query: "Ruby")
  .then(:visit) { |r| { url: r.first[:url] } }
  .select { |r| r[:score] > 0.5 }
  .run
```

### Builder Features (All Builders)

All builders inherit from `Builders::Base` via `DSL.Builder`:

```ruby
builder.help           # REPL-friendly introspection
builder.freeze!        # Lock configuration for production
builder.validate!      # Early error detection with helpful messages
```

Pattern matching support:
```ruby
case builder
in ModelBuilder[type_or_model: :openai, configuration: { model_id: }]
  puts "OpenAI model: #{model_id}"
end
```

### Agent Types

- **CodeAgent** - Writes Ruby code to accomplish tasks. Best for complex reasoning.
- **ToolCallingAgent** - Uses JSON tool calls. Better for smaller models.

### Tool Result System

All tools return chainable `ToolResult` objects:

```ruby
results = search_tool.call(query: "Ruby")
  .select { |r| r[:score] > 0.5 }
  .sort_by(:score, descending: true)
  .take(5)
  .pluck(:title)

# Pattern matching
case results
in ToolResult[data: Array, empty?: false]
  process(results)
end

# Output formats
results.as_markdown  # For LLM context
results.as_table     # ASCII table
results.as_json      # JSON string
```

### Instrumentation

All operations emit events:

```ruby
Smolagents::Telemetry::LoggingSubscriber.enable(level: :debug)

# Events:
# - smolagents.agent.run
# - smolagents.agent.step
# - smolagents.model.generate
# - smolagents.tool.call
# - smolagents.executor.execute
```

## Creating Tools

```ruby
# Block-based
calculator = Smolagents::Tools.define_tool(
  "calculator",
  description: "Evaluate math expressions",
  inputs: { expression: { type: "string", description: "Math expression" } },
  output_type: "number"
) { |expression:| eval(expression).to_f }

# Class-based
class MyTool < Smolagents::Tool
  self.tool_name = "my_tool"
  self.description = "What this tool does"
  self.inputs = { param: { type: "string", description: "Parameter" } }
  self.output_type = "string"

  def execute(param:)
    "Result: #{param}"
  end
end
```

## Ruby 4.0 Patterns

### Data.define Everywhere

```ruby
# Immutable value objects
Result = Data.define(:value, :timestamp) do
  def expired? = Time.now - timestamp > 60
end

# Pattern matching
case step
in ActionStep[tool_calls: Array => calls] if calls.any?
  process_tool_calls(calls)
in FinalAnswerStep[answer:]
  return answer
end
```

### Thread::Queue for Coordination

```ruby
# NEVER use sleep() - use blocking operations
started = Thread::Queue.new
complete = Thread::Queue.new

thread = Thread.new do
  started.push(:ready)  # Signal start
  complete.pop          # Block until signaled
  do_work
end

started.pop             # Wait for thread to start
complete.push(:go)      # Release thread
thread.join
```

## Testing

### Deterministic Tests

Tests must be **deterministic** without live models:

```ruby
# Good: Use Thread::Queue for synchronization
let(:controllable_model) do
  Class.new do
    def initialize
      @call_started = Thread::Queue.new
      @allow_complete = Thread::Queue.new
    end

    def generate(messages, **)
      @call_started.push(:started)
      @allow_complete.pop  # Block until released
      ChatMessage.assistant("Response")
    end

    def release!
      @allow_complete.push(:complete)
    end
  end.new
end

# Bad: sleep-based timing
# sleep(0.1)  # NEVER do this
```

### Test Categories

- **Unit tests** - Fast, no I/O, mock dependencies
- **Integration tests** - `spec/integration/` - May use live services
- **Live model tests** - `LIVE_MODEL_TESTS=1 bundle exec rspec spec/integration/`

## Refactoring Notes

### Known Technical Debt

These patterns violate our event-driven architecture and need refactoring:

| File | Pattern | Replacement Strategy |
|------|---------|---------------------|
| `concerns/rate_limiter.rb` | `sleep()` for throttling | Token bucket with Thread::Queue |
| `concerns/model_reliability.rb` | `sleep()` for retry backoff | Scheduled callback with Thread::Queue |
| `tools/speech_to_text.rb` | Polling loop with `sleep(1)` | Webhook callback or async with queue |
| `concerns/browser.rb` | `sleep(1.0)` for page wait | Selenium wait conditions |
| `spec/**/tool_execution_spec.rb` | `sleep()` in tests | Thread::Queue synchronization |

### Python Vestiges

These patterns came from the Python implementation and should be modernized:

1. **Polling loops** - Replace with event-driven callbacks
2. **Time-based waits** - Replace with condition-based waits
3. **Mutable configuration** - Replace with Data.define builders

## Code Style

- **RuboCop** for linting (configuration in `.rubocop.yml`)
- **YARD** for documentation (`@param`, `@return`, `@example`)
- **Data.define** for value objects (immutable by default)
- **Composition over inheritance** - Use concerns/mixins
- **Method chaining** for fluent APIs

## Key Files

| Purpose | Location |
|---------|----------|
| Main entry point | `lib/smolagents.rb` |
| DSL factory | `lib/smolagents/dsl.rb` |
| Builder base | `lib/smolagents/builders/base.rb` |
| Agent implementations | `lib/smolagents/agents/` |
| Tool base class | `lib/smolagents/tools/tool.rb` |
| Type definitions | `lib/smolagents/types/` |
| Configuration | `lib/smolagents/config/` |
| Test support | `spec/spec_helper.rb` |
