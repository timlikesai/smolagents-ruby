require "smolagents/concerns/agents/react_loop/execution/monitoring"

RSpec.describe Smolagents::Concerns::ReActLoop::Execution::Monitoring do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ReActLoop::Execution::Monitoring

      attr_accessor :logger, :executor

      def step(task, step_number:)
        Smolagents::Types::ActionStep.new(step_number:, action_output: "result")
      end

      def monitor_step(name)
        yield if block_given?
      end

      def step_monitors
        @step_monitors ||= Hash.new do |h, k|
          monitor = Object.new
          monitor.define_singleton_method(:duration) { 0.5 }
          h[k] = monitor
        end
      end

      def emitting? = @emitting

      def emit(event)
        @last_event = event
      end
    end
  end

  let(:instance) do
    obj = test_class.new
    obj.logger = double("logger", step_start: nil, step_complete: nil, debug: nil, info: nil, warn: nil)
    obj.instance_variable_set(:@emitting, false)
    obj
  end

  describe "#execute_step_with_monitoring" do
    let(:memory) { double("memory", add_step: nil) }
    let(:ctx) do
      double("context",
             step_number: 1,
             add_tokens: double("new_ctx"))
    end

    it "logs step start" do
      allow(instance.logger).to receive(:step_start)
      instance.send(:execute_step_with_monitoring, "task", ctx, memory:)
      expect(instance.logger).to have_received(:step_start).with(1)
    end

    it "logs step complete with duration" do
      allow(instance.logger).to receive(:step_complete)
      instance.send(:execute_step_with_monitoring, "task", ctx, memory:)
      expect(instance.logger).to have_received(:step_complete).with(1, hash_including(:duration))
    end

    it "returns step and updated context" do
      step, new_ctx = instance.send(:execute_step_with_monitoring, "task", ctx, memory:)

      expect(step).to be_a(Smolagents::Types::ActionStep)
      expect(new_ctx).not_to be_nil
    end
  end

  describe "#emit_step_event" do
    let(:step) do
      Smolagents::Types::ActionStep.new(
        step_number: 1,
        action_output: "result",
        observations: "obs"
      )
    end

    it "does not emit when not emitting" do
      allow(instance).to receive(:emit)
      instance.send(:emit_step_event, step)
      expect(instance).not_to have_received(:emit)
    end

    it "emits StepCompleted event when emitting" do
      instance.instance_variable_set(:@emitting, true)
      emitted_event = nil
      allow(instance).to receive(:emit) { |event| emitted_event = event }
      instance.send(:emit_step_event, step)
      expect(emitted_event).to be_a(Smolagents::Events::StepCompleted)
    end
  end

  describe "#step_outcome" do
    it "returns :final_answer for final answer step" do
      step = double("step", final_answer?: true)

      result = instance.send(:step_outcome, step)

      expect(result).to eq(:final_answer)
    end

    it "returns :error for step with error" do
      step = double("step", final_answer?: false, error: "some error")

      result = instance.send(:step_outcome, step)

      expect(result).to eq(:error)
    end

    it "returns :success for normal step" do
      step = double("step", final_answer?: false, error: nil)

      result = instance.send(:step_outcome, step)

      expect(result).to eq(:success)
    end
  end

  describe "#record_observability" do
    it "records step to observability context when present" do
      ctx = double("ctx", step_number: 1)
      step = double("step", token_usage: nil, tool_calls: nil)

      obs_ctx = double("obs_ctx", record_step: nil, add_tokens: nil)
      allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(obs_ctx)
      allow(obs_ctx).to receive(:record_step)

      instance.send(:record_observability, step, ctx)

      expect(obs_ctx).to have_received(:record_step).with(1)
    end

    it "does nothing when no observability context" do
      ctx = double("ctx", step_number: 1)
      step = double("step")

      allow(Smolagents::Types::ObservabilityContext).to receive(:current).and_return(nil)

      expect { instance.send(:record_observability, step, ctx) }.not_to raise_error
    end
  end
end
