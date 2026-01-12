module Smolagents
  class RubyInterpreterTool < Tool
    self.tool_name = "ruby"
    self.description = "Execute Ruby code for calculations, data processing, or text manipulation. Returns stdout and the final expression value."
    self.inputs = { code: { type: "string", description: "Ruby code to execute" } }
    self.output_type = "string"

    attr_reader :inputs

    def initialize(authorized_imports: nil)
      @authorized_imports = authorized_imports || Configuration::DEFAULT_AUTHORIZED_IMPORTS
      @executor = LocalRubyExecutor.new
      @inputs = {
        code: {
          type: "string",
          description: "Ruby code to evaluate. Allowed libraries: #{@authorized_imports.join(", ")}."
        }
      }
      super()
    end

    def execute(code:)
      result = @executor.execute(code, language: :ruby, timeout: 30)
      result.success? ? "Stdout:\n#{result.logs}\nOutput: #{result.output}" : "Error: #{result.error}"
    end
  end
end
