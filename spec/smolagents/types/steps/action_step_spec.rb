RSpec.describe Smolagents::ActionStep do
  describe "tool output delimiters" do
    describe "#to_messages" do
      context "with observations" do
        let(:step) { described_class.new(step_number: 1, observations: "Search result: Paris") }

        it "wraps observations in tool_output tags" do
          messages = step.to_messages
          observation_msg = messages.find { |m| m.content.include?("Observation:") }

          expect(observation_msg).not_to be_nil
          expect(observation_msg.content).to include("<tool_output>")
          expect(observation_msg.content).to include("</tool_output>")
          expect(observation_msg.content).to include("Search result: Paris")
        end

        it "places content between the tags" do
          messages = step.to_messages
          observation_msg = messages.find { |m| m.content.include?("Observation:") }

          # Verify the structure: Observation:\n<tool_output>\n...content...\n</tool_output>
          expected_pattern = %r{Observation:\n<tool_output>\nSearch result: Paris\n</tool_output>}
          expect(observation_msg.content).to match(expected_pattern)
        end
      end

      context "with error" do
        let(:step) { described_class.new(step_number: 1, error: "Tool failed: connection timeout") }

        it "wraps error text in tool_output tags" do
          messages = step.to_messages
          error_msg = messages.find { |m| m.content.include?("Error:") }

          expect(error_msg).not_to be_nil
          expect(error_msg.content).to include("<tool_output>")
          expect(error_msg.content).to include("</tool_output>")
          expect(error_msg.content).to include("Tool failed: connection timeout")
        end

        it "includes error recovery guidance after the tags" do
          messages = step.to_messages
          error_msg = messages.find { |m| m.content.include?("Error:") }

          # Error guidance should appear after </tool_output>
          expect(error_msg.content).to match(%r{</tool_output>\nNow let's retry})
        end
      end

      context "with exception error" do
        let(:exception) { StandardError.new("Something went wrong") }
        let(:step) { described_class.new(step_number: 1, error: exception) }

        it "wraps exception message in tool_output tags" do
          messages = step.to_messages
          error_msg = messages.find { |m| m.content.include?("Error:") }

          expect(error_msg.content).to include("<tool_output>")
          expect(error_msg.content).to include("Something went wrong")
          expect(error_msg.content).to include("</tool_output>")
        end
      end

      context "without observations or errors" do
        let(:step) { described_class.new(step_number: 1) }

        it "returns no observation or error messages" do
          messages = step.to_messages

          observation_msg = messages.find { |m| m.content&.include?("Observation:") }
          error_msg = messages.find { |m| m.content&.include?("Error:") }

          expect(observation_msg).to be_nil
          expect(error_msg).to be_nil
        end
      end

      context "with empty observations" do
        let(:step) { described_class.new(step_number: 1, observations: "") }

        it "returns no observation message" do
          messages = step.to_messages
          observation_msg = messages.find { |m| m.content&.include?("Observation:") }

          expect(observation_msg).to be_nil
        end
      end
    end
  end

  describe "TOOL_OUTPUT constants" do
    it "defines TOOL_OUTPUT_START" do
      expect(Smolagents::Types::TOOL_OUTPUT_START).to eq("<tool_output>")
    end

    it "defines TOOL_OUTPUT_END" do
      expect(Smolagents::Types::TOOL_OUTPUT_END).to eq("</tool_output>")
    end

    it "freezes constants" do
      expect(Smolagents::Types::TOOL_OUTPUT_START).to be_frozen
      expect(Smolagents::Types::TOOL_OUTPUT_END).to be_frozen
    end
  end
end
