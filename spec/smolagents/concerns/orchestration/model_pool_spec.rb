require "spec_helper"

RSpec.describe Smolagents::Concerns::Orchestration::ModelPool do
  let(:pool_host) { Class.new { include Smolagents::Concerns::Orchestration::ModelPool }.new }
  let(:mock_model) { Smolagents::Testing::MockModel.new(model_id: "test-model") }
  let(:execution_model) { Smolagents::Testing::MockModel.new(model_id: "execution") }
  let(:planning_model) { Smolagents::Testing::MockModel.new(model_id: "planning") }

  describe "#configure_model_pool" do
    it "yields configurator when block given" do
      yielded = nil
      pool_host.configure_model_pool { |c| yielded = c }

      expect(yielded).to be_a(described_class::PoolConfigurator)
    end

    it "returns self for chaining" do
      result = pool_host.configure_model_pool

      expect(result).to eq(pool_host)
    end
  end

  describe "#register_model" do
    it "registers model for purpose" do
      pool_host.register_model(:execution) { mock_model }

      expect(pool_host.registered_purposes).to include(:execution)
    end

    it "returns self for chaining" do
      result = pool_host.register_model(:execution) { mock_model }

      expect(result).to eq(pool_host)
    end

    it "clears model instance cache" do
      pool_host.register_model(:execution) { execution_model }
      _ = pool_host.model_for(:execution) # Prime cache

      pool_host.register_model(:execution) { planning_model }

      expect(pool_host.model_for(:execution)).to eq(planning_model)
    end
  end

  describe "#model_for" do
    before do
      pool_host.register_model(:execution) { execution_model }
      pool_host.register_model(:planning) { planning_model }
    end

    it "returns model for purpose" do
      expect(pool_host.model_for(:execution)).to eq(execution_model)
      expect(pool_host.model_for(:planning)).to eq(planning_model)
    end

    it "defaults to :execution when nil" do
      expect(pool_host.model_for).to eq(execution_model)
      expect(pool_host.model_for(nil)).to eq(execution_model)
    end

    it "caches model instances" do
      first_call = pool_host.model_for(:execution)
      second_call = pool_host.model_for(:execution)

      expect(first_call).to equal(second_call)
    end
  end

  describe "#multi_model?" do
    it "returns false when no models registered" do
      expect(pool_host.multi_model?).to be false
    end

    it "returns true when multiple purposes registered" do
      pool_host.register_model(:execution) { execution_model }
      pool_host.register_model(:planning) { planning_model }

      expect(pool_host.multi_model?).to be true
    end

    it "returns true when single non-default purpose registered" do
      pool_host.register_model(:execution) { execution_model }

      expect(pool_host.multi_model?).to be true
    end
  end

  describe "#registered_purposes" do
    it "returns empty array when no models" do
      expect(pool_host.registered_purposes).to be_empty
    end

    it "returns all registered purposes" do
      pool_host.register_model(:execution) { execution_model }
      pool_host.register_model(:planning) { planning_model }

      expect(pool_host.registered_purposes).to contain_exactly(:execution, :planning)
    end
  end

  describe "#model_pool_config=" do
    it "sets config directly" do
      config = Smolagents::Types::ModelPoolConfig.single { mock_model }
      pool_host.model_pool_config = config

      expect(pool_host.model_pool_config).to eq(config)
    end

    it "clears instance cache" do
      pool_host.register_model(:execution) { execution_model }
      _ = pool_host.model_for(:execution)

      new_config = Smolagents::Types::ModelPoolConfig.create.with_model(:execution) { planning_model }
      pool_host.model_pool_config = new_config

      expect(pool_host.model_for(:execution)).to eq(planning_model)
    end
  end

  describe "PoolConfigurator" do
    it "registers models via fluent interface" do
      pool_host.configure_model_pool do |c|
        c.register(:execution) { execution_model }
         .register(:planning) { planning_model }
      end

      expect(pool_host.registered_purposes).to contain_exactly(:execution, :planning)
    end
  end

  describe "class-level configuration" do
    let(:klass) do
      Class.new do
        include Smolagents::Concerns::Orchestration::ModelPool
      end
    end

    it "has default pool config" do
      expect(klass.default_model_pool_config).to be_a(Smolagents::Types::ModelPoolConfig)
    end

    it "can set default pool config" do
      config = Smolagents::Types::ModelPoolConfig.single { mock_model }
      klass.default_model_pool_config = config

      expect(klass.default_model_pool_config).to eq(config)
    end

    it "inherits default config to instances" do
      config = Smolagents::Types::ModelPoolConfig.create.with_model(:execution) { mock_model }
      klass.default_model_pool_config = config

      instance = klass.new
      expect(instance.model_pool_config.purposes).to include(:execution)
    end
  end

  describe "lazy instantiation" do
    it "does not call factory until model_for" do
      call_count = 0
      pool_host.register_model(:execution) do
        call_count += 1
        mock_model
      end

      expect(call_count).to eq(0)
    end

    it "calls factory on first model_for" do
      call_count = 0
      pool_host.register_model(:execution) do
        call_count += 1
        mock_model
      end

      pool_host.model_for(:execution)
      expect(call_count).to eq(1)
    end

    it "caches result after first call" do
      call_count = 0
      pool_host.register_model(:execution) do
        call_count += 1
        mock_model
      end

      3.times { pool_host.model_for(:execution) }
      expect(call_count).to eq(1)
    end
  end
end
