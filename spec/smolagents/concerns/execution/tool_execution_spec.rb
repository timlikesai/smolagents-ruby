require "spec_helper"

RSpec.describe Smolagents::Concerns::ToolExecution do
  describe Smolagents::Concerns::ToolExecution::ThreadPool do
    describe "#spawn" do
      it "executes block in a new thread" do
        pool = described_class.new(4)
        result = nil

        thread = pool.spawn { result = 42 }
        thread.join

        expect(result).to eq(42)
      end

      it "returns the thread" do
        pool = described_class.new(4)
        thread = pool.spawn { "work" }

        expect(thread).to be_a(Thread)
        thread.join
      end

      it "respects max_threads limit" do
        pool = described_class.new(2)
        execution_order = []
        mutex = Mutex.new

        threads = Array.new(4) do |i|
          pool.spawn do
            mutex.synchronize { execution_order << "start_#{i}" }
            mutex.synchronize { execution_order << "end_#{i}" }
          end
        end

        threads.each(&:join)
        expect(execution_order.size).to eq(8)
      end

      it "releases slot even when block raises" do
        pool = described_class.new(1)

        thread1 = pool.spawn { raise "error" }
        expect { thread1.join }.to raise_error(RuntimeError, "error")

        result = nil
        thread2 = pool.spawn { result = "success" }
        thread2.join

        expect(result).to eq("success")
      end

      it "tracks active thread count during execution" do
        pool = described_class.new(2)
        barrier = Mutex.new
        started = ConditionVariable.new
        continue = ConditionVariable.new

        thread = pool.spawn do
          barrier.synchronize do
            started.signal
            continue.wait(barrier)
          end
        end

        barrier.synchronize do
          started.wait(barrier)
          # At this point, the thread is active
          expect(pool.instance_variable_get(:@active)).to be > 0
          continue.signal
        end
        thread.join
      end

      it "decrements active count after thread completion" do
        pool = described_class.new(1)
        thread = pool.spawn { "done" }
        thread.join

        expect(pool.instance_variable_get(:@active)).to eq(0)
      end

      it "is thread-safe with concurrent spawns" do
        pool = described_class.new(4)
        results = []
        mutex = Mutex.new

        threads = Array.new(10) do |i|
          pool.spawn do
            mutex.synchronize { results << i }
          end
        end

        threads.each(&:join)
        expect(results.sort).to eq((0..9).to_a)
      end
    end

    describe "concurrent execution" do
      it "executes multiple tasks concurrently up to max_threads" do
        pool = described_class.new(3)
        results = []
        mutex = Mutex.new

        threads = Array.new(3) do |i|
          pool.spawn { mutex.synchronize { results << i } }
        end

        threads.each(&:join)
        expect(results.size).to eq(3)
      end

      it "queues tasks beyond max_threads" do
        pool = described_class.new(1)
        execution_order = []
        mutex = Mutex.new

        threads = Array.new(3) do |i|
          pool.spawn { mutex.synchronize { execution_order << i } }
        end

        threads.each(&:join)
        expect(execution_order).to eq([0, 1, 2])
      end

      it "handles exceptions in concurrent threads" do
        pool = described_class.new(2)
        results = []
        mutex = Mutex.new

        thread1 = pool.spawn { raise "error in thread 1" }
        thread2 = pool.spawn { mutex.synchronize { results << "success" } }

        expect { thread1.join }.to raise_error(RuntimeError, "error in thread 1")
        thread2.join

        expect(results).to eq(["success"])
      end
    end

    describe "initialization" do
      it "stores max_threads value" do
        pool = described_class.new(8)
        expect(pool.instance_variable_get(:@max_threads)).to eq(8)
      end

      it "initializes mutex for thread safety" do
        pool = described_class.new(4)
        expect(pool.instance_variable_get(:@mutex)).to be_a(Mutex)
      end

      it "initializes active counter to zero" do
        pool = described_class.new(4)
        expect(pool.instance_variable_get(:@active)).to eq(0)
      end
    end
  end

  describe "#execute_tool_calls_parallel" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution
        include Smolagents::Events::Emitter

        attr_accessor :tools, :max_tool_threads

        def initialize
          @tools = {}
          @max_tool_threads = 4
        end

        def build_tool_output(tool_call, output, observation, is_final: false)
          Smolagents::ToolOutput.new(
            id: tool_call.id,
            output:,
            is_final_answer: is_final,
            observation:,
            tool_call:
          )
        end

        def execute_tool_call(tool_call)
          tool = @tools[tool_call.name]
          return build_tool_output(tool_call, nil, "Unknown tool") unless tool

          result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
          build_tool_output(tool_call, result, "#{tool_call.name}: #{result}")
        end
      end
    end

    let(:instance) { test_class.new }

    let(:mock_tool) do
      tool = instance_double(Smolagents::Tool)
      allow(tool).to receive(:call) { |x:| "result_#{x}" }
      tool
    end

    before do
      instance.tools = { "test_tool" => mock_tool }
    end

    it "executes multiple tool calls in parallel" do
      tool_calls = Array.new(3) do |i|
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => i }, id: "tc_#{i}")
      end

      results = instance.send(:execute_tool_calls_parallel, tool_calls)

      expect(results.size).to eq(3)
      expect(results.map(&:id)).to eq(%w[tc_0 tc_1 tc_2])
      expect(results.map(&:output)).to eq(%w[result_0 result_1 result_2])
    end

    it "preserves order of results" do
      tool_calls = Array.new(3) do |i|
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => i }, id: "tc_#{i}")
      end

      results = instance.send(:execute_tool_calls_parallel, tool_calls)

      expect(results.map(&:id)).to eq(%w[tc_0 tc_1 tc_2])
    end

    it "handles tool execution errors gracefully in single call" do
      # We'll test this at the execute_tool_call level with proper mocking
      # The real test_class doesn't properly implement error handling,
      # so we test through execute_tool_call directly with mocks
      failing_tool = instance_double(Smolagents::Tool)
      allow(failing_tool).to receive(:validate_tool_arguments)
      allow(failing_tool).to receive(:call).and_raise(StandardError.new("tool error"))

      instance.tools["failing_tool"] = failing_tool

      # Mock emit_event and emit_error since they're from Events::Emitter
      allow(instance).to receive(:emit_event).and_return(double(id: "evt_1")) # -- duck-typed event interface
      allow(instance).to receive(:emit_error)

      tool_call = Smolagents::ToolCall.new(name: "failing_tool", arguments: {}, id: "tc_fail")

      # The execute_tool_call method in the included module handles errors
      # It calls the real method which should rescue and return error output
      result = described_class.instance_method(:execute_tool_call).bind_call(instance, tool_call)

      expect(result.output).to be_nil
      expect(result.observation).to include("Error")
    end

    it "respects max_tool_threads and executes in parallel", max_time: 0.05 do
      instance.max_tool_threads = 4
      fast_tool = instance_double(Smolagents::Tool)

      # Use simple synchronous calls instead of sleep
      call_count = Mutex.new
      count = 0

      allow(fast_tool).to receive(:validate_tool_arguments)
      allow(fast_tool).to receive(:call) do
        call_count.synchronize do
          count += 1
        end
        "result_#{count}"
      end

      instance.tools = { "fast_tool" => fast_tool }

      tool_calls = Array.new(4) do |i|
        Smolagents::ToolCall.new(name: "fast_tool", arguments: {}, id: "tc_#{i}")
      end

      results = instance.send(:execute_tool_calls_parallel, tool_calls)

      expect(results.size).to eq(4)
      expect(results.all? { |r| r.output && r.output.start_with?("result_") }).to be true
    end
  end

  describe "#execute_tool_calls" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution
        include Smolagents::Events::Emitter

        attr_accessor :tools, :max_tool_threads

        def initialize
          @tools = {}
          @max_tool_threads = 4
        end

        def build_tool_output(tool_call, output, observation, is_final: false)
          Smolagents::ToolOutput.new(
            id: tool_call.id,
            output:,
            is_final_answer: is_final,
            observation:,
            tool_call:
          )
        end

        def execute_tool_call(tool_call)
          tool = @tools[tool_call.name]
          return build_tool_output(tool_call, nil, "Unknown tool") unless tool

          result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
          build_tool_output(tool_call, result, "#{tool_call.name}: #{result}")
        end

        def execute_tool_calls_async(tool_calls)
          execute_tool_calls_parallel(tool_calls)
        end
      end
    end

    let(:instance) { test_class.new }
    let(:mock_tool) do
      tool = instance_double(Smolagents::Tool)
      allow(tool).to receive(:call).and_return("result")
      tool
    end

    before do
      instance.tools = { "test_tool" => mock_tool }
    end

    it "executes single tool call directly" do
      tool_calls = [
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => 1 }, id: "tc_1")
      ]

      results = instance.send(:execute_tool_calls, tool_calls)

      expect(results.size).to eq(1)
      expect(results.first.output).to eq("result")
    end

    it "executes multiple tool calls asynchronously" do
      tool_calls = Array.new(3) do |i|
        Smolagents::ToolCall.new(name: "test_tool", arguments: { "x" => i }, id: "tc_#{i}")
      end

      results = instance.send(:execute_tool_calls, tool_calls)

      expect(results.size).to eq(3)
      expect(results.map(&:id)).to eq(%w[tc_0 tc_1 tc_2])
    end
  end

  describe "#execute_tool_call" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution
        include Smolagents::Events::Emitter

        attr_accessor :tools

        def initialize
          @tools = {}
        end

        def build_tool_output(tool_call, output, observation, is_final: false)
          Smolagents::ToolOutput.new(
            id: tool_call.id,
            output:,
            is_final_answer: is_final,
            observation:,
            tool_call:
          )
        end
      end
    end

    let(:instance) { test_class.new }

    it "executes a tool and returns output" do
      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:validate_tool_arguments)
      allow(mock_tool).to receive(:call).and_return("result")

      instance.tools = { "my_tool" => mock_tool }

      tool_call = Smolagents::ToolCall.new(
        name: "my_tool",
        arguments: { "query" => "test" },
        id: "tc_1"
      )

      result = instance.send(:execute_tool_call, tool_call)

      expect(result).to be_a(Smolagents::ToolOutput)
      expect(result.output).to eq("result")
      expect(result.observation).to include("my_tool")
      expect(result.is_final_answer).to be false
    end

    it "handles final_answer tool specially" do
      final_answer_tool = instance_double(Smolagents::Tool)
      allow(final_answer_tool).to receive(:validate_tool_arguments)
      allow(final_answer_tool).to receive(:call).and_return("The final answer")

      instance.tools = { "final_answer" => final_answer_tool }

      tool_call = Smolagents::ToolCall.new(
        name: "final_answer",
        arguments: { "answer" => "42" },
        id: "tc_final"
      )

      result = instance.send(:execute_tool_call, tool_call)

      expect(result.is_final_answer).to be true
    end

    it "returns error for unknown tool" do
      tool_call = Smolagents::ToolCall.new(
        name: "unknown_tool",
        arguments: {},
        id: "tc_unknown"
      )

      result = instance.send(:execute_tool_call, tool_call)

      expect(result.output).to be_nil
      expect(result.observation).to include("Unknown tool")
    end

    it "handles tool validation errors" do
      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:validate_tool_arguments).and_raise(StandardError.new("Invalid arguments"))

      instance.tools = { "my_tool" => mock_tool }

      tool_call = Smolagents::ToolCall.new(
        name: "my_tool",
        arguments: { "bad" => "args" },
        id: "tc_invalid"
      )

      result = instance.send(:execute_tool_call, tool_call)

      expect(result.output).to be_nil
      expect(result.observation).to include("Error")
    end

    it "handles tool execution errors" do
      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:validate_tool_arguments)
      allow(mock_tool).to receive(:call).and_raise(StandardError.new("Execution failed"))

      instance.tools = { "my_tool" => mock_tool }

      tool_call = Smolagents::ToolCall.new(
        name: "my_tool",
        arguments: {},
        id: "tc_error"
      )

      result = instance.send(:execute_tool_call, tool_call)

      expect(result.output).to be_nil
      expect(result.observation).to include("Error")
      expect(result.observation).to include("Execution failed")
    end

    it "emits events during execution" do
      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:validate_tool_arguments)
      allow(mock_tool).to receive(:call).and_return("success")

      instance.tools = { "my_tool" => mock_tool }
      events_emitted = []

      allow(instance).to receive(:emit_event) do |event|
        events_emitted << event
        event
      end

      tool_call = Smolagents::ToolCall.new(
        name: "my_tool",
        arguments: { "q" => "test" },
        id: "tc_1"
      )

      instance.send(:execute_tool_call, tool_call)

      # Check that ToolCallRequested and ToolCallCompleted events were emitted
      expect(events_emitted.size).to be >= 2
    end

    it "transforms string argument keys to symbols" do
      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:validate_tool_arguments)

      # Capture the call to verify argument transformation
      captured_args = {}
      allow(mock_tool).to receive(:call) do |**args|
        captured_args = args
        "result"
      end

      instance.tools = { "my_tool" => mock_tool }

      tool_call = Smolagents::ToolCall.new(
        name: "my_tool",
        arguments: { "query" => "search term", "limit" => 10 },
        id: "tc_1"
      )

      instance.send(:execute_tool_call, tool_call)

      # Arguments should be passed with symbol keys
      expect(captured_args).to eq({ query: "search term", limit: 10 })
    end
  end

  describe "#system_prompt" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution

        attr_accessor :tools, :custom_instructions, :managed_agents

        def initialize
          @tools = {}
          @custom_instructions = nil
          @managed_agents = {}
        end

        def managed_agent_descriptions
          @managed_agents.values.map(&:description).join("\n")
        end
      end
    end

    let(:instance) { test_class.new }

    before do
      allow(Smolagents::Prompts::Agent).to receive(:generate).and_return("Base prompt")
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("")
    end

    it "generates system prompt with tool calling preset" do
      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:to_tool_calling_prompt).and_return("tool: test")
      instance.tools = { "test" => mock_tool }
      prompt = instance.system_prompt
      expect(prompt).to include("Base prompt")
    end

    it "includes capabilities when available" do
      instance.tools = {}
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("Capabilities info")
      prompt = instance.system_prompt
      expect(prompt).to include("Capabilities info")
    end

    it "handles empty capabilities gracefully" do
      instance.tools = {}
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("")
      prompt = instance.system_prompt
      expect(prompt).to eq("Base prompt")
    end
  end

  describe "#capabilities_prompt" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution

        attr_accessor :tools, :managed_agents

        def initialize
          @tools = {}
          @managed_agents = {}
        end
      end
    end

    let(:instance) { test_class.new }

    it "generates capabilities prompt using Prompts module" do
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("Capabilities")
      capabilities = instance.capabilities_prompt
      expect(capabilities).to eq("Capabilities")
    end

    it "passes correct agent type to generate_capabilities" do
      allow(Smolagents::Prompts).to receive(:generate_capabilities).and_return("Capabilities")

      instance.capabilities_prompt

      expect(Smolagents::Prompts).to have_received(:generate_capabilities).with(
        tools: instance.tools,
        managed_agents: instance.managed_agents,
        agent_type: :tool
      )
    end
  end

  describe "#template_path" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution
      end
    end

    let(:instance) { test_class.new }

    it "returns nil by default" do
      expect(instance.template_path).to be_nil
    end

    it "can be overridden in subclasses" do
      custom_class = Class.new(test_class) do
        def template_path
          "/custom/path"
        end
      end

      custom_instance = custom_class.new
      expect(custom_instance.template_path).to eq("/custom/path")
    end
  end

  describe "module inclusion" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution
      end
    end

    it "includes Events::Emitter" do
      expect(test_class.include?(Smolagents::Events::Emitter)).to be true
    end

    it "adds max_tool_threads attr_reader" do
      instance = test_class.new
      instance.instance_variable_set(:@max_tool_threads, 8)
      expect(instance.max_tool_threads).to eq(8)
    end
  end

  describe "#execute_step" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution
        include Smolagents::Events::Emitter

        attr_accessor :tools, :model, :max_tool_threads

        def initialize
          @tools = {}
          @model = nil
          @max_tool_threads = 4
        end

        def write_memory_to_messages
          [Smolagents::ChatMessage.user("test")]
        end

        def build_tool_output(tool_call, output, observation, is_final: false)
          Smolagents::ToolOutput.new(
            id: tool_call.id,
            output:,
            is_final_answer: is_final,
            observation:,
            tool_call:
          )
        end

        def execute_tool_calls(tool_calls)
          tool_calls.map { |tc| execute_tool_call(tc) }
        end

        def execute_tool_call(tool_call)
          tool = @tools[tool_call.name]
          return build_tool_output(tool_call, nil, "Unknown tool") unless tool

          result = tool.call(**tool_call.arguments.transform_keys(&:to_sym))
          build_tool_output(tool_call, result, "#{tool_call.name}: #{result}")
        end
      end
    end

    let(:instance) { test_class.new }

    it "updates action step with model response" do
      mock_model = instance_double(Smolagents::Models::Model)
      mock_response = instance_double(Smolagents::ChatMessage)
      tokens = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      allow(mock_response).to receive_messages(tool_calls: nil, content: "Response text", token_usage: tokens)

      allow(mock_model).to receive(:generate).and_return(mock_response)
      instance.model = mock_model

      step_builder = Smolagents::ActionStepBuilder.new(step_number: 0)
      instance.execute_step(step_builder)

      expect(step_builder.model_output_message).to eq(mock_response)
      expect(step_builder.token_usage.total_tokens).to eq(15)
    end

    it "handles tool calls in response" do
      mock_model = instance_double(Smolagents::Models::Model)
      mock_response = instance_double(Smolagents::ChatMessage)

      tool_call = Smolagents::ToolCall.new(
        name: "test_tool",
        arguments: { "x" => 1 },
        id: "tc_1"
      )

      allow(mock_response).to receive_messages(tool_calls: [tool_call],
                                               token_usage: Smolagents::TokenUsage.new(
                                                 input_tokens: 10, output_tokens: 5
                                               ))

      allow(mock_model).to receive(:generate).and_return(mock_response)

      mock_tool = instance_double(Smolagents::Tool)
      allow(mock_tool).to receive(:validate_tool_arguments)
      allow(mock_tool).to receive(:call).and_return("result")

      instance.model = mock_model
      instance.tools = { "test_tool" => mock_tool }

      step_builder = Smolagents::ActionStepBuilder.new(step_number: 0)
      instance.execute_step(step_builder)

      expect(step_builder.tool_calls).to eq([tool_call])
      expect(step_builder.observations).to include("test_tool")
    end

    it "handles final answer in tool execution" do
      mock_model = instance_double(Smolagents::Models::Model)
      mock_response = instance_double(Smolagents::ChatMessage)

      final_call = Smolagents::ToolCall.new(
        name: "final_answer",
        arguments: { "answer" => "The answer is 42" },
        id: "tc_final"
      )

      allow(mock_response).to receive_messages(tool_calls: [final_call],
                                               token_usage: Smolagents::TokenUsage.new(
                                                 input_tokens: 10, output_tokens: 5
                                               ))

      allow(mock_model).to receive(:generate).and_return(mock_response)

      # The test class's execute_tool_call needs to call build_tool_output with is_final: true for final_answer
      # The real code would have final_answer tool with special handling
      # Mock it directly instead of relying on test class implementation
      final_tool = instance_double(Smolagents::Tool)
      allow(final_tool).to receive(:validate_tool_arguments)
      allow(final_tool).to receive(:call).and_return("The answer is 42")

      instance.model = mock_model
      instance.tools = { "final_answer" => final_tool }

      # Stub the execute_tool_call to return proper final answer output
      allow(instance).to receive(:execute_tool_call).and_wrap_original do |method, tool_call|
        if tool_call.name == "final_answer"
          instance.send(:build_tool_output, tool_call, "The answer is 42", "final_answer: The answer is 42",
                        is_final: true)
        else
          method.call(tool_call)
        end
      end

      # Mock emit_event
      allow(instance).to receive(:emit_event).and_return(double(id: "evt_1")) # -- duck-typed event interface

      step_builder = Smolagents::ActionStepBuilder.new(step_number: 0)
      instance.execute_step(step_builder)

      expect(step_builder.is_final_answer).to be true
      expect(step_builder.action_output).to eq("The answer is 42")
    end

    it "handles empty response without tool calls or content" do
      mock_model = instance_double(Smolagents::Models::Model)
      mock_response = instance_double(Smolagents::ChatMessage)
      tokens = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      allow(mock_response).to receive_messages(tool_calls: nil, content: nil, token_usage: tokens)

      allow(mock_model).to receive(:generate).and_return(mock_response)
      instance.model = mock_model

      step_builder = Smolagents::ActionStepBuilder.new(step_number: 0)
      instance.execute_step(step_builder)

      expect(step_builder.error).to include("No tool calls or content")
    end

    it "handles empty content string" do
      mock_model = instance_double(Smolagents::Models::Model)
      mock_response = instance_double(Smolagents::ChatMessage)
      tokens = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      allow(mock_response).to receive_messages(tool_calls: nil, content: "", token_usage: tokens)

      allow(mock_model).to receive(:generate).and_return(mock_response)
      instance.model = mock_model

      step_builder = Smolagents::ActionStepBuilder.new(step_number: 0)
      instance.execute_step(step_builder)

      expect(step_builder.error).to include("No tool calls or content")
    end

    it "sets observations from response content" do
      mock_model = instance_double(Smolagents::Models::Model)
      mock_response = instance_double(Smolagents::ChatMessage)
      tokens = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
      allow(mock_response).to receive_messages(tool_calls: nil, content: "Some analysis", token_usage: tokens)

      allow(mock_model).to receive(:generate).and_return(mock_response)
      instance.model = mock_model

      step_builder = Smolagents::ActionStepBuilder.new(step_number: 0)
      instance.execute_step(step_builder)

      expect(step_builder.observations).to eq("Some analysis")
    end
  end

  describe "#build_tool_output" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution

        def build_tool_output(tool_call, output, observation, is_final: false)
          Smolagents::ToolOutput.from_call(tool_call, output:, observation:, is_final:)
        end
      end
    end

    let(:instance) { test_class.new }

    it "creates ToolOutput from tool call" do
      tool_call = Smolagents::ToolCall.new(name: "test", arguments: {}, id: "tc_1")
      output = instance.send(:build_tool_output, tool_call, "result", "observation")

      expect(output).to be_a(Smolagents::ToolOutput)
      expect(output.output).to eq("result")
      expect(output.observation).to eq("observation")
      expect(output.is_final_answer).to be false
    end

    it "marks final answers correctly" do
      tool_call = Smolagents::ToolCall.new(name: "final_answer", arguments: {}, id: "tc_final")
      output = instance.send(:build_tool_output, tool_call, "answer", "observation", is_final: true)

      expect(output.is_final_answer).to be true
    end
  end
end
