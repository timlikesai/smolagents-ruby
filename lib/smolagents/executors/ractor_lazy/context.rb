require "stringio"

module Smolagents
  module Executors
    module RactorLazy
      # Builds execution context with Fiber-based lazy tool calls.
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
              Smolagents::Executors::RactorLazy::ToolFuture.new(name, args, kw, @batch)
            end
          end
        end
      end
    end
  end
end
