RSpec.describe Smolagents::UserInputTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { question: "What is your name?" } }
  let(:required_input_name) { :question }

  before do
    # Mock stdin for testing
    allow($stdin).to receive(:gets).and_return("Test Response\n")
  end

  it_behaves_like "a valid tool"
  it_behaves_like "an executable tool"
  it_behaves_like "a tool with input validation"

  describe "tool configuration" do
    it "has tool_name 'ask_user'" do
      expect(described_class.tool_name).to eq("ask_user")
    end

    it "has description mentioning user input" do
      expect(tool.description).to include("user")
      expect(tool.description).to include("question")
    end

    it "has output_type 'string'" do
      expect(tool.output_type).to eq("string")
    end
  end

  describe "#execute" do
    it "prints the question to stdout" do
      expect { tool.execute(question: "Your name?") }
        .to output("Your name? => ").to_stdout
    end

    it "returns the user response with newline stripped" do
      result = tool.execute(question: "Test?")
      expect(result).to eq("Test Response")
    end

    it "handles empty responses" do
      allow($stdin).to receive(:gets).and_return("\n")

      result = tool.execute(question: "Empty?")
      expect(result).to eq("")
    end
  end
end
