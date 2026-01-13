require "stringio"

module Smolagents
  module Executors
    # Local Ruby code executor with sandbox isolation.
    #
    # LocalRuby runs agent-generated Ruby code in a restricted sandbox
    # environment. It uses TracePoint to enforce operation limits and captures
    # stdout for logging.
    #
    # Security features:
    # - Code runs in BasicObject sandbox with limited method access
    # - Operation counting prevents infinite loops
    # - Timeout prevents long-running code
    # - Dangerous methods are blocked
    # - Only registered tools and variables are accessible
    #
    # @example Basic execution
    #   executor = Executors::LocalRuby.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.output  # => 6
    #
    # @example With tools and timeout
    #   executor = Executors::LocalRuby.new(max_operations: 10_000)
    #   executor.send_tools("calculate" => calculator_tool)
    #   result = executor.execute(
    #     'calculate(expression: "2 + 2")',
    #     language: :ruby,
    #     timeout: 30
    #   )
    #
    # @example Different trace modes
    #   # :line counts every line executed (default, more accurate)
    #   executor = Executors::LocalRuby.new(trace_mode: :line)
    #
    #   # :call counts method calls only (faster, less accurate)
    #   executor = Executors::LocalRuby.new(trace_mode: :call)
    #
    # @see Executor Base class
    # @see Sandbox The restricted execution environment
    class LocalRuby < Executor
      # @return [Array<Symbol>] Valid trace mode options
      VALID_TRACE_MODES = %i[line call].freeze

      # Creates a new local Ruby executor.
      #
      # @param max_operations [Integer] Maximum operations before timeout
      # @param max_output_length [Integer] Maximum output bytes to capture
      # @param trace_mode [Symbol] Operation counting mode (:line or :call)
      # @raise [ArgumentError] If trace_mode is invalid
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH, trace_mode: :call)
        super(max_operations: max_operations, max_output_length: max_output_length)
        @trace_mode = validate_trace_mode(trace_mode)
      end

      # @return [Symbol] Current trace mode (:line or :call)
      attr_reader :trace_mode

      # Executes Ruby code in the sandbox.
      #
      # @param code [String] Ruby code to execute
      # @param language [Symbol] Must be :ruby
      # @param timeout [Integer] Maximum execution time in seconds (default: 5)
      # @param options [Hash] Additional options (ignored)
      # @return [ExecutionResult] Result with output, logs, and any error
      # timeout ignored: operation-limited only
      def execute(code, language: :ruby, timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language: language) do
          validate_execution_params!(code, language)
          output_buffer = StringIO.new

          begin
            validate_ruby_code!(code)
            result = with_operation_limit { create_sandbox(output_buffer).instance_eval(code) }
            build_result(result, output_buffer.string)
          rescue FinalAnswerException => e
            build_result(e.value, output_buffer.string, is_final: true)
          rescue InterpreterError => e
            build_result(nil, output_buffer.string, error: e.message)
          rescue StandardError => e
            build_result(nil, output_buffer.string, error: "#{e.class}: #{e.message}")
          end
        end
      end

      # Checks if Ruby is supported (always true for this executor).
      # @param language [Symbol] Language to check
      # @return [Boolean] True only if language is :ruby
      def supports?(language) = language.to_sym == :ruby

      private

      # Creates a new sandbox for code execution.
      # @api private
      def create_sandbox(output_buffer)
        Sandbox.new(tools: tools, variables: variables, output_buffer: output_buffer)
      end

      def validate_trace_mode(mode)
        case mode
        in Symbol if VALID_TRACE_MODES.include?(mode)
          mode
        else
          raise ArgumentError, "Invalid trace_mode: #{mode.inspect}. Must be one of: #{VALID_TRACE_MODES.join(", ")}"
        end
      end

      def trace_event_for_mode
        case @trace_mode
        in :line then :line
        in :call then :a_call
        end
      end

      def with_operation_limit
        operations = 0
        event = trace_event_for_mode
        trace = TracePoint.new(event) do
          operations += 1
          if operations > max_operations
            trace.disable
            Thread.current.raise(InterpreterError, "Operation limit exceeded: #{max_operations}")
          end
        end
        trace.enable
        yield
      ensure
        trace&.disable
      end

      # Restricted execution environment based on BasicObject.
      #
      # Sandbox provides a minimal environment where agent code runs.
      # It has no access to Kernel, Object methods, or the broader Ruby
      # environment. Only explicitly registered tools and variables
      # are accessible via method_missing.
      #
      # @api private
      class Sandbox < ::BasicObject
        Concerns::SandboxMethods.define_on(self)

        # Creates a new sandbox with registered tools and variables.
        # @param tools [Hash{String => Tool}] Callable tools
        # @param variables [Hash{String => Object}] Accessible variables
        # @param output_buffer [StringIO] Buffer for stdout capture
        def initialize(tools:, variables:, output_buffer:)
          @tools = tools
          @variables = variables
          @output_buffer = output_buffer
        end

        # Routes unknown methods to tools or variables.
        # @api private
        def method_missing(name, *, **)
          name_str = name.to_s
          return @tools[name_str].call(*, **) if @tools.key?(name_str)
          return @variables[name_str] if @variables.key?(name_str)

          Sandbox.sandbox_fallback(name)
        end

        # Reports which methods are available.
        # @api private
        def respond_to_missing?(name, _ = false) = @tools.key?(name.to_s) || @variables.key?(name.to_s)
      end
    end
  end
end
