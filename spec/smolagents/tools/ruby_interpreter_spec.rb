RSpec.describe Smolagents::RubyInterpreterTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { code: "1 + 1" } }
  let(:required_input_name) { :code }

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "configuration" do
    it "has the correct tool name" do
      expect(described_class.tool_name).to eq("ruby")
    end

    it "has a description mentioning code execution" do
      expect(described_class.description).to include("Ruby")
    end

    it "accepts code as input" do
      expect(described_class.inputs).to have_key(:code)
    end

    it "returns string output" do
      expect(described_class.output_type).to eq("string")
    end

    it "has a description about code execution" do
      tool = described_class.new
      expect(tool.description).to include("Ruby code")
    end
  end

  describe "initialization" do
    it "creates with default configuration" do
      tool = described_class.new

      expect(tool.timeout).to be_a(Integer)
      expect(tool.timeout).to be > 0
    end

    it "accepts timeout parameter" do
      tool = described_class.new(timeout: 60)

      expect(tool.timeout).to eq(60)
    end

    it "accepts max_operations parameter" do
      tool = described_class.new(max_operations: 50_000)

      expect(tool.instance_variable_get(:@max_operations)).to eq(50_000)
    end

    it "accepts max_output_length parameter" do
      tool = described_class.new(max_output_length: 20_000)

      expect(tool.instance_variable_get(:@max_output_length)).to eq(20_000)
    end

    it "accepts trace_mode parameter" do
      tool = described_class.new(trace_mode: :line)

      expect(tool.instance_variable_get(:@trace_mode)).to eq(:line)
    end

    it "accepts authorized_imports parameter" do
      imports = %w[JSON Time Math]
      tool = described_class.new(authorized_imports: imports)

      expect(tool.authorized_imports).to eq(imports)
    end
  end

  describe "#call" do
    it "executes Ruby code" do
      result = tool.call(code: "2 + 2")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.to_s).to include("4")
    end

    it "returns formatted result with output" do
      result = tool.call(code: '"Hello: " + "world"')

      expect(result.to_s).to include("Hello")
      expect(result.to_s).to include("world")
    end

    it "wraps result in ToolResult by default" do
      result = tool.call(code: "1")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.tool_name).to eq("ruby")
    end

    it "handles code errors gracefully" do
      result = tool.call(code: "1 / 0")

      expect(result).to be_a(Smolagents::ToolResult)
      expect(result.error?).to be true
      expect(result.metadata[:error]).to include("divided by 0")
    end

    it "supports wrap_result: false", max_time: 0.1 do
      result = tool.call(code: "42", wrap_result: false)

      expect(result).not_to be_a(Smolagents::ToolResult)
      expect(result).to be_a(String)
    end
  end

  describe "#execute" do
    it "returns string output" do
      output = tool.execute(code: "1 + 1")

      expect(output).to be_a(String)
      expect(output).to include("2")
    end

    it "executes complex Ruby code" do
      code = <<~RUBY
        data = [1, 2, 3, 4, 5]
        data.select { |x| x.even? }.sum
      RUBY

      output = tool.execute(code:)

      expect(output).to include("6")
    end

    it "captures printing output" do
      code = 'puts "Line 1"; puts "Line 2"'
      output = tool.execute(code:)

      expect(output).to include("Line 1")
      expect(output).to include("Line 2")
    end

    it "returns final expression value" do
      code = "x = 10; y = 20; x + y"
      output = tool.execute(code:)

      expect(output).to include("30")
    end
  end

  describe "inputs description" do
    it "includes authorized imports in description" do
      tool = described_class.new
      code_input = tool.inputs[:code]

      expect(code_input[:description]).to include("Allowed libraries")
    end

    it "updates description when authorized_imports changes" do
      imports = ["CustomLib"]
      tool = described_class.new(authorized_imports: imports)

      description = tool.inputs[:code][:description]
      expect(description).to include("CustomLib")
    end
  end

  describe "configuration resolution" do
    it "resolves timeout from parameter" do
      tool = described_class.new(timeout: 45)

      expect(tool.timeout).to eq(45)
    end

    it "resolves default values when parameters nil" do
      tool = described_class.new(timeout: nil)

      # Should use default from configuration
      expect(tool.timeout).to be_a(Integer)
      expect(tool.timeout).to be > 0
    end

    it "resolves authorized_imports" do
      tool = described_class.new

      expect(tool.authorized_imports).to be_a(Array)
      expect(tool.authorized_imports.all?(String)).to be true
    end
  end

  describe "executor building" do
    it "creates RactorExecutor" do
      tool = described_class.new

      executor = tool.instance_variable_get(:@executor)
      expect(executor).to be_a(Smolagents::RactorExecutor)
    end

    it "passes configuration to executor" do
      tool = described_class.new(
        max_operations: 75_000,
        max_output_length: 30_000
      )

      executor = tool.instance_variable_get(:@executor)
      expect(executor).to be_a(Smolagents::RactorExecutor)
    end
  end

  describe "safety and limitations" do
    it "rejects code with dangerous patterns" do
      # Security validation rejects dangerous code at validation time
      expect { tool.call(code: "`echo hi`") }
        .to raise_error(Smolagents::ArgumentValidationError)
    end

    it "rejects code with semicolons" do
      expect { tool.call(code: "a = 1; b = 2") }
        .to raise_error(Smolagents::ArgumentValidationError)
    end
  end

  describe "tool metadata" do
    it "generates code format" do
      format = tool.format_for(:code)

      expect(format).to be_a(String)
      expect(format).to include("ruby")
    end

    it "generates default format" do
      format = tool.format_for(:default)

      expect(format).to be_a(String)
      expect(format).to include(tool.name)
    end

    it "raises error for unknown format" do
      expect { tool.format_for(:tool_calling) }
        .to raise_error(ArgumentError, /Unknown tool format/)
    end
  end
end
