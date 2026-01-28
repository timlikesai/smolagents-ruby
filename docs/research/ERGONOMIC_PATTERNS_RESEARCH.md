# Ergonomic Patterns Research: Ruby Agent Frameworks & LLM Integration

## Executive Summary

This document analyzes ergonomic patterns from 2024-2025 Ruby LLM integration frameworks and recommends patterns that smolagents-ruby could benefit from. The analysis covers:

1. Configuration patterns from competing gems
2. Rails integration approaches
3. Async/background job patterns
4. Logging and observability
5. Error handling and resilience
6. Testing utilities
7. Production deployment considerations

---

## 1. Configuration Patterns

### Current State (smolagents-ruby)

**Strengths:**
- Block-based model instantiation: `model { OpenAIModel.groq("llama-3.3-70b-versatile") }`
- Lazy evaluation defers API key validation and connections
- ModelBuilder with chainable API: `.with_retry()`, `.with_fallback()`, `.with_circuit_breaker()`, `.with_health_check()`
- Fluent DSL design: `Smolagents.model(:openai).id("gpt-4").temperature(0.7).build`

**Notable Features:**
- Type-safe configuration via `Data.define`
- Immutable builders prevent accidental mutation
- Method registration with validation: `register_method :temperature, validates: ->(v) { v >= 0 && v <= 2 }`

### Best Practices from Other Gems (2024-2025)

#### Configuration Source Hierarchy

**Recommended Pattern:**
The industry standard is a three-tier configuration hierarchy:

1. **Environment Variables** (highest priority)
   - For secrets and deployment-specific values
   - Use `ENV["KEY"]` for reading, not configuring gem behavior

2. **YAML/Config Files** (middle tier)
   - Non-sensitive settings
   - Environment-specific configs

3. **Block/Initializer Configuration** (lowest priority)
   - Application-level defaults
   - Rails initializer pattern

**Examples from Industry:**

**RubyLLM (Rails Integration Pattern):**
```ruby
# config/initializers/ruby_llm.rb
RubyLLM.configure do |config|
  config.openai_api_key = ENV['OPENAI_API_KEY']
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY']
  config.default_model = "claude-sonnet"
end
```

**LangchainRB (Direct Instantiation):**
```ruby
llm = Langchain::LLM::OpenAI.new(
  api_key: ENV["OPENAI_API_KEY"],
  default_options: { temperature: 0.7, chat_model: "gpt-4o" }
)
```

**Anyway Config (Gem Configuration Pattern):**
```ruby
# Uses automatic ENV variable discovery
# Loads from config/smolagents.yml and ENV with automatic prefix
Smolagents.config.openai_api_key  # reads SMOLAGENTS_OPENAI_API_KEY
Smolagents.config.retry_attempts  # reads from config file or ENV
```

### Recommendation: Multi-Source Configuration

**For smolagents-ruby integration with Rails:**

```ruby
# config/initializers/smolagents.rb
Smolagents.configure do |config|
  # Model defaults
  config.default_model_type = :openai
  config.default_temperature = 0.7

  # Reliability defaults
  config.retry_max_attempts = 3
  config.retry_initial_delay = 1
  config.circuit_breaker_threshold = 5

  # API keys (from ENV, Rails credentials, or explicit)
  config.openai_api_key = Rails.application.credentials.openai_api_key
  config.anthropic_api_key = Rails.application.credentials.anthropic_api_key

  # Observability
  config.enable_telemetry = !Rails.env.test?
  config.logging_level = :info
end

# Usage in agents
agent = Smolagents.agent
  .model { OpenAIModel.new(api_key: Smolagents.config.openai_api_key) }
  .tools(:search)
  .build
```

**Pattern Benefits:**
- Centralized configuration for Rails apps
- Automatic ENV variable discovery (with prefix namespacing)
- Rails credentials integration (encrypted secrets)
- Test/development/production environment overrides
- Introspection: `Smolagents.config.help` for available settings

**Implementation Approach:**
1. Adopt `anyway_config` gem or lightweight equivalent
2. Add `Smolagents.configure { |config| }` block support
3. Support `.env` files via `dotenv` integration guidance
4. Document Rails credential integration

---

## 2. Rails Integration Patterns

### Current State

**smolagents-ruby Strengths:**
- Generators not mentioned (could be added)
- Models work standalone or in agents
- Event-driven architecture allows Rails observers
- Builder pattern fits Rails initialization patterns

### Best Practices from Industry (2024-2025)

#### RubyLLM Rails Integration

**Generator-based Setup:**
```bash
rails generate ruby_llm:install
rails generate ruby_llm:chat_ui  # Optional UI
rails db:migrate
```

**Creates:**
- Migration files for Chat, Message, ToolCall, Model persistence
- ActiveRecord mixins: `acts_as_chat`, `acts_as_message`
- Database schema optimized for conversations
- ReadytoUse `/chats` endpoint

**Model Integration:**
```ruby
class Chat < ApplicationRecord
  acts_as_chat  # Adds methods: ask(), stream(), remember()
end

class Message < ApplicationRecord
  acts_as_message  # Validates role, persists content properly
  # CRITICAL: Cannot use validates :content, presence: true
  # because persistence creates empty assistant messages before API response
end

chat = Chat.create(model: "claude-sonnet-4")
chat.ask("Analyze this file", with: "report.pdf")  # Auto-handles attachments
```

**Key Insight: Persistence Flow**
RubyLLM optimizes for real-time Turbo Streams:
1. User message saved immediately
2. Empty assistant message created on first streaming chunk
3. Message updated with content on success, or destroyed on failure
4. Enables seamless Turbo Streams integration

#### LangchainRB Rails Integration

**Initializer Pattern:**
```ruby
# config/initializers/langchainrb_rails.rb
Langchain::Config.set do |config|
  config.vectorsearch = Langchain::Vectorsearch::Pgvector.new(
    llm: Langchain::LLM::OpenAI.new(
      api_key: ENV["OPENAI_KEY"],
      default_options: {
        temperature: 0.0,
        chat_completion_model_name: 'gpt-4',
        embeddings_model_name: "text-embedding-3-small"
      }
    )
  )
end
```

**Key Features:**
- Generator creates initializers, migrations, and migrations
- Automatic dependency injection into ActiveRecord
- Vector search integration (pgvector)
- Structured output persistence

### Recommendations for smolagents-ruby

**1. Rails Generator**
```bash
rails generate smolagents:install
```

Creates:
- `config/initializers/smolagents.rb` - Main configuration
- Migration for agent execution logs (optional)
- Railtie for autoloading concerns

**2. ActiveRecord Integration Concern**
```ruby
module Smolagents::Rails::Recordable
  # Stores agent execution results in AR models
  # Useful for audit trails, debugging
  def record_execution(model_name = "AgentExecution")
    record_model = model_name.constantize
    on(:step_complete) { |e| record_model.create!(step_data: e.to_h) }
  end
end
```

**3. Background Job Integration**
```ruby
# app/jobs/smolagents/agent_job.rb
class Smolagents::AgentJob < ApplicationJob
  def perform(agent_class, task)
    agent = agent_class.constantize.new
    result = agent.run(task)
    # Store result or broadcast via ActionCable
  end
end

# Usage in controller
Smolagents::AgentJob.perform_later("ResearchAgent", query)
```

**4. Rails Credentials Integration**
```ruby
# config/credentials.yml.enc
smolagents:
  openai_api_key: <%= ENV['OPENAI_API_KEY'] %>
  anthropic_api_key: <%= ENV['ANTHROPIC_API_KEY'] %>
  retry_attempts: 3
  timeout: 30

# Usage
Rails.application.credentials.smolagents.openai_api_key
```

**5. Middleware for Request Context**
```ruby
# lib/smolagents/rails/request_context.rb
class Smolagents::Rails::RequestContextMiddleware
  def call(env)
    # Captures request ID, user ID for agent execution tracking
    Smolagents.request_context = {
      request_id: env['action_dispatch.request_id'],
      user_id: Current.user&.id
    }
    @app.call(env)
  end
end
```

---

## 3. Async/Background Job Patterns

### Current State

**smolagents-ruby Strengths:**
- Fiber-based execution via concerns
- Event-driven architecture allows async subscribers
- No blocking dependencies on job queues

### Industry Challenge: LLM Operations in Background Jobs

**The Core Problem:**
Traditional background job processors (Sidekiq, SolidQueue) use thread pools. LLM operations:
- Take 5-60 seconds
- Spend 99% of time waiting for streaming tokens
- Using 1000 threads for 1000 concurrent LLM operations means 1000 database connections held idle

**Solution Options from Industry:**

#### Option 1: Hybrid Approach (Recommended by RubyLLM author)

**Pattern:**
```ruby
# For LLM-heavy workloads: Use fiber-based async
# For traditional jobs: Use Sidekiq

# app/jobs/llm_job.rb - LLM operations
class LLMJob < Smolagents::Async::Job
  adapter :async  # Uses fibers, not threads

  def perform(agent_class, task)
    agent = agent_class.constantize.new
    result = agent.run(task)
    broadcast_result(result)
  end
end

# app/jobs/data_job.rb - Traditional work
class DataJob < ApplicationJob
  queue_as :default  # Uses Sidekiq

  def perform(data)
    # Process synchronously
  end
end
```

**Benefits:**
- Sidekiq handles CPU-bound tasks efficiently
- Async/fibers handle I/O-bound LLM work efficiently
- No forced overhead on either workload type

#### Option 2: Async Ruby with Fibers

**Pattern (from Async gem):**
```ruby
# Lightweight, runs thousands of concurrent operations on few connections
Async do
  tasks = (1..1000).map do |i|
    Async do
      agent.run("Task #{i}")
    end
  end

  tasks.map(&:wait)
end
```

**Why Fibers Trump Threads for LLM:**
- OS-scheduled threads: Heavy context switching, one thread per operation
- Fibers: User-space, cooperative, thousands share few connections
- LLM workload: 99% idle waiting = perfect fiber use case

#### Option 3: Sidekiq with Streaming

**Pattern:**
```ruby
class StreamingLLMJob < ApplicationJob
  queue_as :default

  def perform(agent_id, task, connection_id)
    agent = Agent.find(agent_id)
    ActionCable.server.broadcast(
      "agent_#{connection_id}",
      message: "Starting..."
    )

    agent.run(task) do |token|
      ActionCable.server.broadcast(
        "agent_#{connection_id}",
        token: token
      )
    end
  end
end
```

### Recommendations for smolagents-ruby

**1. Async Adapter Pattern**

```ruby
# lib/smolagents/adapters/sidekiq_adapter.rb
module Smolagents::Adapters
  class SidekiqAdapter
    def enqueue(agent_class, task, options = {})
      AgentJob.set(options).perform_later(agent_class, task)
    end
  end
end

# lib/smolagents/adapters/async_adapter.rb
module Smolagents::Adapters
  class AsyncAdapter
    def enqueue(agent_class, task, options = {})
      Async { agent_class.new.run(task) }
    end
  end
end

# Usage
agent.run_async(:sidekiq, task)  # Queue in Sidekiq
agent.run_async(:async, task)     # Run with fibers
```

**2. ActionCable Integration**

```ruby
# app/channels/agent_channel.rb
class AgentChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_#{params[:agent_id]}"
  end

  def execute_agent(data)
    Smolagents::AgentJob.perform_later(
      data['agent_class'],
      data['task'],
      connection_id: connection.connection_identifier
    )
  end
end

# Usage in JavaScript
consumer.subscriptions.create(
  { channel: "AgentChannel", agent_id: 123 },
  {
    received(data) {
      console.log(data.token);  // Stream tokens
    },
    executeAgent(task) {
      this.perform('execute_agent', { task });
    }
  }
);
```

**3. Progress Tracking Pattern**

```ruby
# Extend events for async tracking
Smolagents.agent
  .on(:step_complete) do |event|
    broadcast_progress(event.step_number, event.output)
  end
  .run_async(task)

# Helper
def broadcast_progress(step, output)
  ActionCable.server.broadcast(
    "agent_#{session[:agent_id]}",
    step: step,
    output: output
  )
end
```

**4. Documentation Guidance**

```ruby
# Guide in README/docs for different scenarios:

# Scenario 1: User waits (< 5 seconds)
result = agent.run(task)

# Scenario 2: Background, email when done
AgentJob.perform_later(agent, task)

# Scenario 3: Streaming to WebSocket
agent.run(task) { |token| broadcast_token(token) }
```

---

## 4. Logging and Observability Patterns

### Current State (smolagents-ruby)

**Strengths:**
- Event-driven architecture (40+ event types)
- `Telemetry` module with OpenTelemetry support
- `LoggingSubscriber` for step/tool visibility
- Call logging API for testing
- Request logging system

**Key Components:**
```ruby
# From CLAUDE.md
Smolagents::Telemetry::LoggingSubscriber.enable(level: :info)
# Auto-enables logging for agent progress visibility
```

### Best Practices from Industry (2024-2025)

#### OpenTelemetry Integration

**Standard Pattern:**
```ruby
# config/initializers/opentelemetry.rb
require 'opentelemetry/sdk'
require 'opentelemetry/exporter/otlp'
require 'opentelemetry-instrumentation-all'

OpenTelemetry::SDK.configure do |c|
  c.use_all()  # Auto-instruments Rails, HTTP, ActiveRecord
  c.add_span_processor(
    OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(
      OpenTelemetry::Exporter::OTLP::Exporter.new(
        endpoint: ENV['OTEL_EXPORTER_OTLP_ENDPOINT']
      )
    )
  )
end
```

**Benefits:**
- Single instrumentation format (OTLP)
- Works with any backend (Datadog, New Relic, Jaeger, SigNoz)
- Automatic trace correlation across services
- Low overhead with batch processing

#### Structured Logging Pattern

**Ruby Standard (JSON logs for production):**
```ruby
# For development
Smolagents::Telemetry::LoggingSubscriber.enable(format: :text)

# For production
Smolagents::Telemetry::LoggingSubscriber.enable(
  format: :json,
  output: $stdout
)

# Output in production
{
  "timestamp": "2025-01-26T10:30:00Z",
  "level": "info",
  "agent_id": "agent_123",
  "step": 1,
  "tool": "search",
  "duration_ms": 1234,
  "request_id": "abc123"
}
```

#### Log Correlation Pattern

**Best Practice:** Include trace context in all logs
```ruby
# Automatic trace context injection
on(:step_complete) do |event|
  logger.info(
    "Step complete",
    step: event.step_number,
    trace_id: OpenTelemetry::Trace.current_span.trace_id,
    span_id: OpenTelemetry::Trace.current_span.span_id
  )
end
```

### Recommendations for smolagents-ruby

**1. Structured Logging Enhancement**

```ruby
# lib/smolagents/logging/structured_logger.rb
module Smolagents::Logging
  class StructuredLogger
    def initialize(level: :info, format: :text)
      @level = level
      @format = format
    end

    def log_event(event, additional_context = {})
      context = {
        timestamp: Time.now.iso8601,
        event_type: event.class.name.demodulize,
        duration_ms: event.duration_ms,
        trace_id: current_trace_id,
        request_id: request_context[:request_id],
        user_id: request_context[:user_id],
        **additional_context
      }

      case @format
      when :json
        puts context.to_json
      when :text
        format_text(context)
      end
    end

    private

    def current_trace_id
      OpenTelemetry::Trace.current_span.trace_id
    rescue
      nil
    end
  end
end
```

**2. OpenTelemetry Integration**

```ruby
# lib/smolagents/telemetry/otel_publisher.rb
module Smolagents::Telemetry
  class OTelPublisher
    include Smolagents::Events::Consumer

    def initialize
      tracer = OpenTelemetry.tracer_provider.tracer('smolagents')
      @tracer = tracer

      on_lifecycle { |event| record_span(event) }
    end

    private

    def record_span(event)
      @tracer.in_span(event_name(event)) do |span|
        span.set_attribute('duration_ms', event.duration_ms)
        span.set_attribute('tool', event.tool_name) if event.respond_to?(:tool_name)
      end
    end
  end
end
```

**3. Custom Instrumentation Helpers**

```ruby
# Usage in agents/tools
class MyTool < Smolagents::Tool
  def execute(**args)
    Smolagents::Telemetry.instrument('custom_tool.execute') do
      # Your code here
      # Automatically creates span, logs timing
    end
  end
end
```

**4. Production Logging Configuration**

```ruby
# config/initializers/smolagents.rb
if Rails.env.production?
  Smolagents::Telemetry::LoggingSubscriber.enable(
    format: :json,
    level: :info,
    output: $stdout,
    include_context: true  # Adds request_id, user_id, etc.
  )

  # Connect to OpenTelemetry
  Smolagents::Telemetry::OTelPublisher.new
end
```

---

## 5. Error Handling and Resilience Patterns

### Current State (smolagents-ruby)

**Excellent Foundation:**
- Circuit breaker pattern: `.with_circuit_breaker(threshold: 5)`
- Retry with exponential backoff: `.with_retry(max_attempts: 3)`
- Fallback chains: `.with_fallback(backup_model)`
- Health checks: `.with_health_check(cache_for: 5)`
- Rate limiting: `Concerns::Resilience::RateLimiter`
- Dead Letter Queue: `Concerns::Models::Queue::DeadLetter`

**Event-Driven:**
- `Events::RetryRequested` - Before retry
- `Events::FailoverOccurred` - When switching models
- `Events::ErrorOccurred` - On any error
- `Events::RecoveryCompleted` - When retry succeeds

### Best Practices from Industry (2024-2025)

#### Retry Strategy Pattern

**From Retriable and Retryable gems:**
```ruby
# Pattern 1: Fixed delays
retry_with(
  max_attempts: 3,
  delays: [1, 2, 4]  # 1s, 2s, 4s
)

# Pattern 2: Exponential backoff (industry standard)
retry_with(
  max_attempts: 5,
  initial_delay: 1,
  exponential_base: 2,
  max_delay: 60,
  jitter: true  # Prevents thundering herd
)

# Pattern 3: Custom backoff
retry_with(
  max_attempts: 3,
  delay_calculator: ->(attempt) { 2 ** attempt }
)
```

**Current smolagents-ruby supports this via:**
```ruby
Smolagents.model(:openai)
  .id("gpt-4")
  .with_retry(
    max_attempts: 3,
    initial_delay: 1,
    exponential_base: 2,
    max_delay: 60
  )
```

#### Error Classification Pattern

**Key Insight:** Different errors need different handling

```ruby
# Retriable errors: retry (network timeout, rate limit, transient 5xx)
# Non-retriable: fail immediately (auth error, validation error, permanent 4xx)

# Implementation pattern:
class ErrorClassifier
  def retriable?(error)
    case error
    when Timeout::Error, Errno::ECONNREFUSED
      true  # Network errors
    when RateLimitError
      true  # Rate limit
    when AuthenticationError, ValidationError
      false  # Permanent failures
    else
      false
    end
  end

  def backoff_for(error)
    case error
    when RateLimitError
      exponential_with_max(10, 60)  # Longer backoff for rate limits
    else
      exponential_with_max(1, 30)
    end
  end
end

# smolagents-ruby should extend error handling to classify:
model.with_retry(
  max_attempts: 3,
  classify_error: ->(e) { ErrorClassifier.new.retriable?(e) }
)
```

#### Timeout Handling Pattern

**Critical for LLM calls:**
```ruby
# Pattern: Separate timeouts for different phases
model = Smolagents::OpenAIModel.new(
  timeout: 30,  # Connection timeout (global)
  read_timeout: 120,  # Response timeout (for streaming)
  write_timeout: 10   # Request body timeout
)

# Per-request timeout
model.generate(
  prompt: "...",
  timeout: 60  # Override for this call
)
```

### Recommendations for smolagents-ruby

**1. Error Classification Framework**

```ruby
# lib/smolagents/concerns/resilience/error_classifier.rb
module Smolagents::Concerns::Resilience
  class ErrorClassifier
    # Classify errors for retry decisions
    def self.retriable?(error)
      case error
      when Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED
        true
      when Smolagents::RateLimitError
        true
      when Smolagents::AuthenticationError
        false
      when Smolagents::ValidationError
        false
      else
        false  # Default: don't retry unknown errors
      end
    end

    def self.backoff_for(error)
      case error
      when Smolagents::RateLimitError
        { initial_delay: 10, exponential_base: 2, max_delay: 300 }
      else
        { initial_delay: 1, exponential_base: 2, max_delay: 60 }
      end
    end
  end
end

# Usage
model.with_retry(
  classify_error: Smolagents::Concerns::Resilience::ErrorClassifier.method(:retriable?)
)
```

**2. Timeout Configuration Pattern**

```ruby
# Already exists but could be enhanced:
Smolagents.model(:openai)
  .id("gpt-4")
  .timeout(30)  # Connection
  .read_timeout(120)  # Streaming
  .write_timeout(10)  # Request body
  .build
```

**3. Error Context Preservation**

```ruby
# For better debugging, capture error context
on(Smolagents::Events::ErrorOccurred) do |event|
  logger.error(
    "Model error",
    error_class: event.error.class.name,
    error_message: event.error.message,
    model_id: event.model_id,
    attempt: event.attempt,
    trace: event.error.backtrace.first(5)
  )
end
```

**4. Fallback with Health Checks (Already Exists)**

Documentation should emphasize this pattern:
```ruby
# Production pattern: Multiple models with health checks
agent = Smolagents.agent
  .model {
    Smolagents.model(:openai)
      .id("gpt-4")
      .with_health_check(cache_for: 5)  # Check every 5 seconds
      .with_fallback { backup_model }
      .prefer_healthy  # Use backup if primary unhealthy
      .build
  }
  .build
```

**5. Dead Letter Queue Processing (Already Exists)**

Enhance documentation:
```ruby
# Automatic retry of failed model calls
model.on(Smolagents::Events::MessageQueued) do |event|
  # Message in DLQ for retry
  # Process periodically or manually
end

# Manual DLQ processing
model.process_dead_letter_queue(max_retries: 3)
```

---

## 6. Testing Utilities Provided to Users

### Current State (smolagents-ruby)

**Excellent Testing Infrastructure:**
- `Smolagents::Testing::MockModel` - Predefined response sequences
- `Smolagents::Testing::MatCHERS` - RSpec matchers (call_log, agent matchers)
- `Smolagents::Testing::Scenarios` - Test case building
- `Smolagents::Testing::CallLog` - Request logging for assertions
- `Smolagents::Testing::BehaviorTracer` - Execution tracing
- Test case builders and fixtures
- Model capability testing framework

### Best Practices from Industry (2024-2025)

#### Test Double Patterns (RSpec, Mocha)

**From rspec-mocks documentation:**

```ruby
# Stubs - Predefined responses
allow(model).to receive(:generate).and_return("response")

# Mocks - Verify interactions
expect(model).to receive(:generate).with(prompt: "test").once

# Spies - Record interactions
spy = spy_on(model, :generate)
model.generate(prompt: "test")
expect(spy).to have_been_called

# Fakes - Working implementations
class FakeModel < Smolagents::Model
  def generate(prompt)
    "Canned response for: #{prompt}"
  end
end
```

#### VCR Pattern (Recorded HTTP)

**Industry standard for external API testing:**
```ruby
# Gem: vcr
VCR.use_cassette('smolagents/model_generate') do
  response = model.generate("prompt")
  # First run: records actual HTTP
  # Subsequent runs: plays back from cassette
end
```

#### Factory Pattern

**For building test agents consistently:**
```ruby
# spec/factories/agents.rb
FactoryBot.define do
  factory :research_agent, class: 'Smolagents::Agent' do
    model { Smolagents::Testing::MockModel.new }
    tools { [:search, :web] }
    persona { :researcher }
  end
end

# Usage
agent = create(:research_agent)
result = agent.run("Research Ruby")
```

### Recommendations for smolagents-ruby

**1. Enhance MockModel Documentation**

```ruby
# lib/smolagents/testing/mock_model.rb
# Add method documentation showing all features:

model = Smolagents::Testing::MockModel.new(
  responses: ['tool_call(...)', 'final_answer(...)'],
  delay: 0.1,  # Simulate latency
  raise_on_tool: { 'search' => RateLimitError.new },
  track_calls: true  # Record all calls for inspection
)

# Assertions
expect(model.call_log).to match(
  have_tool_call(:search, query: /Ruby/)
)
```

**2. Add Matchers Documentation**

```ruby
# Existing but document in testing guide:
expect(agent).to have_run_tool(:search)
expect(agent).to have_completed
expect(result).to match_pattern(/^The answer is.*/)

# New: Step matchers
expect(agent).to have_completed_in_steps(5..10)
expect(agent).to have_called_tool_in_order(:search, :web)
```

**3. Scenario Builder Pattern**

```ruby
# Already exists, enhance with:
scenario = Smolagents::Testing::Scenario.new
  .when_tool_called(:search, query: /Ruby/).then_return("Ruby docs")
  .when_tool_called(:web).then_return("Ruby homepage")
  .build

agent = Smolagents.agent
  .model { scenario }
  .tools(:search, :web)
  .build

result = agent.run("Find Ruby info")
```

**4. Add Behavior Tracing Guide**

```ruby
# Document BehaviorTracer for understanding what agent did
tracer = Smolagents::Testing::BehaviorTracer.new
agent.on(:step_complete) { |e| tracer.record(e) }

result = agent.run(task)

tracer.steps  # All steps
tracer.tools_used  # Which tools called
tracer.duration  # Total time
tracer.tokens_used  # Token counts
```

**5. Add RSpec Configuration Helper**

```ruby
# spec/spec_helper.rb
require 'smolagents/testing/rspec'

# Provides:
# - `mock_model { responses }`
# - `build_agent { model, tools, etc }`
# - `stub_search(with: "results")`
# - Automatic agent cleanup

RSpec.configure do |config|
  config.include Smolagents::Testing::RSpec::AgentHelpers
end

describe MyAgent do
  let(:model) { mock_model { ['answer'] } }
  let(:agent) { build_agent(model:, tools: [:search]) }

  it 'uses search tool' do
    agent.run("Find X")
    expect(agent).to have_run_tool(:search)
  end
end
```

**6. Add VCR Integration Guide**

```ruby
# spec/support/smolagents_cassettes.rb
VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.define_cassette_placeholder('<API_KEY>', ENV['OPENAI_API_KEY'])

  # Auto-record smoke tests, playback otherwise
  config.default_cassette_options = {
    record: :none,  # Use recorded cassettes
    allow_playback_repeats: true
  }
end

# Usage in specs
it 'generates response' do
  VCR.use_cassette('smolagents/gpt4_response') do
    response = model.generate("test")
    expect(response).to include("text")
  end
end
```

---

## 7. Production Deployment Considerations

### From Industry Best Practices (2024-2025)

#### Health Checks

**Standard Pattern (from health_check gem, Rails-HealthCheck):**
```ruby
# config/routes.rb
# Single endpoint for monitoring
get '/health' => 'health#show'

# lib/smolagents/rails/health_check.rb
class HealthCheck
  def check
    {
      status: 'healthy',
      models: check_models,
      services: check_services,
      timestamp: Time.now.iso8601
    }
  end

  private

  def check_models
    Smolagents.config.models.map do |name, model|
      {
        name:,
        status: model.healthy? ? 'up' : 'down',
        response_time_ms: model.health_check_ms
      }
    end
  end
end
```

**Prometheus metrics:**
```ruby
# Automatically expose metrics endpoint /metrics
# Integrate with prometheus_client gem

# Track:
# - agent_runs_total (counter)
# - agent_steps_total (counter)
# - agent_duration_seconds (histogram)
# - tool_calls_total (counter)
# - model_errors_total (counter)
# - model_fallover_total (counter)
```

#### Monitoring Dashboard

**Key Metrics to Track:**
```ruby
# Performance
- Average agent completion time
- P95/P99 latency
- Tokens generated per run
- Cost per run

# Reliability
- Error rate by type
- Fallback frequency
- Retry attempts distribution
- Model health status

# Usage
- Requests per agent
- Most-used tools
- Error patterns
- Cost trends
```

#### Rate Limiting and Quotas

**Pattern from RubyLLM and Langchain:**
```ruby
# Per-model rate limiting
model.with_rate_limit(
  requests_per_minute: 60,
  tokens_per_minute: 10_000,
  strategy: :token_bucket  # or :sliding_window, :fixed_window
)

# Per-user rate limiting (in agent)
agent.with_rate_limit(
  per_user: { requests_per_day: 100 }
)
```

#### Cost Tracking

**Production requirement:**
```ruby
# Track API costs per request
on(Smolagents::Events::ModelGenerateCompleted) do |event|
  cost = calculate_cost(
    model_id: event.model_id,
    input_tokens: event.input_tokens,
    output_tokens: event.output_tokens
  )

  logger.info("Request cost: $#{cost}")
  User.find(current_user).increment_spend(cost)
end
```

#### Environment-Specific Configuration

**Pattern:**
```ruby
# config/smolagents/development.yml
models:
  default: gpt-3.5-turbo  # Cheaper for dev

# config/smolagents/production.yml
models:
  default: gpt-4
  backup: gpt-4-turbo-preview

retry_policy:
  max_attempts: 5  # More retries in prod

circuit_breaker:
  failure_threshold: 5  # Fail fast in prod
```

#### Observability Standards

**Complete observability setup:**
```ruby
# 1. Logging: Structured JSON logs with trace IDs
# 2. Metrics: Prometheus endpoint for monitoring
# 3. Tracing: OpenTelemetry spans for request flow
# 4. Health: /health endpoint for load balancers
# 5. Secrets: Environment variables, never hardcoded
# 6. Rate limiting: Per-model, per-user limits
# 7. Cost tracking: Every request logged with cost
# 8. Audit trail: All agent runs recorded in DB
```

### Recommendations for smolagents-ruby

**1. Production Checklist Documentation**

```markdown
# Production Readiness Checklist for smolagents

## Configuration
- [ ] Environment variables set for all API keys
- [ ] Retry policy configured: max_attempts >= 3
- [ ] Fallback model configured
- [ ] Timeout values appropriate for use case
- [ ] Rate limiting enabled

## Observability
- [ ] Logging enabled with structured JSON format
- [ ] OpenTelemetry configured and connected
- [ ] Health checks configured
- [ ] Metrics endpoint exposed
- [ ] Error alerting configured

## Reliability
- [ ] Circuit breaker enabled
- [ ] Health checks running
- [ ] Dead letter queue monitored
- [ ] Fallback tested and verified
- [ ] Error handling tested

## Security
- [ ] API keys in environment/credentials only
- [ ] No secrets in logs
- [ ] Request validation enabled
- [ ] Rate limiting per-user/IP
- [ ] Audit logging enabled

## Testing
- [ ] Unit tests with mock models
- [ ] Integration tests with real models
- [ ] Load testing completed
- [ ] Cost estimation complete
- [ ] Canary deployment plan ready
```

**2. Production Configuration Template**

```ruby
# config/initializers/smolagents_production.rb
return unless Rails.env.production?

Smolagents.configure do |config|
  # Models with health checks and fallbacks
  config.default_model = Smolagents.model(:openai)
    .id(ENV['OPENAI_MODEL_ID'])
    .api_key(Rails.application.credentials.openai_api_key)
    .with_health_check(cache_for: 30)
    .with_retry(max_attempts: 5, initial_delay: 2)
    .with_fallback(backup_model)
    .prefer_healthy
    .build

  # Logging and observability
  config.enable_logging = true
  config.logging_format = :json

  # Telemetry
  Smolagents::Telemetry::OTelPublisher.new if defined?(OpenTelemetry)

  # Rate limiting
  config.rate_limiter = Smolagents::Concerns::Resilience::RateLimiter.new(
    strategy: :token_bucket,
    tokens_per_minute: 10_000
  )

  # Cost tracking
  Smolagents::CostTracker.new.subscribe_to_events
end
```

**3. Health Check Endpoint**

```ruby
# app/controllers/smolagents/health_controller.rb
module Smolagents
  class HealthController < ApplicationController
    skip_authentication!  # Allow without auth

    def show
      health_status = {
        status: 'healthy',
        models: check_models,
        timestamp: Time.now.iso8601,
        version: Smolagents::VERSION
      }

      render json: health_status, status: any_down?(health_status) ? 503 : 200
    end

    private

    def check_models
      Smolagents.config.models.map do |name, model|
        { name:, status: model.health_check.status }
      end
    end
  end
end

# config/routes.rb
get '/smolagents/health' => 'smolagents/health#show'
```

**4. Cost Tracking Module**

```ruby
# lib/smolagents/production/cost_tracker.rb
module Smolagents::Production
  class CostTracker
    PRICING = {
      'gpt-4' => { input: 0.03 / 1000, output: 0.06 / 1000 },
      'gpt-3.5-turbo' => { input: 0.0005 / 1000, output: 0.0015 / 1000 }
    }.freeze

    def subscribe_to_events
      Smolagents::Events::Emitter.subscribe(:model_generate_completed) do |event|
        cost = calculate(event.model_id, event.input_tokens, event.output_tokens)
        track_cost(cost, event)
      end
    end

    private

    def calculate(model_id, input, output)
      rates = PRICING[model_id] || {}
      (input * rates[:input]) + (output * rates[:output])
    end

    def track_cost(cost, event)
      # Log to analytics service
      # Update user spend
      # Alert if exceeds daily limit
    end
  end
end
```

---

## Summary Table: Implementation Priority

| Pattern | Effort | Impact | Priority |
|---------|--------|--------|----------|
| Rails generator | Medium | High | P1 |
| Multi-source config | Small | High | P1 |
| OpenTelemetry docs | Small | High | P2 |
| Async adapter pattern | Medium | Medium | P2 |
| Error classification | Small | Medium | P2 |
| Production checklist | Small | High | P1 |
| Health check endpoint | Small | High | P2 |
| Cost tracking module | Medium | Medium | P2 |
| Enhanced testing docs | Small | Medium | P2 |
| VCR integration guide | Small | Low | P3 |

---

## Key Takeaways for smolagents-ruby

### Strengths to Maintain
1. **Event-driven architecture** - Already superior to competitors
2. **Builder fluent API** - Clean, immutable, composable
3. **Reliability features** - Circuit breaker, retry, fallback all present
4. **Testing utilities** - MockModel, matchers, scenarios excellent
5. **Type safety** - Data.define throughout

### Quick Wins (< 1 week effort)
1. Add Rails generator for initializers and migrations
2. Document production checklist
3. Create health check endpoint template
4. Document OpenTelemetry integration
5. Add cost tracking example

### Medium-Term (1-2 weeks)
1. Implement multi-source configuration (ENV, YAML, credentials)
2. Create async adapter pattern for Sidekiq/Async
3. Enhance error classification framework
4. Create production configuration templates
5. Improve ActionCable integration docs

### Long-Term (ongoing)
1. Native OpenTelemetry instrumentation (consider building from scratch)
2. Rails plugin gem for easier integration
3. Dashboard for agent monitoring
4. Cost analytics integration
5. Advanced rate limiting strategies

---

## References

### Gems Analyzed
- [LangchainRB](https://github.com/patterns-ai-core/langchainrb) - Unified LLM interface
- [RubyLLM](https://github.com/crmne/ruby_llm) - Multi-provider unified API with Rails integration
- [ruby-openai](https://github.com/alexrudall/ruby-openai) - Official OpenAI SDK
- [Anthropic Ruby SDK](https://github.com/anthropics/anthropic-sdk-ruby) - Official Anthropic SDK
- [FlowNodes](https://github.com/rjrobinson/flownodes) - Graph-based LLM framework

### Industry Patterns Analyzed
- [Anyway Config](https://github.com/palkan/anyway_config) - Configuration gem pattern
- [Dotenv](https://github.com/bkeepers/dotenv) - Environment variable management
- [Retriable](https://github.com/kamui/retriable) - Retry with exponential backoff gem
- [Retryable](https://github.com/nfedyashev/retryable) - Alternative retry gem
- [RSpec Mocks](https://github.com/rspec/rspec-mocks) - Test double framework
- [Mocha](https://github.com/freerange/mocha) - Mocking and stubbing
- [OpenTelemetry Ruby](https://github.com/open-telemetry/opentelemetry-ruby) - Observability standard
- [Prometheus Client](https://github.com/prometheus/client_ruby) - Metrics collection
- [Health Check](https://github.com/Purple-Devs/health_check) - Rails health endpoint gem
- [Async Ruby](https://github.com/socketry/async) - Fiber-based async gem

### Articles and Guides
- [Ruby on Rails AI Integration in 2025: Essential Gems](https://medium.com/@ronakabhattrz/ruby-on-rails-ai-integration-in-2025-essential-gems-and-practical-guide-14496efdf48d)
- [AI in Ruby on Rails: Integrating LLM APIs with Production-Ready Examples](https://rubyroidlabs.com/blog/2025/12/ruby-on-rails-llm-integration-guide/)
- [Async Ruby is the Future of AI Apps](https://paolino.me/async-ruby-is-the-future-of-ai-apps/)
- [How to Build AI Agents with Ruby](https://www.digitalocean.com/community/conceptual-articles/how-to-build-ai-agents-with-ruby)
- [Anyway Config - Keep your Ruby configuration sane](https://evilmartians.com/chronicles/anyway-config-keep-your-ruby-configuration-sane)
- [OpenTelemetry Ruby Documentation](https://opentelemetry.io/docs/languages/ruby/)

---

**Document prepared:** 2026-01-26
**Research scope:** 2024-2025 Ruby gem best practices and patterns
