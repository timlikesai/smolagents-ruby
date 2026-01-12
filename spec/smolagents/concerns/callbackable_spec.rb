RSpec.describe Smolagents::Concerns::Callbackable do
  let(:callbackable_class) do
    Class.new do
      include Smolagents::Concerns::Callbackable

      def trigger_test_event(**)
        trigger_callbacks(:before_step, **)
      end
    end
  end

  let(:instance) { callbackable_class.new }

  describe "#callbacks" do
    it "returns a hash with array default" do
      expect(instance.callbacks).to be_a(Hash)
      expect(instance.callbacks[:any_key]).to eq([])
    end
  end

  describe "#register_callback" do
    it "stores block callbacks" do
      called = false
      instance.register_callback(:before_step) { called = true }
      instance.trigger_test_event(step_number: 1)
      expect(called).to be true
    end

    it "stores callable callbacks" do
      called = false
      callback = proc { called = true }
      instance.register_callback(:before_step, callback)
      instance.trigger_test_event(step_number: 1)
      expect(called).to be true
    end

    it "returns self for chaining" do
      result = instance.register_callback(:before_step) { "noop" }
      expect(result).to eq(instance)
    end

    it "raises for unknown events when validation enabled" do
      expect { instance.register_callback(:unknown_event) { "noop" } }
        .to raise_error(Smolagents::Callbacks::InvalidCallbackError, /Unknown callback event/)
    end

    it "skips validation when validate: false" do
      expect { instance.register_callback(:unknown_event, validate: false) { "noop" } }
        .not_to raise_error
    end

    it "allows multiple callbacks for same event" do
      calls = []
      instance.register_callback(:before_step) { calls << :first }
      instance.register_callback(:before_step) { calls << :second }
      instance.trigger_test_event(step_number: 1)
      expect(calls).to eq(%i[first second])
    end
  end

  describe "#clear_callbacks" do
    before do
      instance.register_callback(:before_step) { "noop" }
      instance.register_callback(:after_step, validate: false) { "noop" }
    end

    it "clears specific event callbacks" do
      instance.clear_callbacks(:before_step)
      expect(instance.callback_registered?(:before_step)).to be false
      expect(instance.callback_registered?(:after_step)).to be true
    end

    it "clears all callbacks when no event specified" do
      instance.clear_callbacks
      expect(instance.callback_count).to eq(0)
    end

    it "returns self for chaining" do
      expect(instance.clear_callbacks(:before_step)).to eq(instance)
    end
  end

  describe "#callback_registered?" do
    it "returns true when callback exists" do
      instance.register_callback(:before_step) { "noop" }
      expect(instance.callback_registered?(:before_step)).to be true
    end

    it "returns false when no callback" do
      expect(instance.callback_registered?(:before_step)).to be false
    end
  end

  describe "#callback_count" do
    it "returns count for specific event" do
      instance.register_callback(:before_step) { "one" }
      instance.register_callback(:before_step) { "two" }
      expect(instance.callback_count(:before_step)).to eq(2)
    end

    it "returns total count when no event specified" do
      instance.register_callback(:before_step) { "one" }
      instance.register_callback(:after_step, validate: false) { "two" }
      expect(instance.callback_count).to eq(2)
    end
  end

  describe "callback invocation" do
    it "passes keyword arguments to callbacks accepting them" do
      received = nil
      instance.register_callback(:before_step) { |step_number:| received = step_number }
      instance.trigger_test_event(step_number: 42)
      expect(received).to eq(42)
    end

    it "passes positional arguments to callbacks with splat" do
      received = nil
      instance.register_callback(:before_step) { |step_num| received = step_num }
      instance.trigger_test_event(step_number: 42)
      expect(received).to eq(42)
    end

    it "calls zero-arity callbacks" do
      called = false
      instance.register_callback(:before_step) { called = true }
      instance.trigger_test_event(step_number: 1)
      expect(called).to be true
    end

    it "handles callback errors gracefully" do
      good_called = false
      instance.register_callback(:before_step) { raise "oops" }
      instance.register_callback(:before_step) { good_called = true }

      expect do
        expect { instance.trigger_test_event(step_number: 1) }.to output(/Callback error/).to_stderr
      end.not_to raise_error

      expect(good_called).to be true
    end
  end

  describe "class-level callback restrictions" do
    let(:restricted_class) do
      Class.new do
        include Smolagents::Concerns::Callbackable

        allowed_callbacks :custom_event, :another_event
      end
    end

    let(:restricted_instance) { restricted_class.new }

    it "allows registering allowed callbacks" do
      expect { restricted_instance.register_callback(:custom_event) { "noop" } }
        .not_to raise_error
    end

    it "rejects non-allowed callbacks" do
      expect { restricted_instance.register_callback(:before_step) { "noop" } }
        .to raise_error(Smolagents::Callbacks::InvalidCallbackError, /Unknown callback event.*Valid events:.*custom_event/)
    end

    it "reports validates_callback_events?" do
      expect(restricted_class.validates_callback_events?).to be true
      expect(callbackable_class.validates_callback_events?).to be false
    end

    it "returns allowed callbacks via callback_events" do
      expect(restricted_class.callback_events).to eq(%i[custom_event another_event])
    end
  end

  describe "integration with ReActLoop callbacks" do
    let(:react_compatible_class) do
      Class.new do
        include Smolagents::Concerns::Callbackable

        allowed_callbacks :before_step, :after_step, :after_task, :on_max_steps

        def run_step(step_number)
          trigger_callbacks(:before_step, step_number: step_number)
          step = Smolagents::ActionStep.new(
            step_number: step_number,
            timing: Smolagents::Timing.start_now.tap(&:stop),
            is_final_answer: step_number >= 3
          )
          trigger_callbacks(:after_step, step: step, monitor: nil)
          step
        end
      end
    end

    let(:react_instance) { react_compatible_class.new }

    it "triggers before_step with step_number" do
      received = nil
      react_instance.register_callback(:before_step) { |step_number:| received = step_number }
      react_instance.run_step(5)
      expect(received).to eq(5)
    end

    it "triggers after_step with step and monitor" do
      received_step = nil
      # rubocop:disable Lint/UnusedBlockArgument
      react_instance.register_callback(:after_step) { |step:, monitor:| received_step = step }
      # rubocop:enable Lint/UnusedBlockArgument
      step = react_instance.run_step(2)
      expect(received_step).to eq(step)
    end
  end
end
