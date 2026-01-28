# Implementation Examples: Ergonomic Patterns for smolagents-ruby

Quick copy-paste examples for implementing patterns identified in the research.

---

## 1. Rails Configuration Initializer

**File:** `config/initializers/smolagents.rb`

```ruby
# smolagents-ruby configuration
# Supports environment-specific overrides

module Smolagents
  def self.configure(&block)
    @configuration = Configuration.new
    yield @configuration if block_given?
    @configuration
  end

  def self.config
    @configuration ||= Configuration.new
  end

  class Configuration
    attr_accessor :default_model_type, :default_temperature
    attr_accessor :retry_max_attempts, :retry_initial_delay
    attr_accessor :circuit_breaker_threshold
    attr_accessor :openai_api_key, :anthropic_api_key
    attr_accessor :enable_telemetry, :logging_level

    def initialize
      # Defaults
      @default_model_type = :openai
      @default_temperature = 0.7
      @retry_max_attempts = 3
      @retry_initial_delay = 1
      @circuit_breaker_threshold = 5
      @enable_telemetry = !Rails.env.test?
      @logging_level = :info

      # Load from environment
      load_from_env
      load_from_credentials if defined?(Rails)
    end

    private

    def load_from_env
      @openai_api_key ||= ENV['OPENAI_API_KEY']
      @anthropic_api_key ||= ENV['ANTHROPIC_API_KEY']
    end

    def load_from_credentials
      creds = Rails.application.credentials.smolagents
      @openai_api_key ||= creds[:openai_api_key]
      @anthropic_api_key ||= creds[:anthropic_api_key]
    rescue
      # Credentials not configured
    end
  end
end

# Configure based on environment
Smolagents.configure do |config|
  case Rails.env
  when 'production'
    config.retry_max_attempts = 5
    config.circuit_breaker_threshold = 5
    config.logging_level = :warn
    config.enable_telemetry = true

  when 'development'
    config.retry_max_attempts = 2
    config.logging_level = :debug
    config.enable_telemetry = false

  when 'test'
    config.enable_telemetry = false
  end
end

# Enable logging and telemetry
if Smolagents.config.enable_telemetry
  Smolagents::Telemetry::LoggingSubscriber.enable(level: Smolagents.config.logging_level)
end
```

---

## 2. Rails Credentials Configuration

**File:** `config/credentials.yml.enc` (edit with `rails credentials:edit`)

```yaml
smolagents:
  openai_api_key: <%= ENV['OPENAI_API_KEY'] %>
  anthropic_api_key: <%= ENV['ANTHROPIC_API_KEY'] %>

  models:
    default: gpt-4
    fast: gpt-3.5-turbo
    backup: gpt-4-turbo-preview

  retry_policy:
    max_attempts: 3
    initial_delay: 1
    exponential_base: 2
    max_delay: 60

  circuit_breaker:
    failure_threshold: 5
    success_threshold: 2
    timeout: 30

rails:
  key: value
```

---

## 3. Rails Health Check Endpoint

**File:** `app/controllers/health_controller.rb`

```ruby
class HealthController < ApplicationController
  skip_authentication! if respond_to?(:skip_authentication!)
  skip_authorization! if respond_to?(:skip_authorization!)

  def show
    status = health_status
    render json: status, status: status[:all_healthy] ? 200 : 503
  end

  private

  def health_status
    {
      status: 'healthy',
      timestamp: Time.now.iso8601,
      all_healthy: true,
      checks: {
        database: check_database,
        models: check_models,
        external_services: check_external_services
      }
    }
  end

  def check_database
    begin
      ActiveRecord::Base.connection.execute('SELECT 1')
      { status: 'up' }
    rescue => e
      { status: 'down', error: e.message }
    end
  end

  def check_models
    models = {}.tap do |h|
      h['openai'] = check_model('openai')
      h['anthropic'] = check_model('anthropic') if defined?(AnthropicModel)
    end

    all_up = models.values.all? { |m| m[:status] == 'up' }
    { models:, all_up: }
  end

  def check_model(provider)
    model_class = "#{provider.capitalize}Model".constantize
    model = model_class.new(api_key: 'health-check')

    # Try lightweight operation
    model.health_check_ms = Time.now.to_i
    { status: 'up', response_time_ms: 0 }
  rescue => e
    { status: 'down', error: e.message }
  end

  def check_external_services
    {
      # Add other service checks as needed
    }
  end
end
```

**File:** `config/routes.rb`

```ruby
Rails.application.routes.draw do
  get '/health' => 'health#show'
end
```

---

## 4. Rails Migration for Agent Execution Log

**File:** `db/migrate/20250126000001_create_agent_executions.rb`

```ruby
class CreateAgentExecutions < ActiveRecord::Migration[7.0]
  def change
    create_table :agent_executions do |t|
      t.string :agent_class, null: false
      t.string :agent_id
      t.text :task
      t.text :result
      t.integer :status, default: 0  # pending, running, completed, failed
      t.integer :step_count, default: 0
      t.decimal :cost, precision: 10, scale: 6, default: 0
      t.integer :input_tokens, default: 0
      t.integer :output_tokens, default: 0
      t.string :model_used
      t.string :error_message
      t.text :error_backtrace
      t.integer :duration_ms
      t.string :request_id
      t.references :user, foreign_key: true
      t.jsonb :metadata, default: {}

      t.timestamps
    end

    add_index :agent_executions, :status
    add_index :agent_executions, :created_at
    add_index :agent_executions, :user_id
    add_index :agent_executions, :request_id
  end
end
```

**File:** `app/models/agent_execution.rb`

```ruby
class AgentExecution < ApplicationRecord
  belongs_to :user, optional: true

  enum status: { pending: 0, running: 1, completed: 2, failed: 3 }

  validates :agent_class, presence: true

  def log_step(step_number, step_data)
    update(step_count: step_number)
    metadata['steps'] ||= []
    metadata['steps'] << {
      number: step_number,
      data: step_data,
      timestamp: Time.now.iso8601
    }
    save
  end

  def duration
    return nil unless created_at && updated_at
    (updated_at - created_at).to_i
  end

  def cost_per_step
    return 0 if step_count.zero?
    cost / step_count
  end
end
```

---

## 5. ActionCable Integration for Streaming Agent Execution

**File:** `app/channels/agent_channel.rb`

```ruby
class AgentChannel < ApplicationCable::Channel
  def subscribed
    stream_from "agent_#{params[:agent_id]}"
  end

  def unsubscribed
    # Any cleanup when user disconnects
  end

  def execute(data)
    agent_class = data['agent_class']
    task = data['task']
    agent_id = params[:agent_id]

    # Queue the job
    Smolagents::AgentExecutionJob.perform_later(
      agent_class:,
      task:,
      agent_id:,
      user_id: current_user&.id,
      connection_id: connection.connection_identifier
    )

    # Send confirmation
    transmit({ status: 'queued', agent_id: })
  end
end
```

**File:** `app/jobs/smolagents/agent_execution_job.rb`

```ruby
class Smolagents::AgentExecutionJob < ApplicationJob
  queue_as :default

  def perform(agent_class:, task:, agent_id:, user_id: nil, connection_id:)
    agent = agent_class.constantize.new
    execution = AgentExecution.create!(
      agent_class:,
      agent_id:,
      task:,
      user_id:,
      status: :running,
      request_id: request_id,
      metadata: { connection_id: }
    )

    # Subscribe to agent events
    agent.on(:step_complete) do |event|
      execution.log_step(event.step_number, {
        tool: event.tool_name,
        output: event.output,
        duration_ms: event.duration_ms
      })

      # Broadcast to WebSocket
      ActionCable.server.broadcast(
        "agent_#{agent_id}",
        type: 'step_complete',
        step: event.step_number,
        tool: event.tool_name,
        output: event.output
      )
    end

    agent.on(Smolagents::Events::ErrorOccurred) do |event|
      ActionCable.server.broadcast(
        "agent_#{agent_id}",
        type: 'error',
        error: event.error.message,
        message: "Agent encountered an error: #{event.error.message}"
      )
    end

    # Run the agent
    result = agent.run(task)

    # Mark as complete
    execution.update!(
      status: :completed,
      result: result.output.to_s,
      input_tokens: result.token_usage.input_tokens,
      output_tokens: result.token_usage.output_tokens,
      duration_ms: result.duration_ms,
      model_used: result.model_used
    )

    # Calculate cost
    cost = calculate_cost(result)
    execution.update!(cost:)

    # Broadcast completion
    ActionCable.server.broadcast(
      "agent_#{agent_id}",
      type: 'completed',
      result: result.output,
      cost:,
      duration_ms: result.duration_ms
    )
  rescue => e
    execution.update!(
      status: :failed,
      error_message: e.message,
      error_backtrace: e.backtrace.first(10).join("\n")
    )

    ActionCable.server.broadcast(
      "agent_#{agent_id}",
      type: 'failed',
      error: e.message
    )

    raise
  end

  private

  def calculate_cost(result)
    pricing = {
      'gpt-4' => { input: 0.03 / 1000, output: 0.06 / 1000 },
      'gpt-3.5-turbo' => { input: 0.0005 / 1000, output: 0.0015 / 1000 }
    }

    rates = pricing[result.model_used] || { input: 0, output: 0 }
    (result.token_usage.input_tokens * rates[:input]) +
      (result.token_usage.output_tokens * rates[:output])
  end
end
```

**File:** `app/javascript/channels/agent_channel.js`

```javascript
import consumer from "./consumer"

document.addEventListener('DOMContentLoaded', () => {
  const agentForm = document.getElementById('agent-form')
  const agentId = agentForm?.dataset.agentId

  if (!agentId) return

  const subscription = consumer.subscriptions.create(
    { channel: "AgentChannel", agent_id: agentId },
    {
      connected() {
        console.log('Connected to agent channel')
      },

      received(data) {
        const output = document.getElementById('agent-output')

        switch (data.type) {
          case 'step_complete':
            output.innerHTML += `
              <div class="step">
                <strong>Step ${data.step}:</strong> ${data.tool}
                <p>${data.output}</p>
              </div>
            `
            break

          case 'error':
            output.innerHTML += `<div class="error">${data.error}</div>`
            break

          case 'completed':
            output.innerHTML += `
              <div class="result">
                <strong>Result:</strong> ${data.result}
                <p>Cost: $${data.cost}</p>
                <p>Duration: ${data.duration_ms}ms</p>
              </div>
            `
            break

          case 'failed':
            output.innerHTML += `<div class="error">Failed: ${data.error}</div>`
        }
      }
    }
  )

  agentForm?.addEventListener('submit', (e) => {
    e.preventDefault()
    const task = document.getElementById('task').value
    subscription.perform('execute', {
      agent_class: agentForm.dataset.agentClass,
      task: task
    })
  })
})
```

---

## 6. Async Adapter Pattern for Background Jobs

**File:** `lib/smolagents/adapters/sidekiq_adapter.rb`

```ruby
module Smolagents::Adapters
  class SidekiqAdapter
    def self.enqueue(agent_class, task, options = {})
      job_options = extract_job_options(options)
      Smolagents::AgentExecutionJob.set(job_options).perform_later(
        agent_class:,
        task:,
        connection_id: options[:connection_id]
      )
    end

    private

    def self.extract_job_options(options)
      {
        queue: options[:queue] || 'default',
        wait: options[:wait],
        wait_until: options[:wait_until]
      }.compact
    end
  end
end
```

**File:** `lib/smolagents/adapters/async_adapter.rb`

```ruby
module Smolagents::Adapters
  class AsyncAdapter
    def self.enqueue(agent_class, task, options = {})
      require 'async'

      # Run with fibers instead of threads
      Async do
        agent = agent_class.constantize.new

        # Subscribe to events if callback provided
        if options[:on_step]
          agent.on(:step_complete) { |e| options[:on_step].call(e) }
        end

        agent.run(task)
      end
    end
  end
end
```

**File:** `lib/smolagents/adapters.rb`

```ruby
module Smolagents::Adapters
  def self.enqueue(adapter_type, agent_class, task, **options)
    adapter_class = adapter_for(adapter_type)
    adapter_class.enqueue(agent_class, task, options)
  end

  private

  def self.adapter_for(type)
    case type
    when :sidekiq
      require_relative 'adapters/sidekiq_adapter'
      SidekiqAdapter
    when :async
      require_relative 'adapters/async_adapter'
      AsyncAdapter
    else
      raise "Unknown adapter: #{type}"
    end
  end
end
```

**Usage:**

```ruby
# In controller
case Rails.env
when 'production'
  Smolagents::Adapters.enqueue(:sidekiq, 'ResearchAgent', query)
else
  Smolagents::Adapters.enqueue(:async, 'ResearchAgent', query)
end
```

---

## 7. Structured Logging Configuration

**File:** `lib/smolagents/logging/structured_logger.rb`

```ruby
module Smolagents::Logging
  class StructuredLogger
    def initialize(format: :text, output: $stdout, include_context: true)
      @format = format
      @output = output
      @include_context = include_context
    end

    def log_event(event, additional = {})
      context = build_context(event, additional)
      @output.puts format_output(context)
    end

    private

    def build_context(event, additional)
      {
        timestamp: Time.now.iso8601,
        level: level_for(event),
        event_type: event.class.name.demodulize,
        duration_ms: event.duration_ms,
        trace_id: trace_id,
        request_id: request_id,
        user_id: user_id,
        **event_attributes(event),
        **additional
      }
    end

    def format_output(context)
      case @format
      when :json
        context.to_json
      when :text
        text_format(context)
      end
    end

    def text_format(context)
      parts = [
        "[#{context[:timestamp]}]",
        "[#{context[:level].upcase}]",
        context[:event_type],
        context[:duration_ms] && "(#{context[:duration_ms]}ms)"
      ].compact

      message = parts.join(' ')
      message += " | #{context.except(*parts).to_s}" if context.size > parts.size

      message
    end

    def event_attributes(event)
      attrs = {}
      attrs[:tool_name] = event.tool_name if event.respond_to?(:tool_name)
      attrs[:step_number] = event.step_number if event.respond_to?(:step_number)
      attrs[:error] = event.error.message if event.respond_to?(:error)
      attrs
    end

    def level_for(event)
      case event
      when Smolagents::Events::ErrorOccurred
        :error
      when Smolagents::Events::WarningIssued
        :warn
      else
        :info
      end
    end

    def trace_id
      return unless defined?(OpenTelemetry)
      OpenTelemetry::Trace.current_span.trace_id
    rescue
      nil
    end

    def request_id
      RequestStore.store[:request_id] if defined?(RequestStore)
    end

    def user_id
      CurrentAttributes.user_id if defined?(CurrentAttributes)
    end
  end
end
```

**File:** `config/initializers/smolagents_logging.rb`

```ruby
# Set up structured logging
logger = Smolagents::Logging::StructuredLogger.new(
  format: Rails.env.production? ? :json : :text,
  output: Rails.logger.instance_variable_get(:@logdev).dev,
  include_context: true
)

# Subscribe to all events
Smolagents::Events::Emitter.subscribe do |event|
  logger.log_event(event)
end
```

---

## 8. Error Classification and Retry Strategy

**File:** `lib/smolagents/concerns/resilience/error_classifier.rb`

```ruby
module Smolagents::Concerns::Resilience
  class ErrorClassifier
    RETRIABLE_ERRORS = [
      Net::OpenTimeout,
      Net::ReadTimeout,
      Net::WriteTimeout,
      Errno::ECONNREFUSED,
      Errno::ECONNRESET,
      Errno::EHOSTUNREACH
    ].freeze

    def self.retriable?(error)
      case error
      when *RETRIABLE_ERRORS
        true
      when Smolagents::RateLimitError
        true
      when Smolagents::ServiceUnavailableError
        true
      when Smolagents::AuthenticationError, Smolagents::ValidationError
        false
      else
        false
      end
    end

    def self.backoff_for(error)
      case error
      when Smolagents::RateLimitError
        {
          initial_delay: 10,
          exponential_base: 2,
          max_delay: 300,  # 5 minutes
          jitter: true
        }
      when Net::OpenTimeout
        {
          initial_delay: 2,
          exponential_base: 2,
          max_delay: 60
        }
      else
        {
          initial_delay: 1,
          exponential_base: 2,
          max_delay: 60
        }
      end
    end

    def self.alert_on?(error)
      case error
      when Smolagents::AuthenticationError
        true  # Alert immediately on auth failures
      when Smolagents::RateLimitError
        false  # Normal, retry will handle
      when Smolagents::ValidationError
        true  # Invalid input should be reviewed
      else
        false
      end
    end
  end
end
```

**Usage:**

```ruby
model = Smolagents.model(:openai)
  .id("gpt-4")
  .with_retry(
    classify_error: Smolagents::Concerns::Resilience::ErrorClassifier.method(:retriable?),
    backoff: Smolagents::Concerns::Resilience::ErrorClassifier.method(:backoff_for)
  )
  .build

# Extend agent with error alerting
agent.on(Smolagents::Events::ErrorOccurred) do |event|
  if Smolagents::Concerns::Resilience::ErrorClassifier.alert_on?(event.error)
    AlertService.notify("Agent error", event.error.message)
  end
end
```

---

## 9. Production Checklist Implementation

**File:** `lib/smolagents/production/checklist.rb`

```ruby
module Smolagents::Production
  class Checklist
    REQUIRED_CHECKS = [
      :api_keys_configured,
      :retry_policy_set,
      :health_check_enabled,
      :logging_enabled,
      :telemetry_configured,
      :rate_limiting_enabled,
      :error_handling_verified,
      :cost_tracking_enabled
    ].freeze

    def self.verify
      puts "="* 60
      puts "smolagents-ruby Production Readiness Checklist"
      puts "="* 60

      results = {}
      REQUIRED_CHECKS.each do |check|
        passed = public_send("check_#{check}")
        results[check] = passed
        status = passed ? "✓" : "✗"
        puts "[#{status}] #{format_check_name(check)}"
      end

      puts "="* 60
      passed = results.values.all?
      puts passed ? "✓ All checks passed!" : "✗ Some checks failed"
      results
    end

    private

    def self.check_api_keys_configured
      ENV['OPENAI_API_KEY'].present? || ENV['ANTHROPIC_API_KEY'].present?
    end

    def self.check_retry_policy_set
      Smolagents.config.retry_max_attempts >= 2
    end

    def self.check_health_check_enabled
      # Check if health endpoint is configured
      Rails.application.routes.routes.any? { |r| r.path.include?('health') }
    rescue
      false
    end

    def self.check_logging_enabled
      Smolagents.config.enable_logging == true
    end

    def self.check_telemetry_configured
      defined?(OpenTelemetry) || Smolagents::Telemetry::LoggingSubscriber.enabled?
    end

    def self.check_rate_limiting_enabled
      # Add logic to check rate limiting config
      true
    end

    def self.check_error_handling_verified
      # Add logic to verify error handling is set up
      true
    end

    def self.check_cost_tracking_enabled
      # Add logic to check cost tracking
      true
    end

    def self.format_check_name(name)
      name.to_s.humanize
    end
  end
end
```

**Usage:**

```ruby
# In config/initializers/smolagents.rb
if Rails.env.production?
  Smolagents::Production::Checklist.verify
end

# Or manually run
rake smolagents:verify_production_readiness
```

---

## 10. Cost Tracking Module

**File:** `lib/smolagents/production/cost_tracker.rb`

```ruby
module Smolagents::Production
  class CostTracker
    PRICING = {
      'gpt-4' => { input: 0.03 / 1000, output: 0.06 / 1000 },
      'gpt-4-turbo' => { input: 0.01 / 1000, output: 0.03 / 1000 },
      'gpt-3.5-turbo' => { input: 0.0005 / 1000, output: 0.0015 / 1000 },
      'claude-3-opus' => { input: 0.015 / 1000, output: 0.075 / 1000 },
      'claude-3-sonnet' => { input: 0.003 / 1000, output: 0.015 / 1000 }
    }.freeze

    def self.configure(pricing_map = {})
      PRICING.merge!(pricing_map)
    end

    def self.subscribe
      Smolagents::Events::Emitter.subscribe(:model_generate_completed) do |event|
        cost = calculate_cost(event.model_id, event.input_tokens, event.output_tokens)
        track_cost(cost, event)
      end
    end

    def self.calculate_cost(model_id, input_tokens, output_tokens)
      rates = PRICING[model_id] || {}
      (input_tokens * (rates[:input] || 0)) + (output_tokens * (rates[:output] || 0))
    end

    private

    def self.track_cost(cost, event)
      # Log to cost tracking service
      logger.info("Model call cost", {
        model_id: event.model_id,
        input_tokens: event.input_tokens,
        output_tokens: event.output_tokens,
        cost: cost
      })

      # Update user spend if available
      if defined?(Current) && Current.user
        Current.user.increment_total_spend(cost)
      end

      # Alert if exceeds threshold
      if cost > 1.0  # $1 per call is high
        AlertService.warn("High cost API call", cost:)
      end
    end

    def self.logger
      @logger ||= Logger.new(STDOUT)
    end
  end
end
```

**Usage:**

```ruby
# config/initializers/smolagents.rb
if Rails.env.production?
  Smolagents::Production::CostTracker.configure(
    'gpt-4' => { input: 0.03 / 1000, output: 0.06 / 1000 }
  )
  Smolagents::Production::CostTracker.subscribe
end
```

---

## 11. RSpec Testing Helpers

**File:** `spec/support/smolagents_helpers.rb`

```ruby
module SmolagentsHelpers
  def mock_model(responses: [])
    Smolagents::Testing::MockModel.new(
      responses:,
      delay: 0.01  # Don't slow down tests
    )
  end

  def build_agent(model: nil, tools: [], persona: nil)
    builder = Smolagents.agent
    builder = builder.model { model } if model
    builder = builder.tools(*tools) if tools.any?
    builder = builder.as(persona) if persona
    builder.build
  end

  def stub_model_response(model, response)
    allow(model).to receive(:generate).and_return(response)
  end

  def expect_tool_called(agent, tool_name)
    expect(agent).to have_run_tool(tool_name)
  end
end

RSpec.configure do |config|
  config.include SmolagentsHelpers
end
```

**Usage in specs:**

```ruby
describe MyAgent do
  let(:model) { mock_model(responses: ['answer(text: "response")']) }
  let(:agent) { build_agent(model:, tools: [:search]) }

  it 'uses tools' do
    result = agent.run("Find something")
    expect_tool_called(agent, :search)
    expect(result.output).to include("response")
  end
end
```

---

## 12. VCR Configuration for API Recording

**File:** `spec/support/vcr.rb`

```ruby
require 'vcr'

VCR.configure do |config|
  config.cassette_library_dir = 'spec/cassettes'
  config.hook_into :faraday
  config.allow_http_connections_when_no_cassette = false

  # Redact sensitive data
  config.define_cassette_placeholder('<OPENAI_API_KEY>', ENV['OPENAI_API_KEY'])
  config.define_cassette_placeholder('<ANTHROPIC_API_KEY>', ENV['ANTHROPIC_API_KEY'])

  # Record mode configuration
  config.default_cassette_options = {
    record: ENV['SMOLAGENTS_RECORD_CASSETTES'] ? :all : :none,
    match_requests_on: [:method, :uri],
    allow_playback_repeats: true
  }
end

# Usage in specs
RSpec.configure do |config|
  config.around(:each, type: :integration) do |example|
    name = example.metadata[:cassette] || example.full_description
    VCR.use_cassette(name) { example.run }
  end
end
```

**Usage in tests:**

```ruby
describe 'Agent integration', type: :integration do
  it 'generates response from real API', cassette: 'gpt4_response' do
    model = Smolagents::OpenAIModel.new(api_key: ENV['OPENAI_API_KEY'])
    response = model.generate("What is 2+2?")
    expect(response).to include("4")
  end
end
```

---

## Quick Implementation Checklist

- [ ] Copy `config/initializers/smolagents.rb` template
- [ ] Add `config/credentials.yml.enc` smolagents section
- [ ] Create health check endpoint
- [ ] Create agent execution model and migration
- [ ] Set up ActionCable integration (optional)
- [ ] Configure logging/telemetry
- [ ] Set up error classification
- [ ] Add cost tracking
- [ ] Create RSpec helpers
- [ ] Run production readiness checklist

---

**All examples are Rails-focused and assume Rails 7.0+**
