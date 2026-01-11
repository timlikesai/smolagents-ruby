# frozen_string_literal: true

module Smolagents
  module DefaultTools
    # Tool that prompts the user for input during agent execution.
    # Useful for interactive workflows where the agent needs clarification.
    class UserInputTool < Tool
      self.tool_name = "user_input"
      self.description = "Asks for user's input on a specific question. Use this when you need clarification or additional information from the user."
      self.inputs = {
        question: {
          type: "string",
          description: "The question to ask the user"
        }
      }
      self.output_type = "string"

      # Prompt user for input.
      #
      # @param question [String] question to ask the user
      # @return [String] user's response
      def forward(question:)
        print "#{question} => Type your answer here: "
        $stdin.gets.chomp
      end
    end
  end
end
