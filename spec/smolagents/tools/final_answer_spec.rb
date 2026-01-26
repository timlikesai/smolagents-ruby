RSpec.describe Smolagents::FinalAnswerTool do
  let(:tool) { described_class.new }
  let(:valid_args) { { answer: "The final result" } }
  let(:required_input_name) { :answer }

  it_behaves_like "a valid tool"
  it_behaves_like "a tool with input validation"

  describe "tool configuration" do
    it "has tool_name 'final_answer'" do
      expect(described_class.tool_name).to eq("final_answer")
    end

    it "has description mentioning task completion" do
      expect(tool.description).to include("end the task")
    end

    it "has output_type 'any'" do
      expect(tool.output_type).to eq("any")
    end
  end

  describe "#execute" do
    it "raises FinalAnswerException with keyword argument" do
      expect { tool.execute(answer: "done") }
        .to raise_error(Smolagents::FinalAnswerException) do |error|
          expect(error.value).to eq("done")
        end
    end

    it "raises FinalAnswerException with positional argument" do
      expect { tool.execute("positional result") }
        .to raise_error(Smolagents::FinalAnswerException) do |error|
          expect(error.value).to eq("positional result")
        end
    end

    it "prefers keyword argument over positional" do
      expect { tool.execute("positional", answer: "keyword") }
        .to raise_error(Smolagents::FinalAnswerException) do |error|
          expect(error.value).to eq("keyword")
        end
    end
  end

  describe "#call" do
    it "raises FinalAnswerException (not wrapped)" do
      expect { tool.call(answer: "result") }
        .to raise_error(Smolagents::FinalAnswerException)
    end
  end
end
