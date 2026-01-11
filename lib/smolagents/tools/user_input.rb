module Smolagents
  class UserInputTool < Tool
    self.tool_name = "user_input"
    self.description = "Asks for user input when clarification is needed."
    self.inputs = { question: { type: "string", description: "The question to ask" } }
    self.output_type = "string"

    def forward(question:)
      print "#{question} => "
      $stdin.gets.chomp
    end
  end
end
