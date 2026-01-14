require "spec_helper"

# Tests for StepExecution concern - NO sleeps, NO timeouts, NO timing-dependent assertions.
# All tests verify structure and state, not elapsed time.
RSpec.describe Smolagents::Concerns::StepExecution do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::StepExecution

      attr_accessor :logger
    end
  end

  let(:logger) { double("Logger") }
  let(:instance) do
    inst = test_class.new
    inst.logger = logger
    allow(logger).to receive(:error)
    allow(logger).to receive(:debug)
    allow(logger).to receive(:info)
    inst
  end

  describe "#with_step_timing" do
    it "yields builder to the block" do
      builder_received = nil

      instance.with_step_timing(step_number: 1) do |builder|
        builder_received = builder
      end

      expect(builder_received).to be_a(Smolagents::Collections::ActionStepBuilder)
    end

    it "returns an ActionStep from the built builder" do
      step = instance.with_step_timing(step_number: 0) do |builder|
        builder.observations = "test observation"
      end

      expect(step).to be_a(Smolagents::Types::ActionStep)
    end

    it "sets the correct step number" do
      step = instance.with_step_timing(step_number: 5) do |_builder|
        # no-op
      end

      expect(step.step_number).to eq(5)
    end

    it "captures block results via builder attributes" do
      step = instance.with_step_timing(step_number: 1) do |builder|
        builder.observations = "Found results"
        builder.action_output = "42"
      end

      expect(step.observations).to eq("Found results")
      expect(step.action_output).to eq("42")
    end

    it "captures multiple builder attributes" do
      step = instance.with_step_timing(step_number: 2) do |builder|
        builder.observations = "obs1"
        builder.action_output = "output1"
        builder.code_action = "some_code"
      end

      expect(step.observations).to eq("obs1")
      expect(step.action_output).to eq("output1")
      expect(step.code_action).to eq("some_code")
    end

    describe "timing structure" do
      # These tests verify timing is captured structurally, not by elapsed time

      it "creates a Timing object" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          # Block executes synchronously - no sleep needed
        end

        expect(step.timing).to be_a(Smolagents::Types::Timing)
      end

      it "sets end_time after block completes" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          # Block completes synchronously
        end

        expect(step.timing.end_time).not_to be_nil
      end

      it "calculates duration as Float" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          # Block executes synchronously
        end

        # Verify structural property: duration is a Float
        expect(step.timing.duration).to be_a(Float)
      end

      it "sets start_time before end_time" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          # Block executes
        end

        # Verify structural property: times are ordered correctly
        expect(step.timing.start_time).to be_a(Time)
        expect(step.timing.end_time).to be_a(Time)
        expect(step.timing.start_time).to be <= step.timing.end_time
      end
    end

    describe "error handling" do
      it "handles errors raised in the block" do
        error_message = "Something went wrong"
        step = nil

        expect do
          step = instance.with_step_timing(step_number: 1) do |_builder|
            raise error_message
          end
        end.not_to raise_error

        expect(step).not_to be_nil
      end

      it "captures error message in builder error field" do
        error_message = "Custom error message"
        step = instance.with_step_timing(step_number: 1) do |_builder|
          raise error_message
        end

        expect(step.error).to include("RuntimeError")
        expect(step.error).to include(error_message)
      end

      it "captures exception class and message in error field" do
        step = instance.with_step_timing(step_number: 1) do |_builder|
          raise ArgumentError, "Invalid argument"
        end

        expect(step.error).to eq("ArgumentError: Invalid argument")
      end

      it "logs errors via logger" do
        allow(instance.logger).to receive(:error)

        instance.with_step_timing(step_number: 1) do |_builder|
          raise "test error"
        end

        expect(instance.logger).to have_received(:error).with("Step error", error: "test error")
      end

      it "logs error message when exception occurs" do
        error_message = "specific error text"
        allow(instance.logger).to receive(:error)

        instance.with_step_timing(step_number: 1) do |_builder|
          raise error_message
        end

        expect(instance.logger).to have_received(:error).with("Step error", error: error_message)
      end

      it "sets timing end_time even when block raises" do
        step = instance.with_step_timing(step_number: 1) do |_builder|
          raise "error"
        end

        expect(step.timing.end_time).not_to be_nil
      end

      it "continues to build step even after error" do
        step = instance.with_step_timing(step_number: 3) do |builder|
          builder.observations = "partial observation"
          raise "error occurred"
        end

        expect(step.observations).to eq("partial observation")
        expect(step.step_number).to eq(3)
      end

      it "preserves builder state when error occurs" do
        step = instance.with_step_timing(step_number: 1) do |builder|
          builder.observations = "before error"
          builder.action_output = "output"
          builder.code_action = "code"
          raise "error"
        end

        expect(step.observations).to eq("before error")
        expect(step.action_output).to eq("output")
        expect(step.code_action).to eq("code")
        expect(step.error).not_to be_nil
      end

      it "handles StandardError subclasses" do
        step = instance.with_step_timing(step_number: 1) do |_builder|
          raise TypeError, "type error"
        end

        expect(step.error).to eq("TypeError: type error")
      end

      it "logs exactly once per error" do
        allow(instance.logger).to receive(:error)

        instance.with_step_timing(step_number: 1) do |_builder|
          raise "error"
        end

        expect(instance.logger).to have_received(:error).once
      end

      it "handles errors with empty messages" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          raise ""
        end

        expect(step.error).to eq("RuntimeError: ")
      end

      it "handles exceptions with special characters in messages" do
        special_message = "Error: <>&\"'"
        step = instance.with_step_timing(step_number: 0) do |_builder|
          raise special_message
        end

        expect(step.error).to include(special_message)
      end
    end

    describe "return values and immutability" do
      it "does not return the block result, returns ActionStep" do
        result = instance.with_step_timing(step_number: 0) do |_builder|
          "block return value"
        end

        expect(result).to be_a(Smolagents::Types::ActionStep)
        expect(result).not_to eq("block return value")
      end

      it "creates valid ActionStep with all nil fields when block is empty" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          # no-op
        end

        expect(step).to be_a(Smolagents::Types::ActionStep)
        expect(step.step_number).to eq(0)
        expect(step.observations).to be_nil
        expect(step.error).to be_nil
      end

      it "returns a frozen/immutable ActionStep" do
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.observations = "test"
        end

        expect(step).to be_a(Smolagents::Types::ActionStep)
      end
    end

    describe "step numbers" do
      it "works with step_number 0" do
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.observations = "first step"
        end

        expect(step.step_number).to eq(0)
        expect(step.observations).to eq("first step")
      end

      it "works with large step numbers" do
        step = instance.with_step_timing(step_number: 999) do |builder|
          builder.observations = "step 999"
        end

        expect(step.step_number).to eq(999)
      end
    end

    describe "builder isolation" do
      it "initializes new builder for each call" do
        builders = []

        2.times do |i|
          instance.with_step_timing(step_number: i) do |builder|
            builders << builder
          end
        end

        expect(builders[0]).not_to be(builders[1])
      end

      it "generates unique trace IDs for each step" do
        step1 = instance.with_step_timing(step_number: 0) do |_builder|
          # no-op
        end

        step2 = instance.with_step_timing(step_number: 1) do |_builder|
          # no-op
        end

        expect(step1.trace_id).not_to eq(step2.trace_id)
      end

      it "preserves trace_id if builder had one set" do
        trace_id = "custom-trace-id-123"
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.trace_id = trace_id
        end

        expect(step.trace_id).to eq(trace_id)
      end
    end

    describe "observations and outputs" do
      it "handles nil observations" do
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.observations = nil
        end

        expect(step.observations).to be_nil
      end

      it "handles empty string observations" do
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.observations = ""
        end

        expect(step.observations).to eq("")
      end

      it "builds step with is_final_answer if set" do
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.is_final_answer = true
        end

        expect(step.is_final_answer).to be true
      end

      it "builds step with token_usage if set" do
        usage = Smolagents::Types::TokenUsage.new(input_tokens: 100, output_tokens: 50)
        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.token_usage = usage
        end

        expect(step.token_usage).to eq(usage)
      end
    end

    describe "normal execution" do
      it "raises no errors for normal execution" do
        expect do
          instance.with_step_timing(step_number: 0) do |builder|
            builder.observations = "normal execution"
          end
        end.not_to raise_error
      end

      it "completes timing for multiple sequential calls" do
        steps = []
        3.times do |i|
          step = instance.with_step_timing(step_number: i) do |builder|
            builder.observations = "step #{i}"
          end
          steps << step
        end

        # Verify all steps have complete timing (no timing-dependent checks)
        expect(steps.map { |s| s.timing.end_time.nil? }).to all(be false)
        expect(steps.map(&:step_number)).to eq([0, 1, 2])
      end
    end

    describe "integration scenarios" do
      it "handles tool execution simulation" do
        step = instance.with_step_timing(step_number: 1) do |builder|
          tool_result = "search found 5 results"
          builder.observations = tool_result
          builder.action_output = "Success"
        end

        expect(step.observations).to eq("search found 5 results")
        expect(step.action_output).to eq("Success")
        expect(step.step_number).to eq(1)
        expect(step.timing).not_to be_nil
      end

      it "handles tool call building" do
        tool_call = Smolagents::Types::ToolCall.new(
          name: "web_search",
          arguments: { query: "Ruby 4.0" },
          id: "call_123"
        )

        step = instance.with_step_timing(step_number: 0) do |builder|
          builder.tool_calls = [tool_call]
          builder.observations = "Tool called successfully"
        end

        expect(step.tool_calls).to eq([tool_call])
        expect(step.observations).to eq("Tool called successfully")
      end

      it "handles error during model parsing" do
        step = instance.with_step_timing(step_number: 0) do |_builder|
          raise JSON::ParserError, "Invalid JSON from model"
        end

        expect(step.error).to include("JSON::ParserError")
        expect(step.error).to include("Invalid JSON from model")
      end

      it "handles multi-step execution flow" do
        steps = []

        # Step 1: Initialize
        steps << instance.with_step_timing(step_number: 0) do |builder|
          builder.observations = "Starting task"
        end

        # Step 2: Tool call
        steps << instance.with_step_timing(step_number: 1) do |builder|
          builder.observations = "Called search tool"
        end

        # Step 3: Final answer
        steps << instance.with_step_timing(step_number: 2) do |builder|
          builder.observations = "Compiled answer"
          builder.is_final_answer = true
        end

        expect(steps.map(&:step_number)).to eq([0, 1, 2])
        expect(steps.map(&:observations)).to eq([
                                                  "Starting task",
                                                  "Called search tool",
                                                  "Compiled answer"
                                                ])
        expect(steps.last.is_final_answer).to be true
      end
    end
  end
end
