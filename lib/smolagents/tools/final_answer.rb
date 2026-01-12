module Smolagents
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
