# frozen_string_literal: true

module Smolagents
  module DefaultTools
    # Tool that signals the agent has reached a final answer.
    # This tool raises FinalAnswerException to exit the agent loop.
    class FinalAnswerTool < Tool
      self.tool_name = "final_answer"
      self.description = "Provides the final answer to the given problem. Always call this when you have the final answer."
      self.inputs = {
        "answer" => {
          "type" => "any",
          "description" => "The final answer to the problem"
        }
      }
      self.output_type = "any"

      def forward(answer:)
        # Raise FinalAnswerException to signal completion
        # This exception inherits from Exception (not StandardError)
        # so it won't be caught by generic rescue blocks
        raise FinalAnswerException, answer
      end
    end
  end
end
