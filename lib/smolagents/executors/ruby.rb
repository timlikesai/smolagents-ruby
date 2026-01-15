require "stringio"
require_relative "../security"

module Smolagents
  module Executors
    # Local Ruby code executor with sandbox isolation.
    #
    # LocalRuby runs agent-generated Ruby code in a restricted sandbox environment.
    # It provides fast execution with operation-based limits and comprehensive output
    # capture. The sandbox is built on BasicObject to minimize accessible methods.
    #
    # == Execution Model
    #
    # Code runs in a Sandbox instance that extends BasicObject. Only explicitly
    # registered tools and variables are accessible. The sandbox uses method_missing
    # to route calls to tools or variable lookups.
    #
    # == Operation Limits
    #
    # Execution is bounded by operation counting using TracePoint. Configurable
    # trace modes (line vs call) trade accuracy for performance:
    # - :line mode counts every line executed (more accurate, slower)
    # - :call mode counts method calls only (faster, less precise)
    #
    # == Security Features
    #
    # - BasicObject-based sandbox minimizes attack surface
    # - Operation counting prevents infinite loops
    # - Dangerous methods are blocked (eval, system, load, etc.)
    # - Output captured and truncated (prevents memory exhaustion)
    # - Only registered tools and variables accessible
    #
    # @example Basic execution
    #   executor = Executors::LocalRuby.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.output  # => 6
    #
    # @example With tools
    #   executor = Executors::LocalRuby.new(max_operations: 10_000)
    #   executor.send_tools("calculate" => calculator_tool)
    #   result = executor.execute('calculate(expression: "2 + 2")', language: :ruby)
    #   result.output  # => 4
    #
    # @example Trace mode selection
    #   # :line mode (default: slower but accurate)
    #   executor = Executors::LocalRuby.new(trace_mode: :line)
    #
    #   # :call mode (faster but less precise operation counting)
    #   executor = Executors::LocalRuby.new(trace_mode: :call)
    #
    # @see Executor Base class with operation/output limits
    # @see Sandbox The restricted execution environment
    # @see Concerns::RubySafety For dangerous method blocking
    class LocalRuby < Executor
      # @return [Array<Symbol>] Valid trace mode options: :line (line-by-line) and :call (method calls)
      VALID_TRACE_MODES = %i[line call].freeze

      # Creates a new local Ruby executor.
      #
      # Initializes executor with resource limits and trace mode for operation counting.
      # Choose trace mode based on performance vs accuracy requirements.
      #
      # @param max_operations [Integer] Maximum operations before timeout
      #   (default: DEFAULT_MAX_OPERATIONS = 100,000)
      # @param max_output_length [Integer] Maximum output bytes to capture
      #   (default: DEFAULT_MAX_OUTPUT_LENGTH = 50,000)
      # @param trace_mode [Symbol] Operation counting mode - :line or :call
      #   - :line (default) counts every line, more accurate but slower
      #   - :call counts only method calls, faster but less precise
      # @raise [ArgumentError] If trace_mode is not :line or :call
      # @return [void]
      # @example Create with defaults
      #   executor = Executors::LocalRuby.new
      #
      # @example Strict limits with call counting
      #   executor = Executors::LocalRuby.new(
      #     max_operations: 1_000,
      #     max_output_length: 5_000,
      #     trace_mode: :call
      #   )
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH,
                     trace_mode: :call)
        super(max_operations:, max_output_length:)
        @trace_mode = validate_trace_mode(trace_mode)
      end

      # Current trace mode for operation counting.
      #
      # @return [Symbol] :line or :call
      attr_reader :trace_mode

      # Executes Ruby code in the sandbox.
      #
      # Main execution entry point. Validates code, creates sandbox, and runs code
      # with operation limits. Code validation checks for obviously unsafe patterns.
      #
      # The timeout parameter is accepted for API compatibility but execution is
      # bounded by operation limits instead (via TracePoint and the trace_mode).
      #
      # == Execution Flow
      # 1. Validate code and language
      # 2. Validate Ruby safety (pattern-based checks)
      # 3. Create sandbox with tools and variables
      # 4. Run code with operation limit TracePoint
      # 5. Capture and return result or error
      #
      # @param code [String] Ruby code to execute. Must not be empty.
      # @param language [Symbol] Must be :ruby
      # @param timeout [Integer] Accepted for API compatibility (not used).
      #   Operation limits via TracePoint provide the actual bound.
      # @param options [Hash] Additional options (ignored)
      # @return [ExecutionResult] Result containing:
      #   - output: return value of code
      #   - logs: captured stdout
      #   - error: error message if failed
      #   - is_final_answer: true if final_answer() was called
      # @raise [ArgumentError] If code is empty or language is not :ruby
      # @example
      #   executor = Executors::LocalRuby.new
      #   result = executor.execute("[1, 2, 3].map { |x| x * 2 }", language: :ruby)
      #   result.output  # => [2, 4, 6]
      #
      # @example With tool execution
      #   executor = Executors::LocalRuby.new
      #   executor.send_tools("search" => search_tool)
      #   result = executor.execute('search(query: "Ruby")', language: :ruby)
      # @see Sandbox For the restricted environment
      # @see Concerns::RubySafety For code safety checks
      def execute(code, language: :ruby, timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          execute_validated_code(code)
        end
      end

      # Checks if Ruby is supported.
      #
      # LocalRuby only executes Ruby code.
      #
      # @param language [Symbol] Language to check
      # @return [Boolean] True only if language is :ruby
      # @example
      #   executor = Executors::LocalRuby.new
      #   executor.supports?(:ruby)    # => true
      #   executor.supports?(:python)  # => false
      def supports?(language) = language.to_sym == :ruby

      private

      def execute_validated_code(code)
        output_buffer = StringIO.new
        validate_ruby_code!(code)
        result = with_operation_limit { create_sandbox(output_buffer).instance_eval(code) }
        build_result(result, output_buffer.string)
      rescue FinalAnswerException => e
        build_final_answer_result(e, output_buffer)
      rescue InterpreterError => e
        build_error_result(Security::SecretRedactor.redact(e.message), output_buffer)
      rescue StandardError => e
        build_error_result(Security::SecretRedactor.redact("#{e.class}: #{e.message}"), output_buffer)
      end

      def build_final_answer_result(exception, output_buffer)
        build_result(exception.value, output_buffer.string, is_final: true)
      end

      def build_error_result(message, output_buffer)
        build_result(nil, output_buffer.string, error: message)
      end

      # Creates a new sandbox for code execution.
      #
      # Instantiates a Sandbox with all registered tools and variables.
      # The sandbox is a fresh instance for each execution, ensuring isolation.
      #
      # @param output_buffer [StringIO] Buffer to capture stdout output
      # @return [Sandbox] A new sandbox instance ready for code execution
      # @api private
      def create_sandbox(output_buffer)
        Sandbox.new(tools:, variables:, output_buffer:)
      end

      # Validates and returns the trace mode.
      #
      # @param mode [Symbol] Trace mode to validate
      # @return [Symbol] The validated mode (:line or :call)
      # @raise [ArgumentError] If mode is not in VALID_TRACE_MODES
      # @api private
      def validate_trace_mode(mode)
        case mode
        in Symbol if VALID_TRACE_MODES.include?(mode)
          mode
        else
          raise ArgumentError, "Invalid trace_mode: #{mode.inspect}. Must be one of: #{VALID_TRACE_MODES.join(", ")}"
        end
      end

      # Gets the TracePoint event type for the current trace mode.
      #
      # @return [Symbol] :line for line-by-line tracking or :a_call for method call tracking
      # @api private
      def trace_event_for_mode
        case @trace_mode
        in :line then :line
        in :call then :a_call
        end
      end

      # Executes a block with operation limit enforcement.
      #
      # Sets up a TracePoint to count operations and uses throw/catch for
      # clean non-local exit when limit is exceeded. The trace is disabled
      # BEFORE throwing to prevent additional events during stack unwinding.
      #
      # @yield Block to execute with operation limits
      # @return [Object] Return value from the yielded block
      # @raise [InterpreterError] If operation limit is exceeded during execution
      # @api private
      def with_operation_limit(&)
        count = 0
        limit = max_operations
        trace = TracePoint.new(trace_event_for_mode) do |tp|
          # Only count operations from sandbox eval, not external code (path starts with "(eval")
          throw :limit_exceeded if tp.path&.start_with?("(eval") && (count += 1) > limit
        end
        execute_with_trace(trace, limit, &)
      end

      def execute_with_trace(trace, limit)
        catch(:limit_exceeded) do
          trace.enable
          return yield
        ensure
          trace.disable if trace.enabled?
        end
        raise InterpreterError, "Operation limit exceeded: #{limit}"
      end

      # Restricted execution environment based on BasicObject.
      #
      # == Design
      #
      # Sandbox is a minimal execution environment extending BasicObject instead of Object.
      # This removes access to Kernel, Object, and their methods. Only explicitly
      # registered tools and variables are accessible.
      #
      # == Method Resolution
      #
      # Unknown methods are routed via method_missing:
      # 1. Check if name matches a registered tool → call it with arguments
      # 2. Check if name matches a registered variable → return its value
      # 3. Check for well-known safe methods (puts, print, p, rand)
      # 4. Fallback to sandbox_fallback for error handling
      #
      # == Output Capture
      #
      # The output_buffer (StringIO) captures all puts/print calls, making
      # stdout visible in the ExecutionResult.
      #
      # @example
      #   sandbox = Sandbox.new(
      #     tools: { "search" => search_tool },
      #     variables: { "api_key" => "secret" },
      #     output_buffer: StringIO.new
      #   )
      #   sandbox.instance_eval('search(query: "Ruby").length')
      #
      # @api private
      class Sandbox < ::BasicObject
        Concerns::SandboxMethods.define_on(self)

        # Creates a new sandbox with registered tools and variables.
        #
        # @param tools [Hash{String => Tool}] Callable tools by name
        # @param variables [Hash{String => Object}] Accessible variables by name
        # @param output_buffer [StringIO] Buffer for stdout capture
        # @return [void]
        def initialize(tools:, variables:, output_buffer:)
          @tools = tools
          @variables = variables
          @output_buffer = output_buffer
        end

        # Routes unknown methods to tools, variables, or raises NoMethodError.
        #
        # Implements method routing for the sandbox environment:
        # 1. If name is a registered tool, calls it with provided arguments
        # 2. If name is a registered variable, returns its value
        # 3. Otherwise delegates to sandbox_fallback (raises NoMethodError)
        #
        # @param name [Symbol] Method name (becomes a string for lookup)
        # @param args [Array] Positional arguments (passed to tools)
        # @param kwargs [Hash] Keyword arguments (passed to tools)
        # @return [Object] Tool result, variable value, or raises
        # @raise [NoMethodError] If method not found in tools/variables
        # @api private
        def method_missing(name, *, **)
          name_str = name.to_s
          return @tools[name_str].call(*, **) if @tools.key?(name_str)
          return @variables[name_str] if @variables.key?(name_str)

          Sandbox.sandbox_fallback(name)
        end

        # Reports which methods are available to respond_to?.
        #
        # @param name [Symbol] Method name to check
        # @param _include_all [Boolean] Ignored
        # @return [Boolean] True if name is a registered tool or variable
        # @api private
        def respond_to_missing?(name, _include_all = false) = @tools.key?(name.to_s) || @variables.key?(name.to_s)
      end
    end
  end
end
