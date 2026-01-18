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
    # with memory isolation. Use when you need GVL-free parallelism or
    # complete memory separation between executions.
    #
    # Trade-offs: ~20ms startup overhead, values must be serializable.
    #
    # @note Requires Ruby 3.0+ with Ractor support
    # @example
    #   executor = Smolagents::Executors::Ractor.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.output #=> 6
    # @see LocalRuby For faster single-threaded execution
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
      # @param code [String] Ruby code to execute
      # @param language [Symbol] Must be :ruby
      # @return [ExecutionResult] Result with output, logs, and any error
      def execute(code, language: :ruby, _timeout: nil, **_options)
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

      # Class methods for Ractor blocks (cannot call instance methods due to isolation).
      class << self
        # @api private
        def build_operation_limiter(max_ops)
          ops = 0
          TracePoint.new(:line) do |tp|
            ops += 1
            next unless ops > max_ops

            tp.disable
            Thread.current.raise("Operation limit exceeded: #{max_ops}")
          end
        end

        # @api private
        def result_hash(output:, logs:, error: nil, is_final: false) = { output:, logs:, error:, is_final: }

        # @api private
        def send_tool_result(output:, logs:, error: nil, is_final: false)
          ::Ractor.main.send({ type: :result, **result_hash(output:, logs:, error:, is_final:) })
        end
      end

      private

      def execute_code(code)
        wait_for_result(spawn_code_ractor(code))
      rescue ::Ractor::RemoteError => e
        build_ractor_error(e)
      end

      # rubocop:disable Metrics/MethodLength -- Ractor isolation requires inline block
      def spawn_code_ractor(code)
        ::Ractor.new(code, max_operations, prepare_variables) do |code_str, max_ops, vars|
          buf = StringIO.new
          trace = Smolagents::Executors::Ractor.build_operation_limiter(max_ops)
          sandbox = CodeSandbox.new(variables: vars, output_buffer: buf)

          trace.enable
          Ractor.result_hash(output: sandbox.instance_eval(code_str), logs: buf.string)
        rescue StandardError => e
          Ractor.result_hash(output: nil, logs: buf.string, error: "#{e.class}: #{e.message}")
        ensure
          trace&.disable
        end
      end
      # rubocop:enable Metrics/MethodLength

      def execute_with_tools(code)
        wait_for_tool_result(spawn_tool_ractor(code))
      rescue ::Ractor::RemoteError => e
        build_ractor_error(e)
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- Ractor isolation requires inline block
      def spawn_tool_ractor(code)
        ractor_args = [code, max_operations, tools.keys.freeze, prepare_variables]
        ::Ractor.new(*ractor_args) do |code_str, max_ops, tool_names, vars|
          buf = StringIO.new
          trace = Smolagents::Executors::Ractor.build_operation_limiter(max_ops)
          sandbox = ToolSandbox.new(tool_names:, variables: vars, output_buffer: buf)

          trace.enable
          Ractor.send_tool_result(output: sandbox.instance_eval(code_str), logs: buf.string)
        rescue FinalAnswerSignal => e
          Ractor.send_tool_result(output: e.value, logs: buf.string, is_final: true)
        rescue StandardError => e
          Ractor.send_tool_result(output: nil, logs: buf.string, error: "#{e.class}: #{e.message}")
        ensure
          trace&.disable
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def wait_for_tool_result(ractor)
        r = process_messages(ractor)
        build_result(r[:output], r[:logs], error: r[:error], is_final: r[:is_final])
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

      def wait_for_result(ractor)
        ractor.value.then { |r| build_result(r[:output], r[:logs], error: r[:error], is_final: r[:is_final]) }
      end

      def build_ractor_error(err)
        build_result(nil, "", error: "Ractor error: #{err.cause&.message || err.message}")
      end

      def prepare_variables = variables.transform_values { |v| prepare_for_ractor(v) }
    end
  end
end
