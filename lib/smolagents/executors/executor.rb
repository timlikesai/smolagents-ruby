require_relative "execution_result"

module Smolagents
  module Executors
    # Abstract base class for code execution environments.
    #
    # Executor provides the interface for safely executing agent-generated code.
    # Concrete implementations handle specific languages and execution contexts
    # (local Ruby, Docker containers, Ractors, etc.).
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
    # - {Docker} - Multi-language execution in isolated containers
    # - {Ractor} - Ruby 3.0+ Ractor-based parallel execution
    #
    # @example Creating an executor and running code
    #   executor = Smolagents::Executors::LocalRuby.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.success? #=> true
    #   result.output   #=> 6
    #
    # @example Checking execution failure
    #   executor = Smolagents::Executors::LocalRuby.new
    #   result = executor.execute("undefined_variable", language: :ruby)
    #   result.failure? #=> true
    #
    # @example Using resource limits
    #   executor = Smolagents::Executors::LocalRuby.new(
    #     max_operations: 1_000,
    #     max_output_length: 5_000
    #   )
    #
    # @abstract Subclass and implement {#execute} and {#supports?}
    # @see LocalRuby For local Ruby execution
    # @see Docker For containerized execution
    # @see Ractor For parallel Ractor-based execution
    class Executor
      include Concerns::RubySafety

      # @return [Integer] Default maximum operations before timeout
      DEFAULT_MAX_OPERATIONS = 100_000

      # @return [Integer] Default maximum output length in bytes
      DEFAULT_MAX_OUTPUT_LENGTH = 50_000

      # Alias for backwards compatibility.
      # @see Smolagents::Executors::ExecutionResult
      ExecutionResult = Smolagents::Executors::ExecutionResult

      # Creates a new executor with resource limits.
      #
      # Initializes an executor with configuration for operation limits and output
      # capture. This is the base initialization for all executor subclasses.
      #
      # @param max_operations [Integer] Maximum number of operations before timeout
      #   (default: DEFAULT_MAX_OPERATIONS = 100,000). Prevents infinite loops.
      # @param max_output_length [Integer] Maximum output bytes to capture
      #   (default: DEFAULT_MAX_OUTPUT_LENGTH = 50,000). Prevents memory exhaustion.
      # @return [void]
      # @example Default limits
      #   executor = Smolagents::Executors::LocalRuby.new
      #
      # @example Custom limits for untrusted code
      #   executor = Smolagents::Executors::LocalRuby.new(
      #     max_operations: 5_000,
      #     max_output_length: 10_000
      #   )
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        @max_operations = max_operations
        @max_output_length = max_output_length
        @tools = {}
        @variables = {}
      end

      # Executes code in the sandboxed environment.
      #
      # Main execution method for running agent-generated code. This is the primary
      # interface for sandboxed code execution. Subclasses must implement this method.
      #
      # == Execution Isolation
      #
      # The execution is isolated from the host environment using:
      # - **Operation limits** - Prevents infinite loops via TracePoint counting
      # - **Output capture** - Logs all stdout/stderr to the result
      # - **Error handling** - Catches and reports exceptions gracefully
      # - **Tool allowlisting** - Only registered tools are callable
      #
      # == Return Value
      #
      # Always returns an {ExecutionResult} containing:
      # - {ExecutionResult#output} - The return value of the evaluated code
      # - {ExecutionResult#logs} - Captured stdout/stderr output
      # - {ExecutionResult#error} - Error message if execution failed (nil on success)
      # - {ExecutionResult#is_final_answer} - Whether final_answer() was called
      #
      # @param code [String] Source code to execute. Must not be empty.
      # @param language [Symbol] Programming language (:ruby, :python, :javascript, etc.)
      # @param timeout [Integer] Maximum execution time in seconds. Some executors ignore
      #   this in favor of operation limits. (default: 5)
      # @param memory_mb [Integer] Maximum memory usage in MB (supported by Docker executor).
      #   (default: 256)
      # @return [ExecutionResult] Result with output, logs, error, and is_final_answer
      # @raise [NotImplementedError] When called on abstract Executor class
      # @abstract Subclasses must override this method
      # @example Executing Ruby code
      #   executor = Smolagents::Executors::LocalRuby.new
      #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
      #   result.output #=> 6
      #
      # @example Handling execution errors
      #   executor = Smolagents::Executors::LocalRuby.new
      #   result = executor.execute("1 / 0", language: :ruby)
      #   result.failure? #=> true
      #
      # @see LocalRuby For local Ruby execution
      # @see Docker For multi-language Docker execution
      # @see Ractor For parallel Ractor-based execution
      def execute(_code, language:, timeout: 5, memory_mb: 256, **_options)
        raise NotImplementedError, "#{self.class} must implement #execute"
      end

      # Executes code and returns ExecutorExecutionOutcome (composition pattern).
      #
      # This wraps the ExecutionResult in an ExecutorExecutionOutcome, adding
      # state machine semantics and timing information. The outcome provides a
      # richer interface for tracking execution state and duration. Prefer this
      # for new code that uses outcome-based control flow patterns.
      #
      # Measures actual wall-clock time using Process::CLOCK_MONOTONIC.
      #
      # @param code [String] Source code to execute
      # @param language [Symbol] Programming language (:ruby, :python, etc.)
      # @param timeout [Integer] Maximum execution time in seconds (default: 5)
      # @param memory_mb [Integer] Maximum memory usage in MB (default: 256)
      # @return [Types::ExecutorExecutionOutcome] Outcome wrapping the ExecutionResult with:
      #   - result: the ExecutionResult from execution
      #   - duration: actual execution time in seconds
      #   - state machine methods for control flow
      # @example Getting execution outcome with timing
      #   executor = Smolagents::Executors::LocalRuby.new
      #   outcome = executor.execute_with_outcome("[1, 2, 3].sum", language: :ruby)
      #   outcome.success? #=> true
      #
      # @see ExecutionResult For the wrapped result
      # @see Types::ExecutorExecutionOutcome For outcome interface
      def execute_with_outcome(code, language:, timeout: 5, memory_mb: 256, **)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = execute(code, language:, timeout:, memory_mb:, **)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        Types::ExecutorExecutionOutcome.from_result(result, duration:)
      end

      # Checks if this executor supports a given language.
      #
      # Determines whether this executor can execute code in the given language.
      # Each executor subclass must declare its supported languages.
      #
      # @param language [Symbol] Language to check (:ruby, :python, :javascript, etc.)
      # @return [Boolean] True if language is supported by this executor, false otherwise
      # @raise [NotImplementedError] When called on abstract Executor class
      # @abstract Subclasses must override this method
      # @example LocalRuby only supports Ruby
      #   executor = Smolagents::Executors::LocalRuby.new
      #   executor.supports?(:ruby)   #=> true
      #   executor.supports?(:python) #=> false
      #
      # @see LocalRuby#supports? For Ruby-only support
      # @see Docker#supports? For multi-language support
      def supports?(_language)
        raise NotImplementedError, "#{self.class} must implement #supports?"
      end

      # Registers tools that can be called from executed code.
      #
      # Makes tools available to agent code for execution. Tools are exposed as
      # callable methods within the sandbox. Dangerous method names are blocked
      # to prevent sandbox escapes.
      #
      # == Tool Registration
      #
      # Tools are registered by name and become callable from within the sandbox.
      # The tool's {Tool#call} method is invoked when code calls the tool name.
      #
      # == Security
      #
      # Tool names matching DANGEROUS_METHODS (eval, system, exec, etc.) are
      # rejected to prevent sandbox escapes.
      #
      # @param tools [Hash{String, Symbol => Tool}] Mapping of tool names to Tool instances.
      #   Keys become callable method names in sandbox environment.
      # @raise [ArgumentError] If any tool name matches DANGEROUS_METHODS
      # @return [void]
      # @example Registering tools
      #   executor = Smolagents::Executors::LocalRuby.new
      #   # Create a simple tool-like object that responds to #call
      #   tool = Object.new.tap { |t| t.define_singleton_method(:call) { "results" } }
      #   executor.send_tools({ "search" => tool })
      #
      # @example Tool is then callable in code
      #   executor = Smolagents::Executors::LocalRuby.new
      #   tool = Object.new.tap { |t| t.define_singleton_method(:call) { 42 } }
      #   executor.send_tools({ "add" => tool })
      #   result = executor.execute("add()", language: :ruby)
      #   result.output #=> 42
      #
      # @see Tool For tool interface
      # @see Concerns::RubySafety For DANGEROUS_METHODS constant
      def send_tools(tools)
        tools.each do |name, tool|
          name_str = name.to_s
          if DANGEROUS_METHODS.include?(name_str)
            raise ArgumentError,
                  "Cannot register tool with dangerous name: #{name_str}"
          end

          @tools[name_str] = tool
        end
      end

      # Registers variables accessible from executed code.
      #
      # Makes variables available to agent code as named values. Variables are
      # accessible in the sandbox as method-like lookups (not reassignable).
      #
      # == Variable Access
      #
      # Variables become accessible as method calls within the sandbox. They
      # cannot be reassigned - they are read-only references to the original values.
      #
      # @param variables [Hash{String, Symbol => Object}] Mapping of variable names to values.
      #   Keys become accessible identifiers in sandbox environment.
      # @return [void]
      # @example Registering variables
      #   executor = Smolagents::Executors::LocalRuby.new
      #   executor.send_variables({ "multiplier" => 10, "data" => [1, 2, 3] })
      #
      # @example Variables are accessible in code
      #   executor = Smolagents::Executors::LocalRuby.new
      #   executor.send_variables({ "factor" => 5 })
      #   result = executor.execute("factor * 2", language: :ruby)
      #   result.output #=> 10
      #
      # @see Sandbox#method_missing For how variables are resolved
      def send_variables(variables)
        variables.each { |name, value| @variables[name.to_s] = value }
      end

      protected

      # @!attribute [r] tools
      #   @return [Hash{String => Tool}] Registered tools by name
      # @!attribute [r] variables
      #   @return [Hash{String => Object}] Registered variables by name
      # @!attribute [r] max_operations
      #   @return [Integer] Maximum operations limit
      # @!attribute [r] max_output_length
      #   @return [Integer] Maximum output bytes to capture
      attr_reader :tools, :variables, :max_operations, :max_output_length

      # Validates execution parameters and raises on failure.
      #
      # Checks that code is not empty and language is supported. Raises descriptive
      # errors if validation fails.
      #
      # @param code [String] Source code to validate
      # @param language [Symbol] Language to validate
      # @return [void]
      # @raise [ArgumentError] If code is empty or language not supported
      # @api protected
      def validate_execution_params!(code, language)
        raise ArgumentError, "Code cannot be empty" if code.to_s.empty?
        raise ArgumentError, "Language not supported: #{language}" unless supports?(language)
      end

      # Validates execution parameters and returns boolean.
      #
      # Non-raising version of validation. Returns true if code is valid and
      # language is supported, false otherwise.
      #
      # @param code [String] Source code to validate
      # @param language [Symbol] Language to validate
      # @return [Boolean] True if valid, false otherwise
      # @api protected
      def validate_execution_params(code, language)
        code && !code.to_s.empty? && supports?(language)
      end

      # Alias for validate_execution_params (predicate form).
      # @see #validate_execution_params
      alias valid_execution_params? validate_execution_params

      # Builds an ExecutionResult with output length truncation.
      #
      # Creates a result, ensuring logs don't exceed max_output_length bytes.
      # This prevents memory exhaustion from extremely verbose output.
      #
      # @param output [Object] The execution result value
      # @param logs [String] Captured output to truncate and include
      # @param error [String, nil] Error message if execution failed (default: nil)
      # @param is_final [Boolean] Whether final_answer() was called (default: false)
      # @return [ExecutionResult] A properly formatted result
      # @api protected
      def build_result(output, logs, error: nil, is_final: false)
        ExecutionResult.new(
          output:,
          logs: logs.to_s.byteslice(0, @max_output_length) || "",
          error:,
          is_final_answer: is_final
        )
      end
    end

    autoload :Ruby, "smolagents/executors/ruby"
    autoload :Docker, "smolagents/executors/docker"
  end
end
