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
    # @example In agent tool list
    #   agent = Smolagents.agent(:code)
    #     .model { my_model }
    #     .tools(:duckduckgo_search, :final_answer)
    #     .build
    #
    # @example Agent code calling final_answer (positional)
    #   # In agent-generated code - easier for models to generate
    #   result = search(query: "Ruby 4.0")
    #   final_answer("Ruby 4.0 was released in December 2024 with...")
    #
    # @example Agent code calling final_answer (keyword)
    #   # Also supported for tool-calling agents
    #   result = search(query: "Ruby 4.0")
    #   final_answer(answer: "Ruby 4.0 was released in December 2024 with...")
    #
    # @example In specialized agent
    #   class ResearchAgent < Agents::ToolCalling
    #     include Concerns::Specialized
    #
    #     default_tools :duckduckgo_search, :visit_webpage, :final_answer
    #   end
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
      self.description = "Return the final answer and end the task. Call this when you have completed the request."
      self.inputs = { answer: { type: "any", description: "The complete answer to return to the user" } }
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
