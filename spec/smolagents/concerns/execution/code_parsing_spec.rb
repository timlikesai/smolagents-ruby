RSpec.describe Smolagents::Concerns::CodeParsing do
  before do
    stub_const("TestCodeParser", Class.new do
      include Smolagents::Concerns::CodeParsing
    end)
  end

  let(:parser) { TestCodeParser.new }

  describe "#extract_code_from_response" do
    let(:action_step) do
      Smolagents::ActionStepBuilder.new(step_number: 0)
    end

    context "with valid ruby code block" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Here's the code:\n```ruby\nputs 'hello'\n```",
          tool_calls: nil
        )
      end

      it "extracts the code" do
        code = parser.extract_code_from_response(action_step, response)

        expect(code).to eq("puts 'hello'")
      end

      it "does not set error" do
        parser.extract_code_from_response(action_step, response)

        expect(action_step.error).to be_nil
      end
    end

    context "with generic code block" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Code:\n```\nresult = 2 + 2\n```",
          tool_calls: nil
        )
      end

      it "extracts generic code block if it looks like Ruby" do
        code = parser.extract_code_from_response(action_step, response)

        expect(code).to eq("result = 2 + 2")
      end
    end

    context "with no code block" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "No code here, just text.",
          tool_calls: nil
        )
      end

      it "returns nil" do
        code = parser.extract_code_from_response(action_step, response)

        expect(code).to be_nil
      end

      it "sets error on action_step" do
        parser.extract_code_from_response(action_step, response)

        expect(action_step.error).to eq("No code block found in response")
      end
    end

    context "with HTML code tags" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Try: <code>final_answer(answer: 42)</code>",
          tool_calls: nil
        )
      end

      it "extracts HTML code tags" do
        code = parser.extract_code_from_response(action_step, response)

        expect(code).to eq("final_answer(answer: 42)")
      end
    end

    context "with code inside backticks without newline" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Code: ```rubyresult = search(query: 'test')\n```",
          tool_calls: nil
        )
      end

      it "extracts code despite missing newline" do
        code = parser.extract_code_from_response(action_step, response)

        expect(code).to eq("result = search(query: 'test')")
      end
    end
  end
end
