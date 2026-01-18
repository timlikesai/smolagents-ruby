require_relative "execution_result"
require_relative "executor/tool_registration"
require_relative "executor/validation"
require_relative "executor/result_builder"
require_relative "executor/outcome_wrapper"

module Smolagents
  module Executors
    # Abstract base class for code execution environments.
    #
    # Executor provides the interface for safely executing agent-generated code.
    # Concrete implementations handle specific execution contexts with different
    # isolation levels (BasicObject sandbox or Ractor memory isolation).
    #
    # == Executor Interface
    #
    # All executors implement a common interface:
    # - {#execute} - Run code and return an {ExecutionResult}
    # - {#supports?} - Check if a language is supported
    # - {#send_tools} - Register callable tools
    # - {#send_variables} - Register accessible variables
    #
    # == Security Model
    #
    # Executors provide multiple layers of protection:
    # - **Operation limits** - Prevent infinite loops via TracePoint counting
    # - **Output limits** - Truncate output to prevent memory exhaustion
    # - **Sandbox isolation** - BasicObject-based sandbox minimizes attack surface
    # - **Tool allowlisting** - Only registered tools are callable
    # - **Dangerous method blocking** - Methods like eval, system, exec are blocked
    #
    # == Available Implementations
    #
    # - {LocalRuby} - Fast local Ruby execution with BasicObject sandbox
    # - {Ractor} - Full memory isolation with Ractor-based execution
    #
    # @example Creating an executor and running code
    #   executor = Smolagents::Executors::LocalRuby.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.success? #=> true
    #   result.output   #=> 6
    #
    # @abstract Subclass and implement {#execute} and {#supports?}
    # @see LocalRuby For fast local Ruby execution
    # @see Ractor For memory-isolated Ractor-based execution
    class Executor
      include Concerns::RubySafety
      include ToolRegistration
      include Validation
      include ResultBuilder
      include OutcomeWrapper

      # @return [Integer] Default maximum operations before timeout
      DEFAULT_MAX_OPERATIONS = Config.default(:execution, :max_operations) || 100_000

      # @return [Integer] Default maximum output length in bytes
      DEFAULT_MAX_OUTPUT_LENGTH = Config.default(:execution, :max_output_length) || 50_000

      # Alias for backwards compatibility.
      # @see Smolagents::Executors::ExecutionResult
      ExecutionResult = Smolagents::Executors::ExecutionResult

      # Creates a new executor with resource limits.
      #
      # @param max_operations [Integer] Maximum operations before timeout
      # @param max_output_length [Integer] Maximum output bytes to capture
      # @return [void]
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        @max_operations = max_operations
        @max_output_length = max_output_length
        initialize_tool_registration
      end

      # Executes code in the sandboxed environment.
      #
      # @param code [String] Source code to execute
      # @param language [Symbol] Programming language (:ruby, :python, etc.)
      # @param timeout [Integer] Maximum execution time in seconds
      # @param memory_mb [Integer] Maximum memory usage in MB
      # @return [ExecutionResult] Result with output, logs, error, and is_final_answer
      # @raise [NotImplementedError] When called on abstract Executor class
      # @abstract Subclasses must override this method
      def execute(_code, language:, timeout: 5, memory_mb: 256, **_options)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      # Checks if this executor supports a given language.
      #
      # @param language [Symbol] Language to check
      # @return [Boolean] True if language is supported
      # @raise [NotImplementedError] When called on abstract Executor class
      # @abstract Subclasses must override this method
      def supports?(_language)
        raise NotImplementedError, "#{self.class} must implement #supports?"
      end

      protected

      # @!attribute [r] max_operations
      #   @return [Integer] Maximum operations limit
      attr_reader :max_operations
    end

    autoload :Ruby, "smolagents/executors/ruby"
  end
end
