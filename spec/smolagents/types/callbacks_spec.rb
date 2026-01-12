RSpec.describe Smolagents::Callbacks do
  describe ".valid_event?" do
    it "returns true for valid events" do
      expect(described_class.valid_event?(:step_start)).to be true
      expect(described_class.valid_event?(:step_complete)).to be true
      expect(described_class.valid_event?(:task_complete)).to be true
      expect(described_class.valid_event?(:max_steps_reached)).to be true
      expect(described_class.valid_event?(:on_step_complete)).to be true
      expect(described_class.valid_event?(:on_step_error)).to be true
      expect(described_class.valid_event?(:on_tokens_tracked)).to be true
    end

    it "returns false for invalid events" do
      expect(described_class.valid_event?(:unknown_event)).to be false
      expect(described_class.valid_event?(:random)).to be false
    end
  end

  describe ".validate_event!" do
    it "does not raise for valid events" do
      expect { described_class.validate_event!(:step_start) }.not_to raise_error
    end

    it "raises InvalidCallbackError for invalid events" do
      expect { described_class.validate_event!(:invalid_event) }
        .to raise_error(Smolagents::Callbacks::InvalidCallbackError, /Unknown callback event/)
    end

    it "includes valid events in error message" do
      expect { described_class.validate_event!(:invalid) }
        .to raise_error(/Valid events:.*step_start/)
    end
  end

  describe ".validate_args!" do
    context "with :step_start event" do
      it "accepts valid arguments" do
        expect { described_class.validate_args!(:step_start, step_number: 1) }.not_to raise_error
      end

      it "raises when required argument is missing" do
        expect { described_class.validate_args!(:step_start, {}) }
          .to raise_error(Smolagents::Callbacks::InvalidArgumentError, /missing required arguments: step_number/)
      end

      it "raises for wrong argument type" do
        expect { described_class.validate_args!(:step_start, step_number: "not an integer") }
          .to raise_error(Smolagents::Callbacks::InvalidArgumentError, /expected Integer/)
      end
    end

    context "with :step_complete event" do
      let(:action_step) do
        Smolagents::ActionStep.new(
          step_number: 1,
          timing: Smolagents::Timing.start_now.tap(&:stop),
          is_final_answer: false
        )
      end

      it "accepts valid arguments with monitor" do
        monitor = Smolagents::Concerns::Monitorable::StepMonitor.new(:test)
        expect { described_class.validate_args!(:step_complete, step: action_step, monitor: monitor) }.not_to raise_error
      end

      it "accepts nil monitor" do
        expect { described_class.validate_args!(:step_complete, step: action_step, monitor: nil) }.not_to raise_error
      end

      it "raises when step is missing" do
        expect { described_class.validate_args!(:step_complete, monitor: nil) }
          .to raise_error(Smolagents::Callbacks::InvalidArgumentError, /missing required arguments: step/)
      end
    end

    context "with :task_complete event" do
      let(:run_result) do
        Smolagents::RunResult.new(
          output: "result",
          state: :success,
          steps: [],
          token_usage: nil,
          timing: nil
        )
      end

      it "accepts valid RunResult" do
        expect { described_class.validate_args!(:task_complete, result: run_result) }.not_to raise_error
      end
    end

    context "with :max_steps_reached event" do
      it "accepts valid step_count" do
        expect { described_class.validate_args!(:max_steps_reached, step_count: 10) }.not_to raise_error
      end
    end

    context "with :on_step_complete event" do
      let(:monitor) { Smolagents::Concerns::Monitorable::StepMonitor.new(:test) }

      it "accepts symbol step_name" do
        expect { described_class.validate_args!(:on_step_complete, step_name: :test, monitor: monitor) }.not_to raise_error
      end

      it "accepts string step_name" do
        expect { described_class.validate_args!(:on_step_complete, step_name: "test", monitor: monitor) }.not_to raise_error
      end
    end

    context "with :on_step_error event" do
      let(:monitor) { Smolagents::Concerns::Monitorable::StepMonitor.new(:test) }
      let(:error) { StandardError.new("test error") }

      it "accepts valid arguments" do
        expect { described_class.validate_args!(:on_step_error, step_name: :test, error: error, monitor: monitor) }
          .not_to raise_error
      end
    end

    context "with :on_tokens_tracked event" do
      it "accepts valid TokenUsage" do
        usage = Smolagents::TokenUsage.new(input_tokens: 10, output_tokens: 5)
        expect { described_class.validate_args!(:on_tokens_tracked, usage: usage) }.not_to raise_error
      end
    end
  end

  describe ".signature_for" do
    it "returns CallbackSignature for valid event" do
      sig = described_class.signature_for(:step_start)
      expect(sig).to be_a(Smolagents::Callbacks::CallbackSignature)
      expect(sig.required_args).to eq([:step_number])
    end

    it "raises for invalid event" do
      expect { described_class.signature_for(:invalid) }
        .to raise_error(Smolagents::Callbacks::InvalidCallbackError)
    end
  end

  describe ".events" do
    it "returns all registered events" do
      events = described_class.events
      expect(events).to include(:step_start, :step_complete, :task_complete, :max_steps_reached)
      expect(events).to include(:on_step_complete, :on_step_error, :on_tokens_tracked)
    end
  end

  describe Smolagents::Callbacks::CallbackSignature do
    let(:signature) do
      described_class.new(
        required_args: [:name, :count],
        optional_args: [:extra],
        arg_types: { name: String, count: Integer }
      )
    end

    describe "#validate_args!" do
      it "passes with valid args" do
        expect { signature.validate_args!(:test, name: "test", count: 1) }.not_to raise_error
      end

      it "fails when missing required arg" do
        expect { signature.validate_args!(:test, name: "test") }
          .to raise_error(Smolagents::Callbacks::InvalidArgumentError, /missing required arguments: count/)
      end

      it "fails with wrong type" do
        expect { signature.validate_args!(:test, name: 123, count: 1) }
          .to raise_error(Smolagents::Callbacks::InvalidArgumentError, /expected String/)
      end

      it "allows nil values" do
        expect { signature.validate_args!(:test, name: nil, count: nil) }.not_to raise_error
      end
    end
  end
end
