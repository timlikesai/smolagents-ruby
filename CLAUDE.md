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

The system is designed around **typed events and message passing**:
- Use `Events::Emitter` to emit typed events (`emit(MyEvent.create(...))`)
- Use `Events::Consumer` to handle events (`.on(:event_name) { |e| ... }`)
- Use `Events::Mappings` for ergonomic event name resolution
- Use `Thread::Queue` for coordination, not `sleep()`
- Use blocking operations (`queue.pop`) instead of polling loops
- NO callbacks - all observability through events

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

**Refactored** (no longer using sleep/timeout):
- `rate_limiter.rb` - Now raises `RateLimitExceeded` with `retry_after` info
- `model_reliability.rb` - Now emits `:retry` events with suggested intervals
- `speech_to_text.rb` - Now returns `TranscriptionJob` for async polling
- `browser.rb` - Now uses Selenium explicit waits
- `executors/ruby.rb` - Now uses deadline checking in TracePoint
- `executors/ractor.rb` - Now uses `Ractor.select(timeout:)` and deadline checking

## Commands

```bash
# Install dependencies
bundle install

# Run tests (should complete in <10 seconds without live models)
bundle exec rspec                    # All tests (1855 examples)
bundle exec rspec spec/smolagents/   # Specific directory
bundle exec rspec -fd                # Formatted output

# Code quality
bundle exec rubocop                  # Lint
bundle exec rubocop -A               # Auto-fix

# Documentation
bundle exec yard doc                 # Generate docs
bundle exec yard server --reload     # Live doc server
```

## CRITICAL: Command Output Policy

**NEVER filter command output with `| head` or `| tail` or `timeout` wrappers.**

This causes:
- Wasted time when commands hang (no visible output to diagnose)
- Wasted tokens running commands that produce no useful output
- Inability to diagnose failures

**Instead:**
- Run commands directly and read full output
- If a command takes longer than 10 seconds, **that is a bug to fix**, not a long-running command to work around
- Tests MUST complete in under 10 seconds total - this is enforced in spec_helper.rb
- If tests hang or timeout, fix the underlying issue (missing WebMock stubs, real HTTP calls, sleeps)

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

### Ergonomic API Entry Points

```ruby
# ============================================================
# Preferred: Zero-config entry points
# ============================================================

# Code agent - writes Ruby code to call tools (includes final_answer by default)
agent = Smolagents.code
  .model { OpenAI.gpt4 }
  .tools(:web_search, :visit_webpage)
  .on(:step_complete) { |e| puts e.step_number }
  .build

# Tool-calling agent - uses JSON tool calls (includes final_answer by default)
agent = Smolagents.tool_calling
  .model { LMStudio.llama3 }
  .tools(:web_search)
  .build

# ============================================================
# Model builder with reliability features
# ============================================================
model = Smolagents.model(:openai)
  .id("gpt-4")
  .api_key(ENV["KEY"])
  .with_retry(max_attempts: 3)
  .with_fallback { backup_model }
  .on(:failover) { |e| alert(e.to_model) }
  .build

# ============================================================
# Team builder - multi-agent composition
# ============================================================
team = Smolagents.team
  .model { my_model }
  .agent(researcher, as: "researcher")
  .agent(writer, as: "writer")
  .coordinate("Research then write")
  .build

# ============================================================
# Pipeline - composable tool chains
# ============================================================
result = Smolagents.pipeline
  .call(:search, query: :input)
  .then(:visit) { |r| { url: r.first[:url] } }
  .run(query: "Ruby")
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

### Event-Driven Architecture

The system uses typed events for all observability and coordination:

```ruby
# Event handling with convenience names (via Events::Mappings)
agent = Smolagents.code
  .on(:step_complete) { |e| puts "Step #{e.step_number}: #{e.duration}s" }
  .on(:tool_complete) { |e| log("Tool #{e.tool_name}: #{e.result}") }
  .on(:error) { |e| alert(e.error_message) }
  .build

# Or with explicit event classes
agent = Smolagents.code
  .on(Events::StepCompleted) { |e| puts e.step_number }
  .on(Events::ErrorOccurred) { |e| handle_error(e) }
  .build

# Available event names (see Events::Mappings for full list):
# - :tool_call, :tool_complete
# - :model_generate, :model_complete
# - :step_complete, :task_complete
# - :agent_launch, :agent_progress, :agent_complete
# - :rate_limit, :error, :retry, :failover, :recovery
```

### Instrumentation

Enable structured logging or OpenTelemetry:

```ruby
# Structured logging (debug visibility)
Smolagents::Telemetry::LoggingSubscriber.enable(level: :debug)

# OpenTelemetry integration
Smolagents::Telemetry::OTel.enable(service_name: "my-agent")

# Custom subscriber
Smolagents::Telemetry::Instrumentation.subscriber = ->(event, payload) {
  metrics.record(event, payload[:duration])
}
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

### Completed Refactoring

| File | Old Pattern | New Pattern |
|------|-------------|-------------|
| `concerns/rate_limiter.rb` | `sleep()` | `RateLimitExceeded` exception with `retry_after` |
| `concerns/model_reliability.rb` | `sleep()` backoff | `:retry` event with suggested interval |
| `tools/speech_to_text.rb` | Polling `sleep(1)` | Async `TranscriptionJob` + `check_status` |
| `concerns/browser.rb` | `sleep(1.0)` | Selenium `WebDriverWait` |
| `executors/ruby.rb` | `Timeout.timeout` | Deadline checking in TracePoint |
| `executors/ractor.rb` | `Timeout.timeout` | `Ractor.select(timeout:)` + deadline |
| `concerns/request_queue.rb` | `sleep()` timeout | `Thread::Queue#pop(timeout:)` |
| `orchestrators/ractor_orchestrator.rb` | `Timeout.timeout` | `Ractor.select(timeout:)` |

### Remaining Technical Debt

| File | Issue | Priority |
|------|-------|----------|
| `spec/**/tool_execution_spec.rb` | Some tests may use sleep | Low - audit needed |

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

## Future Features

### Auto-Detect Local Models (IRB Integration)

When smolagents is loaded in IRB/Pry, automatically detect running local model servers:

**Target servers to detect:**
- Ollama (`localhost:11434`)
- LM Studio (`localhost:1234`)
- vLLM (`localhost:8000`)
- llama.cpp server (`localhost:8080`)
- mlx_lm.server (`localhost:8080`)

**Behavior:**
- Quiet detection (no errors shown to user)
- If servers found, display available/loaded models
- Auto-configure sensible defaults
- Show user what was detected and selected

**Example UX:**
```ruby
require 'smolagents'
# => Detected: LM Studio (localhost:1234)
# =>   Models: llama-3.2-3b-instruct (loaded), gemma-2-9b
# =>   Default: Smolagents.model set to llama-3.2-3b-instruct
# =>
# => Ready! Try: Smolagents.code.tools(:web_search).build.run("Hello")
```

**Implementation notes:**
- Use non-blocking HTTP probes with short timeouts
- Cache detection results for session
- Respect `SMOLAGENTS_NO_AUTODETECT=1` env var to disable
