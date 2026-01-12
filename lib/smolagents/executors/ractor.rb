require "stringio"

module Smolagents
  class RactorExecutor < Executor
    def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
      super(max_operations: max_operations, max_output_length: max_output_length)
    end

    def execute(code, language: :ruby, timeout: 5, **_options)
      Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language: language) do
        validate_execution_params!(code, language)
        validate_ruby_code!(code)

        if @tools.empty?
          execute_in_ractor_isolated(code, timeout)
        else
          execute_with_tool_support(code, timeout)
        end
      rescue InterpreterError => e
        build_result(nil, "", error: e.message)
      end
    end

    def supports?(language) = language.to_sym == :ruby

    private

    def execute_in_ractor_isolated(code, timeout)
      variables_copy = prepare_variables
      max_ops = @max_operations

      ractor = Ractor.new(code, max_ops, variables_copy) do |code_str, max_operations, vars|
        output_buffer = StringIO.new
        operations = 0

        trace = TracePoint.new(:line) do
          operations += 1
          if operations > max_operations
            trace.disable
            raise "Operation limit exceeded: #{max_operations}"
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

      result = Timeout.timeout(timeout) do
        ractor.value
      end

      build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
    rescue Timeout::Error
      ractor_kill(ractor)
      build_result(nil, "", error: "Execution timeout after #{timeout} seconds")
    rescue Ractor::RemoteError => e
      build_result(nil, "", error: "Ractor error: #{e.cause&.message || e.message}")
    end

    def execute_with_tool_support(code, timeout)
      variables_copy = prepare_variables
      tool_names = @tools.keys.freeze
      max_ops = @max_operations

      child_ractor = Ractor.new(code, max_ops, tool_names, variables_copy) do |code_str, max_operations, tools_list, vars|
        output_buffer = StringIO.new
        operations = 0

        trace = TracePoint.new(:line) do
          operations += 1
          if operations > max_operations
            trace.disable
            raise "Operation limit exceeded: #{max_operations}"
          end
        end

        sandbox = ToolSandbox.new(
          tool_names: tools_list,
          variables: vars,
          output_buffer: output_buffer
        )

        begin
          trace.enable
          result = sandbox.instance_eval(code_str)
          Ractor.main.send({ type: :result, output: result, logs: output_buffer.string, error: nil, is_final: false })
        rescue FinalAnswerSignal => e
          Ractor.main.send({ type: :result, output: e.value, logs: output_buffer.string, error: nil, is_final: true })
        rescue StandardError => e
          Ractor.main.send({ type: :result, output: nil, logs: output_buffer.string, error: "#{e.class}: #{e.message}", is_final: false })
        ensure
          trace&.disable
        end
      end

      result = Timeout.timeout(timeout) do
        process_messages(child_ractor)
      end

      build_result(result[:output], result[:logs], error: result[:error], is_final: result[:is_final])
    rescue Timeout::Error
      ractor_kill(child_ractor)
      build_result(nil, "", error: "Execution timeout after #{timeout} seconds")
    rescue Ractor::RemoteError => e
      build_result(nil, "", error: "Ractor error: #{e.cause&.message || e.message}")
    end

    def process_messages(child_ractor)
      loop do
        message = Ractor.receive

        case message
        in { type: :result, **data }
          return data
        in { type: :tool_call, name: tool_name, args:, kwargs:, caller_ractor: }
          response = handle_tool_call(tool_name, args, kwargs)
          caller_ractor.send(response)
        end
      end
    end

    def handle_tool_call(tool_name, args, kwargs)
      tool = @tools[tool_name]
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
      @variables.transform_values { |v| prepare_for_ractor(v) }
    end

    def prepare_for_ractor(obj)
      case obj
      when NilClass, TrueClass, FalseClass, Integer, Float, Symbol
        obj
      when String
        obj.frozen? ? obj : obj.dup.freeze
      when Array
        obj.map { |v| prepare_for_ractor(v) }.freeze
      when Hash
        obj.transform_keys { |k| prepare_for_ractor(k) }
           .transform_values { |v| prepare_for_ractor(v) }
           .freeze
      else
        return obj if Ractor.shareable?(obj)

        Marshal.load(Marshal.dump(obj))
      end
    end

    class FinalAnswerSignal < StandardError
      attr_reader :value

      def initialize(value)
        @value = value
        super("Final answer")
      end
    end

    class IsolatedSandbox < ::BasicObject
      def initialize(variables:, output_buffer:)
        @variables = variables
        @output_buffer = output_buffer
      end

      def method_missing(name, *args, **kwargs)
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

      def puts(*args) = @output_buffer.puts(*args) || nil
      def print(*args) = @output_buffer.print(*args) || nil
      def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)
      def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand
      def sleep(duration) = ::Kernel.sleep(duration)
      def state = @variables
      def is_a?(_) = false
      def kind_of?(_) = false
      def ==(other) = equal?(other)
      def !=(other) = !equal?(other)

      define_method(:raise) { |*args| ::Kernel.raise(*args) }
      define_method(:loop) { |&block| ::Kernel.loop(&block) }
    end

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

      def puts(*args) = @output_buffer.puts(*args) || nil
      def print(*args) = @output_buffer.print(*args) || nil
      def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)
      def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand
      def sleep(duration) = ::Kernel.sleep(duration)
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
