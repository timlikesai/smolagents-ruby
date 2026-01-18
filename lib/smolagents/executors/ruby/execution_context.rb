module Smolagents
  module Executors
    class LocalRuby < Executor
      # Execution context with operation limit enforcement.
      #
      # Provides TracePoint-based operation counting to prevent infinite loops
      # and runaway code. Supports two trace modes for accuracy vs performance.
      #
      # == Trace Modes
      #
      # - `:call` (default) - Counts method/block calls. Faster, recommended.
      # - `:line` - Counts every line executed. More accurate but slower.
      #
      # @api private
      module ExecutionContext
        # @return [Array<Symbol>] Valid trace mode options
        VALID_TRACE_MODES = %i[line call].freeze

        # Validates and returns the trace mode.
        #
        # @param mode [Symbol] Trace mode to validate
        # @return [Symbol] The validated mode (:line or :call)
        # @raise [ArgumentError] If mode is not in VALID_TRACE_MODES
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
        # @return [Symbol] :line for line-by-line or :a_call for method calls
        def trace_event_for_mode
          case @trace_mode
          in :line then :line
          in :call then :a_call
          end
        end

        # Executes a block with operation limit enforcement.
        #
        # Sets up a TracePoint to count operations and uses throw/catch for
        # clean non-local exit when limit is exceeded.
        #
        # @yield Block to execute with operation limits
        # @return [Object] Return value from the yielded block
        # @raise [InterpreterError] If operation limit exceeded
        def with_operation_limit(&)
          count = 0
          limit = max_operations
          trace = TracePoint.new(trace_event_for_mode) do |tp|
            throw :limit_exceeded if tp.path&.start_with?("(eval") && (count += 1) > limit
          end
          execute_with_trace(trace, limit, &)
        end

        private

        # Runs block with trace enabled and handles limit exceeded.
        #
        # @param trace [TracePoint] Configured trace point
        # @param limit [Integer] Operation limit for error message
        # @yield Block to execute
        # @return [Object] Block return value
        # @raise [InterpreterError] When limit exceeded
        def execute_with_trace(trace, limit)
          catch(:limit_exceeded) do
            trace.enable
            return yield
          ensure
            trace.disable if trace.enabled?
          end
          raise InterpreterError, "Operation limit exceeded: #{limit}"
        end
      end
    end
  end
end
