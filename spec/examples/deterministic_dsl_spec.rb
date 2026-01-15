# Deterministic Examples Spec
#
# Tests all DSL patterns from examples/ directory WITHOUT requiring live models.
# Uses controllable mock models with Thread::Queue for synchronization.
#
# These tests verify:
# 1. Builder patterns construct objects correctly
# 2. Tool definitions work as documented
# 3. Configuration is properly applied
# 4. Pattern matching works on builders/results
#
# For live model integration tests, see spec/integration/comprehensive_examples_spec.rb

RSpec.describe "Deterministic DSL Examples" do
  # Controllable model - NO sleeps, NO timeouts
  let(:mock_model_class) do
    Class.new do
      attr_reader :model_id, :generate_calls

      def initialize(model_id: "test-model")
        @model_id = model_id
        @generate_calls = []
        @responses = []
        @mutex = Mutex.new
      end

      def queue_response(response)
        @responses << response
        self
      end

      def generate(messages, **)
        @mutex.synchronize { @generate_calls << messages }
        response = @responses.shift || default_response
        Smolagents::ChatMessage.assistant(response)
      end

      private

      def default_response
        <<~RESPONSE
          Thought: I need to provide a final answer.
          Code:
          ```ruby
          final_answer("Test response")
          ```
        RESPONSE
      end
    end
  end

  let(:mock_model) { mock_model_class.new }

  # Mock tool for testing
  let(:mock_tool) do
    Smolagents::Tools.define_tool(
      "mock_tool",
      description: "A mock tool for testing",
      inputs: { query: { type: "string", description: "Query string" } },
      output_type: "string"
    ) { |query:| "Result for: #{query}" }
  end

  describe "Agent Builder (from examples/agent_patterns.rb)" do
    it "builds code agent with fluent API" do
      agent = Smolagents.agent(:code)
                        .model { mock_model }
                        .tools(:final_answer)
                        .max_steps(15)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Code)
      expect(agent.model).to eq(mock_model)
      expect(agent.max_steps).to eq(15)
    end

    it "builds tool_calling agent" do
      agent = Smolagents.agent(:tool)
                        .model { mock_model }
                        .tools(:final_answer)
                        .build

      expect(agent).to be_a(Smolagents::Agents::Tool)
    end

    it "supports event handler registration" do
      agent = Smolagents.agent(:code)
                        .model { mock_model }
                        .tools(:final_answer)
                        .on(:step_complete) { |e|  }
                        .on(:task_complete) { |e|  }
                        .build

      # Agent includes Events::Consumer which manages handlers
      expect(agent).to respond_to(:on)
      expect(agent).to respond_to(:consume)
    end

    it "supports planning configuration" do
      agent = Smolagents.agent(:code)
                        .model { mock_model }
                        .tools(:final_answer)
                        .planning(interval: 5)
                        .max_steps(20)
                        .build

      expect(agent.planning_interval).to eq(5)
      expect(agent.max_steps).to eq(20)
    end

    it "maintains immutability across chains" do
      base = Smolagents.agent(:code)
                       .model { mock_model }
                       .tools(:final_answer)

      with_steps = base.max_steps(10)
      with_more_steps = base.max_steps(20)

      expect(with_steps.config[:max_steps]).to eq(10)
      expect(with_more_steps.config[:max_steps]).to eq(20)
    end

    it "provides help introspection" do
      builder = Smolagents.agent(:code)
      help = builder.help

      expect(help).to include("AgentBuilder")
      expect(help).to include("max_steps")
    end

    it "supports freeze for production configs" do
      frozen = Smolagents.agent(:code)
                         .model { mock_model }
                         .tools(:final_answer)
                         .freeze!

      expect(frozen.frozen_config?).to be true
      expect { frozen.max_steps(10) }.to raise_error(FrozenError)
    end
  end

  describe "Custom Tools (from examples/custom_tools.rb)" do
    it "creates block-based tool with define_tool" do
      calculator = Smolagents::Tools.define_tool(
        "calculator",
        description: "Evaluate math expressions",
        inputs: { expression: { type: "string", description: "Math expression" } },
        output_type: "number"
      ) { |expression:| eval(expression).to_f }

      result = calculator.call(expression: "2 + 3 * 4")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.data).to eq(14.0)
    end

    it "creates class-based tool with state" do
      tool_class = Class.new(Smolagents::Tool) do
        self.tool_name = "stateful"
        self.description = "Tool with state"
        self.inputs = {}
        self.output_type = "integer"

        def setup
          @count = 0
          super
        end

        def execute
          @count += 1
        end
      end

      tool = tool_class.new
      expect(tool.call.data).to eq(1)
      expect(tool.call.data).to eq(2)
    end

    it "supports chainable ToolResult operations" do
      search_results = Smolagents::Tools.define_tool(
        "search",
        description: "Search",
        inputs: { query: { type: "string", description: "Query" } },
        output_type: "array"
      ) do |query:|
        [
          { title: "Ruby Guide", score: 0.9, query: },
          { title: "Python Docs", score: 0.3 },
          { title: "Ruby Gems", score: 0.8 }
        ]
      end

      results = search_results.call(query: "Ruby")
                              .select { |r| r[:title].include?("Ruby") }
                              .sort_by { |r| -r[:score] } # Descending by negating
                              .pluck(:title)

      expect(results).to eq(["Ruby Guide", "Ruby Gems"])
    end

    it "supports pattern matching on ToolResult" do
      tool = Smolagents::Tools.define_tool(
        "data",
        description: "Return data",
        inputs: {},
        output_type: "array"
      ) { [1, 2, 3] }

      result = tool.call

      matched = case result
                in Smolagents::ToolResult[data: Array => items]
                  items.sum
                else
                  0
                end

      expect(matched).to eq(6)
    end
  end

  describe "Model Builder (from examples/local_models.rb)" do
    it "configures OpenAI-compatible model" do
      builder = Smolagents.model(:openai)
                          .id("test-model")
                          .api_key("test-key")
                          .temperature(0.7)
                          .max_tokens(2048)

      expect(builder.config[:model_id]).to eq("test-model")
      expect(builder.config[:api_key]).to eq("test-key")
      expect(builder.config[:temperature]).to eq(0.7)
      expect(builder.config[:max_tokens]).to eq(2048)
    end

    it "validates temperature range" do
      expect do
        Smolagents.model(:openai)
                  .id("test")
                  .temperature(5.0)
      end.to raise_error(ArgumentError, /Invalid value for temperature/)
    end

    it "supports pattern matching" do
      builder = Smolagents.model(:openai).id("gpt-4")

      matched = case builder
                in Smolagents::Builders::ModelBuilder[type_or_model: :openai]
                  "OpenAI builder"
                else
                  "Other"
                end

      expect(matched).to eq("OpenAI builder")
    end

    it "supports fluent configuration" do
      builder = Smolagents.model(:openai)
                          .id("test")
                          .temperature(0.5)
                          .max_tokens(1000)
                          .api_key("secret")

      expect(builder.config[:temperature]).to eq(0.5)
      expect(builder.config[:max_tokens]).to eq(1000)
      expect(builder.config[:api_key]).to eq("secret")
    end
  end

  describe "Team Builder (from examples/multi_agent_team.rb)" do
    let(:researcher) do
      Smolagents.agent(:tool)
                .model { mock_model }
                .tools(:final_answer)
                .build
    end

    let(:writer) do
      Smolagents.agent(:tool)
                .model { mock_model }
                .tools(:final_answer)
                .build
    end

    it "builds multi-agent team" do
      team = Smolagents.team
                       .model { mock_model }
                       .agent(researcher, as: "researcher")
                       .agent(writer, as: "writer")
                       .coordinate("Research then write")
                       .max_steps(20)
                       .build

      # Default coordinator is :code agent
      expect(team).to be_a(Smolagents::Agents::Code)
      expect(team.managed_agents.size).to eq(2)
      expect(team.managed_agents.keys).to contain_exactly("researcher", "writer")
    end

    it "supports nested agent builders" do
      team = Smolagents.team
                       .model { mock_model }
                       .agent(
                         Smolagents.agent(:tool).tools(:final_answer),
                         as: "agent1"
                       )
                       .coordinate("Coordinate")
                       .build

      expect(team.managed_agents).to have_key("agent1")
    end

    it "shares model with sub-agents when building from builders" do
      team = Smolagents.team
                       .model { mock_model }
                       .agent(
                         Smolagents.agent(:tool).tools(:final_answer),
                         as: "worker"
                       )
                       .coordinate("Work")
                       .build

      expect(team.model).to eq(mock_model)
      expect(team.managed_agents["worker"].agent.model).to eq(mock_model)
    end
  end

  describe "Pipeline (pipeline API)" do
    it "creates composable pipeline with call steps" do
      # Pipeline.call adds a tool call step (tool resolved at runtime)
      pipeline = Smolagents::Pipeline.new
                                     .call(:search, query: "Ruby")
                                     .pluck(:title)

      expect(pipeline).to be_a(Smolagents::Pipeline)
      expect(pipeline.steps.size).to eq(2)
    end

    it "supports transformation steps" do
      pipeline = Smolagents::Pipeline.new
                                     .select { |r| r[:score] > 0.5 }
                                     .take(5)

      expect(pipeline).to be_a(Smolagents::Pipeline)
      expect(pipeline.steps.size).to eq(2)
    end

    it "supports dynamic argument resolution with then" do
      pipeline = Smolagents::Pipeline.new
                                     .call(:search, query: :input)
                                     .then(:visit) { |prev| { url: prev.first[:url] } }
                                     .pluck(:content)

      expect(pipeline).to be_a(Smolagents::Pipeline)
      expect(pipeline.steps.size).to eq(3)
    end

    it "is immutable" do
      base = Smolagents::Pipeline.new
      with_select = base.select { |r| r[:score] > 0.5 }
      with_take = base.take(3)

      expect(base.steps.size).to eq(0)
      expect(with_select.steps.size).to eq(1)
      expect(with_take.steps.size).to eq(1)
    end
  end

  describe "DSL.Builder custom builders (from spec examples)" do
    before do
      stub_const("ExampleBuilder", Smolagents::DSL.Builder(:target, :configuration) do
        register_method :max_retries,
                        description: "Set maximum retry attempts (1-10)",
                        validates: ->(v) { v.is_a?(Integer) && (1..10).cover?(v) }

        def self.default_configuration
          { max_retries: 3, enabled: true }
        end

        def self.create(target)
          new(target:, configuration: default_configuration)
        end

        def max_retries(n)
          check_frozen!
          validate!(:max_retries, n)
          with_config(max_retries: n)
        end

        def build
          { target:, **configuration.except(:__frozen__) }
        end

        private

        def with_config(**kwargs)
          self.class.new(target:, configuration: configuration.merge(kwargs))
        end
      end)
    end

    it "includes Base module automatically" do
      expect(ExampleBuilder.ancestors).to include(Smolagents::Builders::Base)
    end

    it "provides help introspection" do
      builder = ExampleBuilder.create(:test)
      help = builder.help

      expect(help).to include("ExampleBuilder")
      expect(help).to include("max_retries")
    end

    it "validates at setter time" do
      builder = ExampleBuilder.create(:test)

      expect { builder.max_retries(15) }.to raise_error(ArgumentError, /Invalid value/)
      expect { builder.max_retries(5) }.not_to raise_error
    end

    it "supports freeze" do
      frozen = ExampleBuilder.create(:test).max_retries(5).freeze!

      expect(frozen.frozen_config?).to be true
      expect { frozen.max_retries(3) }.to raise_error(FrozenError)
    end

    it "supports pattern matching" do
      builder = ExampleBuilder.create(:test).max_retries(7)

      matched = case builder
                in ExampleBuilder[target: :test, configuration: { max_retries: }]
                  "Retries: #{max_retries}"
                else
                  "no match"
                end

      expect(matched).to eq("Retries: 7")
    end

    it "builds final object" do
      result = ExampleBuilder.create(:test).max_retries(8).build

      expect(result).to eq(target: :test, max_retries: 8, enabled: true)
    end
  end
end
