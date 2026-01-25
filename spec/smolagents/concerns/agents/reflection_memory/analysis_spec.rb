require "smolagents/concerns/agents/reflection_memory/analysis"
require "smolagents/concerns/agents/reflection_memory/store"
require "smolagents/types/reflection"
require "smolagents/events/emitter"

RSpec.describe Smolagents::Concerns::ReflectionMemory::Analysis do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::ReflectionMemory::Analysis

      attr_accessor :reflection_config, :reflection_store, :logger

      def initialize(reflection_config:, reflection_store:, logger: nil)
        @reflection_config = reflection_config
        @reflection_store = reflection_store
        @logger = logger
      end

      # Expose private methods for testing
      def test_record_reflection(step, task) = record_reflection(step, task)
      def test_relevant_reflections(task, limit: 3) = relevant_reflections(task, limit:)
      def test_infer_reflection_from_error(error, step) = infer_reflection_from_error(error, step)
    end
  end

  let(:reflection_config) do
    Smolagents::Types::ReflectionConfig.new(
      max_reflections: 10,
      enabled: true,
      include_successful: false
    )
  end
  let(:reflection_store) { Smolagents::Concerns::ReflectionMemory::Store.new }
  let(:logger) do
    double("Logger").tap do |l|
      allow(l).to receive(:debug)
      allow(l).to receive(:info)
    end
  end
  let(:instance) { test_class.new(reflection_config:, reflection_store:, logger:) }

  def make_step(error: nil, tool_calls: nil, code_action: nil, action_output: nil, final_answer: false)
    instance_double(
      Smolagents::Types::ActionStep,
      error:,
      tool_calls:,
      code_action:,
      action_output:,
      final_answer?: final_answer,
      observations: "test observation"
    )
  end

  describe "#record_reflection (private)" do
    context "when reflection is disabled" do
      let(:reflection_config) { Smolagents::Types::ReflectionConfig.disabled }

      it "returns nil" do
        step = make_step(error: "some error")

        result = instance.test_record_reflection(step, "test task")

        expect(result).to be_nil
      end
    end

    context "when step is a final answer" do
      it "returns nil" do
        step = make_step(final_answer: true)

        result = instance.test_record_reflection(step, "test task")

        expect(result).to be_nil
      end
    end

    context "when step has an error" do
      it "creates a failure reflection" do
        step = make_step(error: "undefined local variable or method `foo'", code_action: "puts foo")

        result = instance.test_record_reflection(step, "test task")

        expect(result).to be_a(Smolagents::Types::Reflection)
        expect(result.failure?).to be true
        expect(result.reflection).to include("Define foo before using it")
      end

      it "stores the reflection in the store" do
        step = make_step(error: "some error", code_action: "test code")

        instance.test_record_reflection(step, "test task")

        expect(reflection_store.size).to eq(1)
      end
    end

    context "when step is successful and include_successful is false" do
      it "returns nil" do
        step = make_step(action_output: "success result")

        result = instance.test_record_reflection(step, "test task")

        expect(result).to be_nil
      end
    end

    context "when step is successful and include_successful is true" do
      let(:reflection_config) do
        Smolagents::Types::ReflectionConfig.new(
          max_reflections: 10,
          enabled: true,
          include_successful: true
        )
      end

      it "creates a success reflection" do
        step = make_step(action_output: "success result", code_action: "puts 'hello'")

        result = instance.test_record_reflection(step, "test task")

        expect(result).to be_a(Smolagents::Types::Reflection)
        expect(result.success?).to be true
      end
    end
  end

  describe "#relevant_reflections (private)" do
    context "when reflection is disabled" do
      let(:reflection_config) { Smolagents::Types::ReflectionConfig.disabled }

      it "returns empty array" do
        result = instance.test_relevant_reflections("test task")

        expect(result).to eq([])
      end
    end

    context "when reflection is enabled" do
      before do
        # Add some reflections to the store
        reflection_store.add(Smolagents::Types::Reflection.new(
                               task: "ruby programming task",
                               action: "test",
                               outcome: :failure,
                               observation: "error",
                               reflection: "lesson learned",
                               timestamp: Time.now
                             ))
      end

      it "delegates to the store" do
        result = instance.test_relevant_reflections("ruby task")

        expect(result).to be_a(Array)
        expect(result.size).to eq(1)
      end

      it "respects the limit parameter" do
        2.times do |i|
          reflection_store.add(Smolagents::Types::Reflection.new(
                                 task: "task #{i}",
                                 action: "test",
                                 outcome: :failure,
                                 observation: "error",
                                 reflection: "lesson",
                                 timestamp: Time.now
                               ))
        end

        result = instance.test_relevant_reflections("task", limit: 1)

        expect(result.size).to eq(1)
      end
    end
  end

  describe "#infer_reflection_from_error (private)" do
    let(:step) { make_step }

    it "handles undefined variable errors" do
      result = instance.test_infer_reflection_from_error("undefined local variable or method `myvar'", step)

      expect(result).to include("Define myvar before using it")
    end

    it "handles undefined method errors" do
      result = instance.test_infer_reflection_from_error("undefined method `missing_method'", step)

      expect(result).to include("Method missing_method doesn't exist")
    end

    it "handles wrong number of arguments errors" do
      result = instance.test_infer_reflection_from_error("wrong number of arguments (given 2, expected 1)", step)

      expect(result).to include("Check the method signature")
    end

    it "handles type conversion errors" do
      result = instance.test_infer_reflection_from_error("no implicit conversion of String into Integer", step)

      expect(result).to include("explicit type conversion")
    end

    it "handles syntax errors" do
      result = instance.test_infer_reflection_from_error("syntax error, unexpected end", step)

      expect(result).to include("brackets")
    end

    it "handles tool not found errors" do
      result = instance.test_infer_reflection_from_error("Tool 'search' not found", step)

      expect(result).to include("available tools")
    end

    it "handles timeout errors" do
      result = instance.test_infer_reflection_from_error("execution timed out after 30s", step)

      expect(result).to include("Simplify")
    end

    it "returns generic advice for unknown errors" do
      result = instance.test_infer_reflection_from_error("some random error", step)

      expect(result).to eq("Avoid this approach - try something different")
    end
  end

  describe "error pattern matching" do
    it "defines ERROR_PATTERNS constant" do
      expect(described_class::ERROR_PATTERNS).to be_a(Array)
      expect(described_class::ERROR_PATTERNS).not_to be_empty
    end

    it "each pattern has regex and callable advice" do
      described_class::ERROR_PATTERNS.each do |pattern, advice|
        expect(pattern).to be_a(Regexp)
        expect(advice).to respond_to(:call)
      end
    end
  end
end
