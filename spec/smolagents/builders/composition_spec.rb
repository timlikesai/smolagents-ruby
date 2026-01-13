RSpec.describe "Builder Composition" do
  describe "Full DSL composition" do
    let(:mock_model) do
      instance_double(Smolagents::Models::OpenAIModel,
                      model_id: "gpt-4",
                      generate: "test response")
    end

    let(:mock_tool) do
      instance_double(Smolagents::Tool,
                      name: "test_tool",
                      description: "Test tool",
                      inputs: {},
                      output_type: "string",
                      call: "tool result",
                      to_tool_calling_prompt: { name: "test_tool", description: "Test tool", parameters: {} })
    end

    before do
      # Mock tools registry
      allow(Smolagents::Tools).to receive(:get).with("test_tool").and_return(mock_tool)
      allow(Smolagents::Tools).to receive(:names).and_return(["test_tool"])
    end

    it "builds a complete team with model, agents, and event handlers" do
      team = Smolagents.team
                       .model { mock_model }
                       .coordinator(:tool_calling)
                       .agent(
                         Smolagents.agent(:tool_calling)
                           .tools(:test_tool)
                           .max_steps(5),
                         as: "researcher"
                       )
                       .agent(
                         Smolagents.agent(:tool_calling)
                           .tools(:test_tool)
                           .max_steps(5),
                         as: "writer"
                       )
                       .coordinate("Research and write")
                       .max_steps(10)
                       .on(:step_complete) { |e| puts e }
                       .on(:task_complete) { |e| puts e }
                       .build

      expect(team).to be_a(Smolagents::Agents::ToolCalling)
      expect(team.model).to eq(mock_model)
      expect(team.managed_agents.size).to eq(2)
      # managed_agents is a Hash with agent names as keys
      expect(team.managed_agents.keys).to contain_exactly("researcher", "writer")
    end

    it "validates configurations early with helpful errors" do
      # Temperature out of range
      expect do
        Smolagents.model(:openai)
                  .id("gpt-4")
                  .temperature(5.0)
      end.to raise_error(ArgumentError, /Invalid value for temperature.*0.0-2.0/)

      # Max steps out of range
      expect do
        Smolagents.agent(:code)
                  .model { mock_model }
                  .max_steps(1001)
      end.to raise_error(ArgumentError, /Invalid value for max_steps/)

      # Empty coordination instructions
      expect do
        Smolagents.team
                  .model { mock_model }
                  .coordinate("")
      end.to raise_error(ArgumentError, /Invalid value for coordinate/)
    end

    it "supports convenience aliases throughout the DSL" do
      # Model aliases
      model_builder = Smolagents.model(:openai)
                                .id("gpt-4")
                                .temp(0.7)           # alias for temperature
                                .tokens(4000)        # alias for max_tokens
                                .key("test-key")     # alias for api_key

      expect(model_builder.config[:temperature]).to eq(0.7)
      expect(model_builder.config[:max_tokens]).to eq(4000)
      expect(model_builder.config[:api_key]).to eq("test-key")

      # Agent aliases
      agent_builder = Smolagents.agent(:code)
                                .model { mock_model }
                                .steps(15)           # alias for max_steps
                                .prompt("Custom")    # alias for instructions

      expect(agent_builder.config[:max_steps]).to eq(15)
      expect(agent_builder.config[:custom_instructions]).to eq("Custom")

      # Team aliases
      team_builder = Smolagents.team
                               .model { mock_model }
                               .steps(20) # alias for max_steps
                               .instructions("Coordinate") # alias for coordinate

      expect(team_builder.config[:max_steps]).to eq(20)
      expect(team_builder.config[:coordinator_instructions]).to eq("Coordinate")
    end

    it "freezes production configurations safely" do
      # Freeze model config
      prod_model = Smolagents.model(:openai)
                             .id("gpt-4")
                             .api_key(ENV.fetch("OPENAI_API_KEY", "test-key"))
                             .temperature(0.7)
                             .freeze!

      expect(prod_model.frozen_config?).to be true
      expect { prod_model.temperature(0.5) }.to raise_error(FrozenError)

      # Can still build from frozen config
      model = prod_model.build
      expect(model).to be_a(Smolagents::OpenAIModel)

      # Freeze agent config
      prod_agent = Smolagents.agent(:tool_calling)
                             .model { mock_model }
                             .tools(:test_tool)
                             .max_steps(10)
                             .freeze!

      expect(prod_agent.frozen_config?).to be true
      expect { prod_agent.max_steps(5) }.to raise_error(FrozenError)
    end

    it "supports pattern matching for conditional configuration" do
      def configure_for_environment(builder)
        case builder
        in Smolagents::Builders::ModelBuilder[type_or_model: :openai]
          builder.timeout(30)
        in Smolagents::Builders::ModelBuilder[type_or_model: :anthropic]
          builder.timeout(60)
        else
          builder
        end
      end

      openai_builder = Smolagents.model(:openai).id("gpt-4")
      configured = configure_for_environment(openai_builder)
      expect(configured.config[:timeout]).to eq(30)

      anthropic_builder = Smolagents.model(:anthropic).id("claude-3")
      configured = configure_for_environment(anthropic_builder)
      expect(configured.config[:timeout]).to eq(60)
    end

    it "provides help introspection at any point" do
      model_help = Smolagents.model(:openai).help
      expect(model_help).to include("ModelBuilder - Available Methods")
      expect(model_help).to include(".temperature")
      expect(model_help).to include("aliases: temp")

      agent_help = Smolagents.agent(:code).help
      expect(agent_help).to include("AgentBuilder - Available Methods")
      expect(agent_help).to include(".max_steps")
      expect(agent_help).to include("aliases: steps")

      team_help = Smolagents.team.help
      expect(team_help).to include("TeamBuilder - Available Methods")
      expect(team_help).to include(".coordinate")
      expect(team_help).to include("aliases: instructions")
    end

    it "chains event handlers consistently across all builders" do
      # Agent with event handlers
      agent = Smolagents.agent(:tool_calling)
                        .model { mock_model }
                        .tools(:test_tool)
                        .on(:step_complete) { |e| puts e }
                        .on(:task_complete) { |e| puts e }
                        .build

      # Agent includes Events::Consumer for event handling
      expect(agent).to respond_to(:on)
      expect(agent).to respond_to(:consume)

      # Team with event handlers
      team = Smolagents.team
                       .model { mock_model }
                       .agent(agent, as: "worker")
                       .coordinate("Coordinate work")
                       .on(:step_complete) { |e| puts e }
                       .on(:task_complete) { |e| puts e }
                       .build

      expect(team).to respond_to(:on)
      expect(team).to respond_to(:consume)
    end

    it "maintains immutability throughout the chain" do
      # Start with base builder
      base = Smolagents.model(:openai)

      # Each method returns a new instance
      with_id = base.id("gpt-4")
      with_temp = with_id.temperature(0.7)
      with_tokens = with_temp.max_tokens(4000)

      # Original unchanged
      expect(base.config[:model_id]).to be_nil
      expect(base.config[:temperature]).to be_nil
      expect(base.config[:max_tokens]).to be_nil

      # Each step preserved
      expect(with_id.config[:model_id]).to eq("gpt-4")
      expect(with_id.config[:temperature]).to be_nil

      expect(with_temp.config[:model_id]).to eq("gpt-4")
      expect(with_temp.config[:temperature]).to eq(0.7)
      expect(with_temp.config[:max_tokens]).to be_nil

      expect(with_tokens.config[:model_id]).to eq("gpt-4")
      expect(with_tokens.config[:temperature]).to eq(0.7)
      expect(with_tokens.config[:max_tokens]).to eq(4000)
    end

    it "supports nested agent builders in teams" do
      team = Smolagents.team
                       .model { mock_model }
                       .agent(
                         Smolagents.agent(:tool_calling)
                           .tools(:test_tool)
                           .max_steps(8)
                           .instructions("Research the topic"),
                         as: "researcher"
                       )
                       .agent(
                         Smolagents.agent(:tool_calling)
                           .tools(:test_tool)
                           .max_steps(10)
                           .instructions("Write the report"),
                         as: "writer"
                       )
                       .coordinate("Coordinate research and writing")
                       .planning(interval: 3)
                       .max_steps(15)
                       .build

      # Verify team structure
      expect(team.managed_agents.size).to eq(2)
      expect(team.max_steps).to eq(15)
      expect(team.planning_interval).to eq(3)

      # Verify sub-agents have their own configuration (managed_agents is a Hash of ManagedAgentTool)
      expect(team.managed_agents["researcher"].agent.max_steps).to eq(8)
      expect(team.managed_agents["writer"].agent.max_steps).to eq(10)
    end

    it "shares model configuration across team members" do
      shared_model_called = false
      shared_model_block = proc do
        shared_model_called = true
        mock_model
      end

      team = Smolagents.team
                       .model(&shared_model_block)
                       .agent(
                         Smolagents.agent(:tool_calling).tools(:test_tool),
                         as: "agent1"
                       )
                       .agent(
                         Smolagents.agent(:tool_calling).tools(:test_tool),
                         as: "agent2"
                       )
                       .coordinate("Coordinate")
                       .build

      # Model shared between coordinator and sub-agents (managed_agents is a Hash of ManagedAgentTool)
      expect(team.model).to eq(mock_model)
      expect(team.managed_agents["agent1"].agent.model).to eq(mock_model)
      expect(team.managed_agents["agent2"].agent.model).to eq(mock_model)
    end
  end

  describe "Custom builder composition with DSL.Builder" do
    # Create a custom pipeline builder for testing
    PipelineBuilder = Smolagents::DSL.Builder(:name, :configuration) do
      builder_method :max_retries,
                     description: "Set maximum retry attempts (1-10)",
                     validates: ->(v) { v.is_a?(Integer) && (1..10).cover?(v) }

      def self.create(name)
        new(name: name, configuration: { max_retries: 3, enabled: true })
      end

      def max_retries(n)
        check_frozen!
        validate!(:max_retries, n)
        with_config(max_retries: n)
      end

      def enabled(value)
        with_config(enabled: value)
      end

      def build
        { name: name, **configuration.except(:__frozen__) }
      end

      private

      def with_config(**kwargs)
        self.class.new(name: name, configuration: configuration.merge(kwargs))
      end
    end

    it "creates custom builders with all core features" do
      builder = PipelineBuilder.create(:test_pipeline)

      # Has help
      help = builder.help
      expect(help).to include("PipelineBuilder - Available Methods")
      expect(help).to include("max_retries")

      # Has validation
      expect { builder.max_retries(15) }.to raise_error(ArgumentError)
      expect { builder.max_retries(5) }.not_to raise_error

      # Has freeze
      frozen = builder.max_retries(7).freeze!
      expect(frozen.frozen_config?).to be true
      expect { frozen.max_retries(3) }.to raise_error(FrozenError)

      # Can build
      result = builder.max_retries(8).enabled(false).build
      expect(result).to eq(name: :test_pipeline, max_retries: 8, enabled: false)
    end

    it "supports pattern matching on custom builders" do
      builder = PipelineBuilder.create(:my_pipeline).max_retries(7)

      matched = case builder
                in PipelineBuilder[name: :my_pipeline, configuration: { max_retries: }]
                  "Retries: #{max_retries}"
                else
                  "no match"
                end

      expect(matched).to eq("Retries: 7")
    end
  end
end
