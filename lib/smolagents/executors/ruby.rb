require_relative "../security"
require_relative "ruby/execution_context"
require_relative "ruby/output_capture"
require_relative "ruby/sandbox"

module Smolagents
  module Executors
    # Local Ruby code executor with sandbox isolation.
    #
    # Runs agent-generated Ruby code in a BasicObject-based sandbox.
    # Uses TracePoint operation limits (not memory limits - use Docker for that).
    #
    # @example Basic execution
    #   executor = Smolagents::Executors::LocalRuby.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.output #=> 6
    #
    # @see Docker For untrusted code with memory/CPU limits
    # @see Sandbox The restricted execution environment
    # @see ExecutionContext For operation limit enforcement
    class LocalRuby < Executor
      include ExecutionContext
      include OutputCapture

      # Creates a new local Ruby executor.
      #
      # @param max_operations [Integer] Maximum operations before timeout
      # @param max_output_length [Integer] Maximum output bytes to capture
      # @param trace_mode [Symbol] :call (faster) or :line (more accurate)
      # @raise [ArgumentError] If trace_mode is not :line or :call
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH,
                     trace_mode: :call)
        super(max_operations:, max_output_length:)
        @trace_mode = validate_trace_mode(trace_mode)
      end

      # @return [Symbol] Current trace mode (:line or :call)
      attr_reader :trace_mode

      # Executes Ruby code in the sandbox.
      #
      # @param code [String] Ruby code to execute
      # @param language [Symbol] Must be :ruby
      # @param _timeout [Integer] Accepted for API compatibility (not used)
      # @return [ExecutionResult] Result with output, logs, error, is_final_answer
      # @raise [ArgumentError] If code is empty or language is not :ruby
      def execute(code, language: :ruby, _timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          execute_validated_code(code)
        end
      end

      # Checks if Ruby is supported.
      #
      # @param language [Symbol] Language to check
      # @return [Boolean] True only if language is :ruby
      def supports?(language) = language.to_sym == :ruby
    end
  end
end
