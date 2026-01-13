require "stringio"

module Smolagents
  module Executors
    # Ractor-based code executor for thread-safe isolation.
    #
    # Ractor uses Ruby's Ractor feature for true parallel execution with
    # memory isolation. Each execution runs in its own Ractor with no
    # shared mutable state.
    #
    # Features:
    # - True parallelism (not limited by GVL)
    # - Memory isolation between executions
    # - Tool calls routed through message passing
    # - Operation limits via TracePoint
    #
    # @note Requires Ruby 3.0+ with Ractor support
    # @note Objects passed to Ractors must be shareable (frozen or primitive)
    #
    # @example Basic execution
    #   executor = Executors::Ractor.new
    #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
    #
    # @see Executor Base class
    class Ractor < Executor
      def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
        super
      end

      # timeout ignored: operation-limited only
      def execute(code, language: :ruby, timeout: nil, **_options)
        Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language: language) do
          validate_execution_params!(code, language)
          validate_ruby_code!(code)

          if tools.empty?
            execute_in_ractor_isolated(code)
          else
            execute_with_tool_support(code)
          end
        rescue InterpreterError => e
          build_result(nil, "", error: e.message)
        end
      end

      def supports?(language) = language.to_sym == :ruby

      # Maximum message iterations before returning error (prevents runaway)
      MAX_MESSAGE_ITERATIONS = 10_000

      private

      def execute_in_ractor_isolated(code)
        ractor = create_isolated_ractor(code)
        wait_for_ractor_result(ractor)
      rescue ::Ractor::RemoteError => e
        handle_ractor_error(e)
      end

      def create_isolated_ractor(code)
        variables_copy = prepare_variables
        max_ops = max_operations

        ::Ractor.new(code, max_ops, variables_copy) do |code_str, max_operations, vars|
          output_buffer = StringIO.new
          operations = 0

          trace = TracePoint.new(:line) do
            operations += 1
            if operations > max_operations
              trace.disable
              Thread.current.raise("Operation limit exceeded: #{max_operations}")
            end
          end

          sandbox = IsolatedSandbox.new(variables: vars, output_buffer: output_buffer)

          begin
            trace.enable
            result = sandbox.instance_eval(code_str)
            { output: result, logs: output_buffer.string, error: nil, is_final: false }
          rescue StandardError => e
            { output: nil, logs: output_buffer.string, error: "#{e.class}: #{e.message}", is_final: false }
          ensure
            trace&.disable
          end
        end
      end

      def wait_for_ractor_result(ractor)
        result = ractor.value
        build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
      end

      def handle_ractor_error(err)
        build_result(nil, "", error: "Ractor error: #{err.cause&.message || err.message}")
      end

      def execute_with_tool_support(code)
        child_ractor = create_tool_ractor(code)
        wait_for_tool_ractor_result(child_ractor)
      rescue ::Ractor::RemoteError => e
        handle_ractor_error(e)
      end

      def create_tool_ractor(code)
        variables_copy = prepare_variables
        tool_names = tools.keys.freeze
        max_ops = max_operations

        ::Ractor.new(code, max_ops, tool_names, variables_copy) do |code_str, max_operations, tools_list, vars|
          output_buffer = StringIO.new
          operations = 0

          trace = TracePoint.new(:line) do
            operations += 1
            if operations > max_operations
              trace.disable
              Thread.current.raise("Operation limit exceeded: #{max_operations}")
            end
          end

          sandbox = ToolSandbox.new(tool_names: tools_list, variables: vars, output_buffer: output_buffer)

          begin
            trace.enable
            result = sandbox.instance_eval(code_str)
            ::Ractor.main.send({ type: :result, output: result, logs: output_buffer.string, error: nil, is_final: false })
          rescue FinalAnswerSignal => e
            ::Ractor.main.send({ type: :result, output: e.value, logs: output_buffer.string, error: nil, is_final: true })
          rescue StandardError => e
            ::Ractor.main.send({ type: :result, output: nil, logs: output_buffer.string, error: "#{e.class}: #{e.message}", is_final: false })
          ensure
            trace&.disable
          end
        end
      end

      def wait_for_tool_ractor_result(child_ractor)
        result = process_messages(child_ractor)
        build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
      end

      def process_messages(_child_ractor)
        MAX_MESSAGE_ITERATIONS.times do
          message = ::Ractor.receive

          case message
          in { type: :result, **data }
            return data
          in { type: :tool_call, name: tool_name, args:, kwargs:, caller_ractor: }
            response = handle_tool_call(tool_name, args, kwargs)
            caller_ractor.send(response)
          end
        end

        # Exceeded max iterations without receiving result
        { output: nil, logs: "", error: "Message processing limit exceeded", is_final: false }
      end

      def handle_tool_call(tool_name, args, kwargs)
        tool = tools[tool_name]
        return { error: "Unknown tool: #{tool_name}" } unless tool

        begin
          result = tool.call(*args, **kwargs)
          { result: prepare_for_ractor(result) }
        rescue FinalAnswerException => e
          { final_answer: prepare_for_ractor(e.value) }
        rescue StandardError => e
          { error: "#{e.class}: #{e.message}" }
        end
      end

      def ractor_kill(ractor)
        return unless ractor

        ractor.close if ractor.respond_to?(:close)
      rescue StandardError
        # Ignore errors when killing
      end

      def prepare_variables
        variables.transform_values { |val| prepare_for_ractor(val) }
      end

      # Prepare an object for Ractor boundary crossing.
      #
      # == Shareability Rules (see PLAN.md "Data.define Ractor Shareability")
      #
      # * Primitives (Integer, Float, Symbol, nil, true, false) - always shareable
      # * Frozen strings - shareable by reference
      # * Frozen arrays/hashes - shareable if all contents shareable
      # * Data.define instances - shareable when ALL values are shareable
      #   (custom methods in block do NOT affect shareability)
      # * Procs/Lambdas - NEVER shareable
      # * Arbitrary objects - not shareable unless explicitly made so
      #
      # This method ensures values crossing the Ractor boundary are frozen
      # and serializable. Complex objects are converted to hash representations.
      def prepare_for_ractor(obj)
        case obj
        when NilClass, TrueClass, FalseClass, Integer, Float, Symbol
          obj
        when String
          obj.frozen? ? obj : obj.dup.freeze
        when Array
          obj.map { |item| prepare_for_ractor(item) }.freeze
        when Hash
          obj.transform_keys { |key| prepare_for_ractor(key) }
             .transform_values { |val| prepare_for_ractor(val) }
             .freeze
        else
          return obj if ::Ractor.shareable?(obj)

          # Use JSON instead of Marshal for safety (avoids deserialization attacks)
          # Complex objects are converted to their hash representation
          safe_serialize_for_ractor(obj)
        end
      end

      def safe_serialize_for_ractor(obj)
        case obj
        when Range, Set
          # Pure enumerables without meaningful to_h
          prepare_for_ractor(obj.to_a)
        when Struct, Data
          # Struct-like objects should use to_h
          prepare_for_ractor(obj.to_h)
        else
          # Try to_h first for objects with hash representation
          if obj.respond_to?(:to_h) && !obj.is_a?(Array)
            prepare_for_ractor(obj.to_h)
          elsif obj.respond_to?(:to_a)
            prepare_for_ractor(obj.to_a)
          else
            # Last resort: convert to string representation
            obj.to_s.freeze
          end
        end
      end

      # Signal for final answer in Ractor context
      class FinalAnswerSignal < StandardError
        attr_reader :value

        def initialize(value)
          @value = value
          super("Final answer")
        end
      end

      # Sandbox for isolated execution without tools
      class IsolatedSandbox < ::BasicObject
        def initialize(variables:, output_buffer:)
          @variables = variables
          @output_buffer = output_buffer
        end

        def method_missing(name, *_args, **_kwargs)
          name_str = name.to_s
          if @variables.key?(name_str)
            @variables[name_str]
          else
            case name
            when :nil? then false
            when :class then ::Object
            else
              ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
            end
          end
        end

        def respond_to_missing?(name, _ = false)
          @variables.key?(name.to_s)
        end

        def puts(*) = @output_buffer.puts(*) || nil
        def print(*) = @output_buffer.print(*) || nil
        def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)
        def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand
        def state = @variables
        def is_a?(_) = false
        def kind_of?(_) = false
        def ==(other) = equal?(other)
        def !=(other) = !equal?(other)

        define_method(:raise) { |*args| ::Kernel.raise(*args) }
        define_method(:loop) { |&block| ::Kernel.loop(&block) }
      end

      # Sandbox for execution with tool support
      class ToolSandbox < ::BasicObject
        def initialize(tool_names:, variables:, output_buffer:)
          @tool_names = tool_names
          @variables = variables
          @output_buffer = output_buffer
        end

        def method_missing(name, *args, **kwargs)
          name_str = name.to_s
          if @tool_names.include?(name_str)
            call_tool(name_str, args, kwargs)
          elsif @variables.key?(name_str)
            @variables[name_str]
          else
            case name
            when :nil? then false
            when :class then ::Object
            else
              ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
            end
          end
        end

        def respond_to_missing?(name, _ = false)
          name_str = name.to_s
          @tool_names.include?(name_str) || @variables.key?(name_str)
        end

        def puts(*) = @output_buffer.puts(*) || nil
        def print(*) = @output_buffer.print(*) || nil
        def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)
        def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand
        def state = @variables
        def is_a?(_) = false
        def kind_of?(_) = false
        def ==(other) = equal?(other)
        def !=(other) = !equal?(other)

        define_method(:raise) { |*args| ::Kernel.raise(*args) }
        define_method(:loop) { |&block| ::Kernel.loop(&block) }

        private

        def call_tool(name, args, kwargs)
          current = ::Ractor.current
          ::Ractor.main.send({
                               type: :tool_call,
                               name: name,
                               args: args,
                               kwargs: kwargs,
                               caller_ractor: current
                             })
          response = ::Ractor.receive

          case response
          in { result: value }
            value
          in { final_answer: value }
            ::Kernel.raise(FinalAnswerSignal, value)
          in { error: message }
            ::Kernel.raise(::RuntimeError, message)
          end
        end
      end
    end
  end
end
