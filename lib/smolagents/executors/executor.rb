module Smolagents
  # Abstract base class for code execution environments.
  #
  # Executor provides the interface for safely executing agent-generated code.
  # Concrete implementations handle specific languages and execution contexts
  # (local Ruby, Docker containers, Ractors, etc.).
  #
  # All executors share:
  # - Operation limits to prevent infinite loops
  # - Output length limits to prevent memory exhaustion
  # - Tool and variable injection for agent access
  # - Consistent result format via ExecutionResult
  #
  # @example Using LocalRubyExecutor
  #   executor = LocalRubyExecutor.new(max_operations: 10_000)
  #   executor.send_tools("search" => search_tool)
  #   result = executor.execute("search(query: 'Ruby 4.0')", language: :ruby, timeout: 30)
  #
  #   if result.success?
  #     puts result.output
  #   else
  #     puts "Error: #{result.error}"
  #   end
  #
  # @abstract Subclass and implement {#execute} and {#supports?}
  # @see LocalRubyExecutor For local Ruby execution
  # @see DockerExecutor For containerized execution
  class Executor
    include Concerns::RubySafety

    # @return [Integer] Default maximum operations before timeout
    DEFAULT_MAX_OPERATIONS = 100_000

    # @return [Integer] Default maximum output length in bytes
    DEFAULT_MAX_OUTPUT_LENGTH = 50_000

    # Immutable result from code execution.
    #
    # @example Successful execution
    #   result = ExecutionResult.success(output: "42", logs: "Computing...")
    #   result.success?  # => true
    #
    # @example Failed execution
    #   result = ExecutionResult.failure(error: "Syntax error")
    #   result.failure?  # => true
    ExecutionResult = Data.define(:output, :logs, :error, :is_final_answer) do
      def initialize(output: nil, logs: "", error: nil, is_final_answer: false) = super

      # @param output [Object] The execution result value
      # @param logs [String] Captured stdout output
      # @param is_final_answer [Boolean] Whether final_answer was called
      # @return [ExecutionResult] Successful result
      def self.success(output:, logs: "", is_final_answer: false) = new(output:, logs:, error: nil, is_final_answer:)

      # @param error [String] Error message
      # @param logs [String] Captured stdout output
      # @return [ExecutionResult] Failed result
      def self.failure(error:, logs: "") = new(output: nil, logs:, error:, is_final_answer: false)

      # @return [Boolean] True if no error occurred
      def success? = error.nil?

      # @return [Boolean] True if an error occurred
      def failure? = !success?
    end

    # Creates a new executor with resource limits.
    #
    # @param max_operations [Integer] Maximum operations before timeout
    # @param max_output_length [Integer] Maximum output bytes to capture
    def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
      @max_operations = max_operations
      @max_output_length = max_output_length
      @tools = {}
      @variables = {}
    end

    # Executes code in the sandboxed environment.
    #
    # @param code [String] Source code to execute
    # @param language [Symbol] Programming language (:ruby, etc.)
    # @param timeout [Integer] Maximum execution time in seconds
    # @param memory_mb [Integer] Maximum memory usage in MB (if supported)
    # @param options [Hash] Additional executor-specific options
    # @return [ExecutionResult] Result with output, logs, and any error
    # @raise [NotImplementedError] When called on abstract base class
    # @abstract
    def execute(_code, language:, timeout: 5, memory_mb: 256, **_options)
      raise NotImplementedError, "#{self.class} must implement #execute"
    end

    # Checks if this executor supports a given language.
    #
    # @param language [Symbol] Language to check
    # @return [Boolean] True if language is supported
    # @raise [NotImplementedError] When called on abstract base class
    # @abstract
    def supports?(_language)
      raise NotImplementedError, "#{self.class} must implement #supports?"
    end

    # Registers tools that can be called from executed code.
    #
    # @param tools [Hash{String, Symbol => Tool}] Name to tool mapping
    # @raise [ArgumentError] If tool name conflicts with dangerous methods
    # @return [void]
    def send_tools(tools)
      tools.each do |name, tool|
        name_str = name.to_s
        raise ArgumentError, "Cannot register tool with dangerous name: #{name_str}" if DANGEROUS_METHODS.include?(name_str)

        @tools[name_str] = tool
      end
    end

    # Registers variables accessible from executed code.
    #
    # @param variables [Hash{String, Symbol => Object}] Name to value mapping
    # @return [void]
    def send_variables(variables)
      variables.each { |name, value| @variables[name.to_s] = value }
    end

    protected

    attr_reader :tools, :variables, :max_operations, :max_output_length

    def validate_execution_params!(code, language)
      raise ArgumentError, "Code cannot be empty" if code.to_s.empty?
      raise ArgumentError, "Language not supported: #{language}" unless supports?(language)
    end

    def validate_execution_params(code, language)
      code && !code.to_s.empty? && supports?(language)
    end
    alias valid_execution_params? validate_execution_params

    def build_result(output, logs, error: nil, is_final: false)
      ExecutionResult.new(
        output: output,
        logs: logs.to_s.byteslice(0, @max_output_length) || "",
        error: error,
        is_final_answer: is_final
      )
    end
  end

  module Executors
    autoload :Ruby, "smolagents/executors/ruby"
    autoload :Docker, "smolagents/executors/docker"
  end
end
