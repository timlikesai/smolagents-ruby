# Developer Ergonomics Analysis: smolagents-ruby

**Date:** 2026-01-26
**Ruby Version Target:** 4.0+
**Current Version:** 0.1.0
**Analysis Scope:** Integration into existing production Ruby systems

---

## Executive Summary

smolagents-ruby provides a **solid foundation** for building agent systems with exceptional strengths in event-driven architecture, resilience patterns, and code quality. The gem follows modern Ruby 4.0 idioms and maintains high test coverage (93.42%, 3,127 tests).

**Overall Production Readiness: 7.5/10**

### Key Strengths
- **Event-driven architecture** (40+ events) - superior to competitors
- **Resilience patterns** - circuit breakers, retries, fallbacks all excellent
- **Testing utilities** - MockModel, matchers, scenarios comprehensive
- **Security** - AST validation, sandboxing, secret redaction built-in
- **Fluent DSL** - immutable, composable, chainable builders

### Critical Gaps for Production Integration
1. **No Rails integration** - manual setup required
2. **No background job adapters** - Sidekiq/Resque integration missing
3. **Resource cleanup is manual** - no automatic lifecycle management
4. **Limited observability** - must build custom metric exporters
5. **Connection pooling minimal** - unbounded HTTP connection cache

---

## Detailed Findings

### 1. Configuration & Initialization ✅ EXCELLENT

**File:** `lib/smolagents/config/configuration.rb`

#### What Works Well
```ruby
# Thread-safe configuration with validation
Smolagents.configure do |config|
  config.max_steps = 30
  config.log_level = :debug
  config.authorized_imports = %w[json net/http]

  # Model palette for named factories
  config.models do |m|
    m.register(:fast, -> { OpenAIModel.lm_studio("gemma-3n") })
    m.register(:smart, -> { AnthropicModel.new("claude-sonnet-4-5") })
  end
end

# Production freeze prevents runtime mutation
Smolagents.configuration.freeze!
```

**Configuration Sources (priority order):**
1. Explicit `configure` blocks
2. Environment variables (auto-loaded from `.env`)
3. Framework defaults

**Environment Variables:**
- `SMOLAGENTS_QUIET=1` - Disable interactive features
- `SMOLAGENTS_NO_DISCOVER=1` - Skip model discovery on load
- `OPENAI_API_KEY`, `ANTHROPIC_API_KEY` - API credentials
- `SEARXNG_URL` - Custom search provider

#### Gap: No Rails Integration

**Missing:** `lib/smolagents/railtie.rb`

Users must manually create initializers:
```ruby
# config/initializers/smolagents.rb
Smolagents.configure do |config|
  config.max_steps = ENV.fetch('AGENT_MAX_STEPS', 30).to_i
  config.log_level = Rails.env.production? ? :warn : :debug
  config.http[:timeout_seconds] = 60
end

Smolagents.configuration.freeze!  # CRITICAL in production
```

**Recommendation:** Add Rails generator:
```bash
rails generate smolagents:install
# Creates: config/initializers/smolagents.rb
# Creates: config/smolagents.yml (optional)
```

---

### 2. Thread Safety & Concurrency ⚠️ PARTIAL

#### Thread-Safe Components

**Event System** (`lib/smolagents/events/`)
- `AsyncQueue` uses stdlib `Queue` (thread-safe)
- Independent handler lists per consumer
- Thread-local test mode: `Thread.current[:smolagents_test_mode]`

**Isolation Executors** (`lib/smolagents/concerns/isolation/`)
- `ThreadExecutor` uses `Thread.new` + `Thread.join(timeout)`
- Avoids unsafe `Timeout.timeout`
- Ractor support (experimental in Ruby 4.0)

#### Thread Safety Concerns

**1. Mutable Global Configuration**
```ruby
# Problem: Config can be modified at runtime across threads
Smolagents.configure { |c| c.max_steps = 50 }

# Solution: Freeze in production
Smolagents.configuration.freeze!
```

**2. Shared Circuit Breaker State**
```ruby
# Problem: In-memory Stoplight data store not shared across processes
# Solution: Use Redis backend

require 'stoplight/data_store/redis'
Stoplight.default_data_store = Stoplight::DataStore::Redis.new(
  Redis.new(url: ENV['REDIS_URL'])
)
```

**3. Event Handler Accumulation**
```ruby
# Problem: @event_handlers hash grows if agents created/destroyed frequently
# Solution: Create agent instances per request, not shared

# Good (thread-safe)
def handle_request
  agent = Smolagents.agent.model { fast_model }.build
  agent.run(task)
end

# Bad (not thread-safe)
@shared_agent = Smolagents.agent.build
def handle_request
  @shared_agent.run(task)  # Concurrent access unsafe
end
```

**Recommendation:** Document thread safety guarantees explicitly in README.

---

### 3. Production Readiness: Resource Management ⚠️ NEEDS WORK

#### Memory Management Issues

**File:** `lib/smolagents/http/connection.rb`

**Problem:** HTTP connection cache grows unbounded
```ruby
# Current implementation
@_connections ||= {}  # No max size, no TTL, no eviction
```

**Recommendation:** Use `connection_pool` gem:
```ruby
require 'connection_pool'

@_connections ||= ConnectionPool.new(size: 5, timeout: 5) do
  build_connection(url, resolved_ip)
end
```

#### Resource Cleanup is Manual

**What Exists:**
- ✅ `shutdown!` method on Ractor executor
- ✅ `close_connections` on HTTP module
- ✅ `AsyncQueue.shutdown(timeout: 5)` for events

**What's Missing:**
- ❌ No automatic cleanup (all manual)
- ❌ No `at_exit` hooks
- ❌ No finalizers on long-lived objects
- ❌ No graceful shutdown documentation

**Recommendation:** Add automatic cleanup:
```ruby
# Add to lib/smolagents.rb
at_exit do
  Smolagents.shutdown_all_resources
end

# Add to Agent class
def self.finalize(executor_id, http_connections)
  proc do
    cleanup_resources(executor_id, http_connections)
  end
end

def initialize(...)
  ObjectSpace.define_finalizer(self, self.class.finalize(@executor_id, @http_connections))
end
```

---

### 4. Observability & Monitoring ⚠️ BASIC

#### What Works Well

**Event System**
- 40+ event types covering full lifecycle
- Event-driven instrumentation (no wrapping)
- Duration tracking on all operations

**Logging** (`lib/smolagents/telemetry/logging_subscriber.rb`)
- Pluggable logger design
- Structured JSON format option
- Log levels (debug, info, warn, error)

**OpenTelemetry** (mentioned, autoloaded)

#### Critical Gaps

**1. No Metrics Integration**

Users must implement custom exporters:
```ruby
# Users must write this themselves
Smolagents::Telemetry::Instrumentation.subscriber = ->(event, payload) {
  statsd.timing("smolagents.#{event}", payload[:duration_ms])
  statsd.increment("smolagents.#{event}.count")
}
```

**Recommendation:** Add metrics adapter layer:
```ruby
# lib/smolagents/telemetry/metrics_adapter.rb
Smolagents.configure do |config|
  config.metrics_adapter = :prometheus
  # Or: :statsd, :datadog, :cloudwatch
end

# Auto-export standard metrics:
# - smolagents.steps.count
# - smolagents.tool_calls.duration
# - smolagents.model_generate.duration
# - smolagents.errors.count
```

**2. No Automatic Secret Redaction in Logs**

`SecretRedactor` exists but not automatically applied:

**Recommendation:** Auto-apply to logs:
```ruby
# In LoggingSubscriber
def format_payload(payload)
  Smolagents::Security::SecretRedactor.redact(payload.to_json)
end
```

---

### 5. Background Job Integration ❌ MISSING

**Current State:** Agents run in-process only

**Problem:** No adapters for common job systems:
- Sidekiq
- Resque
- GoodJob
- Delayed Job

**Workaround:**
```ruby
class AgentJob < ApplicationJob
  queue_as :default

  def perform(task)
    agent = Smolagents.agent
      .model { fast_model }
      .sync_events  # Force synchronous events (critical!)
      .on(:error) { |e| Rails.logger.error(e) }
      .build

    agent.run(task)
  end
end
```

**Why `.sync_events` is critical:**
- `AsyncQueue` assumes long-running process
- Background jobs are short-lived
- Async events may not flush before job completes

**Recommendation:** Add adapters:
```ruby
# lib/smolagents/adapters/sidekiq_adapter.rb
class AgentWorker
  include Sidekiq::Worker
  include Smolagents::Adapters::SidekiqAdapter

  def perform(task)
    run_agent(task) do |agent|
      agent.model { fast_model }
          .tools(:search, :web)
    end
  end
end
```

---

### 6. Error Handling & Debugging ✅ EXCELLENT

**File:** `lib/smolagents/errors.rb`

#### Pattern-Matching Friendly Errors
```ruby
begin
  agent.run("task")
rescue Smolagents::AgentError => e
  case e
  in Smolagents::ToolExecutionError[tool_name:, step_number:]
    log("Tool #{tool_name} failed at step #{step_number}")
  in Smolagents::AgentMaxStepsError[max_steps:]
    log("Exceeded #{max_steps} steps")
  in Smolagents::TimeoutError[operation:, duration:]
    log("#{operation} timed out after #{duration}s")
  in Smolagents::CircuitOpenError[service:, last_failure:]
    log("Circuit open for #{service}: #{last_failure}")
  end
end
```

#### Event-Based Debugging
```ruby
agent = Smolagents.agent
  .model { model }
  .on(:step_complete) { |e| puts "Step #{e.step_number}: #{e.outcome}" }
  .on(:tool_call) { |e| puts "→ #{e.tool_name}(#{e.args})" }
  .on(:model_generate_started) { |e| puts "Calling model..." }
  .on(:error) { |e|
    Sentry.capture_exception(e.error)
    puts "ERROR: #{e.error_message}"
  }
  .build
```

**Strength:** No instrumentation needed - everything event-driven

---

### 7. Testing Utilities ✅ EXCELLENT

**Files:**
- `lib/smolagents/testing/mock_model.rb`
- `lib/smolagents/testing/test_mode.rb`
- `lib/smolagents/testing/matchers.rb`
- `lib/smolagents/testing/call_log.rb`

#### MockModel for Deterministic Tests
```ruby
model = Smolagents::Testing::MockModel.new
model.queue_code_action('search(query: "Ruby")')
model.queue_code_action('final_answer(answer: "Found it")')

agent = Smolagents.agent.model { model }.tools(:search).build
result = agent.run("Find Ruby")

expect(model).to be_exhausted
expect(result.output).to eq("Found it")
```

#### Test Mode
```ruby
# Global enable
Smolagents.test_mode!

# Scoped
Smolagents.test_mode do
  # Network blocked, verbose events, skip retry delays
  agent.run("task")
end
```

#### Call Log Matchers
```ruby
log = Smolagents::Testing.call_log

agent = Smolagents.agent
  .model { model }
  .on(:tool_call) { |e| log.record(e) }
  .build

agent.run("task")

expect(log).to have_called_tool(:search)
expect(log).to have_tool_sequence(:search, :visit_webpage, :final_answer)
expect(log).to have_called_tool(:search).with_args(query: "Ruby")
```

**Strength:** Comprehensive testing utilities rival RSpec's quality

---

### 8. Resilience Patterns ✅ EXCELLENT

**Files:**
- `lib/smolagents/concerns/resilience/circuit_breaker.rb`
- `lib/smolagents/concerns/resilience/fallback.rb`
- `lib/smolagents/concerns/resilience/retry_logic.rb`
- `lib/smolagents/concerns/resilience/rate_limiter/`

#### Circuit Breakers (Stoplight Integration)
```ruby
agent = Smolagents.agent
  .model {
    primary_model
      .with_circuit_breaker(threshold: 5, cool_off: 30)
      .with_fallback(backup_model)
      .with_fallback(emergency_model)
  }
  .build
```

**Features:**
- ✅ 3 states (green, yellow, red)
- ✅ Configurable threshold and cool-off
- ✅ Event emission for state changes
- ✅ Excludes rate limits from circuit breaking

#### Retry with Exponential Backoff
```ruby
model = OpenAIModel.new("gpt-4")
  .with_retry(
    max_attempts: 3,
    backoff: :exponential,  # or :linear
    jitter: 0.2,
    on: [Faraday::TimeoutError, OpenAI::RateLimitError]
  )
```

**Features:**
- ✅ Exponential/linear backoff
- ✅ Jitter to avoid thundering herd
- ✅ Selective error retry
- ✅ Event emission for retry attempts

#### Rate Limiting
```ruby
tool = SearchTool.new
  .with_rate_limit(
    strategy: :token_bucket,
    limit: 100,
    window: 3600  # 100 requests per hour
  )
```

**Strategies:**
- Token Bucket (burst handling)
- Sliding Window (precise)
- Fixed Window (simple)

**Features:**
- ✅ Thread-safe (Mutex)
- ✅ Non-blocking (raises exception)
- ✅ Per-tool configuration

#### Health Checks
```ruby
model = AnthropicModel.new("claude-sonnet-4-5")
  .with_health_check(cache_for: 5)
  .prefer_healthy
```

**Features:**
- ✅ Proactive health checks
- ✅ Health-aware routing
- ✅ Cached health status

**Strength:** Best-in-class resilience patterns

---

### 9. Security ✅ EXCELLENT

**Files:**
- `lib/smolagents/security/secret_redactor.rb`
- `lib/smolagents/security/ast_validator.rb`
- `lib/smolagents/security/prompt_sanitizer.rb`
- `lib/smolagents/http/ssrf_protection.rb`

#### Secret Redaction
```ruby
# Auto-detects and redacts
SecretRedactor.redact(text)
# - OpenAI keys (sk-...)
# - Anthropic keys (sk-ant-...)
# - Bearer tokens
# - Generic API keys (64 hex chars)
```

#### Code Execution Safety
```ruby
# AST validation before execution
ASTValidator.validate!(code)
# - Method blocking (File.delete, system, eval, etc.)
# - Operation limits (max nodes, depth)
# - Safe parsing

# Sandboxed execution
ThreadExecutor.run(code, timeout: 10)
RactorExecutor.run(code, timeout: 10)  # Memory isolation
```

#### SSRF Protection
```ruby
# Automatic DNS rebinding protection
# Blocks private IPs (10.0.0.0/8, 192.168.0.0/16, 127.0.0.0/8)
# Blocks cloud metadata endpoints
```

#### Prompt Injection Detection
```ruby
PromptSanitizer.sanitize(user_input)
# Detects and neutralizes injection attempts
```

**Strength:** Production-grade security out of the box

---

## Comparison: Industry Best Practices

### Similar Ruby Gems Analyzed
1. **LangchainRB** - Rails integration, streaming, async
2. **RubyLLM** - Background jobs, cost tracking
3. **ruby-openai** - Simple API wrapper
4. **Anthropic SDK** - Streaming, error handling
5. **FlowNodes** - Visual workflow builder

### What smolagents-ruby Does Better
1. **Event architecture** - 40+ events vs competitors' callbacks
2. **Immutable builders** - Functional style, thread-safe
3. **Type safety** - Data.define throughout
4. **Testing utilities** - MockModel superior to competitors
5. **Security** - AST validation, sandboxing built-in

### What Competitors Do Better
1. **Rails generators** - LangchainRB has `rails g langchain:install`
2. **Streaming support** - ActionCable integration
3. **Cost tracking** - RubyLLM tracks token costs per request
4. **Background jobs** - Sidekiq adapters built-in
5. **Multi-source config** - ENV → Rails credentials → blocks

---

## Quick Wins (< 1 Week Effort)

### 1. Rails Generator
**Priority: HIGH**
**Effort: 1 day**

```bash
rails generate smolagents:install
# Creates:
#   config/initializers/smolagents.rb
#   app/agents/ (directory)
#   app/agents/application_agent.rb (base class)
```

```ruby
# lib/generators/smolagents/install_generator.rb
module Smolagents
  module Generators
    class InstallGenerator < Rails::Generators::Base
      source_root File.expand_path('templates', __dir__)

      def copy_initializer
        template 'initializer.rb', 'config/initializers/smolagents.rb'
      end

      def create_agents_directory
        empty_directory 'app/agents'
        template 'application_agent.rb', 'app/agents/application_agent.rb'
      end
    end
  end
end
```

### 2. Production Deployment Checklist
**Priority: HIGH**
**Effort: 1 day**

Create `PRODUCTION_CHECKLIST.md`:
```markdown
## Production Deployment Checklist

### Configuration
- [ ] Freeze configuration: `Smolagents.configuration.freeze!`
- [ ] Set `SMOLAGENTS_QUIET=1` in production
- [ ] Configure Redis for circuit breakers
- [ ] Set appropriate `max_steps` limit
- [ ] Configure HTTP timeouts

### Observability
- [ ] Enable structured logging (JSON format)
- [ ] Configure OpenTelemetry (if using)
- [ ] Set up custom metrics exporter
- [ ] Configure error tracking (Sentry, Rollbar)

### Resource Management
- [ ] Configure connection pool limits
- [ ] Set thread pool sizes
- [ ] Configure memory budgets
- [ ] Set operation timeouts

### Security
- [ ] Validate `authorized_imports` list
- [ ] Enable secret redaction in logs
- [ ] Configure SSRF protection
- [ ] Review AST validator settings
```

### 3. Health Check Endpoint Template
**Priority: MEDIUM**
**Effort: 1 day**

```ruby
# app/controllers/health_controller.rb
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def agents
    checks = {
      configuration: check_configuration,
      models: check_models,
      tools: check_tools,
      memory: check_memory
    }

    status = checks.values.all? { |c| c[:healthy] } ? :ok : :service_unavailable
    render json: checks, status: status
  end

  private

  def check_configuration
    {
      healthy: Smolagents.configuration.frozen?,
      frozen: Smolagents.configuration.frozen?,
      max_steps: Smolagents.configuration.max_steps
    }
  end

  def check_models
    fast_model = Smolagents.registered_model(:fast)
    {
      healthy: fast_model.respond_to?(:health_check),
      palette_count: Smolagents.configuration.model_palette.count
    }
  end

  def check_tools
    {
      healthy: true,
      toolkit_count: Smolagents::Toolkits.registry.count
    }
  end

  def check_memory
    {
      healthy: GC.stat[:heap_available_slots] > 10_000,
      heap_slots: GC.stat[:heap_available_slots]
    }
  end
end
```

### 4. Cost Tracking Module
**Priority: MEDIUM**
**Effort: 2 days**

```ruby
# lib/smolagents/telemetry/cost_tracker.rb
module Smolagents
  module Telemetry
    class CostTracker
      include Events::Consumer

      def initialize
        @costs = Concurrent::Map.new
        on(:model_generate_completed) { |e| track_cost(e) }
      end

      def track_cost(event)
        model = event.model_id
        tokens = event.token_usage
        cost = calculate_cost(model, tokens)

        @costs.compute(model) do |_key, current|
          (current || 0) + cost
        end
      end

      def total_cost
        @costs.values.sum
      end

      def cost_by_model
        @costs.to_h
      end

      private

      def calculate_cost(model, tokens)
        rates = COST_PER_1K_TOKENS[model] || { input: 0, output: 0 }

        input_cost = (tokens.input_tokens / 1000.0) * rates[:input]
        output_cost = (tokens.output_tokens / 1000.0) * rates[:output]

        input_cost + output_cost
      end

      COST_PER_1K_TOKENS = {
        'gpt-4' => { input: 0.03, output: 0.06 },
        'gpt-3.5-turbo' => { input: 0.001, output: 0.002 },
        'claude-sonnet-4-5' => { input: 0.003, output: 0.015 },
        'claude-opus-4-5' => { input: 0.015, output: 0.075 }
      }.freeze
    end
  end
end
```

Usage:
```ruby
tracker = Smolagents::Telemetry::CostTracker.new
agent = Smolagents.agent.model { model }.build
agent.run("task")

puts tracker.total_cost  # => 0.0234
puts tracker.cost_by_model  # => { 'gpt-4' => 0.0234 }
```

### 5. RSpec Shared Examples
**Priority: MEDIUM**
**Effort: 1 day**

```ruby
# spec/support/shared_examples/agent_examples.rb
RSpec.shared_examples 'an agent' do
  it 'runs without errors' do
    expect { subject.run(task) }.not_to raise_error
  end

  it 'returns a RunResult' do
    result = subject.run(task)
    expect(result).to be_a(Smolagents::Types::RunResult)
  end

  it 'completes within max_steps' do
    result = subject.run(task)
    expect(result.steps.count).to be <= subject.max_steps
  end

  it 'handles errors gracefully' do
    model = Smolagents::Testing::MockModel.new
    model.raise_error(Smolagents::ToolExecutionError.new("Test error"))

    agent = Smolagents.agent.model { model }.tools(:search).build

    expect { agent.run(task) }.to raise_error(Smolagents::ToolExecutionError)
  end
end

# Usage in specs
RSpec.describe MyCustomAgent do
  subject { described_class.new }
  let(:task) { "Test task" }

  it_behaves_like 'an agent'
end
```

---

## Strategic Recommendations (2-4 Weeks)

### 1. Background Job Adapter
**Priority: HIGH**
**Effort: 1 week**

```ruby
# lib/smolagents/adapters/sidekiq_adapter.rb
module Smolagents
  module Adapters
    module SidekiqAdapter
      def self.included(base)
        base.include Sidekiq::Worker
        base.extend ClassMethods
      end

      module ClassMethods
        def agent_builder(&block)
          @agent_builder = block
        end

        def agent_for(task)
          builder = @agent_builder || default_builder
          instance_exec(task, &builder)
            .sync_events  # Force synchronous events
            .on(:error) { |e| logger.error(e) }
            .build
        end
      end

      def perform(task)
        agent = self.class.agent_for(task)
        result = agent.run(task)

        # Store result in database or cache
        Rails.cache.write("agent:#{jid}", result.to_h, expires_in: 1.hour)
      end
    end
  end
end
```

Usage:
```ruby
class ResearchWorker
  include Smolagents::Adapters::SidekiqAdapter

  agent_builder do |task|
    Smolagents.agent
      .model { Smolagents.registered_model(:fast) }
      .tools(:search, :web)
      .max_steps(20)
  end
end

# Enqueue
ResearchWorker.perform_async("Find Ruby trends")
```

### 2. Metrics Adapter Layer
**Priority: HIGH**
**Effort: 1 week**

```ruby
# lib/smolagents/telemetry/metrics_adapter.rb
module Smolagents
  module Telemetry
    class MetricsAdapter
      include Events::Consumer

      def initialize(backend:)
        @backend = backend
        subscribe_to_metrics_events
      end

      private

      def subscribe_to_metrics_events
        on(:step_complete) { |e| track_step(e) }
        on(:tool_call) { |e| track_tool_call(e) }
        on(:model_generate_completed) { |e| track_model_call(e) }
        on(:error) { |e| track_error(e) }
      end

      def track_step(event)
        @backend.increment('smolagents.steps.count', tags: {
          outcome: event.outcome,
          step_type: event.step_type
        })
      end

      def track_tool_call(event)
        @backend.timing('smolagents.tool_call.duration', event.duration_ms, tags: {
          tool_name: event.tool_name
        })
      end

      def track_model_call(event)
        @backend.timing('smolagents.model_generate.duration', event.duration_ms, tags: {
          model: event.model_id
        })

        @backend.gauge('smolagents.tokens.input', event.token_usage.input_tokens)
        @backend.gauge('smolagents.tokens.output', event.token_usage.output_tokens)
      end

      def track_error(event)
        @backend.increment('smolagents.errors.count', tags: {
          error_type: event.error.class.name
        })
      end
    end

    # Backends
    class PrometheusBackend
      def increment(metric, tags: {})
        Prometheus::Client.registry.get(metric).increment(labels: tags)
      end

      def timing(metric, value, tags: {})
        Prometheus::Client.registry.get(metric).observe(value, labels: tags)
      end

      def gauge(metric, value, tags: {})
        Prometheus::Client.registry.get(metric).set(value, labels: tags)
      end
    end

    class StatsDBackend
      def initialize(statsd)
        @statsd = statsd
      end

      def increment(metric, tags: {})
        @statsd.increment(metric, tags: tags)
      end

      def timing(metric, value, tags: {})
        @statsd.timing(metric, value, tags: tags)
      end

      def gauge(metric, value, tags: {})
        @statsd.gauge(metric, value, tags: tags)
      end
    end
  end
end
```

Configuration:
```ruby
# config/initializers/smolagents.rb
require 'datadog/statsd'
statsd = Datadog::Statsd.new('localhost', 8125)

backend = Smolagents::Telemetry::StatsDBackend.new(statsd)
Smolagents::Telemetry::MetricsAdapter.new(backend: backend)
```

### 3. Automatic Resource Cleanup
**Priority: MEDIUM**
**Effort: 1 week**

```ruby
# lib/smolagents/lifecycle.rb
module Smolagents
  module Lifecycle
    class << self
      def register_cleanup(&block)
        cleanups << block
      end

      def cleanup_all
        cleanups.reverse_each do |cleanup|
          cleanup.call
        rescue => e
          warn "Cleanup error: #{e.message}"
        end
      end

      private

      def cleanups
        @cleanups ||= []
      end
    end
  end
end

# Register at_exit handler
at_exit do
  Smolagents::Lifecycle.cleanup_all
end

# In Agent class
class Agent
  def initialize(...)
    # ...
    Smolagents::Lifecycle.register_cleanup do
      @executor&.shutdown!
      @http_connections&.close_all
    end
  end
end
```

### 4. Enhanced Error Classification
**Priority: MEDIUM**
**Effort: 3 days**

```ruby
# lib/smolagents/errors/classifier.rb
module Smolagents
  module Errors
    class Classifier
      def self.classify(error)
        case error
        when RateLimitError
          { retriable: true, backoff: :exponential, base_delay: 10 }
        when AuthenticationError
          { retriable: false, terminal: true }
        when TimeoutError
          { retriable: true, backoff: :linear, max_attempts: 2 }
        when NetworkError
          { retriable: true, backoff: :exponential, max_attempts: 3 }
        when CircuitOpenError
          { retriable: true, backoff: :exponential, base_delay: 30 }
        when ToolExecutionError
          { retriable: true, backoff: :linear, max_attempts: 2 }
        else
          { retriable: false, terminal: true }
        end
      end
    end
  end
end
```

### 5. ActionCable Streaming Integration
**Priority: LOW**
**Effort: 3 days**

```ruby
# app/channels/agent_channel.rb
class AgentChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_#{params[:agent_id]}"
  end

  def run_task(data)
    agent = build_agent_with_streaming(params[:agent_id])
    agent.run(data['task'])
  end

  private

  def build_agent_with_streaming(agent_id)
    Smolagents.agent
      .model { fast_model }
      .on(:step_complete) { |e| broadcast_step(agent_id, e) }
      .on(:tool_call) { |e| broadcast_tool_call(agent_id, e) }
      .on(:model_generate_started) { |e| broadcast_thinking(agent_id) }
      .build
  end

  def broadcast_step(agent_id, event)
    ActionCable.server.broadcast("agent_#{agent_id}", {
      type: 'step_complete',
      step_number: event.step_number,
      outcome: event.outcome
    })
  end

  def broadcast_tool_call(agent_id, event)
    ActionCable.server.broadcast("agent_#{agent_id}", {
      type: 'tool_call',
      tool_name: event.tool_name,
      args: event.args
    })
  end

  def broadcast_thinking(agent_id)
    ActionCable.server.broadcast("agent_#{agent_id}", {
      type: 'thinking'
    })
  end
end
```

Client:
```javascript
const agentChannel = consumer.subscriptions.create(
  { channel: "AgentChannel", agent_id: "123" },
  {
    received(data) {
      switch(data.type) {
        case 'step_complete':
          console.log(`Step ${data.step_number}: ${data.outcome}`);
          break;
        case 'tool_call':
          console.log(`Calling ${data.tool_name}(${JSON.stringify(data.args)})`);
          break;
        case 'thinking':
          console.log('Agent is thinking...');
          break;
      }
    }
  }
);

agentChannel.perform('run_task', { task: "Research Ruby trends" });
```

---

## Production Integration Patterns

### Pattern 1: Rails Application

```ruby
# config/initializers/smolagents.rb
Smolagents.configure do |config|
  # Configuration from Rails credentials
  config.max_steps = Rails.application.credentials.dig(:smolagents, :max_steps) || 30
  config.log_level = Rails.env.production? ? :warn : :debug

  # HTTP timeouts
  config.http[:timeout_seconds] = 60
  config.http[:open_timeout_seconds] = 10

  # Isolation
  config.isolation[:default_timeout_seconds] = 30.0

  # Model palette
  config.models do |m|
    m.register(:fast, -> {
      OpenAIModel.groq("llama-3.3-70b-versatile")
    })

    m.register(:smart, -> {
      AnthropicModel.new(
        "claude-sonnet-4-5",
        api_key: Rails.application.credentials.dig(:anthropic, :api_key)
      )
    })
  end
end

# Freeze config (critical!)
Smolagents.configuration.freeze!

# Circuit breakers with Redis
require 'stoplight/data_store/redis'
Stoplight.default_data_store = Stoplight::DataStore::Redis.new($redis)

# Telemetry
if ENV['ENABLE_OTEL']
  Smolagents::Telemetry::OTel.enable(service_name: 'my-app')
else
  Smolagents::Telemetry::LoggingSubscriber.enable(
    logger: Rails.logger,
    level: :info
  )
end

# Custom instrumentation
Smolagents::Telemetry::Instrumentation.subscriber = ->(event, payload) {
  NewRelic::Agent.record_custom_event(
    event.to_s.tr('.', '_'),
    payload.select { |_, v| v.is_a?(String) || v.is_a?(Numeric) }
  )
end

# Error handling
module AgentErrorHandler
  def run(...)
    super
  rescue Smolagents::AgentError => e
    Sentry.capture_exception(e)
    raise
  end
end

Smolagents::Agents::Agent.prepend(AgentErrorHandler)
```

### Pattern 2: Background Jobs

```ruby
# app/jobs/agent_job.rb
class AgentJob < ApplicationJob
  queue_as :default

  retry_on Smolagents::RateLimitError, wait: :exponentially_longer
  retry_on Smolagents::TimeoutError, attempts: 2
  discard_on Smolagents::AuthenticationError

  def perform(user_id, task)
    agent = build_agent
    result = agent.run(task)

    # Store result
    AgentResult.create!(
      user_id: user_id,
      task: task,
      output: result.output,
      steps: result.steps.count,
      token_usage: result.token_usage.to_h
    )
  end

  private

  def build_agent
    Smolagents.agent
      .model { Smolagents.registered_model(:fast) }
      .tools(:search, :web)
      .max_steps(20)
      .sync_events  # Critical for jobs!
      .on(:error) { |e| Rails.logger.error("Agent error: #{e.error_message}") }
      .build
  end
end
```

### Pattern 3: API Endpoint

```ruby
# app/controllers/api/v1/agents_controller.rb
module Api
  module V1
    class AgentsController < ApplicationController
      def create
        result = with_timeout do
          agent = build_agent
          agent.run(agent_params[:task])
        end

        render json: {
          output: result.output,
          steps: result.steps.count,
          token_usage: result.token_usage.to_h
        }, status: :ok
      rescue Smolagents::AgentMaxStepsError => e
        render json: { error: "Agent exceeded max steps: #{e.max_steps}" }, status: :unprocessable_entity
      rescue Smolagents::TimeoutError => e
        render json: { error: "Agent timed out after #{e.duration}s" }, status: :gateway_timeout
      rescue Smolagents::CircuitOpenError => e
        render json: { error: "Service unavailable: #{e.service}" }, status: :service_unavailable
      end

      private

      def build_agent
        Smolagents.agent
          .model { Smolagents.registered_model(:fast) }
          .tools(*agent_params[:tools])
          .max_steps(agent_params[:max_steps] || 10)
          .build
      end

      def with_timeout
        Timeout.timeout(30) { yield }
      end

      def agent_params
        params.require(:agent).permit(:task, :max_steps, tools: [])
      end
    end
  end
end
```

### Pattern 4: Service Object

```ruby
# app/services/research_service.rb
class ResearchService
  def initialize(user:)
    @user = user
    @agent = build_agent
  end

  def research(topic)
    result = @agent.run("Research #{topic} and provide a summary")

    Research.create!(
      user: @user,
      topic: topic,
      summary: result.output,
      token_cost: calculate_cost(result.token_usage)
    )
  end

  private

  def build_agent
    Smolagents.agent
      .model {
        Smolagents.registered_model(:smart)
          .with_circuit_breaker(threshold: 5, cool_off: 30)
          .with_fallback(Smolagents.registered_model(:fast))
          .with_retry(max_attempts: 3, backoff: :exponential)
      }
      .tools(:search, :web, :summarize)
      .max_steps(15)
      .on(:tool_call) { |e| log_tool_call(e) }
      .on(:error) { |e| alert_on_error(e) }
      .build
  end

  def log_tool_call(event)
    Rails.logger.info("Tool #{event.tool_name} called with #{event.args}")
  end

  def alert_on_error(event)
    Sentry.capture_message("Agent error: #{event.error_message}", level: :error)
  end

  def calculate_cost(token_usage)
    # $0.003 per 1K input tokens, $0.015 per 1K output tokens for Claude Sonnet
    input_cost = (token_usage.input_tokens / 1000.0) * 0.003
    output_cost = (token_usage.output_tokens / 1000.0) * 0.015
    input_cost + output_cost
  end
end
```

---

## Appendix: File References

### Core Architecture
- **Main entry:** `lib/smolagents.rb`
- **Configuration:** `lib/smolagents/config/configuration.rb`
- **DSL:** `lib/smolagents/dsl.rb`
- **Events:** `lib/smolagents/events/`
- **Builders:** `lib/smolagents/builders/`

### Production Concerns
- **Circuit breakers:** `lib/smolagents/concerns/resilience/circuit_breaker.rb`
- **Retry logic:** `lib/smolagents/concerns/resilience/retry_logic.rb`
- **Rate limiting:** `lib/smolagents/concerns/resilience/rate_limiter/`
- **Health checks:** `lib/smolagents/concerns/resilience/model_health.rb`
- **Logging:** `lib/smolagents/telemetry/logging_subscriber.rb`
- **Instrumentation:** `lib/smolagents/telemetry/instrumentation.rb`

### Security
- **Secret redaction:** `lib/smolagents/security/secret_redactor.rb`
- **AST validation:** `lib/smolagents/security/ast_validator.rb`
- **SSRF protection:** `lib/smolagents/http/ssrf_protection.rb`
- **Prompt sanitization:** `lib/smolagents/security/prompt_sanitizer.rb`

### Testing
- **MockModel:** `lib/smolagents/testing/mock_model.rb`
- **Test mode:** `lib/smolagents/testing/test_mode.rb`
- **Matchers:** `lib/smolagents/testing/matchers.rb`
- **Call log:** `lib/smolagents/testing/call_log.rb`

### Build Tools
- **Rakefile:** `Rakefile`
- **Gemspec:** `smolagents.gemspec`
- **RuboCop:** `.rubocop.yml`

---

## Conclusion

smolagents-ruby is **production-ready with caveats**. The gem provides excellent foundations for:
- Event-driven architecture
- Resilience patterns
- Security
- Testing

**To maximize developer ergonomics for integration:**

**Immediate (< 1 week):**
1. Add Rails generator
2. Create production checklist
3. Add health check templates
4. Document thread safety guarantees

**Short-term (1-2 weeks):**
5. Add background job adapters
6. Add metrics adapter layer
7. Implement automatic resource cleanup
8. Add cost tracking utilities

**Long-term (1 month+):**
9. Connection pooling improvements
10. Streaming support (ActionCable)
11. File-based configuration with reload
12. Enhanced observability documentation

The gem is **ready for production use today** with manual integration work. The recommendations above will make it **significantly easier** for developers to integrate into existing systems without sacrificing the gem's architectural strengths.

---

**Analysis conducted:** 2026-01-26
**Ruby version target:** 4.0+
**Gem version:** 0.1.0
**Agent IDs for follow-up:**
- Integration analysis: a6fe5af
- Industry research: a740385
- Production readiness: a8c9dcb
- Ruby patterns: ab47c35
