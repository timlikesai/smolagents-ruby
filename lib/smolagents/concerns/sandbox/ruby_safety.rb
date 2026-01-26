require_relative "../../security"

module Smolagents
  module Concerns
    # Static code analysis concern for validating Ruby code safety.
    #
    # Performs AST-based analysis to detect dangerous operations before
    # code execution. Used by CodeAgent and RubyInterpreterTool to prevent
    # agent-generated code from performing harmful operations.
    #
    # @example Validating code before execution
    #   class MyExecutor
    #     include Concerns::RubySafety
    #
    #     def execute(code)
    #       validate_ruby_code!(code)  # Raises on dangerous code
    #       eval(code, safe_binding)
    #     end
    #   end
    #
    # Detection categories:
    # - Dangerous methods: eval, system, exec, fork, require, send, etc.
    # - Dangerous constants: File, IO, Dir, Process, ENV, Marshal, etc.
    # - Command execution: backticks, %x{}, system calls
    # - Dangerous patterns: shell command patterns
    # - Dangerous imports: net/http, socket, fileutils
    #
    # @see Security::CodeValidator The underlying validator
    # @see Security::ValidationResult Immutable result with violation list
    # @see Security::ValidationViolation Detailed violation information
    module RubySafety
      # Validates Ruby code and raises on any safety violation.
      #
      # @param code [String] Ruby source code to validate
      # @return [ValidationResult] Successful validation result
      # @raise [InterpreterError] If code contains dangerous operations
      def validate_ruby_code!(code) = Security::CodeValidator.validate!(code)

      # Validates Ruby code and returns a detailed result.
      #
      # @param code [String] Ruby source code to validate
      # @return [ValidationResult] Result with valid? status and violations list
      def validate_ruby_code(code) = Security::CodeValidator.validate(code)
    end
  end
end
