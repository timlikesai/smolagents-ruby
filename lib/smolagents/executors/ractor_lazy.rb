require "stringio"
require_relative "final_answer_signal"

module Smolagents
  module Executors
    # Fiber-based lazy execution for Ractor with automatic tool batching.
    #
    # Tool calls return futures immediately. When results are accessed,
    # all pending futures are batched and yielded for parallel execution.
    #
    # @example Inside Ractor
    #   @a = search(query: "ruby")   # Returns future instantly
    #   @b = search(query: "python") # Returns future instantly
    #   @a.first                     # Triggers batch - both resolve in parallel
    #
    module RactorLazy
      # Lazy tool result - yields on access for batching.
      #
      # Inherits from BasicObject to intercept all method calls.
      # Any access triggers batch resolution via Fiber.yield.
      #
      class ToolFuture < BasicObject
        attr_reader :tool_name, :args, :kwargs

        def initialize(tool_name, args, kwargs, batch)
          @tool_name = tool_name
          @args = args
          @kwargs = kwargs
          @batch = batch
          @resolved = false
          @result = nil
          @error = nil
          batch << self
        end

        def _resolve!(value)
          @result = value
          @resolved = true
        end

        def _reject!(error)
          @error = error
          @resolved = true
        end

        def _resolved? = @resolved
        def _result = @result
        def _error = @error
        def _pending? = !@resolved

        # Identity methods that don't trigger resolution
        def _future? = true
        def nil? = false
        def is_a?(klass) = [ToolFuture, ::BasicObject].include?(klass)
        def kind_of?(klass) = is_a?(klass)
        def instance_of?(klass) = klass == ToolFuture
        def class = ToolFuture

        # respond_to? for internal methods (BasicObject doesn't have this)
        # rubocop:disable Style/OptionalBooleanParameter -- matches Ruby's respond_to? signature
        def respond_to?(method, include_private = false)
          # rubocop:enable Style/OptionalBooleanParameter
          return true if method.to_s.start_with?("_")
          return true if %i[nil? is_a? kind_of? instance_of? class].include?(method.to_sym)

          _ensure_resolved!
          @result.respond_to?(method, include_private)
        end

        # Delegate all methods to resolved value
        def method_missing(method, ...)
          _ensure_resolved!
          @result.public_send(method, ...)
        end

        def respond_to_missing?(method, include_private = false)
          # Internal methods don't need resolution
          return true if method.to_s.start_with?("_")

          _ensure_resolved!
          @result.respond_to?(method, include_private)
        end

        def ==(other)
          _ensure_resolved!
          @result == other
        end

        def to_s
          _ensure_resolved!
          @result.to_s
        end

        def to_a
          _ensure_resolved!
          @result.to_a
        end

        def to_h
          _ensure_resolved!
          @result.to_h
        end

        def inspect
          return "#<Future:pending #{@tool_name}>" unless @resolved

          "#<Future:resolved #{@tool_name} => #{@result.inspect[0, 50]}>"
        end

        def each(&)
          _ensure_resolved!
          @result.each(&)
        end

        def [](key)
          _ensure_resolved!
          @result[key]
        end

        private

        def _ensure_resolved!
          return if @resolved

          # Yield batch of all pending futures
          pending = @batch.select(&:_pending?)
          ::Fiber.yield({ type: :batch, futures: pending })

          # After resume, we should be resolved
          ::Kernel.raise "Future not resolved after batch" unless @resolved
          ::Kernel.raise @error if @error
        end
      end

      # Execution context with Fiber-based lazy tool calls.
      module Context
        def self.build(tool_names:, tool_port:, result_port:, initial_vars:, max_ops:)
          output = StringIO.new
          state = initial_vars.transform_keys(&:to_sym)
          batch = []
          ctx = Object.new
          setup_context(ctx, output:, state:, batch:, tool_port:, result_port:, max_ops:, tool_names:)
          [ctx, output, batch]
        end

        def self.setup_context(ctx, output:, state:, batch:, tool_port:, result_port:, max_ops:, tool_names:)
          setup_ivars(ctx, { output:, state:, batch:, tool_port:, result_port:, max_ops: })
          setup_helpers(ctx, tool_names, state)
        end

        def self.setup_ivars(ctx, ivars)
          ivars.each { |k, v| ctx.instance_variable_set(:"@#{k}", v) }
        end

        def self.setup_helpers(ctx, tool_names, state)
          setup_output_helpers(ctx)
          setup_introspection(ctx, tool_names)
          setup_state_management(ctx)
          setup_variable_access(ctx, state)
          setup_lazy_tools(ctx, tool_names)
        end

        def self.setup_output_helpers(ctx)
          ctx.define_singleton_method(:puts) { |*a| @output.puts(*a) }
          ctx.define_singleton_method(:print) { |*a| @output.print(*a) }
          ctx.define_singleton_method(:p) do |*a|
            @output.puts(a.map(&:inspect).join(", "))
            a.first
          end
        end

        def self.setup_introspection(ctx, tool_names)
          ctx.instance_variable_set(:@tool_names, tool_names)
          ctx.define_singleton_method(:tools) { @tool_names.join(", ") }
          ctx.define_singleton_method(:vars) { @state.keys.sort.join(", ") }
          ctx.define_singleton_method(:help) { |t = nil| t ? "Use: #{t}(arg: value)" : "Tools: #{tools}" }
        end

        def self.setup_state_management(ctx)
          ctx.define_singleton_method(:remember) do |name, val|
            sym = name.to_sym
            @state[sym] = val
            define_singleton_method(sym) { @state[sym] } unless respond_to?(sym)
            val
          end
        end

        def self.setup_variable_access(ctx, state)
          ctx.define_singleton_method(:method_missing) do |name, *args, **kw, &block|
            return @state[name] if @state.key?(name)

            super(name, *args, **kw, &block)
          end
          ctx.define_singleton_method(:respond_to_missing?) { |name, _| @state.key?(name) }
          state.each_key { |sym| ctx.define_singleton_method(sym) { @state[sym] } }
        end

        # Tools return lazy futures instead of blocking
        def self.setup_lazy_tools(ctx, tool_names)
          tool_names.each do |name|
            ctx.define_singleton_method(name) do |*args, **kw|
              ToolFuture.new(name, args, kw, @batch)
            end
          end
        end
      end

      # Future resolution helpers for FiberExecutor.
      module FutureResolution
        def tool_future?(value)
          begin
            value.respond_to?(:_future?)
          rescue StandardError
            false
          end && value._future?
        end

        def resolve_all_pending(value)
          return if value.nil?

          if tool_future?(value)
            force_resolve(value) unless value._resolved?
            return
          end

          resolve_pending_collection(value)
        end

        def resolve_pending_collection(value)
          case value
          when Array then value.each { |v| resolve_all_pending(v) }
          when Hash then value.each_value { |v| resolve_all_pending(v) }
          end
        end

        def unwrap_future(value)
          return value if value.nil?
          return unwrap_tool_future(value) if tool_future?(value)

          unwrap_collection(value)
        end

        def unwrap_tool_future(future)
          err = future._error
          ::Kernel.raise err if err
          future._resolved? ? future._result : future.inspect
        end

        def unwrap_collection(value)
          case value
          when Array then value.map { |v| unwrap_future(v) }
          when Hash then value.transform_values { |v| unwrap_future(v) }
          else value
          end
        end
      end

      # Batch handling for FiberExecutor.
      module BatchHandling
        def handle_batch(futures)
          requests = futures.map { |f| build_request(f) }
          @tool_port.send({ type: :batch, requests: })
          resolve_futures(futures, ::Ractor.receive[:results])
        end

        def force_resolve(_future)
          loop do
            pending = @batch.select(&:_pending?)
            return if pending.empty?

            ready = select_ready(pending)
            requests = ready.map { |f| build_request(f) }
            @tool_port.send({ type: :batch, requests: })
            resolve_futures(ready, ::Ractor.receive[:results])
          end
        end

        def select_ready(pending)
          ready = pending.select { |f| ready_to_resolve?(f) }
          ready.empty? ? pending : ready
        end

        def ready_to_resolve?(future)
          all_resolved?(future.args) && all_resolved?(future.kwargs.values)
        end

        def all_resolved?(values)
          values.all? { |v| !v.is_a?(ToolFuture) || v._resolved? }
        end

        def resolve_futures(futures, results)
          futures.zip(results).each { |future, result| apply_result(future, result) }
        end

        def apply_result(future, result)
          case result
          in { success: true, value: } then future._resolve!(value)
          in { success: false, error: } then future._reject!(error)
          in { final_answer: value } then resolve_final(future, value)
          end
        end

        def resolve_final(future, value)
          future._resolve!(value)
          raise FinalAnswerSignal, value
        end

        def build_request(future)
          { name: future.tool_name, args: unwrap_args(future.args), kwargs: unwrap_kwargs(future.kwargs) }
        end

        def unwrap_args(args)
          args.map { |a| a.is_a?(ToolFuture) && a._resolved? ? a._result : a }
        end

        def unwrap_kwargs(kwargs)
          kwargs.transform_values { |v| v.is_a?(ToolFuture) && v._resolved? ? v._result : v }
        end
      end

      # Executes code in a Fiber, handling batch yields.
      class FiberExecutor
        include FutureResolution
        include BatchHandling

        # rubocop:disable Metrics/ParameterLists -- mirrors Context.build parameters
        def initialize(ctx, output, batch, tool_port, result_port, max_ops)
          # rubocop:enable Metrics/ParameterLists
          @ctx = ctx
          @output = output
          @batch = batch
          @tool_port = tool_port
          @result_port = result_port
          @max_ops = max_ops
        end

        def execute(code)
          reset_output
          @batch.clear
          run_fiber(create_fiber(code))
        end

        private

        def reset_output = @output.truncate(0) && @output.rewind

        def create_fiber(code)
          ctx = @ctx
          max_ops = @max_ops
          Fiber.new { execute_with_tracing(ctx, code, max_ops) }
        end

        def execute_with_tracing(ctx, code, max_ops)
          ops = 0
          trace = TracePoint.new(:line) { (ops += 1) > max_ops && raise("Operation limit exceeded") }
          trace.enable
          run_code(ctx, code)
        ensure
          trace.disable
        end

        def run_code(ctx, code)
          { type: :result, value: ctx.instance_eval(code) }
        rescue FinalAnswerSignal => e
          { type: :final_answer, value: e.value }
        rescue StandardError => e
          { type: :error, error: "#{e.class}: #{e.message}" }
        end

        def run_fiber(fiber)
          loop { break unless process_fiber_result(fiber.resume) }
        end

        # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        # Pattern matching requires multiple branches
        def process_fiber_result(result)
          case result
          in { type: :batch, futures: } then handle_batch(futures) || true
          in { type: :result, value: } then resolve_and_send(:result, value) && false
          in { type: :final_answer, value: } then resolve_and_send(:final, value) && false
          in { type: :error, error: } then send_error(error) && false
          end
        end
        # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

        def resolve_and_send(type, value)
          resolve_all_pending(value)
          type == :final ? send_final(value) : send_result(value)
        rescue FinalAnswerSignal => e
          send_final(e.value)
        rescue StandardError => e
          send_error("#{e.class}: #{e.message}")
        end

        def send_result(value)
          @result_port.send({ success: true, result: unwrap_future(value), logs: @output.string, is_final: false })
        end

        def send_final(value)
          @result_port.send({ success: true, result: unwrap_future(value), logs: @output.string, is_final: true })
        end

        def send_error(error)
          @result_port.send({ success: false, error:, logs: @output.string })
        end
      end
    end
  end
end
