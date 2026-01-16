RSpec.describe Smolagents::Tools::InlineTool do
  describe ".create" do
    it "creates an inline tool with name and description" do
      tool = described_class.create(:greet, "Say hello") { |name:| "Hello, #{name}!" }

      expect(tool.tool_name).to eq("greet")
      expect(tool.name).to eq("greet")
      expect(tool.description).to eq("Say hello")
    end

    it "converts input types to JSON Schema" do
      tool = described_class.create(:add, "Add numbers", a: Integer, b: Integer) { |a:, b:| a + b }

      expect(tool.inputs[:a][:type]).to eq("integer")
      expect(tool.inputs[:b][:type]).to eq("integer")
    end

    it "converts String type" do
      tool = described_class.create(:echo, "Echo", text: String) { |text:| text }
      expect(tool.inputs[:text][:type]).to eq("string")
    end

    it "converts Float type to number" do
      tool = described_class.create(:calc, "Calculate", value: Float) { |value:| value }
      expect(tool.inputs[:value][:type]).to eq("number")
    end

    it "converts Array type" do
      tool = described_class.create(:sum, "Sum", values: Array) { |values:| values.sum }
      expect(tool.inputs[:values][:type]).to eq("array")
    end

    it "converts Hash type to object" do
      tool = described_class.create(:process, "Process", data: Hash) { |data:| data }
      expect(tool.inputs[:data][:type]).to eq("object")
    end

    it "defaults output_type to any" do
      tool = described_class.create(:test, "Test") { "result" }
      expect(tool.output_type).to eq("any")
    end

    it "accepts custom output_type as keyword arg" do
      tool = described_class.create(:test, "Test", output_type: "string") { "result" }
      expect(tool.output_type).to eq("string")
    end

    it "accepts output_type with other inputs" do
      tool = described_class.create(:test, "Test", value: String, output_type: "string") { |value:| value }
      expect(tool.output_type).to eq("string")
      expect(tool.inputs[:value][:type]).to eq("string")
    end

    it "raises without block" do
      expect do
        described_class.create(:test, "Test")
      end.to raise_error(ArgumentError, /Block required/)
    end

    it "freezes tool_name, description, and inputs" do
      tool = described_class.create(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }

      expect(tool.tool_name).to be_frozen
      expect(tool.description).to be_frozen
      expect(tool.inputs).to be_frozen
    end
  end

  describe "#execute" do
    it "calls the block with keyword arguments" do
      tool = described_class.create(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }

      result = tool.execute(name: "World")

      expect(result).to eq("Hello, World!")
    end

    it "works with multiple arguments" do
      tool = described_class.create(:add, "Add", a: Integer, b: Integer) { |a:, b:| a + b }

      result = tool.execute(a: 2, b: 3)

      expect(result).to eq(5)
    end

    it "works with no arguments" do
      tool = described_class.create(:timestamp, "Get timestamp") { Time.now.to_i }

      result = tool.execute

      expect(result).to be_a(Integer)
    end
  end

  describe "#call" do
    it "wraps result in ToolResult" do
      tool = described_class.create(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }

      result = tool.call(name: "World")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.data).to eq("Hello, World!")
      expect(result.tool_name).to eq("greet")
    end
  end

  describe "#to_json_schema" do
    it "generates valid JSON Schema" do
      tool = described_class.create(:greet, "Say hello", name: String, formal: String) do |name:, formal:|
        formal == "true" ? "Good day, #{name}." : "Hey #{name}!"
      end

      schema = tool.to_json_schema

      expect(schema[:type]).to eq("function")
      expect(schema[:function][:name]).to eq("greet")
      expect(schema[:function][:description]).to eq("Say hello")
      expect(schema[:function][:parameters][:type]).to eq("object")
      expect(schema[:function][:parameters][:properties]).to have_key("name")
      expect(schema[:function][:parameters][:properties]).to have_key("formal")
      expect(schema[:function][:parameters][:required]).to contain_exactly("name", "formal")
    end
  end

  describe "#setup? and #setup" do
    it "always returns true for setup?" do
      tool = described_class.create(:test, "Test") { "result" }
      expect(tool.setup?).to be true
    end

    it "setup returns self" do
      tool = described_class.create(:test, "Test") { "result" }
      expect(tool.setup).to eq(tool)
    end
  end

  describe "#to_s and #inspect" do
    it "returns readable string representation" do
      tool = described_class.create(:greet, "Say hello to someone", name: String) { |name:| "Hello, #{name}!" }

      expect(tool.to_s).to eq("InlineTool(greet)")
      expect(tool.inspect).to include("InlineTool")
      expect(tool.inspect).to include("greet")
      expect(tool.inspect).to include("Say hello")
    end
  end

  describe "lambda conversion" do
    it "works with lambda passed as block" do
      greet = ->(name:) { "Hello, #{name}!" }
      tool = described_class.create(:greet, "Say hello", name: String, &greet)

      expect(tool.execute(name: "Lambda")).to eq("Hello, Lambda!")
    end

    it "works with proc" do
      greet = proc { |name:| "Hello, #{name}!" }
      tool = described_class.create(:greet, "Say hello", name: String, &greet)

      expect(tool.execute(name: "Proc")).to eq("Hello, Proc!")
    end
  end
end

RSpec.describe Smolagents::Builders::AgentBuilder, "#tool" do
  let(:model) { Smolagents::Testing::MockModel.new }

  before do
    model.queue_final_answer("done")
  end

  it "adds an inline tool to the agent" do
    builder = Smolagents.agent
                        .tool(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }
                        .model { model }

    agent = builder.build

    # Agent stores tools as hash with name => tool
    tool_names = agent.instance_variable_get(:@tools).keys
    expect(tool_names).to include("greet")
  end

  it "chains multiple inline tools" do
    builder = Smolagents.agent
                        .tool(:greet, "Say hello", name: String) { |name:| "Hello, #{name}!" }
                        .tool(:add, "Add numbers", a: Integer, b: Integer) { |a:, b:| a + b }
                        .model { model }

    agent = builder.build

    tool_names = agent.instance_variable_get(:@tools).keys
    expect(tool_names).to include("greet")
    expect(tool_names).to include("add")
  end

  it "combines inline tools with registry tools" do
    builder = Smolagents.agent
                        .tools(:search)
                        .tool(:custom, "Custom tool") { "custom result" }
                        .model { model }

    agent = builder.build

    tool_names = agent.instance_variable_get(:@tools).keys
    expect(tool_names).to include("duckduckgo_search")
    expect(tool_names).to include("custom")
  end

  it "raises without block" do
    expect do
      Smolagents.agent.tool(:test, "Test")
    end.to raise_error(ArgumentError, /Block required/)
  end
end
