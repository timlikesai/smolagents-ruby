require "stringio"
require "timeout"

module Smolagents
  class LocalRubyExecutor < Executor
    VALID_TRACE_MODES = %i[line call].freeze

    def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH, trace_mode: :line)
      super(max_operations: max_operations, max_output_length: max_output_length)
      @trace_mode = validate_trace_mode(trace_mode)
    end

    attr_reader :trace_mode

    def execute(code, language: :ruby, timeout: 5, **_options)
      Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language: language) do
        validate_execution_params!(code, language)
        output_buffer = StringIO.new

        begin
          validate_ruby_code!(code)
          result = Timeout.timeout(timeout) do
            with_operation_limit { create_sandbox(output_buffer).instance_eval(code) }
          end
          build_result(result, output_buffer.string)
        rescue FinalAnswerException => e
          build_result(e.value, output_buffer.string, is_final: true)
        rescue Timeout::Error
          build_result(nil, output_buffer.string, error: "Execution timeout after #{timeout} seconds")
        rescue InterpreterError => e
          build_result(nil, output_buffer.string, error: e.message)
        rescue StandardError => e
          build_result(nil, output_buffer.string, error: "#{e.class}: #{e.message}")
        end
      end
    end

    def supports?(language) = language.to_sym == :ruby

    private

    def create_sandbox(output_buffer)
      Sandbox.new(tools: @tools, variables: @variables, output_buffer: output_buffer)
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
        if operations > @max_operations
          trace.disable
          raise InterpreterError, "Operation limit exceeded: #{@max_operations}"
        end
      end
      trace.enable
      yield
    ensure
      trace&.disable
    end

    class Sandbox < ::BasicObject
      Concerns::SandboxMethods.define_on(self)

      def initialize(tools:, variables:, output_buffer:)
        @tools = tools
        @variables = variables
        @output_buffer = output_buffer
      end

      def method_missing(name, *, **)
        name_str = name.to_s
        return @tools[name_str].call(*, **) if @tools.key?(name_str)
        return @variables[name_str] if @variables.key?(name_str)

        Sandbox.sandbox_fallback(name)
      end

      def respond_to_missing?(name, _ = false) = @tools.key?(name.to_s) || @variables.key?(name.to_s)
    end
  end
end
