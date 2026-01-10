# frozen_string_literal: true

module Smolagents
  module DefaultTools
    # Tool that evaluates Ruby code in a sandboxed environment.
    # Similar to Python's PythonInterpreterTool but for Ruby.
    class RubyInterpreterTool < Tool
      self.tool_name = "ruby_interpreter"
      self.description = "Evaluates Ruby code in a sandboxed environment. Can be used to perform calculations and data processing."
      self.output_type = "string"

      # Initialize the Ruby interpreter tool.
      #
      # @param authorized_imports [Array<String>, nil] Ruby modules allowed in code execution (informational only)
      def initialize(authorized_imports: nil)
        super()
        @authorized_imports = authorized_imports || Configuration::DEFAULT_AUTHORIZED_IMPORTS
        @executor = LocalRubyExecutor.new

        # Update inputs description with authorized imports
        self.class.inputs = {
          "code" => {
            "type" => "string",
            "description" => "The Ruby code snippet to evaluate. All variables used must be defined in this snippet. " \
                             "This code can only import the following Ruby libraries: #{@authorized_imports.join(", ")}."
          }
        }
      end

      # Execute Ruby code and return the result.
      #
      # @param code [String] Ruby code to execute
      # @return [String] formatted output with stdout and return value
      def forward(code:)
        result = @executor.execute(code, language: :ruby, timeout: 30)

        if result.success?
          "Stdout:\n#{result.logs}\nOutput: #{result.output}"
        else
          "Error: #{result.error}"
        end
      end
    end
  end
end
