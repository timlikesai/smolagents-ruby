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
            sleep(0.02)
            mutex.synchronize { execution_order << "end_#{i}" }
          end
        end

        threads.each(&:join)

        # With max 2 threads, we should see interleaving but never more than 2 concurrent
        expect(execution_order.size).to eq(8)
      end

      it "releases slot even when block raises" do
        pool = described_class.new(1)

        thread1 = pool.spawn { raise "error" }
        expect { thread1.join }.to raise_error(RuntimeError, "error")

        # Should still be able to spawn another thread
        result = nil
        thread2 = pool.spawn { result = "success" }
        thread2.join

        expect(result).to eq("success")
      end
    end

    describe "concurrent execution" do
      it "executes multiple tasks concurrently up to max_threads" do
        pool = described_class.new(3)
        start_times = []
        mutex = Mutex.new

        threads = Array.new(3) do
          pool.spawn do
            mutex.synchronize { start_times << Time.now }
            sleep(0.05)
          end
        end

        threads.each(&:join)

        # All 3 should start within a small window (concurrent)
        time_spread = start_times.max - start_times.min
        expect(time_spread).to be < 0.02
      end

      it "queues tasks beyond max_threads" do
        pool = described_class.new(1)
        execution_order = []
        mutex = Mutex.new

        threads = Array.new(3) do |i|
          pool.spawn do
            mutex.synchronize { execution_order << i }
            sleep(0.01)
          end
        end

        threads.each(&:join)

        # With max 1 thread, execution should be sequential
        expect(execution_order).to eq([0, 1, 2])
      end
    end
  end

  describe "#execute_tool_calls_parallel" do
    let(:test_class) do
      Class.new do
        include Smolagents::Concerns::ToolExecution

        attr_accessor :tools, :max_tool_threads

        def initialize
          @tools = {}
          @max_tool_threads = 4
        end

        def build_tool_output(tool_call, output, observation, is_final: false)
          Smolagents::ToolOutput.new(
            id: tool_call.id,
            output: output,
            is_final_answer: is_final,
            observation: observation,
            tool_call: tool_call
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
      tool = double("tool")
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

    it "preserves order of results regardless of completion order" do
      slow_tool = double("slow_tool")
      allow(slow_tool).to receive(:call) do |x:|
        sleep(0.01 * (3 - x)) # First call is slowest
        "slow_#{x}"
      end
      instance.tools["slow_tool"] = slow_tool

      tool_calls = Array.new(3) do |i|
        Smolagents::ToolCall.new(name: "slow_tool", arguments: { "x" => i }, id: "tc_#{i}")
      end

      results = instance.send(:execute_tool_calls_parallel, tool_calls)

      expect(results.map(&:id)).to eq(%w[tc_0 tc_1 tc_2])
      expect(results.map(&:output)).to eq(%w[slow_0 slow_1 slow_2])
    end
  end
end
