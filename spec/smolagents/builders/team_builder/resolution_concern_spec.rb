require "spec_helper"

RSpec.describe Smolagents::Builders::TeamResolutionConcern do
  let(:test_builder_class) do
    Class.new(Data.define(:configuration)) do
      include Smolagents::Builders::TeamResolutionConcern

      def self.create
        new(configuration: { agents: {}, handlers: [] })
      end

      def with_config(new_config)
        self.class.new(configuration: configuration.merge(new_config))
      end
    end
  end

  let(:builder) { test_builder_class.create }

  describe "TeamResolutionConcern" do
    it "is included in builders" do
      expect(builder).to be_a(described_class)
    end

    it "provides resolution methods" do
      # The concern provides private methods for resolution
      expect(builder.class.private_instance_methods).to include(:resolve_model)
    end

    it "has build_managed_agents method" do
      expect(builder.class.private_instance_methods).to include(:build_managed_agents)
    end

    it "has build_coordinator method" do
      expect(builder.class.private_instance_methods).to include(:build_coordinator)
    end

    it "has register_handlers method" do
      expect(builder.class.private_instance_methods).to include(:register_handlers)
    end

    it "has validate_config! method" do
      expect(builder.class.private_instance_methods).to include(:validate_config!)
    end

    it "has resolve_agent method" do
      expect(builder.class.private_instance_methods).to include(:resolve_agent)
    end

    it "has resolve_agent_class method" do
      expect(builder.class.private_instance_methods).to include(:resolve_agent_class)
    end

    it "has field_to_config_key method" do
      expect(builder.class.private_instance_methods).to include(:field_to_config_key)
    end

    it "includes resolution functionality" do
      # The concern provides resolution capabilities
      expect(builder.class.ancestors).to include(described_class)
    end
  end

  describe "private resolution methods" do
    describe "#resolve_model (private)" do
      it "can be called via send for testing" do
        mock_model = instance_double(Smolagents::Models::Model)
        config = test_builder_class.new(configuration: { model_block: proc { mock_model }, agents: {} })

        result = config.send(:resolve_model)

        expect(result).to eq(mock_model)
      end

      it "raises error when no model available" do
        config = test_builder_class.create

        expect { config.send(:resolve_model) }
          .to raise_error(ArgumentError, /Model required/)
      end
    end

    describe "#build_managed_agents (private)" do
      it "creates managed agent tools from configuration" do
        # This method is called internally during build
        # Verify it's implemented in the concern
        expect(builder.class.private_instance_methods).to include(:build_managed_agents)
      end
    end

    describe "#validate_config! (private)" do
      it "raises error when no agents" do
        expect { builder.send(:validate_config!) }
          .to raise_error(ArgumentError, /At least one agent required/)
      end

      it "does not raise when agents present" do
        mock_agent = instance_double(Smolagents::Agents::Agent)
        config = test_builder_class.new(configuration: { agents: { researcher: mock_agent }, handlers: [] })

        expect { config.send(:validate_config!) }.not_to raise_error
      end
    end

    describe "#field_to_config_key (private)" do
      it "maps agent to agents" do
        result = builder.send(:field_to_config_key, :agent)

        expect(result).to eq(:agents)
      end

      it "returns name for unmapped fields" do
        result = builder.send(:field_to_config_key, :max_steps)

        expect(result).to eq(:max_steps)
      end
    end

    describe "#resolve_agent_class (private)" do
      it "returns agent class" do
        result = builder.send(:resolve_agent_class)

        expect(result).not_to be_nil
      end
    end
  end

  describe "configuration handling" do
    it "stores agents in configuration" do
      mock_agent = instance_double(Smolagents::Agents::Agent)
      config = test_builder_class.new(configuration: { agents: { researcher: mock_agent }, handlers: [] })

      expect(config.configuration[:agents]).to include(researcher: mock_agent)
    end

    it "stores handlers in configuration" do
      handler = proc { |_| :ok }
      config = test_builder_class.new(
        configuration: { agents: {}, handlers: [[:step_completed, handler]] }
      )

      expect(config.configuration[:handlers]).to include([:step_completed, handler])
    end

    it "stores model_block in configuration" do
      model_block = proc { "model" }
      config = test_builder_class.new(
        configuration: { agents: {}, model_block:, handlers: [] }
      )

      expect(config.configuration[:model_block]).to eq(model_block)
    end
  end
end
