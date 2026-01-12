module Smolagents
  # Tool for executing Ruby code in a sandboxed environment.
  #
  # RubyInterpreterTool provides safe code execution capabilities for agents,
  # allowing them to perform calculations, data processing, and text manipulation.
  # Code runs in a restricted sandbox with operation limits and timeout protection.
  #
  # The tool captures both stdout output and the final expression value,
  # returning them in a formatted string. Errors are caught and returned
  # as error messages rather than raising exceptions.
  #
  # @example Basic usage with an agent
  #   tool = Smolagents::RubyInterpreterTool.new
  #   result = tool.call(code: "2 + 2")
  #   # => ToolResult with data: "Stdout:\n\nOutput: 4"
  #
  # @example Executing code with output
  #   tool = Smolagents::RubyInterpreterTool.new
  #   result = tool.call(code: <<~RUBY)
  #     puts "Processing..."
  #     numbers = [1, 2, 3, 4, 5]
  #     numbers.map { |n| n * 2 }.sum
  #   RUBY
  #   # => ToolResult with data: "Stdout:\nProcessing...\nOutput: 30"
  #
  # @example Restricting available libraries
  #   tool = Smolagents::RubyInterpreterTool.new(authorized_imports: %w[json date])
  #   # Only 'json' and 'date' libraries mentioned in tool description
  #
  # @see LocalRubyExecutor The underlying executor that runs the code
  # @see Tool Base class providing the tool interface
  class RubyInterpreterTool < Tool
    self.tool_name = "ruby"
    self.description = "Execute Ruby code for calculations, data processing, or text manipulation. Returns stdout and the final expression value."
    self.inputs = { code: { type: "string", description: "Ruby code to execute" } }
    self.output_type = "string"

    # @return [Hash] Input specifications including allowed libraries
    attr_reader :inputs

    # Creates a new Ruby interpreter tool.
    #
    # @param authorized_imports [Array<String>, nil] List of allowed library names
    #   to mention in the tool description. Defaults to {Configuration::DEFAULT_AUTHORIZED_IMPORTS}.
    #   Note: This affects the description shown to agents but does not enforce restrictions.
    #
    # @example Default configuration
    #   tool = RubyInterpreterTool.new
    #
    # @example Custom allowed libraries
    #   tool = RubyInterpreterTool.new(authorized_imports: %w[json yaml csv])
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

    # Executes Ruby code and returns the result.
    #
    # The code runs in a sandboxed environment with a 30-second timeout.
    # Both stdout output and the final expression value are captured.
    #
    # @param code [String] Ruby code to execute
    # @return [String] Formatted result containing stdout and output value,
    #   or an error message if execution failed
    #
    # @example Successful execution
    #   execute(code: "[1,2,3].sum")
    #   # => "Stdout:\n\nOutput: 6"
    #
    # @example Execution with stdout
    #   execute(code: "puts 'hello'; 42")
    #   # => "Stdout:\nhello\nOutput: 42"
    #
    # @example Failed execution
    #   execute(code: "raise 'oops'")
    #   # => "Error: RuntimeError: oops"
    def execute(code:)
      result = @executor.execute(code, language: :ruby, timeout: 30)
      result.success? ? "Stdout:\n#{result.logs}\nOutput: #{result.output}" : "Error: #{result.error}"
    end
  end
end
