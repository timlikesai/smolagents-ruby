# RubyAgents: An Idiomatic Ruby Port of smolagents

## Design Document v1.0

**Author:** Claude (AI Assistant)  
**Date:** January 2026  
**Target Ruby Version:** 3.4+ (with forward-looking design toward 4.x)

---

## Executive Summary

This document outlines the design for **RubyAgents**, an idiomatic Ruby implementation inspired by HuggingFace's smolagents Python library. Rather than a direct port, this design leverages Ruby's unique strengths—expressive DSLs, blocks, metaprogramming, pattern matching, and the emerging Ractor concurrency model—to create a framework that feels native to Ruby while maintaining the core philosophy of smolagents: simplicity, code-first agents, and minimal abstractions.

The key differentiator: **a unified DSL that works identically whether you're defining agents at development time or whether agents are spawning sub-agents at runtime**. This "turtles all the way down" approach enables true recursive agent architectures.

---

## 1. Architecture Overview

### 1.1 Core Philosophy (Inherited from smolagents)

- **Simplicity**: Core logic fits in ~1,000 lines (smolagents achieves this in `agents.py`)
- **Code Agents**: Agents write Ruby code as their actions, not JSON blobs
- **Minimal Abstractions**: Thin wrappers over raw code
- **Model Agnostic**: Support any LLM via adapter pattern
- **Tool Agnostic**: Tools from MCP, custom code, or external services

### 1.2 Ruby-Specific Enhancements

- **DSL-First Design**: Configuration and agent definition via expressive Ruby DSLs
- **Block-Based Composition**: Leverage Ruby's blocks for tool definitions and agent workflows
- **Pattern Matching**: Use Ruby 3.x pattern matching for message routing and result handling
- **Ractor-Ready**: Design for safe parallelism with Ractor boundaries in mind
- **Type Signatures**: Optional RBS type annotations for tooling support

### 1.3 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        RubyAgents                                │
├─────────────────────────────────────────────────────────────────┤
│  DSL Layer                                                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │ Agent DSL   │ │ Tool DSL    │ │ Workflow DSL│                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
├─────────────────────────────────────────────────────────────────┤
│  Core Components                                                 │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │ CodeAgent   │ │ ToolCalling │ │ Memory/     │ │ Executor   │ │
│  │             │ │ Agent       │ │ State       │ │ (Sandbox)  │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│  Adapters                                                        │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                │
│  │ Model       │ │ Tool        │ │ Executor    │                │
│  │ Adapters    │ │ Adapters    │ │ Adapters    │                │
│  │ (LLM)       │ │ (MCP, etc)  │ │ (Docker,etc)│                │
│  └─────────────┘ └─────────────┘ └─────────────┘                │
└─────────────────────────────────────────────────────────────────┘
```

---

## 2. DSL Design

### 2.1 Agent Definition DSL

The agent DSL should feel natural to Ruby developers, similar to how RSpec or Rails routing works.

```ruby
# Define an agent
agent = RubyAgents.define do
  name "research_assistant"
  description "An agent that researches topics and summarizes findings"
  
  model :anthropic, "claude-sonnet-4-20250514" do
    temperature 0.7
    max_tokens 4096
  end
  
  # Tools can be defined inline
  tool :web_search do
    description "Search the web for information"
    input :query, String, required: true, desc: "Search query"
    output String
    
    perform do |query:|
      # Implementation
      WebSearch.query(query)
    end
  end
  
  # Or reference existing tools
  tools WebSearchTool, VisitWebpageTool
  
  # Configure execution
  max_steps 10
  executor :local  # or :docker, :e2b, :wasm
  
  # Planning interval (for ReAct loop enhancement)
  planning_interval 3
end

# Run the agent
result = agent.run("What are the latest developments in Ruby 4?")
```

### 2.2 Tool Definition DSL

Tools are first-class citizens with their own expressive DSL.

```ruby
# Method 1: Class-based tool (for complex tools)
class WebSearchTool < RubyAgents::Tool
  name "web_search"
  description "Performs web searches and returns results"
  
  input :query, String, required: true
  input :num_results, Integer, default: 10
  output Array[Hash]
  
  def forward(query:, num_results: 10)
    # Implementation
  end
end

# Method 2: Block-based tool (for simple tools)
search_tool = RubyAgents.tool(:search) do
  description "Quick search"
  input :q, String
  output String
  
  perform { |q:| SearchAPI.search(q) }
end

# Method 3: Lambda/Proc conversion with type inference
# Uses Ruby's method introspection for automatic documentation
get_weather = ->(city: String) -> String {
  WeatherAPI.get(city)
}.to_tool(
  name: "get_weather",
  description: "Gets weather for a city"
)

# Method 4: Decorator-style (using refinements)
using RubyAgents::ToolRefinements

def calculate_distance(from:, to:, unit: :km)
  # Implementation
end.as_tool(description: "Calculate distance between two points")
```

### 2.3 Multi-Agent/Orchestration DSL

The same DSL works for defining managed agents and hierarchies.

```ruby
# Define a multi-agent system
system = RubyAgents.orchestrate do
  # Define specialized agents
  web_agent = agent(:web_researcher) do
    description "Searches the web"
    tools WebSearchTool, VisitWebpageTool
    model :anthropic, "claude-sonnet-4-20250514"
    max_steps 10
  end
  
  code_agent = agent(:code_executor) do
    description "Executes Python/Ruby code"
    tools PythonInterpreterTool, RubyInterpreterTool
    model :anthropic, "claude-sonnet-4-20250514"
    executor :docker
  end
  
  # Define the manager agent
  manager = agent(:manager) do
    description "Coordinates research and code execution"
    model :anthropic, "claude-sonnet-4-20250514"
    
    # Managed agents become callable tools
    managed_agents web_agent, code_agent
    
    # Manager can also have direct tools
    tools FinalAnswerTool
    
    max_steps 20
    planning_interval 5
  end
  
  # Set the entry point
  entrypoint manager
end

# Run the system
result = system.run("Analyze Ruby 3.4 performance benchmarks")
```

### 2.4 Self-Spawning Agents (The Key Innovation)

Agents can spawn sub-agents using the **exact same DSL**. This is critical for recursive agent architectures.

```ruby
# A coding agent that can spawn helper agents
coding_agent = RubyAgents.define do
  name "coding_agent"
  
  model :anthropic, "claude-sonnet-4-20250514"
  
  # This tool allows the agent to spawn sub-agents
  tool :spawn_agent do
    description "Create a specialized sub-agent to handle a subtask"
    input :task_description, String
    input :agent_spec, String  # Ruby DSL code defining the agent
    output String
    
    perform do |task_description:, agent_spec:|
      # The agent writes Ruby DSL code that gets evaluated
      # Same DSL it was defined with!
      sub_agent = RubyAgents.eval_dsl(agent_spec)
      sub_agent.run(task_description)
    end
  end
  
  # Enable the agent to write agent definitions
  additional_imports ["ruby_agents"]
end
```

The LLM can then generate code like:

```ruby
# Generated by the agent at runtime
sub_agent = RubyAgents.define do
  name "data_analyzer"
  tools DataLoadTool, StatsTool
  model :anthropic, "claude-haiku-4-20250414"  # Use cheaper model for subtask
  max_steps 5
end

result = sub_agent.run("Analyze the CSV data and return summary statistics")
```

---

## 3. Core Components

### 3.1 Agent Base Classes

```ruby
module RubyAgents
  # Abstract base for all agents
  class MultiStepAgent
    attr_reader :name, :description, :tools, :model, :memory, :state
    
    def initialize(**options, &block)
      @name = options[:name]
      @tools = ToolRegistry.new
      @memory = Memory.new
      @state = {}
      @max_steps = options.fetch(:max_steps, 10)
      @planning_interval = options[:planning_interval]
      
      instance_eval(&block) if block_given?
    end
    
    def run(task, **additional_args)
      @state.merge!(additional_args)
      initialize_system_prompt
      
      Enumerator.new do |yielder|
        (1..@max_steps).each do |step|
          plan_if_needed(step)
          
          step_result = execute_step(step)
          yielder << step_result
          
          break if step_result.final_answer?
        end
      end
    end
    
    protected
    
    def execute_step(step_number)
      raise NotImplementedError
    end
  end
  
  # Code-writing agent (primary agent type)
  class CodeAgent < MultiStepAgent
    def initialize(**options, &block)
      super
      @executor = build_executor(options[:executor] || :local)
      @authorized_imports = options.fetch(:additional_imports, [])
    end
    
    protected
    
    def execute_step(step_number)
      # 1. Generate code from LLM
      llm_output = @model.generate(build_messages)
      
      # 2. Parse code from output
      code = parse_code_blob(llm_output)
      
      # 3. Execute code in sandbox
      result = @executor.run(code, tools: @tools, state: @state)
      
      # 4. Record observation
      @memory.record(StepLog.new(
        step: step_number,
        thought: llm_output.thought,
        code: code,
        observation: result.output,
        is_final: result.final_answer?
      ))
      
      result
    end
  end
  
  # JSON/structured tool-calling agent
  class ToolCallingAgent < MultiStepAgent
    protected
    
    def execute_step(step_number)
      # Uses model's native tool calling (function calling)
      llm_output = @model.generate_with_tools(
        build_messages,
        tools: @tools.to_schema
      )
      
      # Execute tool calls
      results = llm_output.tool_calls.map do |call|
        tool = @tools.fetch(call.name)
        tool.call(**call.arguments)
      end
      
      # Record and return
      # ...
    end
  end
end
```

### 3.2 Memory and State Management

```ruby
module RubyAgents
  class Memory
    include Enumerable
    
    def initialize
      @steps = []
      @system_prompt = nil
    end
    
    def record(step_log)
      @steps << step_log
      step_log.freeze  # Immutable history
    end
    
    def each(&block)
      @steps.each(&block)
    end
    
    # Convert to messages for LLM
    def to_messages
      messages = [{ role: :system, content: @system_prompt }]
      
      @steps.each do |step|
        messages << { role: :assistant, content: step.format_assistant }
        messages << { role: :user, content: step.format_observation }
      end
      
      messages
    end
    
    # Pattern matching support for querying history
    def find_pattern(pattern)
      @steps.select do |step|
        case step
        in pattern
          true
        else
          false
        end
      end
    end
  end
  
  # Immutable step record
  StepLog = Data.define(
    :step, :thought, :code, :observation, 
    :tool_calls, :error, :is_final
  ) do
    def final_answer? = is_final
    
    def format_assistant
      if code
        "Thought: #{thought}\n\nCode:\n```ruby\n#{code}\n```"
      else
        "Thought: #{thought}\n\nTool calls: #{tool_calls.inspect}"
      end
    end
    
    def format_observation
      "Observation: #{observation}"
    end
  end
end
```

### 3.3 Tool System

```ruby
module RubyAgents
  class Tool
    class << self
      attr_accessor :tool_name, :tool_description, :inputs, :output_type
      
      def name(n = nil)
        n ? @tool_name = n : @tool_name
      end
      
      def description(d = nil)
        d ? @tool_description = d : @tool_description
      end
      
      def input(name, type, required: false, default: nil, desc: nil)
        @inputs ||= {}
        @inputs[name] = InputSpec.new(name, type, required, default, desc)
      end
      
      def output(type)
        @output_type = type
      end
    end
    
    # Instance method that subclasses implement
    def forward(**kwargs)
      raise NotImplementedError, "Subclasses must implement #forward"
    end
    
    def call(**kwargs)
      validated = validate_inputs(kwargs)
      result = forward(**validated)
      validate_output(result)
    end
    
    # Convert to JSON schema for LLM tool calling
    def to_schema
      {
        name: self.class.tool_name,
        description: self.class.tool_description,
        parameters: {
          type: "object",
          properties: inputs_to_properties,
          required: required_inputs
        }
      }
    end
    
    # Convert to Ruby code representation for CodeAgent
    def to_code_definition
      <<~RUBY
        def #{self.class.tool_name}(#{signature_params})
          """#{self.class.tool_description}
          
          Args:
          #{args_documentation}
          
          Returns:
              #{self.class.output_type}
          """
          # Tool implementation - called via framework
        end
      RUBY
    end
  end
  
  # Block-based tool creation
  class BlockTool < Tool
    def initialize(name, &block)
      @name = name
      @config = ToolConfig.new
      @config.instance_eval(&block)
      
      self.class.name @name
      self.class.description @config.description
      @config.inputs.each { |i| self.class.input(*i) }
      self.class.output @config.output_type
      
      @perform_block = @config.perform_block
    end
    
    def forward(**kwargs)
      @perform_block.call(**kwargs)
    end
  end
  
  # Registry for managing tools
  class ToolRegistry
    include Enumerable
    
    def initialize
      @tools = {}
    end
    
    def register(tool)
      name = tool.is_a?(Class) ? tool.tool_name : tool.class.tool_name
      @tools[name.to_sym] = tool.is_a?(Class) ? tool.new : tool
    end
    
    def fetch(name)
      @tools.fetch(name.to_sym)
    end
    
    def each(&block)
      @tools.values.each(&block)
    end
    
    def to_schema
      map(&:to_schema)
    end
    
    def to_code_definitions
      map(&:to_code_definition).join("\n\n")
    end
  end
end
```

### 3.4 Code Execution / Sandboxing

```ruby
module RubyAgents
  module Executors
    # Base executor interface
    class Base
      def run(code, tools:, state:)
        raise NotImplementedError
      end
    end
    
    # Local Ruby execution with restricted environment
    class LocalExecutor < Base
      ALLOWED_CONSTANTS = %w[
        Array Hash String Integer Float Symbol 
        Range Regexp Time Date DateTime
        Math JSON YAML CSV
      ].freeze
      
      def initialize(authorized_imports: [])
        @authorized_imports = authorized_imports
        @sandbox = create_sandbox
      end
      
      def run(code, tools:, state:)
        # Inject tools as methods
        inject_tools(tools)
        
        # Inject state as local variables
        inject_state(state)
        
        # Execute in restricted binding
        begin
          result = @sandbox.eval(code)
          
          if result.is_a?(FinalAnswer)
            CodeOutput.new(output: result.value, is_final_answer: true)
          else
            CodeOutput.new(output: result.to_s, is_final_answer: false)
          end
        rescue => e
          CodeOutput.new(output: nil, error: e.message, is_final_answer: false)
        end
      end
      
      private
      
      def create_sandbox
        # Create isolated binding with restricted access
        sandbox = BasicObject.new
        
        # Add safe constants
        ALLOWED_CONSTANTS.each do |const|
          sandbox.define_singleton_method(const) { Object.const_get(const) }
        end
        
        # Add final_answer helper
        sandbox.define_singleton_method(:final_answer) do |value|
          FinalAnswer.new(value)
        end
        
        sandbox
      end
    end
    
    # Docker-based execution for full isolation
    class DockerExecutor < Base
      def initialize(image: "ruby:3.4-slim", **options)
        @image = image
        @container_manager = ContainerManager.new(image)
      end
      
      def run(code, tools:, state:)
        # Serialize tools and state
        payload = {
          code: code,
          tools: serialize_tools(tools),
          state: state
        }
        
        # Execute in container
        result = @container_manager.execute(payload)
        
        CodeOutput.new(**result)
      end
    end
    
    # Ractor-based parallel execution (experimental)
    class RactorExecutor < Base
      def run(code, tools:, state:)
        # Tools must be Ractor-shareable
        shareable_tools = tools.map(&:to_shareable)
        frozen_state = Ractor.make_shareable(state.deep_freeze)
        
        worker = Ractor.new(code, shareable_tools, frozen_state) do |c, t, s|
          sandbox = RactorSandbox.new(tools: t, state: s)
          sandbox.eval(c)
        end
        
        result = worker.take
        CodeOutput.new(**result)
      end
    end
  end
  
  CodeOutput = Data.define(:output, :logs, :is_final_answer, :error) do
    def initialize(output: nil, logs: "", is_final_answer: false, error: nil)
      super
    end
    
    def final_answer? = is_final_answer
    def success? = error.nil?
  end
  
  FinalAnswer = Data.define(:value)
end
```

### 3.5 Model Adapters

```ruby
module RubyAgents
  module Models
    class Base
      def generate(messages)
        raise NotImplementedError
      end
      
      def generate_with_tools(messages, tools:)
        raise NotImplementedError
      end
      
      def generate_stream(messages, &block)
        raise NotImplementedError
      end
    end
    
    class AnthropicModel < Base
      def initialize(model_id:, api_key: nil, **options)
        @model_id = model_id
        @api_key = api_key || ENV["ANTHROPIC_API_KEY"]
        @options = options
        @client = build_client
      end
      
      def generate(messages)
        response = @client.messages.create(
          model: @model_id,
          messages: format_messages(messages),
          **@options
        )
        
        parse_response(response)
      end
      
      def generate_with_tools(messages, tools:)
        response = @client.messages.create(
          model: @model_id,
          messages: format_messages(messages),
          tools: tools,
          **@options
        )
        
        parse_tool_response(response)
      end
    end
    
    class OpenAIModel < Base
      # Similar implementation for OpenAI
    end
    
    class OllamaModel < Base
      # Local model support via Ollama
    end
    
    class LiteLLMModel < Base
      # Multi-provider support via LiteLLM protocol
    end
    
    # Model factory
    def self.build(provider, model_id, **options)
      case provider
      when :anthropic then AnthropicModel.new(model_id: model_id, **options)
      when :openai then OpenAIModel.new(model_id: model_id, **options)
      when :ollama then OllamaModel.new(model_id: model_id, **options)
      when :litellm then LiteLLMModel.new(model_id: model_id, **options)
      else
        raise ArgumentError, "Unknown provider: #{provider}"
      end
    end
  end
end
```

---

## 4. Pattern Matching Integration

Ruby 3.x pattern matching enables elegant handling of agent results and routing.

```ruby
module RubyAgents
  class ResultHandler
    def handle(result)
      case result
      in FinalAnswer(value: String => answer)
        puts "Got text answer: #{answer}"
        
      in FinalAnswer(value: { data: Array => rows, summary: String => summary })
        puts "Got structured data: #{rows.size} rows"
        puts "Summary: #{summary}"
        
      in CodeOutput(error: String => err) if err.include?("timeout")
        retry_with_longer_timeout
        
      in CodeOutput(error: String => err)
        handle_error(err)
        
      in StepLog(tool_calls: [{ name: "web_search" }, *rest])
        puts "Agent performed web search"
        
      else
        puts "Unhandled result type"
      end
    end
  end
  
  # Pattern matching in memory queries
  class Memory
    def find_web_searches
      @steps.select do |step|
        case step
        in StepLog(tool_calls: [*, { name: "web_search", arguments: args }, *])
          true
        else
          false
        end
      end
    end
    
    def find_errors
      @steps.select { |s| s in StepLog(error: String) }
    end
  end
end
```

---

## 5. Concurrency Model

### 5.1 Fiber-Based Async (Default)

For I/O-bound operations (LLM calls, web requests), use Ruby's Fiber scheduler.

```ruby
module RubyAgents
  class AsyncAgent < CodeAgent
    def run_async(task, **args)
      Async do |task_context|
        run(task, **args).each do |step|
          yield step if block_given?
        end
      end
    end
  end
  
  # Parallel tool execution within a step
  class ParallelToolExecutor
    def execute_parallel(tool_calls)
      Async do |task|
        tool_calls.map do |call|
          task.async do
            @tools.fetch(call.name).call(**call.arguments)
          end
        end.map(&:wait)
      end
    end
  end
end
```

### 5.2 Ractor-Based Parallelism (For CPU-Bound Work)

For truly parallel execution (multiple agents, CPU-intensive tools).

```ruby
module RubyAgents
  class ParallelOrchestrator
    def run_parallel(agents, tasks)
      # Each agent runs in its own Ractor
      workers = agents.zip(tasks).map do |agent, task|
        # Agent must be Ractor-shareable (immutable or specially designed)
        shareable_agent = agent.to_shareable
        
        Ractor.new(shareable_agent, task) do |ag, t|
          ag.run(t)
        end
      end
      
      # Collect results
      workers.map(&:take)
    end
  end
  
  # Make agents Ractor-safe
  class CodeAgent
    def to_shareable
      # Create a frozen, shareable copy
      frozen_config = {
        name: @name.freeze,
        tools: @tools.to_shareable,
        model_config: @model.config.freeze,
        # ... other config
      }.freeze
      
      Ractor.make_shareable(frozen_config)
      
      # Return a factory that can recreate the agent in any Ractor
      ->(config) { CodeAgent.from_config(config) }
    end
  end
end
```

### 5.3 Thread Pool for Mixed Workloads

```ruby
module RubyAgents
  class ThreadPoolOrchestrator
    def initialize(max_threads: 4)
      @pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 1,
        max_threads: max_threads,
        max_queue: 100
      )
    end
    
    def submit_agent(agent, task)
      Concurrent::Future.execute(executor: @pool) do
        agent.run(task)
      end
    end
  end
end
```

---

## 6. Testing Strategy

### 6.1 Test Doubles for Models

```ruby
# spec/support/model_doubles.rb
module RubyAgents
  module Testing
    class MockModel < Models::Base
      def initialize(&response_generator)
        @responses = []
        @response_generator = response_generator
      end
      
      def stub_response(thought:, code: nil, tool_calls: nil)
        @responses << ModelResponse.new(thought: thought, code: code, tool_calls: tool_calls)
      end
      
      def generate(messages)
        @responses.shift || @response_generator&.call(messages) || 
          raise("No stubbed response available")
      end
    end
    
    # Deterministic model for integration tests
    class ScriptedModel < Models::Base
      def initialize(script)
        @script = script
        @index = 0
      end
      
      def generate(messages)
        response = @script[@index]
        @index += 1
        response
      end
    end
  end
end

# spec/agents/code_agent_spec.rb
RSpec.describe RubyAgents::CodeAgent do
  let(:mock_model) { RubyAgents::Testing::MockModel.new }
  let(:agent) do
    RubyAgents.define do
      name "test_agent"
      model mock_model
      tools CalculatorTool
      max_steps 3
    end
  end
  
  it "executes code and returns results" do
    mock_model.stub_response(
      thought: "I need to calculate 2 + 2",
      code: "result = calculator(expression: '2 + 2')\nfinal_answer(result)"
    )
    
    result = agent.run("What is 2 + 2?")
    
    expect(result.value).to eq("4")
  end
  
  it "handles errors gracefully" do
    mock_model.stub_response(
      thought: "Let me try this",
      code: "raise 'Intentional error'"
    )
    mock_model.stub_response(
      thought: "That didn't work, let me try differently",
      code: "final_answer('Recovered from error')"
    )
    
    result = agent.run("Test error handling")
    
    expect(result.value).to eq("Recovered from error")
    expect(agent.memory.find_errors).not_to be_empty
  end
end
```

### 6.2 Integration Testing with Real Models

```ruby
# spec/integration/anthropic_agent_spec.rb
RSpec.describe "Anthropic Integration", :integration do
  let(:agent) do
    RubyAgents.define do
      name "integration_test"
      model :anthropic, "claude-sonnet-4-20250514"
      tools WebSearchTool
      max_steps 5
    end
  end
  
  it "can perform web searches", vcr: { cassette_name: "web_search" } do
    result = agent.run("What is the current Ruby version?")
    
    expect(result.value).to include("3.4")
  end
end
```

### 6.3 DSL Testing

```ruby
RSpec.describe "Agent DSL" do
  it "correctly configures agents" do
    agent = RubyAgents.define do
      name "test"
      description "A test agent"
      model :anthropic, "claude-sonnet-4-20250514"
      tools WebSearchTool, CalculatorTool
      max_steps 15
      planning_interval 5
    end
    
    expect(agent.name).to eq("test")
    expect(agent.tools.count).to eq(2)
    expect(agent.max_steps).to eq(15)
  end
  
  it "supports nested tool definitions" do
    agent = RubyAgents.define do
      tool :custom_tool do
        description "A custom tool"
        input :query, String, required: true
        output String
        perform { |query:| "Result for #{query}" }
      end
    end
    
    tool = agent.tools.fetch(:custom_tool)
    expect(tool.call(query: "test")).to eq("Result for test")
  end
end
```

### 6.4 Sandbox Security Testing

```ruby
RSpec.describe RubyAgents::Executors::LocalExecutor do
  subject(:executor) { described_class.new }
  
  it "prevents file system access" do
    result = executor.run("File.read('/etc/passwd')", tools: [], state: {})
    
    expect(result.error).to include("NameError")
  end
  
  it "prevents network access" do
    result = executor.run("require 'net/http'", tools: [], state: {})
    
    expect(result.error).to be_present
  end
  
  it "allows safe operations" do
    result = executor.run("[1, 2, 3].map { it * 2 }", tools: [], state: {})
    
    expect(result.output).to eq("[2, 4, 6]")
    expect(result.error).to be_nil
  end
end
```

---

## 7. Project Structure

```
ruby_agents/
├── lib/
│   ├── ruby_agents.rb              # Main entry point, DSL methods
│   ├── ruby_agents/
│   │   ├── version.rb
│   │   ├── dsl/
│   │   │   ├── agent_builder.rb    # Agent definition DSL
│   │   │   ├── tool_builder.rb     # Tool definition DSL
│   │   │   └── orchestration.rb    # Multi-agent DSL
│   │   ├── agents/
│   │   │   ├── base.rb             # MultiStepAgent base class
│   │   │   ├── code_agent.rb       # CodeAgent implementation
│   │   │   └── tool_calling_agent.rb
│   │   ├── tools/
│   │   │   ├── base.rb             # Tool base class
│   │   │   ├── registry.rb         # Tool registry
│   │   │   ├── builtin/
│   │   │   │   ├── web_search.rb
│   │   │   │   ├── python_interpreter.rb
│   │   │   │   └── final_answer.rb
│   │   │   └── adapters/
│   │   │       ├── mcp_adapter.rb
│   │   │       └── langchain_adapter.rb
│   │   ├── models/
│   │   │   ├── base.rb
│   │   │   ├── anthropic.rb
│   │   │   ├── openai.rb
│   │   │   ├── ollama.rb
│   │   │   └── litellm.rb
│   │   ├── executors/
│   │   │   ├── base.rb
│   │   │   ├── local.rb
│   │   │   ├── docker.rb
│   │   │   ├── e2b.rb
│   │   │   └── ractor.rb
│   │   ├── memory/
│   │   │   ├── memory.rb
│   │   │   └── step_log.rb
│   │   ├── prompts/
│   │   │   ├── code_agent.yml
│   │   │   ├── tool_calling_agent.yml
│   │   │   └── manager_agent.yml
│   │   └── testing/
│   │       ├── mock_model.rb
│   │       └── helpers.rb
├── sig/
│   └── ruby_agents.rbs             # RBS type signatures
├── spec/
│   ├── unit/
│   ├── integration/
│   └── support/
├── examples/
│   ├── simple_agent.rb
│   ├── multi_agent.rb
│   ├── self_spawning.rb
│   └── web_browser.rb
├── Gemfile
├── ruby_agents.gemspec
└── README.md
```

---

## 8. Implementation Roadmap

### Phase 1: Core Foundation (Weeks 1-2)

- [ ] Basic agent classes (MultiStepAgent, CodeAgent)
- [ ] Tool base class and registry
- [ ] Local executor with sandboxing
- [ ] Memory/state management
- [ ] Single model adapter (Anthropic)
- [ ] Basic DSL for agent definition

### Phase 2: Tool Ecosystem (Weeks 3-4)

- [ ] Built-in tools (WebSearch, PythonInterpreter, FinalAnswer)
- [ ] MCP adapter for external tools
- [ ] Tool definition DSL refinements
- [ ] Tool testing helpers

### Phase 3: Multi-Model Support (Week 5)

- [ ] OpenAI adapter
- [ ] Ollama adapter
- [ ] LiteLLM adapter
- [ ] Model testing/mocking framework

### Phase 4: Multi-Agent (Weeks 6-7)

- [ ] ManagedAgent wrapper
- [ ] Orchestration DSL
- [ ] Agent-as-tool pattern
- [ ] Self-spawning agent capability

### Phase 5: Advanced Executors (Week 8)

- [ ] Docker executor
- [ ] E2B executor
- [ ] Ractor executor (experimental)

### Phase 6: Polish & Documentation (Weeks 9-10)

- [ ] Comprehensive documentation
- [ ] Example gallery
- [ ] Performance optimization
- [ ] RBS type signatures
- [ ] CI/CD pipeline

---

## 9. Key Differences from smolagents

| Aspect | smolagents (Python) | RubyAgents (Ruby) |
|--------|---------------------|-------------------|
| Tool Definition | `@tool` decorator | Block DSL or class inheritance |
| Agent Definition | Class instantiation | Builder DSL with blocks |
| Type Hints | Python type hints | RBS signatures (optional) |
| Async | asyncio | Fiber scheduler / Async gem |
| Parallelism | Threads/processes | Ractors + Thread pools |
| Code Execution | Python interpreter | Ruby sandbox / eval |
| Metaprogramming | Decorators | Blocks, `instance_eval`, refinements |
| Pattern Matching | Structural (3.10+) | Native Ruby pattern matching |
| Package Sharing | HuggingFace Hub | RubyGems / GitHub |

---

## 10. Open Questions and Considerations

### 10.1 Ruby 4.0 Forward Compatibility

Ruby 4.0 doesn't exist yet (current is 3.4). Design decisions should:
- Embrace Ractors (likely to improve)
- Assume frozen string literals by default
- Use `it` keyword for simple blocks
- Leverage Prism parser improvements
- Prepare for potential GVL removal

### 10.2 Security Considerations

- Code execution is inherently dangerous
- Local executor should be heavily sandboxed
- Docker/E2B recommended for production
- Ractor isolation provides memory safety but not syscall safety
- Consider WASM sandbox (Wasmtime) for maximum isolation

### 10.3 Performance Considerations

- LLM calls dominate latency (not Ruby overhead)
- Code generation/parsing is lightweight
- Tool execution may be parallelizable
- Memory management for long conversations
- YJIT should help with hot paths

### 10.4 Ecosystem Integration

- MCP (Model Context Protocol) support critical
- LangChain tool compatibility
- Integration with Rails (ActiveJob for background agents?)
- CLI tool similar to `smolagent`

---

## Appendix A: Example - Complete Working Agent

```ruby
require "ruby_agents"

# Configure API keys
RubyAgents.configure do |config|
  config.anthropic_api_key = ENV["ANTHROPIC_API_KEY"]
end

# Define a research agent
research_agent = RubyAgents.define do
  name "research_assistant"
  description "An agent that researches topics and provides summaries"
  
  model :anthropic, "claude-sonnet-4-20250514" do
    temperature 0.7
    max_tokens 4096
  end
  
  # Built-in tools
  tools RubyAgents::Tools::WebSearch,
        RubyAgents::Tools::VisitWebpage
  
  # Custom tool defined inline
  tool :summarize do
    description "Summarize text content"
    input :text, String, required: true
    input :max_length, Integer, default: 500
    output String
    
    perform do |text:, max_length:|
      # Could call another LLM here, or use simple extraction
      text.split(/[.!?]/).first(5).join(". ") + "..."
    end
  end
  
  max_steps 10
  planning_interval 3
  executor :local
end

# Run the agent
puts "Starting research agent..."

result = research_agent.run(
  "What are the key new features in Ruby 3.4? Provide a summary.",
  verbose: true
) do |step|
  # Stream intermediate steps
  puts "Step #{step.step}: #{step.thought}"
end

puts "\nFinal Answer:"
puts result.value
```

---

## Appendix B: DSL Grammar Reference

```
agent_definition := 'RubyAgents.define' block
block := 'do' statements 'end'

statements := statement*
statement := name_stmt | description_stmt | model_stmt | tools_stmt | 
             tool_stmt | max_steps_stmt | planning_interval_stmt | 
             executor_stmt | managed_agents_stmt

name_stmt := 'name' string
description_stmt := 'description' string
model_stmt := 'model' symbol ',' string [block]
tools_stmt := 'tools' tool_ref (',' tool_ref)*
tool_stmt := 'tool' symbol block
max_steps_stmt := 'max_steps' integer
planning_interval_stmt := 'planning_interval' integer
executor_stmt := 'executor' symbol
managed_agents_stmt := 'managed_agents' agent_ref (',' agent_ref)*

tool_block := 'do' tool_statements 'end'
tool_statements := tool_statement*
tool_statement := description_stmt | input_stmt | output_stmt | perform_stmt

input_stmt := 'input' symbol ',' type [',' options]
output_stmt := 'output' type
perform_stmt := 'perform' block
```

---

*End of Design Document*
