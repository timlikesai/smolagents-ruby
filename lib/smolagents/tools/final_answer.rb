module Smolagents
  class FinalAnswerTool < Tool
    self.tool_name = "final_answer"
    self.description = "Provides the final answer to the problem."
    self.inputs = { answer: { type: "any", description: "The final answer" } }
    self.output_type = "any"

    def forward(answer:)
      raise FinalAnswerException, answer
    end
  end
end
