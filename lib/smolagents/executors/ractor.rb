require "stringio"
require_relative "final_answer_signal"
require_relative "code_sandbox"
require_relative "tool_sandbox"
require_relative "ractor_serialization"

module Smolagents
  module Executors
    # Ractor-based code executor for thread-safe isolation.
    #
    # Executes code in isolated Ractor instances for true parallelism
    # with memory isolation. Each execution runs in its own Ractor.
    #
    # == Execution Modes
    #
    # 1. **Code execution** (no tools) - Uses CodeSandbox
    # 2. **Tool execution** (has tools) - Uses ToolSandbox with message passing
    #
    # @note Requires Ruby 3.0+ with Ractor support
    # @note Ractors have ~20ms overhead compared to LocalRuby
    #
    # @example Basic execution
    #   executor = Executors::Ractor.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.output  # => 6
    #
    # @see CodeSandbox For code execution without tools
    # @see ToolSandbox For tool-supporting execution
    class Ractor < Executor
      include RactorSerialization

      # Maximum message iterations before error (prevents runaway loops).
      MAX_MESSAGE_ITERATIONS = 10_000

      # @param max_operations [Integer] Maximum operations before timeout
      # @param max_output_length [Integer] Maximum output bytes to capture
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        super
      end

      # Executes Ruby code in an isolated Ractor.
      #
      # @param code [String] Ruby code to execute
      # @param language [Symbol] Must be :ruby
      # @return [ExecutionResult] Result with output, logs, and any error
      def execute(code, language: :ruby, timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          validate_ruby_code!(code)
          tools.empty? ? execute_code(code) : execute_with_tools(code)
        rescue InterpreterError => e
          build_result(nil, "", error: e.message)
        end
      end

      # @return [Boolean] True only if language is :ruby
      def supports?(language) = language.to_sym == :ruby

      # Builds a TracePoint that limits execution operations.
      # Class method for use from within Ractor blocks.
      def self.build_operation_limiter(max_ops)
        ops = 0
        TracePoint.new(:line) do |tp|
          ops += 1
          next unless ops > max_ops

          tp.disable
          Thread.current.raise("Operation limit exceeded: #{max_ops}")
        end
      end

      private

      # == Code Execution (no tools) ==

      def execute_code(code)
        ractor = spawn_code_ractor(code)
        wait_for_result(ractor)
      rescue ::Ractor::RemoteError => e
        build_ractor_error(e)
      end

      # rubocop:disable Metrics/MethodLength -- Ractor block must be inline
      def spawn_code_ractor(code)
        ::Ractor.new(code, max_operations, prepare_variables) do |code_str, max_ops, vars|
          buf = StringIO.new
          trace = Smolagents::Executors::Ractor.build_operation_limiter(max_ops)
          sandbox = CodeSandbox.new(variables: vars, output_buffer: buf)

          trace.enable
          result = sandbox.instance_eval(code_str)
          { output: result, logs: buf.string, error: nil, is_final: false }
        rescue StandardError => e
          { output: nil, logs: buf.string, error: "#{e.class}: #{e.message}", is_final: false }
        ensure
          trace&.disable
        end
      end
      # rubocop:enable Metrics/MethodLength

      # == Tool Execution ==

      def execute_with_tools(code)
        ractor = spawn_tool_ractor(code)
        wait_for_tool_result(ractor)
      rescue ::Ractor::RemoteError => e
        build_ractor_error(e)
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- Ractor block must be inline
      def spawn_tool_ractor(code)
        args = [code, max_operations, tools.keys.freeze, prepare_variables]
        ::Ractor.new(*args) do |code_str, max_ops, tool_names, vars|
          buf = StringIO.new
          trace = Smolagents::Executors::Ractor.build_operation_limiter(max_ops)
          sandbox = ToolSandbox.new(tool_names:, variables: vars, output_buffer: buf)

          trace.enable
          result = sandbox.instance_eval(code_str)
          ::Ractor.main.send({ type: :result, output: result, logs: buf.string, error: nil, is_final: false })
        rescue FinalAnswerSignal => e
          ::Ractor.main.send({ type: :result, output: e.value, logs: buf.string, error: nil, is_final: true })
        rescue StandardError => e
          ::Ractor.main.send({ type: :result, output: nil, logs: buf.string, error: "#{e.class}: #{e.message}",
                               is_final: false })
        ensure
          trace&.disable
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def wait_for_tool_result(ractor)
        result = process_messages(ractor)
        build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
      end

      def process_messages(_ractor)
        MAX_MESSAGE_ITERATIONS.times do
          case ::Ractor.receive
          in { type: :result, **data } then return data
          in { type: :tool_call, name:, args:, kwargs:, caller_ractor: }
            caller_ractor.send(execute_tool_call(name, args, kwargs))
          end
        end
        { output: nil, logs: "", error: "Message processing limit exceeded", is_final: false }
      end

      def execute_tool_call(name, args, kwargs)
        tool = tools[name]
        return { error: "Unknown tool: #{name}" } unless tool

        { result: prepare_for_ractor(tool.call(*args, **kwargs)) }
      rescue FinalAnswerException => e
        { final_answer: prepare_for_ractor(e.value) }
      rescue StandardError => e
        { error: "#{e.class}: #{e.message}" }
      end

      # == Shared Helpers ==

      def wait_for_result(ractor)
        result = ractor.value
        build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
      end

      def build_ractor_error(err)
        build_result(nil, "", error: "Ractor error: #{err.cause&.message || err.message}")
      end

      def prepare_variables = variables.transform_values { |v| prepare_for_ractor(v) }
    end
  end
end
