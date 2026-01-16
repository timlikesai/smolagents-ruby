RSpec.describe Smolagents::Concerns::Specialized do
  let(:mock_model) { instance_double(Smolagents::OpenAIModel) }

  let(:search_tool) do
    Smolagents::Tools.define_tool(
      "test_search",
      description: "Search for something",
      inputs: { "query" => { type: "string", description: "Query" } },
      output_type: "string"
    ) { |query:| "Results for #{query}" }
  end

  let(:answer_tool) do
    Smolagents::Tools.define_tool(
      "final_answer",
      description: "Provide final answer",
      inputs: { "answer" => { type: "string", description: "Answer" } },
      output_type: "string"
    ) { |answer:| answer }
  end

  before do
    allow(Smolagents::Tools).to receive(:get).with("test_search").and_return(search_tool)
    allow(Smolagents::Tools).to receive(:get).with("final_answer").and_return(answer_tool)
  end

  describe "instructions DSL" do
    it "sets specialized instructions" do
      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions <<~TEXT
          You are a test agent.
        TEXT
      end

      expect(klass.specialized_instructions).to include("You are a test agent")
    end

    it "freezes instructions" do
      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions "Test instructions"
      end

      expect(klass.specialized_instructions).to be_frozen
    end
  end

  describe "default_tools DSL" do
    describe "with tool names" do
      it "resolves tools from registry" do
        klass = Class.new(Smolagents::Agents::Agent) do
          include Smolagents::Concerns::Specialized

          instructions "Test agent"
          default_tools :test_search, :final_answer
        end

        agent = klass.new(model: mock_model)

        expect(agent.tools.values).to include(search_tool, answer_tool)
      end
    end

    describe "with block" do
      it "allows dynamic tool instantiation" do
        klass = Class.new(Smolagents::Agents::Agent) do
          include Smolagents::Concerns::Specialized

          instructions "Test agent"

          default_tools do |_options|
            [
              Smolagents::Tools.get("test_search"),
              Smolagents::Tools.get("final_answer")
            ]
          end
        end

        agent = klass.new(model: mock_model)

        expect(agent.tools.values).to include(search_tool, answer_tool)
      end

      it "passes options to block" do
        received_options = nil

        klass = Class.new(Smolagents::Agents::Agent) do
          include Smolagents::Concerns::Specialized

          instructions "Test agent"

          default_tools do |options|
            received_options = options
            [Smolagents::Tools.get("final_answer")]
          end
        end

        klass.new(model: mock_model, custom_option: :test_value)

        expect(received_options[:custom_option]).to eq(:test_value)
      end
    end
  end

  describe "initialization" do
    it "passes custom_instructions to parent" do
      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions "Custom specialized instructions"
        default_tools :final_answer
      end

      agent = klass.new(model: mock_model)

      # The custom_instructions should be accessible via the agent
      expect(agent.instance_variable_get(:@custom_instructions)).to include("Custom specialized instructions")
    end

    it "passes model to parent" do
      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions "Test"
        default_tools :final_answer
      end

      agent = klass.new(model: mock_model)

      expect(agent.model).to eq(mock_model)
    end
  end

  describe "error handling" do
    it "raises on unknown tool name" do
      allow(Smolagents::Tools).to receive(:get).with("unknown_tool").and_return(nil)

      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions "Test"
        default_tools :unknown_tool
      end

      expect { klass.new(model: mock_model) }.to raise_error(ArgumentError, /Unknown tool/)
    end
  end

  describe "integration with existing agents" do
    it "works with Agent base class" do
      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions "Research specialist"
        default_tools :test_search, :final_answer
      end

      agent = klass.new(model: mock_model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
      expect(agent.tools.size).to eq(2)
    end

    it "works with Agent subclass with custom instructions" do
      klass = Class.new(Smolagents::Agents::Agent) do
        include Smolagents::Concerns::Specialized

        instructions "Calculator specialist"
        default_tools :final_answer
      end

      agent = klass.new(model: mock_model)

      expect(agent).to be_a(Smolagents::Agents::Agent)
    end
  end
end
