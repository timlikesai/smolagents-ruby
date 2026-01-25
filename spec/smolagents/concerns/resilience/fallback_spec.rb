require "spec_helper"

RSpec.describe Smolagents::Concerns::ModelFallback do
  let(:test_class) do
    Class.new do
      include Smolagents::Concerns::ModelFallback
    end
  end

  let(:instance) { test_class.new }
  let(:primary_model) { double("PrimaryModel", id: "primary") }
  let(:backup_model) { double("BackupModel", id: "backup") }
  let(:emergency_model) { double("EmergencyModel", id: "emergency") }

  describe "#with_fallback" do
    it "adds a fallback model" do
      instance.with_fallback(backup_model)
      expect(instance.fallback_count).to eq(1)
    end

    it "returns self for chaining" do
      result = instance.with_fallback(backup_model)
      expect(result).to eq(instance)
    end

    it "allows multiple fallbacks to be chained" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      expect(instance.fallback_count).to eq(2)
    end

    it "preserves fallback order" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      chain = instance.model_chain
      expect(chain[1]).to eq(backup_model)
      expect(chain[2]).to eq(emergency_model)
    end

    it "allows same model as multiple fallbacks (though unusual)" do
      instance
        .with_fallback(backup_model)
        .with_fallback(backup_model)

      expect(instance.fallback_count).to eq(2)
    end
  end

  describe "#model_chain" do
    it "includes self as first element" do
      chain = instance.model_chain
      expect(chain.first).to eq(instance)
    end

    it "includes no fallbacks initially" do
      chain = instance.model_chain
      expect(chain.size).to eq(1)
    end

    it "includes added fallbacks in order" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      chain = instance.model_chain
      expect(chain).to eq([instance, backup_model, emergency_model])
    end

    it "returns immutable array" do
      instance.with_fallback(backup_model)
      chain1 = instance.model_chain
      chain2 = instance.model_chain

      # Each call returns a fresh array
      expect(chain1).to eq(chain2)
      expect(chain1.object_id).not_to eq(chain2.object_id)
    end
  end

  describe "#try_chain" do
    it "yields each model in the chain" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      yielded_models = []
      instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
        yielded_models << model
        nil # Don't return result
      end

      expect(yielded_models.size).to eq(3)
      expect(yielded_models.first).to eq(instance)
    end

    it "passes next model in chain" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      next_models = []
      instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
        next_models << next_model
        nil
      end

      expect(next_models[0]).to eq(backup_model)
      expect(next_models[1]).to eq(emergency_model)
      expect(next_models[2]).to be_nil
    end

    it "stops on first successful result" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      yielded = []
      result = instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
        yielded << model
        "success" if model == backup_model
      end

      expect(result).to eq("success")
      expect(yielded.size).to eq(2)
      expect(yielded).to eq([instance, backup_model])
    end

    it "returns nil if no model succeeds" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      result = instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
        nil # All models return nil
      end

      expect(result).to be_nil
    end

    it "passes messages through the chain" do
      instance.with_fallback(backup_model)

      messages_received = []
      instance.try_chain(["test_msg"], {}) do |model, next_model, messages, state|
        messages_received << messages
        nil
      end

      expect(messages_received).to all(eq(["test_msg"]))
    end

    it "passes state through the chain" do
      instance.with_fallback(backup_model)

      state = { attempt: 0 }
      instance.try_chain(["msg"], state) do |model, next_model, messages, st|
        st[:attempt] += 1
        nil
      end

      expect(state[:attempt]).to eq(2)
    end

    it "allows state mutation to be tracked" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      state = { errors: [] }
      instance.try_chain(["msg"], state) do |model, next_model, messages, st|
        st[:errors] << model
        nil if model != emergency_model
      end

      expect(state[:errors].size).to eq(3)
    end

    it "works with single model (no fallbacks)" do
      result = instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
        model == instance ? "success" : nil
      end

      expect(result).to eq("success")
    end
  end

  describe "#clear_fallbacks" do
    it "removes all fallback models" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      expect(instance.fallback_count).to eq(2)

      instance.clear_fallbacks

      expect(instance.fallback_count).to eq(0)
    end

    it "returns self for chaining" do
      instance.with_fallback(backup_model)
      result = instance.clear_fallbacks
      expect(result).to eq(instance)
    end

    it "allows re-adding fallbacks after clearing" do
      instance
        .with_fallback(backup_model)
        .clear_fallbacks
        .with_fallback(emergency_model)

      expect(instance.fallback_count).to eq(1)
      expect(instance.model_chain[1]).to eq(emergency_model)
    end

    it "handles clearing when no fallbacks exist" do
      expect { instance.clear_fallbacks }.not_to raise_error
      expect(instance.fallback_count).to eq(0)
    end
  end

  describe "#fallback_count" do
    it "returns 0 when no fallbacks" do
      expect(instance.fallback_count).to eq(0)
    end

    it "counts single fallback" do
      instance.with_fallback(backup_model)
      expect(instance.fallback_count).to eq(1)
    end

    it "counts multiple fallbacks" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      expect(instance.fallback_count).to eq(2)
    end

    it "updates after clear" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      expect(instance.fallback_count).to eq(2)

      instance.clear_fallbacks

      expect(instance.fallback_count).to eq(0)
    end
  end

  describe "chaining patterns" do
    it "supports DSL-style chaining" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)
        .with_fallback(double("LastResort"))

      expect(instance.fallback_count).to eq(3)
    end

    it "supports mixed operations" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)
        .clear_fallbacks
        .with_fallback(backup_model)

      chain = instance.model_chain
      expect(chain.size).to eq(2)
      expect(chain[1]).to eq(backup_model)
    end
  end

  describe "integration scenarios" do
    it "implements failover logic" do
      instance.with_fallback(backup_model)

      success_order = []
      result = instance.try_chain(["prompt"], {}) do |model, next_model, messages, state|
        if model == instance
          # Primary fails
          state[:error] = "Primary failed"
          nil
        else
          # Backup succeeds
          success_order << model
          "result from backup"
        end
      end

      expect(result).to eq("result from backup")
      expect(success_order).to include(backup_model)
    end

    it "implements cascading failover" do
      instance
        .with_fallback(backup_model)
        .with_fallback(emergency_model)

      attempt_count = 0
      result = instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
        attempt_count += 1
        "success from #{model.id}" if attempt_count == 3
      end

      expect(result).to eq("success from emergency")
      expect(attempt_count).to eq(3)
    end

    it "allows conditional fallback logic" do
      instance.with_fallback(backup_model)

      result = instance.try_chain(["msg"], { retry_count: 0 }) do |model, next_model, messages, state|
        state[:retry_count] += 1

        case model
        when instance
          nil # Primary fails
        when backup_model
          state[:retry_count] <= 2 ? "fallback result" : nil
        end
      end

      expect(result).to eq("fallback result")
    end
  end

  describe "error handling" do
    it "handles nil values in chain gracefully" do
      instance.with_fallback(nil) # Unusual but possible
      chain = instance.model_chain
      expect(chain).to include(nil)
    end

    it "allows yield block to raise errors" do
      instance.with_fallback(backup_model)

      expect do
        instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
          raise StandardError, "Processing error" if model == backup_model

          nil
        end
      end.to raise_error(StandardError, "Processing error")
    end

    it "does not catch errors in the block" do
      instance.with_fallback(backup_model)

      expect do
        instance.try_chain(["msg"], {}) do |model, next_model, messages, state|
          raise "Block error"
        end
      end.to raise_error(RuntimeError, "Block error")
    end
  end
end
