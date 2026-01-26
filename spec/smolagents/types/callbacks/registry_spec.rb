require "spec_helper"

RSpec.describe Smolagents::Types::Callbacks::Registry do
  # Create a test class that extends Registry to test the module methods
  let(:registry_class) do
    Class.new do
      extend Smolagents::Types::Callbacks::Registry
    end
  end

  describe "#valid_event?" do
    it "returns true for registered events" do
      expect(registry_class.valid_event?(:before_step)).to be true
      expect(registry_class.valid_event?(:after_step)).to be true
      expect(registry_class.valid_event?(:after_task)).to be true
      expect(registry_class.valid_event?(:on_max_steps)).to be true
      expect(registry_class.valid_event?(:after_monitor)).to be true
      expect(registry_class.valid_event?(:on_step_error)).to be true
      expect(registry_class.valid_event?(:on_tokens_tracked)).to be true
    end

    it "returns false for unregistered events" do
      expect(registry_class.valid_event?(:invalid_event)).to be false
      expect(registry_class.valid_event?(:unknown)).to be false
      expect(registry_class.valid_event?(:random_callback)).to be false
    end

    it "returns false for nil" do
      expect(registry_class.valid_event?(nil)).to be false
    end

    it "returns false for non-symbol values" do
      expect(registry_class.valid_event?("before_step")).to be false
    end
  end

  describe "#validate_event!" do
    it "does not raise for valid events" do
      expect { registry_class.validate_event!(:before_step) }.not_to raise_error
      expect { registry_class.validate_event!(:after_step) }.not_to raise_error
    end

    it "raises InvalidCallbackError for invalid events" do
      expect { registry_class.validate_event!(:invalid_event) }
        .to raise_error(Smolagents::Types::Callbacks::InvalidCallbackError)
    end

    it "includes event name in error message" do
      expect { registry_class.validate_event!(:my_bad_event) }
        .to raise_error(/my_bad_event/)
    end

    it "includes valid events in error message" do
      expect { registry_class.validate_event!(:invalid) }
        .to raise_error(/Valid events:.*before_step/)
    end
  end

  describe "#validate_args!" do
    it "validates event first" do
      expect { registry_class.validate_args!(:invalid_event, {}) }
        .to raise_error(Smolagents::Types::Callbacks::InvalidCallbackError)
    end

    context "with :before_step event" do
      it "accepts valid arguments" do
        expect { registry_class.validate_args!(:before_step, step_number: 1) }
          .not_to raise_error
      end

      it "raises when required argument is missing" do
        expect { registry_class.validate_args!(:before_step, {}) }
          .to raise_error(Smolagents::Types::Callbacks::InvalidArgumentError, /missing required arguments/)
      end

      it "raises for wrong argument type" do
        expect { registry_class.validate_args!(:before_step, step_number: "not_an_int") }
          .to raise_error(Smolagents::Types::Callbacks::InvalidArgumentError, /expected Integer/)
      end
    end

    context "with :on_max_steps event" do
      it "accepts valid step_count" do
        expect { registry_class.validate_args!(:on_max_steps, step_count: 10) }
          .not_to raise_error
      end

      it "rejects invalid step_count type" do
        expect { registry_class.validate_args!(:on_max_steps, step_count: "ten") }
          .to raise_error(Smolagents::Types::Callbacks::InvalidArgumentError)
      end
    end
  end

  describe "#signature_for" do
    it "returns CallbackSignature for valid event" do
      sig = registry_class.signature_for(:before_step)
      expect(sig).to be_a(Smolagents::Types::Callbacks::CallbackSignature)
    end

    it "returns signature with correct required_args" do
      sig = registry_class.signature_for(:before_step)
      expect(sig.required_args).to eq([:step_number])
    end

    it "raises InvalidCallbackError for invalid event" do
      expect { registry_class.signature_for(:invalid) }
        .to raise_error(Smolagents::Types::Callbacks::InvalidCallbackError)
    end
  end

  describe "#events" do
    it "returns array of event symbols" do
      events = registry_class.events
      expect(events).to be_an(Array)
      expect(events).to all(be_a(Symbol))
    end

    it "includes all defined events" do
      events = registry_class.events
      expect(events).to include(:before_step)
      expect(events).to include(:after_step)
      expect(events).to include(:after_task)
      expect(events).to include(:on_max_steps)
      expect(events).to include(:after_monitor)
      expect(events).to include(:on_step_error)
      expect(events).to include(:on_tokens_tracked)
    end

    it "matches DEFINITIONS keys" do
      expect(registry_class.events).to match_array(Smolagents::Types::Callbacks::DEFINITIONS.keys)
    end
  end

  describe "signature caching" do
    it "returns same signatures on repeated calls" do
      first_call = registry_class.signature_for(:before_step)
      second_call = registry_class.signature_for(:before_step)
      expect(first_call).to equal(second_call)
    end
  end
end
