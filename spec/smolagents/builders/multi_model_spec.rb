require "spec_helper"

# rubocop:disable RSpec/DescribeClass -- integration spec testing DSL across classes
RSpec.describe "Multi-model DSL" do
  let(:execution_model) { Smolagents::Testing::MockModel.new(model_id: "execution-model") }
  let(:planning_model) { Smolagents::Testing::MockModel.new(model_id: "planning-model") }
  let(:evaluation_model) { Smolagents::Testing::MockModel.new(model_id: "evaluation-model") }

  describe "AgentBuilder#model with purpose" do
    describe "single-model mode (backwards compatibility)" do
      it "works with block only" do
        builder = Smolagents.agent.model { execution_model }

        expect(builder.config[:model_block]).to be_a(Proc)
        expect(builder.config[:model_block].call).to eq(execution_model)
      end

      it "works with direct instance" do
        builder = Smolagents.agent.model(execution_model)

        expect(builder.config[:model_block].call).to eq(execution_model)
      end

      it "does not set model_pool_config" do
        builder = Smolagents.agent.model { execution_model }

        expect(builder.config[:model_pool_config]).to be_nil
      end
    end

    describe "multi-model mode" do
      it "stores model in pool config for :execution purpose" do
        builder = Smolagents.agent.model(:execution) { execution_model }

        expect(builder.config[:model_pool_config]).not_to be_nil
        expect(builder.config[:model_pool_config].has_model?(:execution)).to be true
      end

      it "clears model_block when using purpose" do
        builder = Smolagents.agent.model(:execution) { execution_model }

        expect(builder.config[:model_block]).to be_nil
      end

      it "supports multiple purposes" do
        builder = Smolagents.agent
                            .model(:execution) { execution_model }
                            .model(:planning) { planning_model }
                            .model(:evaluation) { evaluation_model }

        pool_config = builder.config[:model_pool_config]
        expect(pool_config.purposes).to contain_exactly(:execution, :planning, :evaluation)
      end

      it "is immutable across calls" do
        builder1 = Smolagents.agent.model(:execution) { execution_model }
        builder2 = builder1.model(:planning) { planning_model }

        expect(builder1.config[:model_pool_config].purposes).to eq([:execution])
        expect(builder2.config[:model_pool_config].purposes).to contain_exactly(:execution, :planning)
      end

      it "supports all built-in purposes" do
        Smolagents::Builders::ModelConcern::BUILT_IN_PURPOSES.each do |purpose|
          builder = Smolagents.agent.model(purpose) { execution_model }

          expect(builder.config[:model_pool_config].has_model?(purpose)).to be true
        end
      end

      it "supports custom purposes" do
        builder = Smolagents.agent
                            .model(:triage) { execution_model }
                            .model(:vision) { planning_model }
                            .model(:reasoning) { evaluation_model }

        pool_config = builder.config[:model_pool_config]
        expect(pool_config.purposes).to contain_exactly(:triage, :vision, :reasoning)
        expect(pool_config.has_model?(:triage)).to be true
        expect(pool_config.has_model?(:vision)).to be true
        expect(pool_config.has_model?(:reasoning)).to be true
      end

      it "allows mixing built-in and custom purposes" do
        builder = Smolagents.agent
                            .model(:execution) { execution_model }
                            .model(:triage) { planning_model }

        pool_config = builder.config[:model_pool_config]
        expect(pool_config.purposes).to contain_exactly(:execution, :triage)
      end
    end

    describe "registered model lookup (symbol without block)" do
      before do
        Smolagents.configure do |c|
          c.models do |m|
            m = m.register(:test_model, -> { execution_model })
            m
          end
        end
      end

      after { Smolagents.reset_configuration! }

      it "looks up registered model (not treated as purpose)" do
        builder = Smolagents.agent.model(:test_model)

        # Should use model_block, not model_pool_config
        expect(builder.config[:model_block]).to be_a(Proc)
        expect(builder.config[:model_pool_config]).to be_nil
      end
    end

    describe "purpose detection" do
      it "treats any symbol with block as multi-model purpose" do
        builder = Smolagents.agent.model(:execution) { execution_model }

        expect(builder.config[:model_pool_config]).not_to be_nil
      end

      it "treats custom symbols with block as multi-model purpose" do
        builder = Smolagents.agent.model(:my_custom_purpose) { execution_model }

        expect(builder.config[:model_pool_config]).not_to be_nil
        expect(builder.config[:model_pool_config].has_model?(:my_custom_purpose)).to be true
      end

      it "treats symbols without block as registered model lookup" do
        # This will fail at build time if :unknown is not registered
        builder = Smolagents.agent.model(:unknown)

        expect(builder.config[:model_block]).to be_a(Proc)
        expect(builder.config[:model_pool_config]).to be_nil
      end
    end
  end

  describe "ModelConcern private methods" do
    let(:builder) { Smolagents::Builders::AgentBuilder.create }

    describe "#multi_model?" do
      it "returns false for single-model config" do
        builder = Smolagents.agent.model { execution_model }

        expect(builder.send(:multi_model?)).to be false
      end

      it "returns true for multi-model config" do
        builder = Smolagents.agent.model(:execution) { execution_model }

        expect(builder.send(:multi_model?)).to be true
      end
    end

    describe "#resolve_model" do
      it "resolves from model_block in single-model mode" do
        builder = Smolagents.agent.model { execution_model }

        expect(builder.send(:resolve_model)).to eq(execution_model)
      end

      it "resolves from pool config in multi-model mode" do
        builder = Smolagents.agent.model(:execution) { execution_model }

        expect(builder.send(:resolve_model)).to eq(execution_model)
      end

      it "raises when no model configured" do
        builder = Smolagents.agent

        expect { builder.send(:resolve_model) }.to raise_error(ArgumentError, /Model required/)
      end
    end

    describe "#resolve_model_pool_config" do
      it "returns pool config when multi-model" do
        builder = Smolagents.agent
                            .model(:execution) { execution_model }
                            .model(:planning) { planning_model }

        config = builder.send(:resolve_model_pool_config)

        expect(config).to be_a(Smolagents::Types::ModelPoolConfig)
        expect(config.multi_model?).to be true
      end

      it "wraps model_block in single pool config" do
        builder = Smolagents.agent.model { execution_model }

        config = builder.send(:resolve_model_pool_config)

        expect(config).to be_a(Smolagents::Types::ModelPoolConfig)
        expect(config.single_model?).to be true
        expect(config.resolve_model).to eq(execution_model)
      end
    end
  end

  describe "lazy instantiation" do
    it "does not call model factory until build time" do
      execution_count = 0
      planning_count = 0

      _builder = Smolagents.agent
                           .model(:execution) do
                             execution_count += 1
                             execution_model
                           end
                           .model(:planning) do
                             planning_count += 1
                             planning_model
                           end

      expect(execution_count).to eq(0)
      expect(planning_count).to eq(0)
    end

    it "resolves models at build time" do
      execution_count = 0

      _agent = Smolagents.agent
                         .model(:execution) do
                           execution_count += 1
                           execution_model.queue_final_answer("done")
                           execution_model
                         end
                         .build

      expect(execution_count).to eq(1)
    end
  end

  describe "chaining with other DSL methods" do
    include_context "with mocked tools"

    it "works with tools" do
      builder = Smolagents.agent
                          .model(:execution) { execution_model }
                          .tools(mock_search_tool)

      expect(builder.config[:model_pool_config]).not_to be_nil
      expect(builder.config[:tool_instances]).to eq([mock_search_tool])
    end

    it "works with planning" do
      builder = Smolagents.agent
                          .model(:execution) { execution_model }
                          .planning(interval: 3)

      expect(builder.config[:model_pool_config]).not_to be_nil
      expect(builder.config[:planning_interval]).to eq(3)
    end

    it "works with full configuration chain" do
      execution_model.queue_final_answer("result")

      agent = Smolagents.agent
                        .model(:execution) { execution_model }
                        .tools(mock_search_tool)
                        .max_steps(10)
                        .planning(interval: 5)
                        .instructions("Be helpful")
                        .build

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.max_steps).to eq(10)
      expect(agent.planning_interval).to eq(5)
    end
  end

  describe "integration with agent execution" do
    it "uses execution model for agent runs" do
      execution_model.queue_final_answer("The answer is 42")

      agent = Smolagents.agent
                        .model(:execution) { execution_model }
                        .build

      result = agent.run("What is the answer?")

      expect(result.output).to eq("The answer is 42")
      expect(execution_model.call_count).to eq(1)
    end
  end
end
# rubocop:enable RSpec/DescribeClass
