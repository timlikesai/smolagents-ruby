RSpec.describe Smolagents::Testing::TestTools do
  describe ".echo" do
    let(:tool) { described_class.echo }

    it "returns a tool" do
      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "has correct name" do
      expect(tool.name).to eq("echo")
    end

    it "has correct description" do
      expect(tool.description).to be_a(String)
      expect(tool.description.downcase).to include("echo")
    end

    it "echoes back the message" do
      result = tool.call(message: "Hello world")

      expect(result).to eq("Hello world")
    end

    it "accepts string input" do
      result = tool.call(message: "test")

      expect(result).to eq("test")
    end

    it "is singleton - same instance returned" do
      tool1 = described_class.echo
      tool2 = described_class.echo

      expect(tool1).to equal(tool2)
    end
  end

  describe ".add" do
    let(:tool) { described_class.add }

    it "returns a tool" do
      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "has correct name" do
      expect(tool.name).to eq("add")
    end

    it "adds two integers" do
      result = tool.call(a: 5, b: 3)

      expect(result).to eq(8)
    end

    it "handles negative numbers" do
      result = tool.call(a: -5, b: 3)

      expect(result).to eq(-2)
    end

    it "handles zero" do
      result = tool.call(a: 0, b: 0)

      expect(result).to eq(0)
    end

    it "is singleton" do
      tool1 = described_class.add
      tool2 = described_class.add

      expect(tool1).to equal(tool2)
    end
  end

  describe ".multiply" do
    let(:tool) { described_class.multiply }

    it "returns a tool" do
      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "has correct name" do
      expect(tool.name).to eq("multiply")
    end

    it "multiplies two integers" do
      result = tool.call(a: 4, b: 3)

      expect(result).to eq(12)
    end

    it "handles negative numbers" do
      result = tool.call(a: -4, b: 3)

      expect(result).to eq(-12)
    end

    it "handles zero" do
      result = tool.call(a: 0, b: 5)

      expect(result).to eq(0)
    end

    it "is singleton" do
      tool1 = described_class.multiply
      tool2 = described_class.multiply

      expect(tool1).to equal(tool2)
    end
  end

  describe ".data" do
    let(:tool) { described_class.data }

    it "returns a tool" do
      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "has correct name" do
      expect(tool.name).to eq("get_data")
    end

    it "returns structured data" do
      result = tool.execute

      expect(result).to be_a(Hash)
      expect(result).to have_key(:name)
      expect(result).to have_key(:count)
      expect(result).to have_key(:active)
    end

    it "returns expected values" do
      result = tool.call

      expect(result[:name]).to eq("TestItem")
      expect(result[:count]).to eq(42)
      expect(result[:active]).to be true
    end

    it "is singleton" do
      tool1 = described_class.data
      tool2 = described_class.data

      expect(tool1).to equal(tool2)
    end
  end

  describe ".failing" do
    let(:tool) { described_class.failing }

    it "returns a tool" do
      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "has correct name" do
      expect(tool.name).to eq("failing_tool")
    end

    it "has description about failing" do
      expect(tool.description).to include("fail")
    end

    it "raises StandardError when called" do
      expect { tool.call }
        .to raise_error(StandardError, /intentionally failed/)
    end

    it "is singleton" do
      tool1 = described_class.failing
      tool2 = described_class.failing

      expect(tool1).to equal(tool2)
    end
  end

  describe ".strict_add" do
    let(:tool) { described_class.strict_add }

    it "returns a tool" do
      expect(tool).to be_a(Smolagents::Tools::Tool)
    end

    it "has correct name" do
      expect(tool.name).to eq("strict_add")
    end

    it "has integer input types" do
      expect(tool.inputs).to have_key(:a)
      expect(tool.inputs).to have_key(:b)
      expect(tool.inputs[:a][:type]).to eq("integer")
      expect(tool.inputs[:b][:type]).to eq("integer")
    end

    it "validates arguments are integers" do
      # Tool is configured to validate integer types
      expect(tool.inputs[:a][:description]).to include("integer")
      expect(tool.inputs[:b][:description]).to include("integer")
    end

    it "is singleton" do
      tool1 = described_class.strict_add
      tool2 = described_class.strict_add

      expect(tool1).to equal(tool2)
    end
  end

  describe "caching behavior" do
    it "caches instances after first call" do
      # Access all tools to populate cache
      described_class.echo
      described_class.add
      described_class.multiply
      described_class.data
      described_class.failing
      described_class.strict_add

      # Second access should return same instance
      echo1 = described_class.echo
      echo2 = described_class.echo

      expect(echo1).to equal(echo2)
    end
  end

  describe "tool specifications" do
    it "echo tool has string input type" do
      tool = described_class.echo

      expect(tool.inputs).to have_key(:message)
      expect(tool.inputs[:message][:type]).to eq("string")
    end

    it "add tool has integer input types" do
      tool = described_class.add

      expect(tool.inputs).to have_key(:a)
      expect(tool.inputs).to have_key(:b)
      expect(tool.inputs[:a][:type]).to eq("integer")
      expect(tool.inputs[:b][:type]).to eq("integer")
    end

    it "multiply tool has integer input types" do
      tool = described_class.multiply

      expect(tool.inputs).to have_key(:a)
      expect(tool.inputs).to have_key(:b)
      expect(tool.inputs[:a][:type]).to eq("integer")
      expect(tool.inputs[:b][:type]).to eq("integer")
    end

    it "data tool has no required inputs" do
      tool = described_class.data

      expect(tool.inputs).to be_empty
    end

    it "failing tool has no required inputs" do
      tool = described_class.failing

      expect(tool.inputs).to be_empty
    end

    it "strict_add tool has integer input types" do
      tool = described_class.strict_add

      expect(tool.inputs).to have_key(:a)
      expect(tool.inputs).to have_key(:b)
      expect(tool.inputs[:a][:type]).to eq("integer")
      expect(tool.inputs[:b][:type]).to eq("integer")
    end
  end

  describe "output types" do
    it "echo has string output" do
      expect(described_class.echo.output_type).to eq("string")
    end

    it "add has integer output" do
      expect(described_class.add.output_type).to eq("integer")
    end

    it "multiply has integer output" do
      expect(described_class.multiply.output_type).to eq("integer")
    end

    it "data has object output" do
      expect(described_class.data.output_type).to eq("object")
    end

    it "failing has string output" do
      expect(described_class.failing.output_type).to eq("string")
    end

    it "strict_add has integer output" do
      expect(described_class.strict_add.output_type).to eq("integer")
    end
  end
end
