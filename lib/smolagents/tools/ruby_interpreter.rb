require_relative "ruby_interpreter/sandbox_config"
require_relative "ruby_interpreter/config_builder"
require_relative "ruby_interpreter/class_dsl"
require_relative "ruby_interpreter/config_resolution"
require_relative "ruby_interpreter/execution"

module Smolagents
  module Tools
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
    # @example Creating and inspecting the tool
    #   tool = Smolagents::RubyInterpreterTool.new(timeout: 10)
    #   tool.name
    #   # => "ruby"
    #
    # @see LocalRubyExecutor The underlying executor that runs the code
    # @see Tool Base class providing the tool interface
    class RubyInterpreterTool < Tool
      extend ClassDsl
      include ConfigResolution
      include Execution

      self.tool_name = "ruby"
      self.description = <<~DESC.strip
        Execute Ruby code for calculations, data processing, or text manipulation.
        Code runs in a sandboxed environment with timeout and operation limits.

        Use when: You need to perform calculations, transform data, or manipulate strings.
        Do NOT use: For web requests, file I/O, or system commands - use dedicated tools.

        Returns: The stdout output and final expression value, or an error message.
      DESC
      self.inputs = { code: { type: "string", description: "Ruby code to execute" } }
      self.output_type = "string"

      # @return [Hash] Input specifications including allowed libraries
      attr_reader :inputs

      # @return [Integer] Execution timeout in seconds
      attr_reader :timeout

      # @return [Array<String>] Authorized imports for description
      attr_reader :authorized_imports

      # Creates a new Ruby interpreter tool.
      #
      # @param timeout [Integer] Execution timeout in seconds (default: 30)
      # @param max_operations [Integer] Maximum operations before timeout (default: 100_000)
      # @param max_output_length [Integer] Maximum output bytes (default: 50_000)
      # @param trace_mode [Symbol] Operation tracing mode (:line or :call)
      # @param authorized_imports [Array<String>, nil] List of allowed library names
      #   to mention in the tool description. Defaults to {Configuration::DEFAULT_AUTHORIZED_IMPORTS}.
      #   Note: This affects the description shown to agents but does not enforce restrictions.
      def initialize(timeout: nil, max_operations: nil, max_output_length: nil, trace_mode: nil,
                     authorized_imports: nil)
        resolve_config(timeout:, max_operations:, max_output_length:, trace_mode:, authorized_imports:)
        @executor = build_executor
        desc = "Ruby code to evaluate. Allowed libraries: #{@authorized_imports.join(", ")}."
        @inputs = { code: { type: "string", description: desc } }
        super()
      end
    end
  end

  # Re-export RubyInterpreterTool at the Smolagents level for backward compatibility.
  # @see Smolagents::Tools::RubyInterpreterTool
  RubyInterpreterTool = Tools::RubyInterpreterTool
end
