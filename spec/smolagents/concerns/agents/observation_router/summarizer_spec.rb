require "spec_helper"

RSpec.describe Smolagents::Concerns::ObservationRouter::Summarizer do
  let(:mock_model) { Smolagents::Testing::MockModel.new }

  describe ".summarize" do
    context "with valid model response" do
      it "parses SUMMARY/RELEVANCE/NEXT format" do
        mock_model.queue_response(<<~RESPONSE)
          SUMMARY: Found 2 results about Ruby 4.0 features.
          RELEVANCE: High - directly answers the query
          NEXT: Extract the title from the first result
        RESPONSE

        result = described_class.summarize(
          model: mock_model,
          tool_name: "search",
          output: '[{"title": "Ruby 4.0"}]',
          task: "Find Ruby 4.0 features"
        )

        expect(result).to include("Summary: Found 2 results about Ruby 4.0 features")
        expect(result).to include("Relevance: High")
        expect(result).to include("Next: Extract the title")
      end

      it "handles partial format" do
        mock_model.queue_response("SUMMARY: Just a summary here")

        result = described_class.summarize(
          model: mock_model,
          tool_name: "search",
          output: "data",
          task: "task"
        )

        expect(result).to include("Summary: Just a summary here")
      end

      it "falls back to raw response if parsing fails" do
        mock_model.queue_response("This is an unstructured response")

        result = described_class.summarize(
          model: mock_model,
          tool_name: "search",
          output: "data",
          task: "task"
        )

        expect(result).to include("Summary:")
        expect(result).to include("This is an unstructured response")
      end
    end

    context "with model error" do
      it "returns error message" do
        error_model = instance_double(Smolagents::Models::Model)
        allow(error_model).to receive(:generate).and_raise(StandardError, "API error")

        result = described_class.summarize(
          model: error_model,
          tool_name: "search",
          output: "data",
          task: "task"
        )

        expect(result).to include("[Summary unavailable: API error]")
      end
    end

    context "with large output" do
      it "truncates output in prompt" do
        large_output = "x" * 5000

        mock_model.queue_response("SUMMARY: Processed large data")

        # Should not raise, should truncate internally
        result = described_class.summarize(
          model: mock_model,
          tool_name: "search",
          output: large_output,
          task: "task"
        )

        expect(result).to include("Summary:")
        # Verify prompt was truncated (check model received truncated version)
        prompt_content = mock_model.calls.last.messages.last.content
        expect(prompt_content).to include("[truncated")
      end
    end
  end
end
