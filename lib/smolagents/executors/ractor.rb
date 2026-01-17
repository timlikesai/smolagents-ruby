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
    # with memory isolation. Each execution runs in its own Ractor with
    # complete memory separation from the caller.
    #
    # == When to Use Ractor
    #
    # Use Ractor executor when you need:
    # - **True parallelism** - Not limited by Global VM Lock (GVL)
    # - **Memory isolation** - Complete separation between executions
    # - **Thread safety** - Safe concurrent execution
    #
    # == Execution Modes
    #
    # 1. **Code execution** (no tools) - Uses CodeSandbox, simple and fast
    # 2. **Tool execution** (has tools) - Uses ToolSandbox with message passing
    #
    # == Trade-offs
    #
    # - **Overhead**: ~20ms startup overhead compared to LocalRuby
    # - **Serialization**: Values passed to/from Ractor must be serializable
    # - **Compatibility**: Some Ruby features are restricted in Ractors
    #
    # @note Requires Ruby 3.0+ with Ractor support
    #
    # @example Basic code execution
    #   executor = Smolagents::Executors::Ractor.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #   result.success? #=> true
    #   result.output   #=> 6
    #
    # @example String operations
    #   executor = Smolagents::Executors::Ractor.new
    #   result = executor.execute('"hello".upcase', language: :ruby)
    #   result.output #=> "HELLO"
    #
    # @example Only Ruby is supported
    #   executor = Smolagents::Executors::Ractor.new
    #   executor.supports?(:ruby)   #=> true
    #   executor.supports?(:python) #=> false
    #
    # @see CodeSandbox For code execution without tools
    # @see ToolSandbox For tool-supporting execution
    # @see LocalRuby For faster single-threaded execution
    class Ractor < Executor
      include RactorSerialization

      # Maximum message iterations before error (prevents runaway loops).
      MAX_MESSAGE_ITERATIONS = 10_000

      # Creates a new Ractor-based executor.
      #
      # Initializes executor with resource limits for operation counting
      # and output capture. Each execution runs in an isolated Ractor.
      #
      # @param max_operations [Integer] Maximum operations before timeout
      #   (default: DEFAULT_MAX_OPERATIONS = 100,000)
      # @param max_output_length [Integer] Maximum output bytes to capture
      #   (default: DEFAULT_MAX_OUTPUT_LENGTH = 50,000)
      # @return [void]
      # @example Default executor
      #   executor = Smolagents::Executors::Ractor.new
      #
      # @example With custom limits
      #   executor = Smolagents::Executors::Ractor.new(max_operations: 5_000)
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        super
      end

      # Executes Ruby code in an isolated Ractor.
      #
      # Each execution runs in its own Ractor with complete memory isolation.
      # This provides true parallelism (not limited by GVL) and thread safety.
      #
      # == Execution Modes
      #
      # - **Without tools**: Simple Ractor execution via CodeSandbox
      # - **With tools**: Message-passing protocol via ToolSandbox
      #
      # @param code [String] Ruby code to execute. Must not be empty.
      # @param language [Symbol] Must be :ruby
      # @return [ExecutionResult] Result with output, logs, and any error
      # @raise [ArgumentError] If code is empty or language is not :ruby
      # @example Simple computation
      #   executor = Smolagents::Executors::Ractor.new
      #   result = executor.execute("2 ** 10", language: :ruby)
      #   result.output #=> 1024
      #
      # @example Array operations
      #   executor = Smolagents::Executors::Ractor.new
      #   result = executor.execute("[1, 2, 3].reverse", language: :ruby)
      #   result.output #=> [3, 2, 1]
      def execute(code, language: :ruby, _timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          validate_execution_params!(code, language)
          validate_ruby_code!(code)
          tools.empty? ? execute_code(code) : execute_with_tools(code)
        rescue InterpreterError => e
          build_result(nil, "", error: e.message)
        end
      end

      # Checks if Ruby is supported.
      #
      # Ractor executor only supports Ruby code.
      #
      # @param language [Symbol] Language to check
      # @return [Boolean] True only if language is :ruby
      # @example
      #   executor = Smolagents::Executors::Ractor.new
      #   executor.supports?(:ruby) #=> true
      def supports?(language) = language.to_sym == :ruby

      # Builds a TracePoint that limits execution operations.
      #
      # Creates a TracePoint that counts line executions and raises
      # when the limit is exceeded. This is a class method because
      # it must be accessible from within Ractor blocks.
      #
      # @param max_ops [Integer] Maximum operations allowed
      # @return [TracePoint] Configured TracePoint for operation limiting
      # @api private
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
