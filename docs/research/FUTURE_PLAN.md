# Future Development Plan: smolagents-ruby

**Last Updated:** 2026-01-27
**Current Version:** 0.1.0
**Target Ruby:** 4.0+

---

## Overview

This document outlines planned enhancements to improve smolagents-ruby's developer ergonomics for integration into production systems. All recommendations maintain the gem's architectural principles: event-driven design, immutable builders, and minimal dependencies.

**Note:** Rails-specific integration (generators, Railtie) is tracked separately and not included in this plan.

---

## Priority Matrix

| Priority | Timeline | Focus Area |
|----------|----------|------------|
| **P0 - Critical** | < 1 week | Production deployment, documentation |
| **P1 - High** | 1-2 weeks | Background jobs, observability |
| **P2 - Medium** | 2-4 weeks | Resource management, error handling |
| **P3 - Low** | 1-2 months | Streaming, advanced features |

---

## P0: Quick Wins (< 1 Week)

### 1. Production Deployment Checklist

**Priority:** P0
**Effort:** 1 day
**Owner:** TBD
**Status:** Not Started

Create `PRODUCTION_CHECKLIST.md` with verification steps for production deployments.

**Implementation:**

```markdown
## Production Deployment Checklist

### Configuration
- [ ] Freeze configuration: `Smolagents.configuration.freeze!`
- [ ] Set `SMOLAGENTS_QUIET=1` in production
- [ ] Configure Redis for circuit breakers (multi-process deployments)
- [ ] Set appropriate `max_steps` limit (default: 30)
- [ ] Configure HTTP timeouts (default: 60s)
- [ ] Configure isolation timeouts (default: 10s)

### Observability
- [ ] Enable structured logging (JSON format in production)
- [ ] Configure OpenTelemetry (optional)
- [ ] Set up custom metrics exporter
- [ ] Configure error tracking (Sentry, Rollbar, Honeybadger)
- [ ] Enable secret redaction in logs

### Resource Management
- [ ] Configure connection pool limits
- [ ] Set thread pool sizes
- [ ] Configure memory budgets
- [ ] Set operation timeouts
- [ ] Review `authorized_imports` list

### Security
- [ ] Validate `authorized_imports` whitelist
- [ ] Enable secret redaction in logs
- [ ] Configure SSRF protection
- [ ] Review AST validator settings
- [ ] Audit tool permissions

### Multi-Process Environments
- [ ] Use Redis backend for Stoplight circuit breakers
- [ ] Verify configuration freeze prevents runtime mutation
- [ ] Test agent instance creation per request (not shared)

### Testing
- [ ] Run full test suite: `rake spec`
- [ ] Run CI pipeline: `rake ci`
- [ ] Test with production-like data
- [ ] Verify error handling paths
- [ ] Load test critical endpoints
```

**Files Created:**
- `PRODUCTION_CHECKLIST.md`

---

### 2. Thread Safety Documentation

**Priority:** P0
**Effort:** 1 day
**Owner:** TBD
**Status:** Not Started

Document thread safety guarantees and best practices in README and API docs.

**Content Required:**

1. **Thread-Safe Components**
   - Event system (AsyncQueue, handlers)
   - Isolation executors (Thread, Ractor)
   - Configuration (when frozen)

2. **Thread Safety Concerns**
   - Mutable global configuration
   - Shared circuit breaker state (needs Redis)
   - Event handler accumulation
   - Shared agent instances

3. **Best Practices**
   ```ruby
   # ✅ Good: Create agent per request
   def handle_request
     agent = Smolagents.agent.model { fast_model }.build
     agent.run(task)
   end

   # ❌ Bad: Share agent across threads
   @shared_agent = Smolagents.agent.build
   def handle_request
     @shared_agent.run(task)  # Unsafe!
   end
   ```

4. **Multi-Process Setup**
   ```ruby
   # Circuit breakers with Redis
   require 'stoplight/data_store/redis'
   Stoplight.default_data_store = Stoplight::DataStore::Redis.new(
     Redis.new(url: ENV['REDIS_URL'])
   )

   # Freeze configuration
   Smolagents.configuration.freeze!
   ```

**Files Modified:**
- `README.md` - Add "Thread Safety" section
- `lib/smolagents/config/configuration.rb` - Add YARD docs
- `lib/smolagents/agents/agent.rb` - Add thread safety notes

---

### 3. Health Check Endpoint Template

**Priority:** P0
**Effort:** 1 day
**Owner:** TBD
**Status:** Not Started

Provide a copy-paste template for health check endpoints in web applications.

**Implementation:**

```ruby
# app/controllers/health_controller.rb
# Or: lib/health_check/smolagents_check.rb (for health_check gem)

class SmolagentsHealthCheck
  def self.check
    checks = {
      configuration: check_configuration,
      models: check_models,
      tools: check_tools,
      memory: check_memory,
      circuit_breakers: check_circuit_breakers
    }

    {
      healthy: checks.values.all? { |c| c[:healthy] },
      checks: checks
    }
  end

  def self.check_configuration
    {
      healthy: Smolagents.configuration.frozen?,
      frozen: Smolagents.configuration.frozen?,
      max_steps: Smolagents.configuration.max_steps,
      log_level: Smolagents.configuration.log_level
    }
  end

  def self.check_models
    palette_count = Smolagents.configuration.model_palette.count
    {
      healthy: palette_count > 0,
      palette_count: palette_count,
      registered_models: Smolagents.configuration.model_palette.keys
    }
  end

  def self.check_tools
    {
      healthy: true,
      toolkit_count: Smolagents::Toolkits.registry.count,
      available_toolkits: Smolagents::Toolkits.registry.keys
    }
  end

  def self.check_memory
    heap_slots = GC.stat[:heap_available_slots]
    {
      healthy: heap_slots > 10_000,
      heap_slots: heap_slots,
      gc_count: GC.count
    }
  end

  def self.check_circuit_breakers
    # If using Stoplight with Redis
    data_store = Stoplight::DataStore::Redis.new($redis)
    {
      healthy: data_store.respond_to?(:ping) ? data_store.ping : true,
      backend: data_store.class.name
    }
  rescue => e
    { healthy: false, error: e.message }
  end
end

# Rails Controller
class HealthController < ApplicationController
  skip_before_action :authenticate_user!

  def agents
    result = SmolagentsHealthCheck.check
    status = result[:healthy] ? :ok : :service_unavailable
    render json: result, status: status
  end
end
```

**Files Created:**
- `examples/health_check_template.rb`
- Documentation in README

---

### 4. Cost Tracking Module

**Priority:** P0
**Effort:** 2 days
**Owner:** TBD
**Status:** Not Started

Provide event-based cost tracking for LLM API usage.

**Implementation:**

```ruby
# lib/smolagents/telemetry/cost_tracker.rb
module Smolagents
  module Telemetry
    class CostTracker
      include Events::Consumer

      def initialize(cost_table: COST_PER_1K_TOKENS)
        @costs = Concurrent::Map.new
        @cost_table = cost_table
        on(:model_generate_completed) { |e| track_cost(e) }
      end

      def track_cost(event)
        model = event.model_id
        tokens = event.token_usage
        cost = calculate_cost(model, tokens)

        @costs.compute(model) do |_key, current|
          (current || 0.0) + cost
        end
      end

      def total_cost
        @costs.values.sum
      end

      def cost_by_model
        @costs.to_h
      end

      def reset!
        @costs.clear
      end

      private

      def calculate_cost(model, tokens)
        rates = @cost_table[model] || @cost_table[:default]

        input_cost = (tokens.input_tokens / 1000.0) * rates[:input]
        output_cost = (tokens.output_tokens / 1000.0) * rates[:output]

        input_cost + output_cost
      end

      # Pricing as of January 2025 (USD per 1K tokens)
      COST_PER_1K_TOKENS = {
        'gpt-4' => { input: 0.03, output: 0.06 },
        'gpt-4-turbo' => { input: 0.01, output: 0.03 },
        'gpt-3.5-turbo' => { input: 0.001, output: 0.002 },
        'claude-opus-4-5' => { input: 0.015, output: 0.075 },
        'claude-sonnet-4-5' => { input: 0.003, output: 0.015 },
        'claude-haiku-4' => { input: 0.0008, output: 0.004 },
        default: { input: 0.0, output: 0.0 }
      }.freeze
    end

    # Helper for per-request tracking
    class RequestCostTracker < CostTracker
      attr_reader :request_id

      def initialize(request_id:, **options)
        @request_id = request_id
        super(**options)
      end

      def finalize
        {
          request_id: request_id,
          total_cost: total_cost,
          cost_by_model: cost_by_model,
          timestamp: Time.now.iso8601
        }
      end
    end
  end
end
```

**Usage:**

```ruby
# Global tracking
tracker = Smolagents::Telemetry::CostTracker.new
agent = Smolagents.agent.model { model }.build
agent.run("task")

puts tracker.total_cost  # => 0.0234
puts tracker.cost_by_model  # => { 'gpt-4' => 0.0234 }

# Per-request tracking
tracker = Smolagents::Telemetry::RequestCostTracker.new(request_id: "req-123")
agent = Smolagents.agent.model { model }.build
agent.run("task")

result = tracker.finalize
# => { request_id: "req-123", total_cost: 0.0234, ... }
```

**Files Created:**
- `lib/smolagents/telemetry/cost_tracker.rb`
- `spec/smolagents/telemetry/cost_tracker_spec.rb`

---

### 5. RSpec Shared Examples

**Priority:** P0
**Effort:** 1 day
**Owner:** TBD
**Status:** Not Started

Provide shared examples for users testing custom agents and tools.

**Implementation:**

```ruby
# lib/smolagents/testing/shared_examples.rb
module Smolagents
  module Testing
    module SharedExamples
      # Shared examples for agent implementations
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

        it 'emits step events' do
          events = []
          subject.on(:step_complete) { |e| events << e }
          subject.run(task)

          expect(events).not_to be_empty
          expect(events.first).to respond_to(:step_number)
        end
      end

      # Shared examples for tool implementations
      RSpec.shared_examples 'a tool' do
        it 'has required metadata' do
          expect(subject.tool_name).not_to be_nil
          expect(subject.description).not_to be_nil
          expect(subject.inputs).to be_a(Hash)
        end

        it 'responds to execute' do
          expect(subject).to respond_to(:execute)
        end

        it 'validates input arguments' do
          # Test with invalid args
          expect { subject.execute({}) }.to raise_error(ArgumentError)
        end

        it 'emits tool_call events' do
          events = []
          subject.on(:tool_call) { |e| events << e }
          subject.execute(valid_args)

          expect(events).not_to be_empty
        end
      end

      # Shared examples for model implementations
      RSpec.shared_examples 'a model' do
        it 'responds to generate' do
          expect(subject).to respond_to(:generate)
        end

        it 'returns a GenerateResult' do
          result = subject.generate(messages: [{ role: :user, content: "test" }])
          expect(result).to respond_to(:content)
          expect(result).to respond_to(:token_usage)
        end

        it 'handles rate limits gracefully' do
          # Assuming rate limit simulation
          allow(subject).to receive(:generate).and_raise(
            Smolagents::RateLimitError.new("Rate limited")
          )

          expect { subject.generate(messages: []) }.to raise_error(
            Smolagents::RateLimitError
          )
        end
      end
    end
  end
end
```

**Usage:**

```ruby
RSpec.describe MyCustomAgent do
  subject { described_class.new }
  let(:task) { "Test task" }

  it_behaves_like 'an agent'
end

RSpec.describe MyCustomTool do
  subject { described_class.new }
  let(:valid_args) { { query: "test" } }

  it_behaves_like 'a tool'
end
```

**Files Created:**
- `lib/smolagents/testing/shared_examples.rb`
- `spec/smolagents/testing/shared_examples_spec.rb`
- Documentation in README

---

## P1: High Priority (1-2 Weeks)

### 6. Background Job Adapter

**Priority:** P1
**Effort:** 1 week
**Owner:** TBD
**Status:** Not Started

Provide adapters for common background job systems.

**Problem:**
- Agents run in-process only
- No official integration with Sidekiq, GoodJob, Resque, Delayed Job
- Users must manually handle `.sync_events` and lifecycle

**Solution:**

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
            .on(:error) { |e| logger.error("Agent error: #{e.error_message}") }
            .build
        end

        def default_builder
          ->(task) {
            Smolagents.agent
              .model { Smolagents.registered_model(:fast) }
              .tools(:search, :web)
          }
        end
      end

      def perform(task, options = {})
        agent = self.class.agent_for(task)
        result = agent.run(task)

        # Store result
        store_result(result, options)

        result
      end

      private

      def store_result(result, options)
        return unless options['store_result']

        key = "agent:#{jid}"
        ttl = options['result_ttl'] || 3600

        Sidekiq.redis do |conn|
          conn.setex(key, ttl, result.to_json)
        end
      end
    end

    # GoodJob adapter
    module GoodJobAdapter
      def self.included(base)
        base.include GoodJob::ActiveJobExtensions::Concurrency
        base.extend ClassMethods
      end

      module ClassMethods
        def agent_builder(&block)
          @agent_builder = block
        end

        def agent_for(task)
          builder = @agent_builder || default_builder
          instance_exec(task, &builder)
            .sync_events
            .on(:error) { |e| Rails.logger.error(e) }
            .build
        end
      end

      def perform(task)
        agent = self.class.agent_for(task)
        agent.run(task)
      end
    end
  end
end
```

**Usage:**

```ruby
# Sidekiq
class ResearchWorker
  include Smolagents::Adapters::SidekiqAdapter

  sidekiq_options retry: 3, queue: 'agents'

  agent_builder do |task|
    Smolagents.agent
      .model { Smolagents.registered_model(:smart) }
      .tools(:search, :web, :summarize)
      .max_steps(20)
  end
end

ResearchWorker.perform_async("Find Ruby trends", { 'store_result' => true })

# GoodJob
class AnalysisJob < ApplicationJob
  include Smolagents::Adapters::GoodJobAdapter
  queue_as :default

  agent_builder do |task|
    Smolagents.agent
      .model { Smolagents.registered_model(:fast) }
      .tools(:search, :calculate)
  end
end

AnalysisJob.perform_later("Analyze data")
```

**Files Created:**
- `lib/smolagents/adapters/sidekiq_adapter.rb`
- `lib/smolagents/adapters/goodjob_adapter.rb`
- `spec/smolagents/adapters/sidekiq_adapter_spec.rb`
- `spec/smolagents/adapters/goodjob_adapter_spec.rb`
- Documentation in README

---

### 7. Metrics Adapter Layer

**Priority:** P1
**Effort:** 1 week
**Owner:** TBD
**Status:** Not Started

Provide pluggable metrics backends for observability.

**Problem:**
- Users must implement custom event subscribers for metrics
- No standard metrics exported
- No integration with common tools (Prometheus, StatsD, DataDog)

**Solution:**

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
        on(:circuit_breaker_opened) { |e| track_circuit_breaker(e, 'opened') }
        on(:circuit_breaker_closed) { |e| track_circuit_breaker(e, 'closed') }
      end

      def track_step(event)
        @backend.increment('smolagents.steps.count', tags: {
          outcome: event.outcome,
          step_type: event.step_type
        })

        @backend.timing('smolagents.steps.duration', event.duration_ms, tags: {
          step_type: event.step_type
        })
      end

      def track_tool_call(event)
        @backend.increment('smolagents.tool_calls.count', tags: {
          tool_name: event.tool_name
        })

        @backend.timing('smolagents.tool_calls.duration', event.duration_ms, tags: {
          tool_name: event.tool_name
        })
      end

      def track_model_call(event)
        @backend.increment('smolagents.model_calls.count', tags: {
          model: event.model_id
        })

        @backend.timing('smolagents.model_calls.duration', event.duration_ms, tags: {
          model: event.model_id
        })

        @backend.gauge('smolagents.tokens.input', event.token_usage.input_tokens, tags: {
          model: event.model_id
        })

        @backend.gauge('smolagents.tokens.output', event.token_usage.output_tokens, tags: {
          model: event.model_id
        })
      end

      def track_error(event)
        @backend.increment('smolagents.errors.count', tags: {
          error_type: event.error.class.name
        })
      end

      def track_circuit_breaker(event, state)
        @backend.increment('smolagents.circuit_breaker.state_change', tags: {
          service: event.service,
          state: state
        })
      end
    end

    # Backends
    class PrometheusBackend
      def initialize(registry: Prometheus::Client.registry)
        @registry = registry
        setup_metrics
      end

      def increment(metric, tags: {})
        counter = @registry.get(metric.to_sym)
        counter.increment(labels: tags)
      end

      def timing(metric, value, tags: {})
        histogram = @registry.get(metric.to_sym)
        histogram.observe(value / 1000.0, labels: tags)  # Convert to seconds
      end

      def gauge(metric, value, tags: {})
        gauge = @registry.get(metric.to_sym)
        gauge.set(value, labels: tags)
      end

      private

      def setup_metrics
        # Define all metrics upfront
        @registry.counter(:'smolagents.steps.count', docstring: '...', labels: [:outcome, :step_type])
        @registry.histogram(:'smolagents.steps.duration', docstring: '...', labels: [:step_type])
        # ... etc
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

    class DatadogBackend < StatsDBackend
      # Uses same interface as StatsD
    end
  end
end
```

**Configuration:**

```ruby
# config/initializers/smolagents.rb
require 'datadog/statsd'

statsd = Datadog::Statsd.new('localhost', 8125, namespace: 'myapp')
backend = Smolagents::Telemetry::DatadogBackend.new(statsd)
Smolagents::Telemetry::MetricsAdapter.new(backend: backend)
```

**Standard Metrics Exported:**
- `smolagents.steps.count` - Total steps executed
- `smolagents.steps.duration` - Step execution time
- `smolagents.tool_calls.count` - Tool invocations
- `smolagents.tool_calls.duration` - Tool execution time
- `smolagents.model_calls.count` - LLM API calls
- `smolagents.model_calls.duration` - LLM API latency
- `smolagents.tokens.input` - Input tokens consumed
- `smolagents.tokens.output` - Output tokens generated
- `smolagents.errors.count` - Errors by type
- `smolagents.circuit_breaker.state_change` - Circuit breaker events

**Files Created:**
- `lib/smolagents/telemetry/metrics_adapter.rb`
- `lib/smolagents/telemetry/backends/prometheus_backend.rb`
- `lib/smolagents/telemetry/backends/statsd_backend.rb`
- `lib/smolagents/telemetry/backends/datadog_backend.rb`
- `spec/smolagents/telemetry/metrics_adapter_spec.rb`

---

### 8. Docker Deployment Stack

**Priority:** P1
**Effort:** 1 week
**Owner:** TBD
**Status:** Not Started

Provide a production-ready Docker deployment stack with CI/CD integration, elegant Agent DSL configuration via docker-compose, and bundled local LLM support (llama.cpp/Ollama).

**Problem:**
- No official Docker image for running smolagents-ruby
- Users must manually configure containerized deployments
- No easy way to run with local LLMs in a self-contained stack
- Agent configuration requires code changes, not environment config

**Solution:**

#### 1. Dockerfile with Multi-Stage Build

```dockerfile
# Dockerfile
ARG RUBY_VERSION=3.3
FROM ruby:${RUBY_VERSION}-slim AS base

WORKDIR /app
ENV BUNDLE_PATH=/gems \
    BUNDLE_WITHOUT=development:test \
    SMOLAGENTS_QUIET=1

# Install runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

FROM base AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

COPY Gemfile* smolagents.gemspec ./
COPY lib/smolagents/version.rb lib/smolagents/version.rb
RUN bundle install --jobs 4

COPY . .

FROM base AS runtime

COPY --from=builder /gems /gems
COPY --from=builder /app /app

# Agent runner entrypoint
COPY docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["run"]
```

#### 2. Entrypoint with DSL Configuration

```bash
#!/bin/bash
# docker/entrypoint.sh
set -e

case "$1" in
  run)
    exec bundle exec ruby -r smolagents -e "
      require 'smolagents/docker/config_loader'
      Smolagents::Docker::ConfigLoader.run
    "
    ;;
  console)
    exec bundle exec irb -r smolagents
    ;;
  *)
    exec "$@"
    ;;
esac
```

#### 3. YAML-Based Agent Configuration

```ruby
# lib/smolagents/docker/config_loader.rb
module Smolagents
  module Docker
    class ConfigLoader
      CONFIG_PATH = ENV.fetch('SMOLAGENTS_CONFIG', '/app/config/agent.yml')

      def self.run
        config = load_config
        agent = build_agent(config)

        if ENV['SMOLAGENTS_TASK']
          # One-shot mode: run task and exit
          result = agent.run(ENV['SMOLAGENTS_TASK'])
          puts result.output
        else
          # Server mode: listen for tasks via stdin or HTTP
          Server.new(agent).start
        end
      end

      def self.load_config
        return {} unless File.exist?(CONFIG_PATH)

        YAML.safe_load(
          ERB.new(File.read(CONFIG_PATH)).result,
          permitted_classes: [],
          permitted_symbols: [],
          aliases: true
        )
      end

      def self.build_agent(config)
        builder = Smolagents.agent

        # Model configuration
        builder = configure_model(builder, config['model'] || {})

        # Tools configuration
        tools = config['tools'] || []
        builder = builder.tools(*tools.map(&:to_sym)) if tools.any?

        # Inline tools from config
        (config['inline_tools'] || []).each do |tool_config|
          builder = builder.tool(
            tool_config['name'],
            tool_config['description']
          ) { |args| eval(tool_config['implementation']).call(args) }
        end

        # Agent settings
        builder = builder.as(config['persona'].to_sym) if config['persona']
        builder = builder.max_steps(config['max_steps']) if config['max_steps']
        builder = builder.instructions(config['instructions']) if config['instructions']

        # Planning
        if config['planning']
          builder = builder.planning(
            interval: config['planning']['interval'] || 3
          )
        end

        # Memory budget
        if config['memory']
          builder = builder.memory(
            budget: config['memory']['budget'] || 50_000
          )
        end

        builder.build
      end

      def self.configure_model(builder, model_config)
        provider = model_config['provider'] || 'openai'
        model_id = model_config['id'] || infer_model_id(provider)

        model = case provider
        when 'openai'
          Smolagents::Models::OpenAIModel.new(
            model_id: model_id,
            api_key: ENV['OPENAI_API_KEY'],
            base_url: model_config['base_url'] || ENV['OPENAI_BASE_URL']
          )
        when 'anthropic'
          Smolagents::Models::AnthropicModel.new(
            model_id: model_id,
            api_key: ENV['ANTHROPIC_API_KEY']
          )
        when 'ollama'
          Smolagents::Models::OpenAIModel.new(
            model_id: model_id,
            api_key: 'ollama',  # Ollama doesn't need real key
            base_url: model_config['base_url'] || 'http://ollama:11434/v1'
          )
        when 'llama_cpp'
          Smolagents::Models::OpenAIModel.new(
            model_id: model_id,
            api_key: 'llama',
            base_url: model_config['base_url'] || 'http://llama-cpp:8080/v1'
          )
        end

        builder.model { model }
      end

      def self.infer_model_id(provider)
        case provider
        when 'openai' then 'gpt-4o-mini'
        when 'anthropic' then 'claude-3-haiku-20240307'
        when 'ollama' then 'llama3.2'
        when 'llama_cpp' then 'local'
        end
      end
    end
  end
end
```

#### 4. Docker Compose with Local LLM Stack

```yaml
# docker-compose.yml
version: '3.8'

services:
  # ============================================
  # smolagents-ruby Agent
  # ============================================
  agent:
    build:
      context: .
      dockerfile: Dockerfile
    image: smolagents-ruby:${VERSION:-latest}
    environment:
      # Model provider: openai, anthropic, ollama, llama_cpp
      - SMOLAGENTS_MODEL_PROVIDER=${MODEL_PROVIDER:-ollama}
      - SMOLAGENTS_MODEL_ID=${MODEL_ID:-llama3.2}
      - SMOLAGENTS_CONFIG=/app/config/agent.yml
      # For cloud providers (optional)
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY:-}
    volumes:
      - ./config:/app/config:ro
      - agent-data:/app/data
    depends_on:
      ollama:
        condition: service_healthy
    networks:
      - smolagents

  # ============================================
  # Ollama - Easy local LLM serving
  # ============================================
  ollama:
    image: ollama/ollama:latest
    ports:
      - "11434:11434"
    volumes:
      - ollama-models:/root/.ollama
    environment:
      - OLLAMA_HOST=0.0.0.0
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:11434/api/tags"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - smolagents

  # ============================================
  # llama.cpp server - High-performance inference
  # (Alternative to Ollama for advanced users)
  # ============================================
  llama-cpp:
    image: ghcr.io/ggerganov/llama.cpp:server
    profiles: ["llama-cpp"]  # Only start with --profile llama-cpp
    ports:
      - "8080:8080"
    volumes:
      - ./models:/models:ro
    command: >
      -m /models/${LLAMA_MODEL:-model.gguf}
      --host 0.0.0.0
      --port 8080
      -c ${LLAMA_CONTEXT:-4096}
      -ngl ${LLAMA_GPU_LAYERS:-0}
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    networks:
      - smolagents

  # ============================================
  # Model Puller - Downloads models on startup
  # ============================================
  model-puller:
    image: curlimages/curl:latest
    depends_on:
      ollama:
        condition: service_healthy
    entrypoint: ["/bin/sh", "-c"]
    command:
      - |
        echo "Pulling model: ${MODEL_ID:-llama3.2}"
        curl -X POST http://ollama:11434/api/pull \
          -d '{"name": "${MODEL_ID:-llama3.2}"}'
        echo "Model ready!"
    networks:
      - smolagents

volumes:
  ollama-models:
  agent-data:

networks:
  smolagents:
    driver: bridge
```

#### 5. Agent Configuration File

```yaml
# config/agent.yml
# Agent configuration loaded at container startup
# Environment variables are interpolated via ERB

model:
  provider: <%= ENV.fetch('SMOLAGENTS_MODEL_PROVIDER', 'ollama') %>
  id: <%= ENV.fetch('SMOLAGENTS_MODEL_ID', 'llama3.2') %>
  base_url: <%= ENV['SMOLAGENTS_MODEL_BASE_URL'] %>

persona: researcher

tools:
  - search
  - web
  - calculate

max_steps: 20

instructions: |
  You are a helpful research assistant running in a Docker container.
  Be concise and accurate in your responses.

planning:
  interval: 5

memory:
  budget: 50000

# Optional: Define inline tools
# inline_tools:
#   - name: timestamp
#     description: Returns the current timestamp
#     implementation: |
#       ->(args) { Time.now.iso8601 }
```

#### 6. CI/CD Integration (GitHub Actions)

```yaml
# .github/workflows/docker.yml
name: Docker Build & Push

on:
  push:
    tags:
      - 'v*'
  pull_request:
    branches: [main]

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
          platforms: linux/amd64,linux/arm64
```

#### 7. Quick Start Documentation

```markdown
# Docker Quick Start

## Run with Ollama (Local LLM)

```bash
# Clone and start the stack
git clone https://github.com/your-org/smolagents-ruby
cd smolagents-ruby

# Start Ollama + Agent
docker compose up -d

# Run a task
docker compose exec agent run "What is the capital of France?"

# Interactive console
docker compose exec agent console
```

## Run with Cloud Provider

```bash
# With OpenAI
OPENAI_API_KEY=sk-... \
MODEL_PROVIDER=openai \
MODEL_ID=gpt-4o-mini \
docker compose up agent

# With Anthropic
ANTHROPIC_API_KEY=sk-ant-... \
MODEL_PROVIDER=anthropic \
MODEL_ID=claude-3-haiku-20240307 \
docker compose up agent
```

## Run with llama.cpp (GPU Acceleration)

```bash
# Download a GGUF model
mkdir -p models
wget -O models/model.gguf https://...

# Start with llama.cpp profile
docker compose --profile llama-cpp up -d
```

## Custom Agent Configuration

Edit `config/agent.yml` to customize:
- Model settings
- Available tools
- Persona and instructions
- Planning intervals
- Memory budget
```

**Usage Examples:**

```bash
# One-shot task execution
docker run -e SMOLAGENTS_TASK="Summarize the news" \
           -e OPENAI_API_KEY=sk-... \
           ghcr.io/your-org/smolagents-ruby:latest

# With custom config mounted
docker run -v ./my-config.yml:/app/config/agent.yml:ro \
           -e OPENAI_API_KEY=sk-... \
           ghcr.io/your-org/smolagents-ruby:latest

# Full local stack with Ollama
docker compose up -d
docker compose exec agent run "Research Ruby 4.0 features"
```

**Files Created:**
- `Dockerfile`
- `docker/entrypoint.sh`
- `docker-compose.yml`
- `config/agent.yml.example`
- `lib/smolagents/docker/config_loader.rb`
- `.github/workflows/docker.yml`
- `docs/docker-quickstart.md`

**Files Modified:**
- `README.md` - Add Docker section
- `.dockerignore` - Exclude dev files

---

## P2: Medium Priority (2-4 Weeks)

### 8. Automatic Resource Cleanup

**Priority:** P2
**Effort:** 1 week
**Owner:** TBD
**Status:** Not Started

Add automatic cleanup for long-lived resources.

**Problem:**
- All resource cleanup is manual (`shutdown!`, `close_connections`)
- No `at_exit` hooks
- No finalizers for automatic cleanup
- No graceful shutdown documentation

**Solution:**

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
          warn "Smolagents cleanup error: #{e.message}"
        end
      ensure
        cleanups.clear
      end

      def shutdown_timeout=(seconds)
        @shutdown_timeout = seconds
      end

      def shutdown_timeout
        @shutdown_timeout ||= 5
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
  timeout = Smolagents::Lifecycle.shutdown_timeout
  Thread.new do
    sleep timeout
    warn "Smolagents: Cleanup timed out after #{timeout}s, forcing exit"
    exit!(1)
  end

  Smolagents::Lifecycle.cleanup_all
end

# In Agent class
module Smolagents
  module Agents
    class Agent
      def initialize(...)
        super
        register_cleanup_hooks
      end

      private

      def register_cleanup_hooks
        Smolagents::Lifecycle.register_cleanup do
          cleanup_resources
        end

        # ObjectSpace finalizer for GC cleanup
        ObjectSpace.define_finalizer(self, self.class.finalize(object_id))
      end

      def self.finalize(agent_id)
        proc do
          # Cleanup without holding agent reference
          cleanup_agent_resources(agent_id)
        end
      end

      def cleanup_resources
        @executor&.shutdown!
        @http_connections&.close_all
        @event_queue&.shutdown(timeout: 1)
      end
    end
  end
end
```

**Configuration:**

```ruby
# Adjust shutdown timeout (default: 5s)
Smolagents::Lifecycle.shutdown_timeout = 10
```

**Files Created:**
- `lib/smolagents/lifecycle.rb`
- `spec/smolagents/lifecycle_spec.rb`
- Documentation in README

**Files Modified:**
- `lib/smolagents/agents/agent.rb` - Add cleanup hooks
- `lib/smolagents/http/connection.rb` - Ensure `close_all` method
- `lib/smolagents/executors/ractor.rb` - Ensure `shutdown!` method

---

### 9. Enhanced Error Classification

**Priority:** P2
**Effort:** 3 days
**Owner:** TBD
**Status:** Not Started

Classify errors for intelligent retry strategies.

**Problem:**
- All errors treated equally
- No distinction between retriable vs terminal errors
- Retry logic doesn't adapt based on error type

**Solution:**

```ruby
# lib/smolagents/errors/classifier.rb
module Smolagents
  module Errors
    class Classifier
      def self.classify(error)
        case error
        when RateLimitError
          {
            retriable: true,
            backoff: :exponential,
            base_delay: 10,
            max_attempts: 5,
            circuit_breaking: false
          }
        when AuthenticationError, APIKeyError
          {
            retriable: false,
            terminal: true,
            circuit_breaking: false
          }
        when TimeoutError
          {
            retriable: true,
            backoff: :linear,
            base_delay: 2,
            max_attempts: 2,
            circuit_breaking: true
          }
        when NetworkError, ConnectionError
          {
            retriable: true,
            backoff: :exponential,
            base_delay: 1,
            max_attempts: 3,
            circuit_breaking: true
          }
        when CircuitOpenError
          {
            retriable: true,
            backoff: :exponential,
            base_delay: 30,
            max_attempts: 1,
            circuit_breaking: false
          }
        when ToolExecutionError
          {
            retriable: true,
            backoff: :linear,
            base_delay: 1,
            max_attempts: 2,
            circuit_breaking: false
          }
        when ValidationError, ASTValidationError
          {
            retriable: false,
            terminal: true,
            circuit_breaking: false
          }
        else
          {
            retriable: false,
            terminal: true,
            circuit_breaking: false
          }
        end
      end

      def self.should_retry?(error, attempt:)
        classification = classify(error)
        classification[:retriable] && attempt < classification[:max_attempts]
      end

      def self.backoff_delay(error, attempt:)
        classification = classify(error)
        base = classification[:base_delay]

        case classification[:backoff]
        when :exponential
          base * (2 ** attempt)
        when :linear
          base * attempt
        else
          base
        end
      end
    end
  end
end
```

**Integration with Retry Logic:**

```ruby
# lib/smolagents/concerns/resilience/retry_logic.rb (modified)
def with_retry(operation)
  attempt = 0

  begin
    yield
  rescue => e
    classification = Errors::Classifier.classify(e)

    if classification[:retriable] && attempt < classification[:max_attempts]
      delay = Errors::Classifier.backoff_delay(e, attempt: attempt)
      sleep(delay)
      attempt += 1
      retry
    else
      raise
    end
  end
end
```

**Files Created:**
- `lib/smolagents/errors/classifier.rb`
- `spec/smolagents/errors/classifier_spec.rb`

**Files Modified:**
- `lib/smolagents/concerns/resilience/retry_logic.rb`

---

### 10. Connection Pooling Improvements

**Priority:** P2
**Effort:** 3 days
**Owner:** TBD
**Status:** Not Started

Implement proper HTTP connection pooling with TTL and size limits.

**Problem:**
- `@_connections` hash grows unbounded
- No connection TTL
- No max pool size
- No health checks
- No automatic eviction

**Solution:**

```ruby
# lib/smolagents/http/connection_pool.rb
require 'connection_pool'

module Smolagents
  module Http
    class ConnectionPool
      DEFAULT_POOL_SIZE = 5
      DEFAULT_TIMEOUT = 5
      DEFAULT_TTL = 300  # 5 minutes

      def initialize(size: DEFAULT_POOL_SIZE, timeout: DEFAULT_TIMEOUT, ttl: DEFAULT_TTL)
        @pool = ::ConnectionPool.new(size: size, timeout: timeout) do
          {}  # Hash of connections
        end
        @ttl = ttl
        @created_at = Concurrent::Map.new
      end

      def with_connection(url, resolved_ip)
        @pool.with do |connections|
          key = connection_key(url, resolved_ip)

          # Check if connection exists and is fresh
          if connections[key] && fresh?(key)
            connections[key]
          else
            # Create new connection
            connections[key] = build_connection(url, resolved_ip)
            @created_at[key] = Time.now
            connections[key]
          end
        end
      end

      def close_all
        @pool.with do |connections|
          connections.each_value do |conn|
            conn.close if conn.respond_to?(:close)
          end
          connections.clear
        end
        @created_at.clear
      end

      private

      def fresh?(key)
        created_at = @created_at[key]
        created_at && (Time.now - created_at) < @ttl
      end

      def connection_key(url, resolved_ip)
        "#{url}:#{resolved_ip}"
      end

      def build_connection(url, resolved_ip)
        # Existing connection building logic
        Faraday.new(url) do |f|
          # ... existing config
        end
      end
    end
  end
end
```

**Integration:**

```ruby
# lib/smolagents/http/connection.rb (modified)
module Connection
  def http_connection_pool
    @http_connection_pool ||= ConnectionPool.new(
      size: Smolagents.configuration.http[:pool_size] || 5,
      timeout: Smolagents.configuration.http[:pool_timeout] || 5,
      ttl: Smolagents.configuration.http[:connection_ttl] || 300
    )
  end

  def http_get(url)
    resolved_ip = resolve_ip(url)
    conn = http_connection_pool.with_connection(url, resolved_ip)
    conn.get
  end
end
```

**Configuration:**

```ruby
Smolagents.configure do |config|
  config.http[:pool_size] = 10
  config.http[:pool_timeout] = 5
  config.http[:connection_ttl] = 300
end
```

**Dependencies:**
Add `connection_pool` gem to gemspec (optional, graceful degradation if not present).

**Files Created:**
- `lib/smolagents/http/connection_pool.rb`
- `spec/smolagents/http/connection_pool_spec.rb`

**Files Modified:**
- `lib/smolagents/http/connection.rb`
- `lib/smolagents/config/configuration.rb` - Add pool settings

---

### 11. Automatic Secret Redaction in Logs

**Priority:** P2
**Effort:** 1 day
**Owner:** TBD
**Status:** Not Started

Automatically apply secret redaction to all log output.

**Problem:**
- `SecretRedactor` exists but not automatically applied
- Users must manually integrate redaction
- Risk of leaking API keys in logs

**Solution:**

```ruby
# lib/smolagents/telemetry/logging_subscriber.rb (modified)
module Smolagents
  module Telemetry
    class LoggingSubscriber
      # ... existing code ...

      def format_payload(payload)
        json = payload.to_json
        Smolagents::Security::SecretRedactor.redact(json)
      end

      def log_event(event_name, payload)
        formatted = format_payload(payload)
        logger.info("[#{event_name}] #{formatted}")
      end
    end
  end
end
```

**Configuration:**

```ruby
Smolagents.configure do |config|
  config.log_redaction_enabled = true  # Default: true
  config.log_redaction_patterns = [
    # Additional custom patterns
    /my-secret-\w+/
  ]
end
```

**Files Modified:**
- `lib/smolagents/telemetry/logging_subscriber.rb`
- `lib/smolagents/security/secret_redactor.rb` - Add config support
- `lib/smolagents/config/configuration.rb` - Add redaction settings

---

## P3: Low Priority (1-2 Months)

### 12. ActionCable Streaming Integration

**Priority:** P3
**Effort:** 3 days
**Owner:** TBD
**Status:** Not Started

Provide real-time streaming of agent execution via ActionCable.

**Implementation:**

```ruby
# lib/smolagents/adapters/action_cable_adapter.rb
module Smolagents
  module Adapters
    class ActionCableAdapter
      def initialize(channel:, stream:)
        @channel = channel
        @stream = stream
      end

      def wrap_agent(agent)
        agent
          .on(:step_complete) { |e| broadcast_step(e) }
          .on(:tool_call) { |e| broadcast_tool_call(e) }
          .on(:model_generate_started) { |e| broadcast_thinking }
          .on(:model_generate_completed) { |e| broadcast_completion(e) }
          .on(:error) { |e| broadcast_error(e) }
      end

      private

      def broadcast_step(event)
        ActionCable.server.broadcast(@stream, {
          type: 'step_complete',
          step_number: event.step_number,
          outcome: event.outcome,
          timestamp: Time.now.iso8601
        })
      end

      def broadcast_tool_call(event)
        ActionCable.server.broadcast(@stream, {
          type: 'tool_call',
          tool_name: event.tool_name,
          args: event.args,
          timestamp: Time.now.iso8601
        })
      end

      def broadcast_thinking
        ActionCable.server.broadcast(@stream, {
          type: 'thinking',
          timestamp: Time.now.iso8601
        })
      end

      def broadcast_completion(event)
        ActionCable.server.broadcast(@stream, {
          type: 'completion',
          content: event.content,
          token_usage: event.token_usage.to_h,
          timestamp: Time.now.iso8601
        })
      end

      def broadcast_error(event)
        ActionCable.server.broadcast(@stream, {
          type: 'error',
          error_message: event.error_message,
          timestamp: Time.now.iso8601
        })
      end
    end
  end
end
```

**Example Channel:**

```ruby
# app/channels/agent_channel.rb
class AgentChannel < ApplicationCable::Channel
  def subscribed
    @agent_id = params[:agent_id]
    stream_from "agent_#{@agent_id}"
  end

  def run_task(data)
    task = data['task']

    adapter = Smolagents::Adapters::ActionCableAdapter.new(
      channel: self,
      stream: "agent_#{@agent_id}"
    )

    agent = build_agent
    wrapped = adapter.wrap_agent(agent)

    AgentJob.perform_later(@agent_id, task)
  end

  private

  def build_agent
    Smolagents.agent
      .model { Smolagents.registered_model(:fast) }
      .tools(:search, :web)
      .build
  end
end
```

**Client:**

```javascript
// app/javascript/channels/agent_channel.js
import consumer from "./consumer"

const agentChannel = consumer.subscriptions.create(
  { channel: "AgentChannel", agent_id: "123" },
  {
    received(data) {
      switch(data.type) {
        case 'step_complete':
          console.log(`Step ${data.step_number}: ${data.outcome}`);
          break;
        case 'tool_call':
          console.log(`→ ${data.tool_name}(${JSON.stringify(data.args)})`);
          break;
        case 'thinking':
          showThinkingIndicator();
          break;
        case 'completion':
          console.log(`Complete: ${data.content}`);
          hideThinkingIndicator();
          break;
        case 'error':
          console.error(`Error: ${data.error_message}`);
          break;
      }
    }
  }
);

agentChannel.perform('run_task', { task: "Research Ruby trends" });
```

**Files Created:**
- `lib/smolagents/adapters/action_cable_adapter.rb`
- `spec/smolagents/adapters/action_cable_adapter_spec.rb`
- Documentation in README

---

## Production Integration Patterns

### Pattern 1: Background Jobs with Cost Tracking

```ruby
# app/jobs/agent_job.rb
class AgentJob < ApplicationJob
  queue_as :default

  retry_on Smolagents::RateLimitError, wait: :exponentially_longer
  retry_on Smolagents::TimeoutError, attempts: 2
  discard_on Smolagents::AuthenticationError

  def perform(user_id, task)
    cost_tracker = Smolagents::Telemetry::RequestCostTracker.new(
      request_id: "job-#{jid}"
    )

    agent = build_agent
    result = agent.run(task)

    # Store result with cost
    AgentResult.create!(
      user_id: user_id,
      task: task,
      output: result.output,
      steps: result.steps.count,
      token_usage: result.token_usage.to_h,
      cost_usd: cost_tracker.total_cost
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

---

### Pattern 2: API Endpoint with Health Checks

```ruby
# app/controllers/api/v1/agents_controller.rb
module Api
  module V1
    class AgentsController < ApplicationController
      def create
        # Check system health before creating agent
        health = SmolagentsHealthCheck.check
        unless health[:healthy]
          return render json: { error: "System unhealthy" }, status: :service_unavailable
        end

        result = with_timeout do
          agent = build_agent
          agent.run(agent_params[:task])
        end

        render json: {
          output: result.output,
          steps: result.steps.count,
          token_usage: result.token_usage.to_h
        }, status: :ok
      rescue Smolagents::AgentError => e
        handle_agent_error(e)
      end

      private

      def build_agent
        Smolagents.agent
          .model {
            Smolagents.registered_model(:fast)
              .with_circuit_breaker(threshold: 5, cool_off: 30)
              .with_fallback(Smolagents.registered_model(:backup))
          }
          .tools(*agent_params[:tools])
          .max_steps(agent_params[:max_steps] || 10)
          .build
      end

      def with_timeout
        Timeout.timeout(30) { yield }
      end

      def handle_agent_error(error)
        status = case error
          when Smolagents::AgentMaxStepsError then :unprocessable_entity
          when Smolagents::TimeoutError then :gateway_timeout
          when Smolagents::CircuitOpenError then :service_unavailable
          else :internal_server_error
        end

        render json: { error: error.message }, status: status
      end

      def agent_params
        params.require(:agent).permit(:task, :max_steps, tools: [])
      end
    end
  end
end
```

---

### Pattern 3: Service Object with Metrics

```ruby
# app/services/research_service.rb
class ResearchService
  def initialize(user:)
    @user = user
    @cost_tracker = Smolagents::Telemetry::CostTracker.new
    @agent = build_agent
  end

  def research(topic)
    result = @agent.run("Research #{topic} and provide a summary")

    Research.create!(
      user: @user,
      topic: topic,
      summary: result.output,
      token_cost: @cost_tracker.total_cost,
      metadata: {
        steps: result.steps.count,
        token_usage: result.token_usage.to_h,
        cost_breakdown: @cost_tracker.cost_by_model
      }
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
end
```

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)
**Focus:** Documentation, templates, critical fixes

- [ ] Production deployment checklist
- [ ] Thread safety documentation
- [ ] Health check template
- [ ] Cost tracking module
- [ ] RSpec shared examples

**Deliverables:**
- 5 new files
- Updated README
- Production-ready templates

---

### Phase 2: Integration (Weeks 3-4)
**Focus:** Background jobs, observability, containerization

- [ ] Sidekiq adapter
- [ ] GoodJob adapter
- [ ] Metrics adapter (Prometheus, StatsD, DataDog)
- [ ] Standard metrics exported
- [ ] Docker deployment stack with CI/CD
- [ ] Local LLM integration (Ollama/llama.cpp)

**Deliverables:**
- 10+ new files
- Background job support
- Production metrics
- Docker images and compose stack

---

### Phase 3: Reliability (Weeks 5-6)
**Focus:** Resource management, error handling

- [ ] Automatic resource cleanup
- [ ] Enhanced error classification
- [ ] Connection pooling improvements
- [ ] Automatic secret redaction

**Deliverables:**
- 5+ new files
- Improved production reliability
- Better resource management

---

### Phase 4: Advanced (Weeks 7-8)
**Focus:** Streaming, advanced features

- [ ] ActionCable streaming
- [ ] Advanced monitoring
- [ ] Performance optimizations

**Deliverables:**
- Real-time streaming support
- Enhanced observability

---

## Success Metrics

### Developer Experience
- Time to production deployment < 1 hour
- Health check setup < 15 minutes
- Background job integration < 30 minutes
- Metrics integration < 30 minutes

### Production Readiness
- Zero manual resource cleanup required
- Automatic secret redaction in all logs
- Circuit breakers work across processes
- Connection pools prevent resource exhaustion

### Observability
- All critical metrics exported by default
- Cost tracking integrated
- Error classification for intelligent retries
- Health checks cover all subsystems

---

## File References

### Core Files to Modify
- `lib/smolagents/http/connection.rb` - Connection pooling
- `lib/smolagents/telemetry/logging_subscriber.rb` - Auto redaction
- `lib/smolagents/agents/agent.rb` - Cleanup hooks
- `lib/smolagents/config/configuration.rb` - New settings
- `README.md` - Documentation updates, Docker section
- `.dockerignore` - Exclude dev files from Docker builds

### New Files to Create
- `PRODUCTION_CHECKLIST.md`
- `examples/health_check_template.rb`
- `lib/smolagents/lifecycle.rb`
- `lib/smolagents/telemetry/cost_tracker.rb`
- `lib/smolagents/telemetry/metrics_adapter.rb`
- `lib/smolagents/telemetry/backends/*.rb`
- `lib/smolagents/adapters/sidekiq_adapter.rb`
- `lib/smolagents/adapters/goodjob_adapter.rb`
- `lib/smolagents/adapters/action_cable_adapter.rb`
- `lib/smolagents/errors/classifier.rb`
- `lib/smolagents/http/connection_pool.rb`
- `lib/smolagents/testing/shared_examples.rb`
- `Dockerfile`
- `docker/entrypoint.sh`
- `docker-compose.yml`
- `config/agent.yml.example`
- `lib/smolagents/docker/config_loader.rb`
- `.github/workflows/docker.yml`
- `docs/docker-quickstart.md`

---

## Notes

- All enhancements maintain backward compatibility
- Event-driven architecture preserved
- No breaking changes to existing API
- Graceful degradation for optional features
- Rails integration tracked separately

---

**Last Updated:** 2026-01-27
**Status:** Planning Phase
**Next Review:** TBD
