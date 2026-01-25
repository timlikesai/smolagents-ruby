require "spec_helper"

RSpec.describe Smolagents::Types::ModelPoolConfig do
  let(:mock_model) { Smolagents::Testing::MockModel.new(model_id: "test-model") }

  describe ".create" do
    subject(:config) { described_class.create }

    it "creates empty configuration" do
      expect(config.purposes).to be_empty
    end

    it "has default purpose of :default" do
      expect(config.default_purpose).to eq(:default)
    end

    it "has :first selection strategy" do
      expect(config.selection_strategy).to eq(:first)
    end
  end

  describe ".single" do
    subject(:config) { described_class.single { mock_model } }

    it "creates single-model configuration" do
      expect(config.single_model?).to be true
    end

    it "registers model under :default" do
      expect(config.purposes).to eq([:default])
    end

    it "resolves to the model" do
      expect(config.resolve_model).to eq(mock_model)
    end
  end

  describe "#with_model" do
    let(:config) { described_class.create }

    it "adds model for purpose" do
      new_config = config.with_model(:execution) { mock_model }

      expect(new_config.has_model?(:execution)).to be true
    end

    it "returns new config (immutable)" do
      new_config = config.with_model(:execution) { mock_model }

      expect(new_config).not_to eq(config)
      expect(config.purposes).to be_empty
    end

    it "requires a block" do
      expect { config.with_model(:execution) }.to raise_error(ArgumentError)
    end

    it "supports chaining" do
      new_config = config
                   .with_model(:execution) { mock_model }
                   .with_model(:planning) { mock_model }

      expect(new_config.purposes).to contain_exactly(:execution, :planning)
    end
  end

  describe "#with_default" do
    let(:config) { described_class.create.with_model(:planning) { mock_model } }

    it "sets default purpose" do
      new_config = config.with_default(:planning)

      expect(new_config.default_purpose).to eq(:planning)
    end
  end

  describe "#with_strategy" do
    let(:config) { described_class.create }

    it "sets selection strategy" do
      new_config = config.with_strategy(:health_aware)

      expect(new_config.selection_strategy).to eq(:health_aware)
    end

    it "rejects unknown strategies" do
      expect { config.with_strategy(:unknown) }.to raise_error(ArgumentError, /Unknown strategy/)
    end

    it "accepts valid strategies" do
      %i[first health_aware round_robin].each do |strategy|
        expect { config.with_strategy(strategy) }.not_to raise_error
      end
    end
  end

  describe "#single_model?" do
    it "returns true for single default model" do
      config = described_class.single { mock_model }

      expect(config.single_model?).to be true
    end

    it "returns false for multiple models" do
      config = described_class.create
                              .with_model(:execution) { mock_model }
                              .with_model(:planning) { mock_model }

      expect(config.single_model?).to be false
    end

    it "returns false for single non-default purpose" do
      config = described_class.create.with_model(:execution) { mock_model }

      expect(config.single_model?).to be false
    end
  end

  describe "#multi_model?" do
    it "returns false for single default model" do
      config = described_class.single { mock_model }

      expect(config.multi_model?).to be false
    end

    it "returns true for multiple models" do
      config = described_class.create
                              .with_model(:execution) { mock_model }
                              .with_model(:planning) { mock_model }

      expect(config.multi_model?).to be true
    end

    it "returns true for single non-default purpose" do
      config = described_class.create.with_model(:execution) { mock_model }

      expect(config.multi_model?).to be true
    end
  end

  describe "#factory_for" do
    let(:execution_model) { Smolagents::Testing::MockModel.new(model_id: "execution") }
    let(:planning_model) { Smolagents::Testing::MockModel.new(model_id: "planning") }
    let(:default_model) { Smolagents::Testing::MockModel.new(model_id: "default") }

    let(:config) do
      described_class.create
                     .with_model(:default) { default_model }
                     .with_model(:execution) { execution_model }
                     .with_model(:planning) { planning_model }
    end

    it "returns factory for registered purpose" do
      expect(config.factory_for(:execution).call).to eq(execution_model)
    end

    it "falls back to default for unknown purpose" do
      expect(config.factory_for(:unknown).call).to eq(default_model)
    end
  end

  describe "#resolve_model" do
    let(:model_a) { Smolagents::Testing::MockModel.new(model_id: "model-a") }
    let(:model_b) { Smolagents::Testing::MockModel.new(model_id: "model-b") }

    let(:config) do
      described_class.create
                     .with_model(:execution) { model_a }
                     .with_model(:planning) { model_b }
    end

    it "resolves model for purpose" do
      expect(config.resolve_model(:execution)).to eq(model_a)
      expect(config.resolve_model(:planning)).to eq(model_b)
    end

    it "raises for missing purpose without fallback" do
      config = described_class.create.with_model(:planning) { model_b }

      expect { config.resolve_model(:execution) }.to raise_error(ArgumentError, /No model configured/)
    end

    it "falls back when purpose not found" do
      config_with_default = config.with_model(:default) { model_a }

      expect(config_with_default.resolve_model(:unknown)).to eq(model_a)
    end
  end

  describe "model factories are lazy" do
    it "does not call factory until resolution" do
      call_count = 0
      config = described_class.create.with_model(:execution) do
        call_count += 1
        mock_model
      end

      expect(call_count).to eq(0)
      config.resolve_model(:execution)
      expect(call_count).to eq(1)
    end

    it "calls factory on each resolution" do
      call_count = 0
      config = described_class.create.with_model(:execution) do
        call_count += 1
        mock_model
      end

      2.times { config.resolve_model(:execution) }
      expect(call_count).to eq(2)
    end
  end

  describe "immutability" do
    let(:config) { described_class.create.with_model(:execution) { mock_model } }

    it "freezes model_factories" do
      expect(config.model_factories).to be_frozen
    end

    it "does not mutate original on with_model" do
      original_purposes = config.purposes.dup
      config.with_model(:planning) { mock_model }

      expect(config.purposes).to eq(original_purposes)
    end
  end

  describe "pattern matching" do
    let(:config) do
      described_class.create.with_model(:execution) { mock_model }
    end

    it "supports deconstruction" do
      case config
      in Smolagents::Types::ModelPoolConfig[default_purpose: purpose, selection_strategy: strategy]
        expect(purpose).to eq(:default)
        expect(strategy).to eq(:first)
      else
        raise "Pattern did not match"
      end
    end
  end
end
