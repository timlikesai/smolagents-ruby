module Smolagents
  module Executors
    # Immutable result from code execution.
    #
    # ExecutionResult represents the outcome of executing code in a sandboxed
    # environment. It captures both successful and failed executions with their
    # outputs, logs, and error messages.
    #
    # == Result States
    #
    # An ExecutionResult is either successful or failed:
    # - **Success**: {#error} is nil, {#success?} returns true
    # - **Failure**: {#error} contains message, {#failure?} returns true
    #
    # == Factory Methods
    #
    # Use {.success} and {.failure} for clearer intent:
    #
    # @example Creating a successful result
    #   result = ExecutionResult.success(output: 42)
    #   result.success? #=> true
    #   result.output   #=> 42
    #
    # @example Creating a failed result
    #   result = ExecutionResult.failure(error: "undefined variable")
    #   result.failure? #=> true
    #
    # @example Result with logs
    #   result = ExecutionResult.success(output: "done", logs: "Processing...")
    #   result.logs #=> "Processing..."
    #
    # @see Executor#execute For how executors create ExecutionResults
    ExecutionResult = Data.define(:output, :logs, :error, :is_final_answer) do
      # @param output [Object, nil] The execution result value
      # @param logs [String] Captured stdout/stderr output (default: "")
      # @param error [String, nil] Error message if failed (default: nil)
      # @param is_final_answer [Boolean] Whether final_answer() was called (default: false)
      def initialize(output: nil, logs: "", error: nil, is_final_answer: false) = super

      # Creates a successful ExecutionResult.
      # @param output [Object] The result value
      # @param logs [String] Captured stdout output (default: "")
      # @param is_final_answer [Boolean] Whether final_answer() was invoked (default: false)
      # @return [ExecutionResult] A successful result
      def self.success(output:, logs: "", is_final_answer: false)
        new(output:, logs:, error: nil, is_final_answer:)
      end

      # Creates a failed ExecutionResult.
      # @param error [String] Description of what went wrong
      # @param logs [String] Captured output before the error (default: "")
      # @return [ExecutionResult] A failed result
      def self.failure(error:, logs: "")
        new(output: nil, logs:, error:, is_final_answer: false)
      end

      # Checks if execution succeeded.
      # @return [Boolean] True if error is nil
      def success? = error.nil?

      # Checks if execution failed.
      # @return [Boolean] True if an error occurred
      def failure? = !success?
    end
  end
end
