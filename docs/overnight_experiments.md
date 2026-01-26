# Overnight Experiment Runner Guide

Build autonomous experiment systems that run overnight, collect LLM interaction data, and survive crashes gracefully using the `smolagents` gem.

## Overview

This guide covers building a self-contained experiment runner for:

- **Model comparison** - Test multiple models against the same tasks
- **Capability testing** - Evaluate agent behaviors with mocked tools
- **Data collection** - Capture all LLM interactions for analysis
- **Autonomous operation** - Run unattended with crash recovery

## Prerequisites

```ruby
# Gemfile
gem "smolagents"
```

## Architecture

```
my_experiments/
├── Gemfile
├── runner.rb                 # Main entry point
├── lib/
│   ├── experiment.rb         # Experiment DSL
│   ├── supervisor.rb         # Process management
│   ├── queue.rb              # Job queue
│   ├── checkpoint.rb         # State persistence
│   └── logger.rb             # JSONL logging
├── definitions/              # Your experiments
│   ├── model_comparison.rb
│   └── capability_matrix.rb
└── data/
    ├── pending/              # Queued jobs
    ├── running/              # In progress
    ├── completed/            # Finished
    ├── failed/               # Exceeded retries
    └── logs/                 # JSONL output
```

## Quick Start

### 1. Define an Experiment

```ruby
# definitions/model_comparison.rb
require_relative "../lib/experiment"

Experiment.define(:model_comparison) do
  description "Compare local models on reasoning tasks"

  # Models to test
  models do
    add :glm, -> { Smolagents::OpenAIModel.lm_studio("glm-4-9b-chat") }
    add :nemotron, -> { Smolagents::OpenAIModel.lm_studio("nemotron-mini") }
  end

  # Mock tools for controlled testing
  tools do
    mock :search do |query:|
      "Search results for: #{query}"
    end

    mock :calculate do |expression:|
      eval(expression).to_s  # Simple calculator
    rescue
      "Error: invalid expression"
    end
  end

  # Test tasks
  tasks do
    task "What is 15 * 7?",
         expect: "105",
         tags: [:arithmetic]

    task "Search for Ruby 3.3 features and summarize",
         validate: ->(output) { output.include?("search") },
         tags: [:tool_use]

    task "Calculate the factorial of 5 step by step",
         expect: "120",
         tags: [:reasoning, :arithmetic]
  end

  # Run configuration
  config do
    iterations 5           # Run each task 5 times per model
    timeout 120            # 2 minutes per task
    max_steps 10           # Agent step limit
    checkpoint_every 1     # Save after each iteration
  end
end
```

### 2. Create the Runner

```ruby
#!/usr/bin/env ruby
# runner.rb
require "bundler/setup"
require "smolagents"
require_relative "lib/supervisor"
require_relative "lib/queue"
require_relative "lib/logger"

# Load experiment definitions
Dir["definitions/*.rb"].each { |f| require_relative f }

supervisor = Supervisor.new(
  data_dir: "data",
  heartbeat_interval: 30
)

supervisor.run do |job|
  experiment = Experiment.registry[job[:experiment_id]]
  ExperimentRunner.new(experiment, logger: job[:logger]).execute
end
```

### 3. Run Overnight

```bash
# Start the runner
./runner.rb

# Check status (from another terminal)
kill -USR1 $(cat data/running/runner.pid)

# Graceful shutdown
kill -TERM $(cat data/running/runner.pid)
```

## Core Components

### Experiment DSL

```ruby
# lib/experiment.rb
module Experiment
  @registry = {}

  def self.define(name, &block)
    definition = Definition.new(name)
    definition.instance_eval(&block)
    @registry[name] = definition
  end

  def self.registry
    @registry
  end

  class Definition
    attr_reader :name, :model_factories, :mock_tools, :task_list, :settings

    def initialize(name)
      @name = name
      @model_factories = {}
      @mock_tools = {}
      @task_list = []
      @settings = { iterations: 1, timeout: 60, max_steps: 10, checkpoint_every: 1 }
    end

    def description(text = nil)
      text ? @description = text : @description
    end

    def models(&block)
      ModelDSL.new(@model_factories).instance_eval(&block)
    end

    def tools(&block)
      ToolDSL.new(@mock_tools).instance_eval(&block)
    end

    def tasks(&block)
      TaskDSL.new(@task_list).instance_eval(&block)
    end

    def config(&block)
      ConfigDSL.new(@settings).instance_eval(&block)
    end
  end

  class ModelDSL
    def initialize(registry)
      @registry = registry
    end

    def add(name, factory)
      @registry[name] = factory
    end
  end

  class ToolDSL
    def initialize(registry)
      @registry = registry
    end

    def mock(name, &block)
      @registry[name] = MockTool.new(name, &block)
    end
  end

  class TaskDSL
    def initialize(list)
      @list = list
    end

    def task(prompt, expect: nil, validate: nil, tags: [])
      @list << { prompt:, expect:, validate:, tags: }
    end
  end

  class ConfigDSL
    def initialize(settings)
      @settings = settings
    end

    def method_missing(name, value)
      @settings[name] = value
    end
  end
end
```

### Mock Tools

Create controlled tool responses for reproducible experiments:

```ruby
# lib/mock_tool.rb
class MockTool < Smolagents::Tools::Tool
  attr_reader :calls

  def initialize(name, &block)
    @tool_name = name
    @handler = block
    @calls = []
    @mutex = Mutex.new
  end

  def execute(**kwargs)
    @mutex.synchronize { @calls << { kwargs:, timestamp: Time.now } }
    @handler.call(**kwargs)
  end

  def call_count
    @calls.size
  end

  def reset!
    @mutex.synchronize { @calls.clear }
  end
end
```

### Process Supervisor

Handles crash recovery and graceful shutdown:

```ruby
# lib/supervisor.rb
class Supervisor
  STALE_THRESHOLD = 90  # seconds

  def initialize(data_dir:, heartbeat_interval: 30)
    @data_dir = Pathname(data_dir)
    @heartbeat_interval = heartbeat_interval
    @shutdown_requested = false
    @current_job = nil

    setup_directories
    setup_signals
  end

  def run(&block)
    acquire_lock
    start_heartbeat

    recover_orphaned_jobs
    queue = JobQueue.new(@data_dir)

    while (job = queue.next) && !@shutdown_requested
      @current_job = job
      execute_job(job, &block)
      @current_job = nil
    end

    cleanup
  end

  private

  def setup_directories
    %w[pending running completed failed logs].each do |dir|
      (@data_dir / dir).mkpath
    end
  end

  def setup_signals
    Signal.trap("TERM") { request_shutdown }
    Signal.trap("INT") { request_shutdown }
    Signal.trap("USR1") { report_status }
  end

  def request_shutdown
    @shutdown_requested = true
    warn "\nShutdown requested, finishing current job..."
  end

  def report_status
    status = {
      pid: Process.pid,
      uptime: Time.now - @start_time,
      current_job: @current_job&.dig(:id),
      shutdown_requested: @shutdown_requested
    }
    warn "\n#{JSON.pretty_generate(status)}"
  end

  def acquire_lock
    pid_file = @data_dir / "running" / "runner.pid"

    if pid_file.exist?
      existing_pid = pid_file.read.to_i
      if process_alive?(existing_pid) && heartbeat_fresh?
        raise "Another runner is active (PID #{existing_pid})"
      end
      warn "Recovering from stale lock (PID #{existing_pid})"
    end

    pid_file.write(Process.pid.to_s)
    @start_time = Time.now
  end

  def start_heartbeat
    @heartbeat_file = @data_dir / "running" / "heartbeat"
    @heartbeat_thread = Thread.new do
      loop do
        @heartbeat_file.write(Time.now.iso8601)
        sleep @heartbeat_interval
      rescue
        break
      end
    end
  end

  def heartbeat_fresh?
    return false unless @heartbeat_file&.exist?
    Time.now - @heartbeat_file.mtime < STALE_THRESHOLD
  end

  def process_alive?(pid)
    Process.kill(0, pid)
    true
  rescue Errno::ESRCH
    false
  end

  def recover_orphaned_jobs
    (@data_dir / "running").glob("*.json").each do |job_file|
      warn "Recovering orphaned job: #{job_file.basename}"
      FileUtils.mv(job_file, @data_dir / "pending")
    end
  end

  def execute_job(job)
    job_file = @data_dir / "pending" / "#{job[:id]}.json"
    running_file = @data_dir / "running" / "#{job[:id]}.json"

    # Atomic move to running
    FileUtils.mv(job_file, running_file)

    logger = ExperimentLogger.new(@data_dir / "logs", job[:id])

    begin
      yield job.merge(logger:)
      FileUtils.mv(running_file, @data_dir / "completed")
    rescue => error
      logger.error(error)
      FileUtils.mv(running_file, @data_dir / "failed")
    end
  end

  def cleanup
    (@data_dir / "running" / "runner.pid").delete rescue nil
    @heartbeat_file&.delete rescue nil
    @heartbeat_thread&.kill
  end
end
```

### Job Queue

File-based queue with atomic operations:

```ruby
# lib/queue.rb
class JobQueue
  def initialize(data_dir)
    @pending_dir = Pathname(data_dir) / "pending"
  end

  def enqueue(experiment_id, priority: 0)
    job = {
      id: "#{experiment_id}_#{Time.now.strftime('%Y%m%d_%H%M%S')}_#{SecureRandom.hex(4)}",
      experiment_id:,
      priority:,
      created_at: Time.now.iso8601
    }

    # Atomic write via temp file
    temp = @pending_dir / ".#{job[:id]}.tmp"
    target = @pending_dir / "#{job[:id]}.json"

    temp.write(JSON.pretty_generate(job))
    File.rename(temp, target)

    job[:id]
  end

  def next
    jobs = @pending_dir.glob("*.json").sort_by do |f|
      data = JSON.parse(f.read, symbolize_names: true)
      [-data[:priority], data[:created_at]]
    end

    return nil if jobs.empty?

    JSON.parse(jobs.first.read, symbolize_names: true)
  end

  def pending_count
    @pending_dir.glob("*.json").size
  end
end
```

### JSONL Logger

Captures all LLM interactions with immediate flush:

```ruby
# lib/logger.rb
class ExperimentLogger
  def initialize(logs_dir, run_id)
    @run_dir = Pathname(logs_dir) / Time.now.strftime("%Y-%m-%d") / run_id
    @run_dir.mkpath

    @traces = File.open(@run_dir / "traces.jsonl", "a")
    @events = File.open(@run_dir / "events.jsonl", "a")
    @counter = 0
    @mutex = Mutex.new
  end

  def trace(data)
    write(@traces, data.merge(
      trace_id: @trace_id,
      span_id: SecureRandom.hex(8),
      sequence: next_sequence
    ))
  end

  def event(type, data = {})
    write(@events, data.merge(
      type:,
      trace_id: @trace_id,
      timestamp: Time.now.iso8601
    ))
  end

  def error(err)
    event(:error, {
      error_class: err.class.name,
      message: err.message,
      backtrace: err.backtrace&.first(10)
    })
  end

  def with_trace(trace_id = SecureRandom.hex(16))
    previous = @trace_id
    @trace_id = trace_id
    yield
  ensure
    @trace_id = previous
  end

  def close
    @traces.close
    @events.close
  end

  private

  def write(file, data)
    @mutex.synchronize do
      file.puts(JSON.generate(data))
      file.flush
    end
  end

  def next_sequence
    @mutex.synchronize { @counter += 1 }
  end
end
```

### Experiment Runner

Executes experiments using smolagents:

```ruby
# lib/experiment_runner.rb
class ExperimentRunner
  def initialize(experiment, logger:)
    @experiment = experiment
    @logger = logger
    @checkpoints = {}
  end

  def execute
    @experiment.model_factories.each do |model_name, factory|
      run_model(model_name, factory)
    end
  end

  private

  def run_model(model_name, factory)
    model = factory.call
    tools = @experiment.mock_tools.values

    @experiment.settings[:iterations].times do |iteration|
      @experiment.task_list.each do |task|
        run_task(model_name, model, tools, task, iteration)
      end

      checkpoint(model_name, iteration)
    end
  end

  def run_task(model_name, model, tools, task, iteration)
    @logger.with_trace do
      @logger.event(:task_start, {
        model: model_name,
        iteration:,
        task: task[:prompt],
        tags: task[:tags]
      })

      agent = build_agent(model, tools)
      subscribe_to_events(agent)

      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      begin
        result = Timeout.timeout(@experiment.settings[:timeout]) do
          agent.run(task[:prompt])
        end

        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

        @logger.event(:task_complete, {
          model: model_name,
          iteration:,
          result: result.to_s,
          duration_ms: (duration * 1000).round,
          passed: validate_result(result, task)
        })
      rescue => error
        @logger.error(error)
        @logger.event(:task_failed, { model: model_name, iteration: })
      end
    end
  end

  def build_agent(model, tools)
    builder = Smolagents.agent.model { model }.max_steps(@experiment.settings[:max_steps])
    tools.each { |tool| builder = builder.tools(tool) }
    builder.build
  end

  def subscribe_to_events(agent)
    agent.on(:model_generate_completed) do |event|
      @logger.trace({
        type: :llm_call,
        model_id: event.model_id,
        input_tokens: event.token_usage&.input,
        output_tokens: event.token_usage&.output,
        duration_ms: event.duration_ms,
        messages: event.messages,
        response: event.response
      })
    end

    agent.on(:tool_complete) do |event|
      @logger.trace({
        type: :tool_call,
        tool_name: event.tool_name,
        arguments: event.arguments,
        result: event.result,
        duration_ms: event.duration_ms
      })
    end
  end

  def validate_result(result, task)
    if task[:validate]
      task[:validate].call(result.to_s)
    elsif task[:expect]
      result.to_s.include?(task[:expect])
    else
      true
    end
  end

  def checkpoint(model_name, iteration)
    return unless (iteration + 1) % @experiment.settings[:checkpoint_every] == 0

    @logger.event(:checkpoint, {
      model: model_name,
      iteration:,
      timestamp: Time.now.iso8601
    })
  end
end
```

## Queueing Experiments

```ruby
# Queue experiments for overnight run
queue = JobQueue.new("data")

# High priority - run first
queue.enqueue(:model_comparison, priority: 10)

# Normal priority
queue.enqueue(:capability_matrix, priority: 0)

puts "Queued #{queue.pending_count} experiments"
```

## Analyzing Results

### Load JSONL Logs

```ruby
require "json"

def load_traces(run_dir)
  File.readlines(File.join(run_dir, "traces.jsonl")).map do |line|
    JSON.parse(line, symbolize_names: true)
  end
end

traces = load_traces("data/logs/2026-01-25/model_comparison_20260125_220000_abc1")

# Filter LLM calls
llm_calls = traces.select { |t| t[:type] == :llm_call }

# Token usage by model
llm_calls.group_by { |t| t[:model_id] }.transform_values do |calls|
  {
    total_input: calls.sum { |c| c[:input_tokens] || 0 },
    total_output: calls.sum { |c| c[:output_tokens] || 0 },
    avg_duration_ms: calls.sum { |c| c[:duration_ms] || 0 } / calls.size
  }
end
```

### Generate Summary Report

```ruby
def summarize_run(run_dir)
  events = File.readlines(File.join(run_dir, "events.jsonl")).map do |line|
    JSON.parse(line, symbolize_names: true)
  end

  completions = events.select { |e| e[:type] == "task_complete" }

  completions.group_by { |e| e[:model] }.transform_values do |tasks|
    passed = tasks.count { |t| t[:passed] }
    {
      total: tasks.size,
      passed:,
      failed: tasks.size - passed,
      pass_rate: (passed.to_f / tasks.size * 100).round(1),
      avg_duration_ms: tasks.sum { |t| t[:duration_ms] } / tasks.size
    }
  end
end
```

## Best Practices

### 1. Mock Tools for Reproducibility

Real tools (web search, file access) introduce variability. Mock tools give you:
- Deterministic responses for comparing models
- Control over edge cases and error conditions
- Faster execution (no network delays)

### 2. Capture Everything

Log more than you think you need:
- Full message history enables replay
- Token counts help understand costs
- Timing data reveals performance issues

### 3. Checkpoint Frequently

With `checkpoint_every: 1`, you lose at most one iteration on crash. The trade-off is more disk writes, but for overnight runs this is negligible.

### 4. Use Priorities

Queue critical experiments with higher priority:
```ruby
queue.enqueue(:critical_test, priority: 100)
queue.enqueue(:nice_to_have, priority: 0)
```

### 5. Monitor with Signals

```bash
# Check status without interrupting
kill -USR1 $(cat data/running/runner.pid)

# Watch logs in real-time
tail -f data/logs/*/traces.jsonl | jq .
```

## Troubleshooting

### Runner Won't Start

```
Another runner is active (PID 12345)
```

Either another runner is running, or it crashed without cleanup:
```bash
# Check if process exists
ps -p 12345

# If not, remove stale lock
rm data/running/runner.pid data/running/heartbeat
```

### Jobs Stuck in Running

Jobs in `data/running/` with stale heartbeats are automatically recovered on next runner start. To force recovery:

```bash
mv data/running/*.json data/pending/
```

### Incomplete Logs

If logs are truncated, the runner likely crashed mid-write. JSONL format means only the last line may be corrupted:

```bash
# Remove last incomplete line
head -n -1 traces.jsonl > traces_clean.jsonl
```
