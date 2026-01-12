module Smolagents
  # Terminal tool that signals task completion and returns the final answer.
  #
  # This tool should be included in every agent's toolkit. When called,
  # it raises FinalAnswerException which the ReAct loop catches to
  # terminate execution and return the answer.
  #
  # @example In agent tool list
  #   agent = Smolagents.agent(:code)
  #     .model { my_model }
  #     .tools(:duckduckgo_search, :final_answer)
  #     .build
  #
  # @example Agent code calling final_answer
  #   # In agent-generated code:
  #   result = search(query: "Ruby 4.0")
  #   final_answer(answer: "Ruby 4.0 was released in...")
  #
  # @example In specialized agent
  #   class MyAgent < Agents::ToolCalling
  #     include Concerns::Specialized
  #
  #     default_tools :my_custom_tool, :final_answer
  #   end
  #
  # @note This tool always raises FinalAnswerException - this is intentional
  #   and is how the agent execution loop knows to stop.
  #
  # @see Agents::ReActLoop Where FinalAnswerException is caught
  class FinalAnswerTool < Tool
    self.tool_name = "final_answer"
    self.description = "Return the final answer and end the task. Call this when you have completed the request."
    self.inputs = { answer: { type: "any", description: "The complete answer to return to the user" } }
    self.output_type = "any"

    def execute(answer:)
      raise FinalAnswerException, answer
    end
  end
end
