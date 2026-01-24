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

      it "returns successful ExtractionResult" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_a(Smolagents::Types::ExtractionResult)
        expect(result).to be_success
        expect(result.code).to eq("puts 'hello'")
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
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_success
        expect(result.code).to eq("result = 2 + 2")
      end
    end

    context "with no code block (short text)" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "No code here, just text.",
          tool_calls: nil
        )
      end

      it "returns failed ExtractionResult with no_code reason" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_failure
        expect(result.code).to be_nil
        expect(result.reason).to eq(:no_code)
      end

      it "sets descriptive error on action_step" do
        parser.extract_code_from_response(action_step, response)

        expect(action_step.error).to eq("No code block found in response")
      end
    end

    context "with prose-only response (long text)" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "I understand your question about finding information on the web. " \
          "There are many different approaches one could take to solve this problem. " \
          "First, we need to consider what sources might be most reliable and authoritative. " \
          "Then we should think about how to structure our search query effectively.",
          tool_calls: nil
        )
      end

      it "returns failed ExtractionResult with prose_only reason" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_failure
        expect(result.reason).to eq(:prose_only)
      end

      it "sets prose error message" do
        parser.extract_code_from_response(action_step, response)

        expect(action_step.error).to eq("Response contained prose but no executable code")
      end
    end

    context "with empty response" do
      let(:response) do
        Smolagents::ChatMessage.assistant("", tool_calls: nil)
      end

      it "returns failed ExtractionResult with empty reason" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_failure
        expect(result.reason).to eq(:empty)
      end

      it "sets descriptive error" do
        parser.extract_code_from_response(action_step, response)

        expect(action_step.error).to eq("Response was empty")
      end
    end

    context "with whitespace-only response" do
      let(:response) do
        Smolagents::ChatMessage.assistant("   \n\t\n  ", tool_calls: nil)
      end

      it "returns failed ExtractionResult with empty reason" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_failure
        expect(result.reason).to eq(:empty)
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
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_success
        expect(result.code).to eq("final_answer(answer: 42)")
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
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_success
        expect(result.code).to eq("result = search(query: 'test')")
      end
    end

    context "with truncated code block" do
      let(:response) do
        Smolagents::ChatMessage.assistant(
          "Here's the code:\n```ruby\nresult = search(query:",
          tool_calls: nil
        )
      end

      it "returns failed ExtractionResult with truncated reason" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result).to be_failure
        expect(result.reason).to eq(:truncated)
      end

      it "sets truncated error message" do
        parser.extract_code_from_response(action_step, response)

        expect(action_step.error).to eq("Code block was truncated or incomplete")
      end

      it "preserves original text for debugging" do
        result = parser.extract_code_from_response(action_step, response)

        expect(result.original).to include("```ruby")
      end
    end
  end

  describe "debug logging" do
    let(:action_step) { Smolagents::ActionStepBuilder.new(step_number: 0) }
    let(:parser_with_logger) { TestCodeParserWithLogger.new(mock_logger) }
    let(:mock_logger) { instance_double(Logger) }

    before do
      stub_const("TestCodeParserWithLogger", Class.new do
        include Smolagents::Concerns::CodeParsing

        attr_reader :logger

        def initialize(logger)
          @logger = logger
        end
      end)
    end

    context "when extraction fails" do
      let(:response) do
        Smolagents::ChatMessage.assistant("No code here, just text.", tool_calls: nil)
      end

      it "logs original response at debug level" do
        allow(mock_logger).to receive(:debug)

        parser_with_logger.extract_code_from_response(action_step, response)

        expect(mock_logger).to have_received(:debug)
          .with("Code extraction failed (no_code): No code here, just text.")
      end
    end

    context "when extraction succeeds" do
      let(:response) do
        Smolagents::ChatMessage.assistant("```ruby\nputs 'hi'\n```", tool_calls: nil)
      end

      it "does not log" do
        allow(mock_logger).to receive(:debug)

        parser_with_logger.extract_code_from_response(action_step, response)

        expect(mock_logger).not_to have_received(:debug)
      end
    end

    context "with long response" do
      let(:long_text) { "x" * 300 }
      let(:response) do
        Smolagents::ChatMessage.assistant(long_text, tool_calls: nil)
      end

      it "truncates logged response to 200 chars" do
        logged_msg = nil
        allow(mock_logger).to receive(:debug) { |msg| logged_msg = msg }

        parser_with_logger.extract_code_from_response(action_step, response)

        expect(logged_msg).to include("...")
        expect(logged_msg.length).to be < 300
      end
    end
  end
end
