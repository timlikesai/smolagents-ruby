require_relative "final_answer_signal"
require_relative "ractor_serialization"
require_relative "ractor_lazy"

module Smolagents
  module Executors
    # Ractor executor with Fiber-based lazy tool batching.
    #
    # Tool calls return futures immediately. When results are accessed,
    # all pending futures are batched and executed in parallel.
    #
    # == LLM-Friendly Hash Keys
    #
    # Tool results are automatically converted to use string keys (not symbols).
    # LLMs trained on JSON data expect `hash["key"]` syntax, not `hash[:key]`.
    # This conversion happens transparently when results cross the Ractor boundary.
    #
    # @example Tool output conversion
    #   # Tool returns: { name: "Alice", age: 30 }
    #   # Agent receives: { "name" => "Alice", "age" => 30 }
    #   # LLM code: @user["name"]  # Works correctly
    #
    # @example Automatic batching
    #   executor.execute(<<~RUBY, language: :ruby)
    #     @a = search(query: "ruby")   # Returns future instantly
    #     @b = search(query: "python") # Returns future instantly
    #     @a.first + @b.first          # Triggers batch - both resolve in parallel
    #   RUBY
    #
    # rubocop:disable Metrics/ClassLength -- Ractor management requires cohesive logic
    class Ractor < Executor
      include RactorSerialization

      MAX_MESSAGE_ITERATIONS = 10_000

      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        super
        @ractor = nil
        @result_port = nil
        @tool_port = nil
      end

      def execute(code, language: :ruby, _timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language:) do
          clear_tool_calls
          validate_execution_params!(code, language)
          validate_ruby_code!(code)
          ensure_ractor!
          execute_in_ractor(code)
        rescue InterpreterError => e
          build_result(nil, "", error: e.message)
        end
      end

      def supports?(language) = language.to_sym == :ruby

      def shutdown!
        return unless @ractor

        @ractor.send(:shutdown)
        @result_port&.close
        @tool_port&.close
        @ractor = nil
      rescue ::Ractor::ClosedError
        @ractor = nil
      end

      private

      def ensure_ractor!
        return if @ractor

        @result_port = ::Ractor::Port.new
        @tool_port = ::Ractor::Port.new
        @ractor = spawn_ractor
      end

      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- Ractor setup is inherently complex
      def spawn_ractor
        args = [@result_port, @tool_port, tools.keys.freeze, max_operations]
        ::Ractor.new(*args) do |result_port, tool_port, tool_names, max_ops|
          ctx, output, batch = RactorLazy::Context.build(
            tool_names:, tool_port:, result_port:, initial_vars: {}, max_ops:
          )
          executor = RactorLazy::FiberExecutor.new(ctx, output, batch, tool_port, result_port, max_ops)
          loop do
            break if (msg = ::Ractor.receive) == :shutdown

            # Merge variables into context state and define accessor methods
            if msg[:vars]
              state = ctx.instance_variable_get(:@state)
              msg[:vars].each do |k, v|
                sym = k.to_sym
                state[sym] = v
                ctx.define_singleton_method(sym) { @state[sym] } unless ctx.singleton_methods.include?(sym)
              end
            end
            executor.execute(msg[:code])
          end
          begin
            result_port.send(:shutdown_complete)
          rescue StandardError
            ::Ractor::ClosedError
          end
        end
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      def ractor_vars
        variables.to_h { |k, v| [k.to_s, prepare_for_ractor(v)] }.freeze
      end

      def execute_in_ractor(code)
        @ractor.send({ code:, vars: ractor_vars })
        process_messages
      end

      def process_messages
        MAX_MESSAGE_ITERATIONS.times do
          result = handle_message(*::Ractor.select(@result_port, @tool_port, @ractor))
          return result if result
        end
        build_result(nil, "", error: "Message limit exceeded")
      rescue ::Ractor::RemoteError => e
        @ractor = nil
        build_result(nil, "", error: "#{e.cause.class}: #{e.cause.message}")
      end

      def handle_message(selected, msg)
        case selected
        when @tool_port then handle_tool_message(msg)
        when @result_port then build_execution_result(msg)
        when @ractor then handle_ractor_termination(msg)
        end
      end

      def handle_tool_message(msg)
        case msg
        in { type: :batch, requests: }
          execute_batch(requests)
        in { name:, args:, kwargs: }
          # Single tool call (non-batched)
          @ractor.send(execute_single_tool(name, args || [], kwargs || {}))
        end
        nil
      end

      def execute_batch(requests)
        results = requests.map do |req|
          execute_single_tool(req[:name], req[:args] || [], req[:kwargs] || {})
        end
        @ractor.send({ results: })
      end

      def execute_single_tool(name, args, kwargs)
        tool = tools[name]
        return { success: false, error: "Unknown tool: #{name}" } unless tool

        with_tool_tracking(name, kwargs) { tool.call(*args, **kwargs) }
      end

      def with_tool_tracking(name, kwargs)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        build_success_result(name, kwargs, result, elapsed(start))
      rescue FinalAnswerException => e
        build_final_result(name, kwargs, e.value, elapsed(start))
      rescue StandardError => e
        build_failure_result(name, kwargs, e, elapsed(start))
      end

      def build_success_result(name, kwargs, result, duration)
        value = result.respond_to?(:data) ? result.data : result
        # Stringify hash keys for LLM compatibility - models expect hash["key"] not hash[:key]
        value = Utilities::Transform.stringify_keys(value)
        record_tool_call(tool_name: name, arguments: kwargs, result: value, duration:)
        { success: true, value: prepare_for_ractor(value) }
      end

      def build_final_result(name, kwargs, value, duration)
        record_tool_call(tool_name: name, arguments: kwargs, result: value, duration:)
        { final_answer: prepare_for_ractor(value) }
      end

      def build_failure_result(name, kwargs, error, duration)
        record_tool_call(tool_name: name, arguments: kwargs, result: nil, duration:, error: error.message)
        { success: false, error: "#{error.class}: #{error.message}" }
      end

      def elapsed(start) = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

      def handle_ractor_termination(msg)
        raise msg if msg.is_a?(Exception)

        build_result(nil, "", error: "Ractor terminated unexpectedly")
      end

      def build_execution_result(msg)
        case msg
        in { success: true, result:, logs:, is_final: } then build_result(result, logs, is_final:)
        in { success: false, error:, logs: } then build_result(nil, logs, error:)
        in :shutdown_complete then build_result(nil, "")
        end
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
