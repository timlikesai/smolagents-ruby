require "spec_helper"

RSpec.describe Smolagents::Builders::ModelBuilderCallbacks do
  let(:builder_class) { Smolagents::Builders::ModelBuilder }
  let(:builder) { builder_class.create(:openai) }

  describe "callback registration methods" do
    describe "#on_failover" do
      it "registers a failover callback" do
        result = builder.on_failover { |_event| :handled }
        callback = result.config[:callbacks].find { |c| c[:type] == :failover }

        expect(callback).not_to be_nil
        expect(callback[:handler]).to be_a(Proc)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.on_failover { |_| nil }

        expect(result).not_to equal(builder)
        expect(result).to be_a(builder_class)
      end

      it "does not mutate original builder" do
        original_callbacks = builder.config[:callbacks].dup
        builder.on_failover { |_| nil }

        expect(builder.config[:callbacks]).to eq(original_callbacks)
      end
    end

    describe "#on_error" do
      it "registers an error callback" do
        result = builder.on_error { |_error, _attempt, _model| :handled }
        callback = result.config[:callbacks].find { |c| c[:type] == :error }

        expect(callback).not_to be_nil
        expect(callback[:handler]).to be_a(Proc)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.on_error { |_, _, _| nil }

        expect(result).not_to equal(builder)
      end
    end

    describe "#on_recovery" do
      it "registers a recovery callback" do
        result = builder.on_recovery { |_model, _attempt| :recovered }
        callback = result.config[:callbacks].find { |c| c[:type] == :recovery }

        expect(callback).not_to be_nil
        expect(callback[:handler]).to be_a(Proc)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.on_recovery { |_, _| nil }

        expect(result).not_to equal(builder)
      end
    end

    describe "#on_model_change" do
      it "registers a model_changed callback" do
        result = builder.on_model_change { |_old, _new| :changed }
        callback = result.config[:callbacks].find { |c| c[:type] == :model_changed }

        expect(callback).not_to be_nil
        expect(callback[:handler]).to be_a(Proc)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.on_model_change { |_, _| nil }

        expect(result).not_to equal(builder)
      end
    end

    describe "#on_queue_wait" do
      it "registers a queue_request_started callback" do
        result = builder.on_queue_wait { |_position, _elapsed| :waiting }
        callback = result.config[:callbacks].find { |c| c[:type] == :queue_request_started }

        expect(callback).not_to be_nil
        expect(callback[:handler]).to be_a(Proc)
      end

      it "returns a new builder instance (immutability)" do
        result = builder.on_queue_wait { |_, _| nil }

        expect(result).not_to equal(builder)
      end
    end
  end

  describe "callback accumulation" do
    it "accumulates multiple callbacks of different types" do
      result = builder
               .on_failover { :failover }
               .on_error { :error }
               .on_recovery { :recovery }

      expect(result.config[:callbacks].size).to eq(3)
      expect(result.config[:callbacks].map { |c| c[:type] }).to contain_exactly(:failover, :error, :recovery)
    end

    it "accumulates multiple callbacks of the same type" do
      result = builder
               .on_error { :first_error }
               .on_error { :second_error }

      error_callbacks = result.config[:callbacks].select { |c| c[:type] == :error }
      expect(error_callbacks.size).to eq(2)
    end
  end

  describe "callback format" do
    it "stores callbacks in hash format with :type and :handler keys" do
      result = builder.on_failover { :test }
      callback = result.config[:callbacks].first

      expect(callback).to have_key(:type)
      expect(callback).to have_key(:handler)
      expect(callback[:type]).to eq(:failover)
      expect(callback[:handler]).to be_a(Proc)
    end
  end

  describe "frozen builder" do
    it "raises FrozenError when adding callbacks to frozen builder" do
      frozen = builder.freeze!

      expect { frozen.on_failover { :test } }.to raise_error(FrozenError)
    end
  end
end
