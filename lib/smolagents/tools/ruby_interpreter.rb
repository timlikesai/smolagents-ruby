module Smolagents
  class RubyInterpreterTool < Tool
    self.tool_name = "ruby"
    self.description = "Execute Ruby code for calculations, data processing, or text manipulation. Returns stdout and the final expression value."
    self.output_type = "string"

    def initialize(authorized_imports: nil)
      super()
      @authorized_imports = authorized_imports || Configuration::DEFAULT_AUTHORIZED_IMPORTS
      @executor = LocalRubyExecutor.new
      self.class.inputs = {
        code: {
          type: "string",
          description: "Ruby code to evaluate. Allowed libraries: #{@authorized_imports.join(", ")}."
        }
      }
    end

    def forward(code:)
      result = @executor.execute(code, language: :ruby, timeout: 30)
      result.success? ? "Stdout:\n#{result.logs}\nOutput: #{result.output}" : "Error: #{result.error}"
    end
  end
end
