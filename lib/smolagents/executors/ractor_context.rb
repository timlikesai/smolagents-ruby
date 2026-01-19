require "stringio"
require_relative "final_answer_signal"

module Smolagents
  module Executors
    # Builds execution context for Ractor-based code execution.
    # Used internally by Ractor executor to set up the environment.
    module RactorContext
      # Creates a context object with output helpers, state management, and tool methods.
      def self.build(tool_names:, tool_port:, initial_vars:)
        output = StringIO.new
        state = initial_vars.transform_keys(&:to_sym)

        ctx = Object.new
        setup_instance_vars(ctx, output, state, tool_names, tool_port)
        setup_output_helpers(ctx)
        setup_introspection(ctx)
        setup_state_management(ctx)
        setup_variable_access(ctx, state)
        setup_tools(ctx, tool_names)
        [ctx, output]
      end

      def self.setup_instance_vars(ctx, output, state, tool_names, tool_port)
        ctx.instance_variable_set(:@output, output)
        ctx.instance_variable_set(:@state, state)
        ctx.instance_variable_set(:@tool_names, tool_names)
        ctx.instance_variable_set(:@tool_port, tool_port)
      end

      def self.setup_output_helpers(ctx)
        setup_puts(ctx)
        setup_print(ctx)
        setup_p(ctx)
      end

      def self.setup_puts(ctx)
        ctx.define_singleton_method(:puts) { |*a| @output.puts(*a) }
      end

      def self.setup_print(ctx)
        ctx.define_singleton_method(:print) { |*a| @output.print(*a) }
      end

      def self.setup_p(ctx)
        ctx.define_singleton_method(:p) do |*a|
          @output.puts(a.map(&:inspect).join(", "))
          a.first
        end
      end

      def self.setup_introspection(ctx)
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

      def self.setup_tools(ctx, tool_names)
        tool_names.each do |name|
          ctx.define_singleton_method(name) do |*args, **kw|
            @tool_port.send({ name:, args:, kwargs: kw })
            case ::Ractor.receive
            in { result: v } then v
            in { final_answer: v } then raise FinalAnswerSignal, v
            in { error: msg } then raise msg.to_s
            end
          end
        end
      end

      # Executes code in context with operation limiting.
      def self.execute(ctx, code, output, max_ops, result_port)
        reset_output(output)
        trace = operation_limiter(max_ops)
        trace.enable
        send_result(result_port, ctx.instance_eval(code), output.string)
      rescue FinalAnswerSignal => e
        send_final(result_port, e.value, output.string)
      rescue StandardError => e
        send_error(result_port, e, output.string)
      ensure
        trace&.disable
      end

      def self.reset_output(output)
        output.truncate(0)
        output.rewind
      end

      def self.operation_limiter(max_ops)
        ops = 0
        TracePoint.new(:line) { (ops += 1) > max_ops && raise("Operation limit exceeded") }
      end

      def self.send_result(port, result, logs) = port.send({ success: true, result:, logs:, is_final: false })
      def self.send_final(port, result, logs) = port.send({ success: true, result:, logs:, is_final: true })
      def self.send_error(port, err, logs) = port.send({ success: false, error: "#{err.class}: #{err.message}", logs: })
    end
  end
end
