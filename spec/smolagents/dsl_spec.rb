# frozen_string_literal: true

RSpec.describe Smolagents::DSL do
  describe ".define_tool" do
    it "creates a tool using DSL" do
      tool = described_class.define_tool(:calculator) do
        description "Performs calculations"
        input :expression, type: :string, description: "Math expression"
        output_type :number

        execute do |expression:|
          eval(expression) # In production, use safe_eval
        end
      end

      expect(tool).to be_a(Smolagents::Tool)
      expect(tool.name).to eq("calculator")
      expect(tool.description).to eq("Performs calculations")
    end

    it "executes tool with defined logic" do
      tool = described_class.define_tool(:doubler) do
        description "Doubles a number"
        input :n, type: :integer
        output_type :integer

        execute do |n:|
          n * 2
        end
      end

      result = tool.call(n: 5)
      expect(result).to eq(10)
    end

    it "supports multiple inputs" do
      tool = described_class.define_tool(:adder) do
        description "Adds two numbers"
        input :a, type: :integer, description: "First number"
        input :b, type: :integer, description: "Second number"
        output_type :integer

        execute do |a:, b:|
          a + b
        end
      end

      result = tool.call(a: 3, b: 7)
      expect(result).to eq(10)
    end

    it "supports bulk input definition" do
      tool = described_class.define_tool(:multi_input) do
        description "Test tool"
        inputs(
          x: { type: :integer, description: "First" },
          y: { type: :integer, description: "Second" },
          z: { type: :integer, description: "Third", nullable: true }
        )
        output_type :integer

        execute do |x:, y:, z: 0|
          x + y + z
        end
      end

      expect(tool.inputs.keys).to contain_exactly("x", "y", "z")
      expect(tool.inputs["z"]["nullable"]).to be true
    end

    it "supports nullable inputs" do
      tool = described_class.define_tool(:greeter) do
        description "Greets someone"
        input :name, type: :string
        input :title, type: :string, nullable: true
        output_type :string

        execute do |name:, title: nil|
          title ? "#{title} #{name}" : name
        end
      end

      expect(tool.call(name: "Alice")).to eq("Alice")
      expect(tool.call(name: "Bob", title: "Dr.")).to eq("Dr. Bob")
    end

    it "sets output schema when provided" do
      tool = described_class.define_tool(:structured) do
        description "Returns structured data"
        output_type :object
        output_schema({
                        type: "object",
                        properties: {
                          success: { type: "boolean" },
                          message: { type: "string" }
                        }
                      })

        execute do
          { success: true, message: "Done" }
        end
      end

      expect(tool.output_schema).to be_a(Hash)
      expect(tool.output_schema[:type]).to eq("object")
    end

    it "requires description" do
      expect do
        described_class.define_tool(:bad) do
          input :x, type: :string
          execute { "test" }
        end
      end.to raise_error(ArgumentError, /Description is required/)
    end

    it "requires execute block" do
      expect do
        described_class.define_tool(:bad) do
          description "Missing execute"
          input :x, type: :string
        end
      end.to raise_error(ArgumentError, /Execute block is required/)
    end
  end

  describe ".define_agent" do
    let(:mock_model) do
      instance_double(Smolagents::Model, model_id: "test-model")
    end

    it "creates an agent using DSL" do
      model = mock_model # Capture in local variable for DSL block
      agent = described_class.define_agent do
        use_model model
        max_steps 5

        tool :test_tool do
          description "Test"
          input :x, type: :string
          execute { |x:| x }
        end
      end

      expect(agent).to be_a(Smolagents::MultiStepAgent)
      expect(agent.max_steps).to eq(5)
      expect(agent.tools.size).to eq(1)
    end

    it "supports adding multiple tools" do
      model = mock_model
      agent = described_class.define_agent do
        use_model model

        tool :tool1 do
          description "First"
          execute { "1" }
        end

        tool :tool2 do
          description "Second"
          execute { "2" }
        end
      end

      expect(agent.tools.size).to eq(2)
      expect(agent.tools.keys).to contain_exactly("tool1", "tool2")
    end

    it "supports tools method for bulk addition" do
      model = mock_model
      # Mock default tools loader
      search_tool = instance_double(Smolagents::Tool, name: "search", to_code_prompt: "def search",
                                                      to_tool_calling_prompt: "search tool")
      final_tool = instance_double(Smolagents::Tool, name: "final_answer", to_code_prompt: "def final_answer",
                                                     to_tool_calling_prompt: "final_answer tool")

      allow_any_instance_of(Smolagents::DSL::AgentBuilder)
        .to receive(:load_default_tool)
        .and_return(search_tool, final_tool)

      agent = described_class.define_agent do
        use_model model
        tools :search, :final_answer
      end

      expect(agent.tools.size).to eq(2)
    end

    it "registers callbacks" do
      model = mock_model
      callback_called = false

      agent = described_class.define_agent do
        use_model model

        tool :test do
          description "Test"
          execute { "test" }
        end

        on :step_complete do |_step, _monitor|
          callback_called = true
        end
      end

      # Callbacks are registered but we can't easily test without running agent
      expect(agent).to be_a(Smolagents::MultiStepAgent)
    end

    it "sets agent name and description" do
      model = mock_model
      agent = described_class.define_agent do
        name "Research Bot"
        description "Helps with research"
        use_model model

        tool :test do
          description "Test"
          execute { "test" }
        end
      end

      # Name/description are set in builder but not exposed on agent
      # This tests that the DSL accepts them without error
      expect(agent).to be_a(Smolagents::MultiStepAgent)
    end

    it "supports agent_type configuration" do
      model = mock_model
      agent = described_class.define_agent do
        agent_type :tool_calling
        use_model model

        tool :test do
          description "Test"
          execute { "test" }
        end
      end

      # Type determines which agent class is instantiated
      # Since we don't have agents implemented yet, this just tests DSL
      expect(agent).to be_a(Smolagents::MultiStepAgent)
    end

    it "requires model" do
      expect do
        described_class.define_agent do
          tool :test do
            description "Test"
            execute { "test" }
          end
        end
      end.to raise_error(ArgumentError, /Model is required/)
    end

    it "requires at least one tool" do
      model = mock_model
      expect do
        described_class.define_agent do
          use_model model
        end
      end.to raise_error(ArgumentError, /At least one tool is required/)
    end

    it "supports adding tool instances directly" do
      model = mock_model
      my_tool = described_class.define_tool(:my_tool) do
        description "Custom tool"
        execute { "result" }
      end

      agent = described_class.define_agent do
        use_model model
        tool my_tool
      end

      expect(agent.tools["my_tool"]).to eq(my_tool)
    end
  end

  describe "Smolagents module convenience methods" do
    let(:mock_model) do
      instance_double(Smolagents::Model, model_id: "test")
    end

    it "provides Smolagents.define_agent shortcut" do
      model = mock_model
      agent = Smolagents.define_agent do
        use_model model
        tool :test do
          description "Test"
          execute { "test" }
        end
      end

      expect(agent).to be_a(Smolagents::MultiStepAgent)
    end

    it "provides Smolagents.define_tool shortcut" do
      tool = Smolagents.define_tool(:shortcut) do
        description "Shortcut test"
        execute { "works" }
      end

      expect(tool).to be_a(Smolagents::Tool)
      expect(tool.name).to eq("shortcut")
    end

    it "provides Smolagents.agent quick creation" do
      # Mock model creation
      allow(Smolagents::DSL::AgentBuilder).to receive(:new).and_call_original
      allow_any_instance_of(Smolagents::DSL::AgentBuilder)
        .to receive(:build_model)
        .and_return(mock_model)
      allow_any_instance_of(Smolagents::DSL::AgentBuilder)
        .to receive(:load_default_tool)
        .and_return(instance_double(Smolagents::Tool, name: "search", to_code_prompt: "def search",
                                                      to_tool_calling_prompt: "search tool"))

      agent = Smolagents.agent(
        model: "gpt-4",
        tools: [:search],
        max_steps: 8
      )

      expect(agent).to be_a(Smolagents::MultiStepAgent)
      expect(agent.max_steps).to eq(8)
    end
  end

  describe "integration examples" do
    let(:mock_model) do
      instance_double(Smolagents::Model, model_id: "test-model")
    end

    it "builds a complete agent with tools and callbacks" do
      model = mock_model
      step_names = []

      agent = Smolagents.define_agent do
        name "Demo Agent"
        description "Demonstrates all DSL features"
        use_model model
        agent_type :code
        max_steps 10

        # Define multiple tools
        tool :calculator do
          description "Calculate expressions"
          input :expr, type: :string
          output_type :number
          execute { |expr:| eval(expr) }
        end

        tool :formatter do
          description "Format text"
          input :text, type: :string
          input :uppercase, type: :boolean, nullable: true
          output_type :string

          execute do |text:, uppercase: false|
            uppercase ? text.upcase : text.downcase
          end
        end

        # Register callbacks
        on :step_complete do |step_name, _monitor|
          step_names << step_name
        end

        on :tokens_tracked do |_usage|
          # Track tokens
        end
      end

      expect(agent.tools.size).to eq(2)
      expect(agent.tools.keys).to contain_exactly("calculator", "formatter")
      expect(agent.max_steps).to eq(10)

      # Test tools work
      calc = agent.tools["calculator"]
      expect(calc.call(expr: "2 + 3")).to eq(5)

      formatter = agent.tools["formatter"]
      expect(formatter.call(text: "Hello", uppercase: true)).to eq("HELLO")
      expect(formatter.call(text: "World")).to eq("world")
    end

    it "combines tool DSL with agent DSL seamlessly" do
      model = mock_model
      # Create a standalone tool
      standalone_tool = Smolagents.define_tool(:standalone) do
        description "Standalone tool"
        input :value, type: :integer
        output_type :integer
        execute { |value:| value * 10 }
      end

      # Use it in an agent
      agent = Smolagents.define_agent do
        use_model model
        tool standalone_tool

        # Also define inline tool
        tool :inline do
          description "Inline tool"
          execute { "inline" }
        end
      end

      expect(agent.tools.size).to eq(2)
      expect(agent.tools["standalone"]).to eq(standalone_tool)
      expect(standalone_tool.call(value: 5)).to eq(50)
    end
  end
end
