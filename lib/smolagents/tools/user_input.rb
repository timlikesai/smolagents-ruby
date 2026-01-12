module Smolagents
  class UserInputTool < Tool
    self.tool_name = "ask_user"
    self.description = "Ask the user a question and wait for their response. Use when you need clarification."
    self.inputs = { question: { type: "string", description: "Clear question to ask the user" } }
    self.output_type = "string"

    def forward(question:)
      print "#{question} => "
      $stdin.gets.chomp
    end
  end
end
