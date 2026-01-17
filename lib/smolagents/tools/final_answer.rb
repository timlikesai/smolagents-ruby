module Smolagents
  module Tools
    # Terminal tool that signals task completion and returns the final answer.
    #
    # This tool should be included in every agent's toolkit. When called,
    # it raises FinalAnswerException which the ReAct loop catches to
    # terminate execution and return the answer to the user.
    #
    # The tool accepts the answer in two forms for model compatibility:
    # - Positional: final_answer("The answer is...")
    # - Keyword: final_answer(answer: "The answer is...")
    #
    # @example Creating and inspecting the tool
    #   tool = Smolagents::FinalAnswerTool.new
    #   tool.name
    #   # => "final_answer"
    #
    # @note This tool always raises FinalAnswerException - this is intentional
    #   and is how the agent execution loop knows to stop gracefully. The exception
    #   is caught by the ReAct loop, not an error condition.
    #
    # @see Agents::ReActLoop Where FinalAnswerException is caught and handled
    # @see Tool Base class for all tools
    # @see Smolagents::FinalAnswerException The exception that terminates execution
    class FinalAnswerTool < Tool
      self.tool_name = "final_answer"
      self.description = <<~DESC.strip
        REQUIRED: Call this to end the task and return your answer to the user.
        Extract and summarize the relevant information from your work.

        Use when: You have completed the task or gathered enough information to answer.
        Do NOT use: To pass raw tool output - always process and summarize first.

        Returns: Your answer is returned directly to the user, ending the task.
      DESC
      self.inputs = { answer: { type: "any", description: "Your processed answer (not raw tool output)" } }
      self.output_type = "any"

      def execute(value = nil, answer: nil)
        # Accept both positional and keyword arguments for model flexibility
        # Positional form: final_answer("result")
        # Keyword form: final_answer(answer: "result")
        final_answer_value = answer || value
        raise FinalAnswerException, final_answer_value
      end
    end
  end

  # Re-export FinalAnswerTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::FinalAnswerTool
  FinalAnswerTool = Tools::FinalAnswerTool
end
