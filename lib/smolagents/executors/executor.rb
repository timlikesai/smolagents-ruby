# frozen_string_literal: true

module Smolagents
  # Abstract base class for code executors.
  # Executors run code in different languages with security isolation.
  #
  # @example Implementing a custom executor
  #   class MyExecutor < Executor
  #     def execute(code, language:, **options)
  #       # Execute code securely
  #       ExecutionResult.new(output: result, logs: logs, error: nil)
  #     end
  #
  #     def supports?(language)
  #       [:ruby].include?(language.to_sym)
  #     end
  #   end
  class Executor
    # Result of code execution.
    ExecutionResult = Data.define(:output, :logs, :error, :is_final_answer) do
      def initialize(output: nil, logs: "", error: nil, is_final_answer: false)
        super
      end

      def success? = error.nil?
      def failure? = !success?
    end

    # Execute code in the specified language.
    #
    # @param code [String] code to execute
    # @param language [Symbol, String] language to execute (:ruby, :python, :javascript, :typescript)
    # @param timeout [Integer] execution timeout in seconds (default: 5)
    # @param memory_mb [Integer] memory limit in MB (default: 256)
    # @param options [Hash] additional executor-specific options
    # @return [ExecutionResult]
    #
    # @raise [NotImplementedError] if not implemented by subclass
    # @raise [ArgumentError] if language is not supported
    def execute(code, language:, timeout: 5, memory_mb: 256, **options)
      raise NotImplementedError, "#{self.class} must implement #execute"
    end

    # Check if executor supports a language.
    #
    # @param language [Symbol, String] language to check
    # @return [Boolean]
    #
    # @raise [NotImplementedError] if not implemented by subclass
    def supports?(language)
      raise NotImplementedError, "#{self.class} must implement #supports?"
    end

    # Send tools to executor environment.
    #
    # @param tools [Hash<String, Tool>] tools to make available
    # @return [void]
    def send_tools(tools)
      @tools = tools
    end

    # Send variables to executor environment.
    #
    # @param variables [Hash] variables to make available
    # @return [void]
    def send_variables(variables)
      @variables = variables
    end

    protected

    attr_reader :tools, :variables

    # Validate execution parameters.
    #
    # @param code [String] code to validate
    # @param language [Symbol] language to validate
    # @raise [ArgumentError] if parameters are invalid
    def validate_execution_params!(code, language)
      raise ArgumentError, "Code cannot be empty" if code.nil? || code.empty?
      raise ArgumentError, "Language not supported: #{language}" unless supports?(language)
    end
  end
end
