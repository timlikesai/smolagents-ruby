module Smolagents
  module Executors
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
    #   executor = Executors::LocalRuby.new(max_operations: 10_000)
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
    # @see LocalRuby For local Ruby execution
    # @see Docker For containerized execution
    class Executor
      include Concerns::RubySafety

      # @return [Integer] Default maximum operations before timeout
      DEFAULT_MAX_OPERATIONS = 100_000

      # @return [Integer] Default maximum output length in bytes
      DEFAULT_MAX_OUTPUT_LENGTH = 50_000

      # Immutable result from code execution.
      #
      # ExecutionResult represents the outcome of executing code in a sandboxed
      # environment. It captures both successful and failed executions with their
      # outputs, logs, and error messages.
      #
      # @example Successful execution
      #   result = ExecutionResult.success(output: "42", logs: "Computing...")
      #   result.success?  # => true
      #   result.output    # => "42"
      #
      # @example Failed execution
      #   result = ExecutionResult.failure(error: "Syntax error", logs: "")
      #   result.failure?  # => true
      #   result.error     # => "Syntax error"
      #
      # @see Executor#execute For how executors create ExecutionResults
      ExecutionResult = Data.define(:output, :logs, :error, :is_final_answer) do
        # Initializes a new ExecutionResult with all fields.
        #
        # @param output [Object, nil] The execution result value (can be any serializable object)
        # @param logs [String] Captured stdout/stderr output (default: empty string)
        # @param error [String, nil] Error message if execution failed (default: nil)
        # @param is_final_answer [Boolean] Whether final_answer() was called during execution (default: false)
        # @return [ExecutionResult] A new result instance
        def initialize(output: nil, logs: "", error: nil, is_final_answer: false) = super

        # Creates a successful ExecutionResult.
        #
        # Used when code executed without errors. The output contains the
        # return value of the evaluated code.
        #
        # @param output [Object] The result value from executing the code
        # @param logs [String] Captured stdout output (default: empty string)
        # @param is_final_answer [Boolean] Whether final_answer() was invoked (default: false)
        # @return [ExecutionResult] A successful result instance
        # @example
        #   result = ExecutionResult.success(output: 42)
        #   result.success?  # => true
        def self.success(output:, logs: "", is_final_answer: false) = new(output:, logs:, error: nil, is_final_answer:)

        # Creates a failed ExecutionResult.
        #
        # Used when code execution encountered an error. The error message
        # describes what went wrong.
        #
        # @param error [String] Description of what went wrong
        # @param logs [String] Captured output before the error (default: empty string)
        # @return [ExecutionResult] A failed result instance
        # @example
        #   result = ExecutionResult.failure(error: "NameError: undefined variable")
        #   result.failure?  # => true
        def self.failure(error:, logs: "") = new(output: nil, logs:, error:, is_final_answer: false)

        # Checks if execution succeeded.
        #
        # @return [Boolean] True if error is nil, false otherwise
        # @example
        #   ExecutionResult.success(output: 42).success?     # => true
        #   ExecutionResult.failure(error: "error").success?  # => false
        def success? = error.nil?

        # Checks if execution failed.
        #
        # @return [Boolean] True if an error occurred, false otherwise
        # @example
        #   ExecutionResult.failure(error: "error").failure?  # => true
        #   ExecutionResult.success(output: 42).failure?       # => false
        def failure? = !success?
      end

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
      # @example
      #   executor = Executor.new(max_operations: 5_000, max_output_length: 10_000)
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
      # The execution is isolated from the host environment using:
      # - Operation limits (prevents infinite loops)
      # - Output capture (logs all stdout/stderr)
      # - Error handling (catches and reports exceptions)
      # - Tool/variable injection (only registered tools are accessible)
      #
      # @param code [String] Source code to execute. Must not be empty.
      # @param language [Symbol] Programming language (:ruby for RubyExecutor, :python/:javascript for Docker, etc.)
      # @param timeout [Integer] Maximum execution time in seconds. Some executors ignore
      #   this in favor of operation limits. (default: 5)
      # @param memory_mb [Integer] Maximum memory usage in MB (supported by Docker executor).
      #   (default: 256)
      # @param options [Hash] Additional executor-specific options. Ignored by base class.
      # @return [ExecutionResult] Result containing:
      #   - output: the return value of the evaluated code
      #   - logs: captured stdout/stderr output
      #   - error: error message if execution failed
      #   - is_final_answer: whether final_answer() was called
      # @raise [NotImplementedError] When called on abstract Executor class (not a concrete subclass)
      # @abstract Subclasses must override this method
      # @example
      #   executor = LocalRuby.new
      #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
      #   # => ExecutionResult with output=6
      # @see LocalRuby For Ruby implementation
      # @see Docker For multi-language Docker implementation
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
      # @param options [Hash] Additional executor-specific options
      # @return [Types::ExecutorExecutionOutcome] Outcome wrapping the ExecutionResult with:
      #   - result: the ExecutionResult from execution
      #   - duration: actual execution time in seconds
      #   - state machine methods for control flow
      # @example
      #   executor = LocalRuby.new
      #   outcome = executor.execute_with_outcome("[1,2,3].sum", language: :ruby)
      #   outcome.success?  # => true
      #   outcome.duration  # => 0.0023 (seconds)
      # @see ExecutionResult For the wrapped result
      # @see Types::ExecutorExecutionOutcome For outcome interface
      def execute_with_outcome(code, language:, timeout: 5, memory_mb: 256, **)
        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = execute(code, language: language, timeout: timeout, memory_mb: memory_mb, **)
        duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time

        Types::ExecutorExecutionOutcome.from_result(result, duration: duration)
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
      # @example
      #   ruby_executor = LocalRuby.new
      #   ruby_executor.supports?(:ruby)      # => true
      #   ruby_executor.supports?(:python)    # => false
      #
      #   docker_executor = Docker.new
      #   docker_executor.supports?(:ruby)    # => true
      #   docker_executor.supports?(:python)  # => true
      def supports?(_language)
        raise NotImplementedError, "#{self.class} must implement #supports?"
      end

      # Registers tools that can be called from executed code.
      #
      # Makes tools available to agent code for execution. Tools are exposed as
      # callable methods within the sandbox. Dangerous method names are blocked
      # to prevent sandbox escapes.
      #
      # @param tools [Hash{String, Symbol => Tool}] Mapping of tool names to Tool instances.
      #   Keys become callable method names in sandbox environment.
      # @raise [ArgumentError] If any tool name matches DANGEROUS_METHODS (e.g., 'eval', 'system', 'load')
      # @return [void]
      # @example
      #   search_tool = SearchTool.new
      #   calculator_tool = CalculatorTool.new
      #
      #   executor.send_tools({
      #     "search" => search_tool,
      #     "calculate" => calculator_tool
      #   })
      #
      #   # Now agent code can call: search(query: "Ruby")
      # @see Tool For tool interface
      # @see Concerns::RubySafety For DANGEROUS_METHODS constant
      def send_tools(tools)
        tools.each do |name, tool|
          name_str = name.to_s
          raise ArgumentError, "Cannot register tool with dangerous name: #{name_str}" if DANGEROUS_METHODS.include?(name_str)

          @tools[name_str] = tool
        end
      end

      # Registers variables accessible from executed code.
      #
      # Makes variables available to agent code as named values. Variables are
      # accessible in the sandbox as method-like lookups (not reassignable).
      #
      # @param variables [Hash{String, Symbol => Object}] Mapping of variable names to values.
      #   Keys become accessible identifiers in sandbox environment.
      # @return [void]
      # @example
      #   executor.send_variables({
      #     "api_key" => ENV["API_KEY"],
      #     "user_id" => current_user.id,
      #     "settings" => { timeout: 30, retries: 3 }
      #   })
      #
      #   # Now agent code can access: api_key, user_id, settings
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
          output: output,
          logs: logs.to_s.byteslice(0, @max_output_length) || "",
          error: error,
          is_final_answer: is_final
        )
      end
    end

    autoload :Ruby, "smolagents/executors/ruby"
    autoload :Docker, "smolagents/executors/docker"
  end
end
