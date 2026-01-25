require "smolagents/concerns/agents/react_loop/completion"

RSpec.describe Smolagents::Concerns::ReActLoop::Completion do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Completion

      attr_accessor :max_steps, :model, :logger

      def emitting?
        @emitting
      end

      def emit(event)
        @last_event = event
      end

      def complete_goal(goal, evidence:)
        # No-op for testing
      end

      attr_reader :current_goal
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.logger = double("logger", warn: nil, info: nil)
    obj.max_steps = 10
    obj.instance_variable_set(:@emitting, false)
    obj
  end

  let(:finished_ctx) do
    double("finished_context",
           step_number: 5,
           steps_completed: 5,
           total_tokens: double("tokens"),
           timing: { total: 1.5 })
  end

  let(:mock_ctx) do
    double("context",
           step_number: 5,
           steps_completed: 5,
           total_tokens: double("tokens"),
           timing: { total: 1.5 },
           finish: finished_ctx)
  end

  let(:mock_memory) { double("memory", steps: []) }

  describe "#finalize" do
    context "with max_steps outcome" do
      it "logs warning for max steps reached" do
        allow(instance.logger).to receive(:warn)
        instance.send(:finalize, :max_steps_reached, nil, mock_ctx, memory: mock_memory)
        expect(instance.logger).to have_received(:warn).with("Max steps reached", max_steps: 10)
      end
    end

    context "with success outcome" do
      it "completes root goal if available" do
        goal = double("goal", root?: true)
        instance.instance_variable_set(:@current_goal, goal)
        allow(instance).to receive(:complete_goal)
        instance.send(:finalize, :success, "output", mock_ctx, memory: mock_memory)
        expect(instance).to have_received(:complete_goal).with(goal, evidence: "output")
      end
    end

    context "cleanup and result building" do
      it "cleans up resources" do
        instance.model = double("model", close_connections: nil)
        allow(instance.model).to receive(:close_connections)
        instance.send(:finalize, :success, "output", mock_ctx, memory: mock_memory)
        expect(instance.model).to have_received(:close_connections)
      end

      it "builds result with outcome and output" do
        result = instance.send(:finalize, :success, "output", mock_ctx, memory: mock_memory)

        expect(result).to be_a(Smolagents::Types::RunResult)
        expect(result.output).to eq("output")
        expect(result.state).to eq(:success)
      end
    end
  end

  describe "#should_complete_root_goal?" do
    context "without current_goal" do
      it "returns falsy" do
        result = instance.send(:should_complete_root_goal?, :success)
        expect(result).to be_falsey
      end
    end

    context "with non-root goal" do
      before do
        goal = double("goal", root?: false)
        instance.instance_variable_set(:@current_goal, goal)
      end

      it "returns false" do
        result = instance.send(:should_complete_root_goal?, :success)
        expect(result).to be false
      end
    end

    context "with root goal but non-success outcome" do
      before do
        goal = double("goal", root?: true)
        instance.instance_variable_set(:@current_goal, goal)
      end

      it "returns false for max_steps outcome" do
        result = instance.send(:should_complete_root_goal?, :max_steps_reached)
        expect(result).to be false
      end
    end

    context "with root goal and success outcome" do
      before do
        goal = double("goal", root?: true)
        instance.instance_variable_set(:@current_goal, goal)
      end

      it "returns true" do
        result = instance.send(:should_complete_root_goal?, :success)
        expect(result).to be true
      end
    end
  end

  describe "#cleanup_resources" do
    context "with model supporting close_connections" do
      before do
        instance.model = double("model", close_connections: nil)
      end

      it "calls close_connections if available" do
        allow(instance.model).to receive(:close_connections)
        instance.send(:cleanup_resources)
        expect(instance.model).to have_received(:close_connections)
      end
    end

    context "without model" do
      it "does not raise error" do
        instance.model = nil

        expect { instance.send(:cleanup_resources) }.not_to raise_error
      end
    end
  end

  describe "#build_result" do
    it "creates RunResult with output and state" do
      result = instance.send(:build_result, :success, "output", mock_ctx, memory: mock_memory)

      expect(result).to be_a(Smolagents::Types::RunResult)
      expect(result.output).to eq("output")
      expect(result.state).to eq(:success)
    end

    it "includes steps from memory" do
      memory_with_steps = double("memory", steps: %w[step1 step2])
      result = instance.send(:build_result, :success, "output", mock_ctx, memory: memory_with_steps)

      expect(result.steps).to eq(%w[step1 step2])
    end

    it "includes token usage from context" do
      result = instance.send(:build_result, :success, "output", mock_ctx, memory: mock_memory)

      expect(result.token_usage).not_to be_nil
    end

    it "includes timing from context" do
      result = instance.send(:build_result, :success, "output", mock_ctx, memory: mock_memory)

      expect(result.timing).not_to be_nil
    end
  end

  describe "#emit_completion_event" do
    before do
      instance.instance_variable_set(:@emitting, true)
    end

    it "creates and emits completion event on success" do
      emitted_event = nil
      allow(instance).to receive(:emit) { |event| emitted_event = event }
      instance.send(:emit_completion_event, :success, "output", mock_ctx)
      expect(emitted_event).to be_a(Smolagents::Events::TaskCompleted)
    end

    it "uses step_number for success outcome" do
      emitted_event = nil
      allow(instance).to receive(:emit) { |event| emitted_event = event }
      instance.send(:emit_completion_event, :success, "output", mock_ctx)
      expect(emitted_event.steps_taken).to eq(5)
    end

    it "uses steps_completed for non-success outcome" do
      emitted_event = nil
      allow(instance).to receive(:emit) { |event| emitted_event = event }
      instance.send(:emit_completion_event, :max_steps_reached, "output", mock_ctx)
      expect(emitted_event.steps_taken).to eq(5)
    end
  end

  describe "integration" do
    let(:mock_output) { "Final answer: 42" }

    it "completes task flow" do
      instance.instance_variable_set(:@emitting, true)

      result = instance.send(:finalize, :success, mock_output, mock_ctx, memory: mock_memory)

      expect(result).to be_a(Smolagents::Types::RunResult)
      expect(result.state).to eq(:success)
      expect(result.output).to eq(mock_output)
    end
  end
end
