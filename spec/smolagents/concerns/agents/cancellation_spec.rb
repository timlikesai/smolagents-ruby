require "smolagents"

RSpec.describe Smolagents::Concerns::Cancellation do
  let(:test_class) do
    Class.new do
      include Smolagents::Events::Emitter
      include Smolagents::Concerns::Cancellation

      attr_accessor :ctx, :memory

      def initialize
        initialize_cancellation
        @ctx = nil
        @memory = nil
        @finalized = nil
      end

      def finalize(state, output, ctx, memory:)
        @finalized = { state:, output:, ctx:, memory: }
        Smolagents::Types::RunResult.cancelled(output: nil, steps: [])
      end

      def finalized? = !@finalized.nil?
      def finalized_state = @finalized&.dig(:state)
    end
  end

  let(:instance) { test_class.new }

  describe "#cancelled?" do
    it "returns false initially" do
      expect(instance).not_to be_cancelled
    end

    it "returns true after cancel!" do
      instance.cancel!
      expect(instance).to be_cancelled
    end
  end

  describe "#cancel!" do
    it "sets cancelled state to true" do
      expect { instance.cancel! }.to change(instance, :cancelled?).from(false).to(true)
    end

    it "is idempotent" do
      instance.cancel!
      instance.cancel!
      expect(instance).to be_cancelled
    end
  end

  describe "#cancellation_token" do
    it "returns a CancellationToken" do
      expect(instance.cancellation_token).to be_a(Smolagents::Types::CancellationToken)
    end

    it "is not cancelled initially" do
      expect(instance.cancellation_token).not_to be_cancelled
    end
  end

  describe "#initialize_cancellation" do
    it "creates a fresh token" do
      old_token = instance.cancellation_token
      instance.send(:initialize_cancellation)
      new_token = instance.cancellation_token

      expect(new_token).not_to equal(old_token)
      expect(new_token).not_to be_cancelled
    end

    it "resets cancelled state even if previously cancelled" do
      instance.cancel!
      expect(instance).to be_cancelled

      instance.send(:initialize_cancellation)
      expect(instance).not_to be_cancelled
    end
  end

  describe "#check_cancellation_if_enabled" do
    it "returns nil when not cancelled" do
      result = instance.send(:check_cancellation_if_enabled)
      expect(result).to be_nil
    end

    it "does not call finalize when not cancelled" do
      instance.send(:check_cancellation_if_enabled)
      expect(instance).not_to be_finalized
    end

    context "when cancelled" do
      before { instance.cancel! }

      it "calls finalize with :cancelled state" do
        instance.send(:check_cancellation_if_enabled)
        expect(instance).to be_finalized
        expect(instance.finalized_state).to eq(:cancelled)
      end

      it "returns a RunResult" do
        result = instance.send(:check_cancellation_if_enabled)
        expect(result).to be_a(Smolagents::Types::RunResult)
        expect(result).to be_cancelled
      end

      it "emits task_lifecycle event with step number from context" do
        instance.ctx = double("Context", step_number: 5)
        queue = Thread::Queue.new
        instance.connect_to(queue)

        instance.send(:check_cancellation_if_enabled)

        events = []
        events << queue.pop until queue.empty?

        lifecycle = events.find { |e| e.respond_to?(:phase) }
        expect(lifecycle).not_to be_nil
        expect(lifecycle.steps_taken).to eq(5)
        expect(lifecycle.outcome).to eq(:cancelled)
      end
    end
  end

  describe "thread safety", :slow do
    it "supports cancel from another thread" do
      thread = Thread.new { instance.cancel! }
      thread.join

      expect(instance).to be_cancelled
    end
  end
end
