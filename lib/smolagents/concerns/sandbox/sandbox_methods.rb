module Smolagents
  module Concerns
    # Sandboxed method definitions for code execution context
    #
    # Dynamically defines safe methods on executor sandboxes for:
    # - Output capturing (puts, print, p)
    # - State access (state, rand)
    # - Tool discovery (tools, help)
    # - Control flow (raise, loop)
    # - Type checking (is_a?, kind_of?, ==, !=)
    #
    # Methods are injected into the sandbox context class so agent-generated
    # code can interact with standard Ruby patterns safely.
    #
    # @example Injecting sandbox methods
    #   class MyExecutor
    #     SandboxMethods.define_on(self)
    #   end
    #
    # @see RubySafety For code validation before execution
    # @see LocalRubyExecutor Which uses this for sandbox setup
    module SandboxMethods
      # Fallback method results for methods not defined in sandbox
      #
      # nil? and class have special fallback behaviors to prevent
      # access to dangerous Object methods.
      FALLBACK_METHODS = { nil?: false, class: ::Object }.freeze

      # Define sandbox methods on a class
      #
      # Injects safe method implementations that capture output,
      # control state access, and prevent type introspection abuse.
      #
      # @param klass [Class] Class to define methods on
      # @return [void]
      # @example
      #   SandboxMethods.define_on(SandboxContext)
      def self.define_on(klass)
        define_output_methods(klass)
        define_help_methods(klass)
        define_type_checks(klass)
        define_kernel_delegates(klass)
        define_fallback_handler(klass)
      end

      def self.define_output_methods(klass)
        klass.class_eval do
          def puts(*) = @output_buffer.puts(*) || nil
          def print(*) = @output_buffer.print(*) || nil
          def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)
          def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand
          def state = @variables
        end
      end

      def self.define_help_methods(klass)
        klass.class_eval do
          # List all available tools with brief descriptions
          def tools
            @tools.map { |name, tool| "#{name}: #{tool.description.split(".").first}" }.join("\n")
          end

          # List all available variables with their values
          def vars
            return "No variables set" if @variables.empty?

            @variables.map { |name, val| "#{name} = #{val.inspect[0..50]}" }.join("\n")
          end

          # Get help for a specific tool
          def help(tool_name = nil)
            return tools unless tool_name

            tool = @tools[tool_name.to_s]
            return "Unknown tool: #{tool_name}. Available: #{@tools.keys.join(", ")}" unless tool

            tool.help
          end

          # Quick reference for sandbox capabilities
          def sandbox_help
            <<~HELP
              SANDBOX QUICK REFERENCE:
              - puts(tools)     # List available tools
              - puts(vars)      # List current variables
              - puts(budget)    # Show step budget (current/max/remaining)
              - help(:search)   # Get help for a tool
              - result * 2      # Tool results support arithmetic
              - result.first    # Tool results are chainable
            HELP
          end

          # Show step budget - how many steps used and remaining
          def budget
            step = @variables["_step"] || 0
            max = @variables["_max_steps"] || "?"
            remaining = @variables["_steps_remaining"] || "?"
            "Step #{step + 1}/#{max} (#{remaining} remaining)"
          end

          # Check if running low on steps (< 3 remaining)
          def low_budget?
            remaining = @variables["_steps_remaining"]
            remaining && remaining < 3
          end
        end
      end

      def self.define_type_checks(klass)
        klass.class_eval do
          def is_a?(_) = false
          def kind_of?(_) = false
          def ==(other) = equal?(other)
          def !=(other) = !equal?(other)
        end
      end

      def self.define_kernel_delegates(klass)
        klass.class_eval do
          define_method(:raise) { |*args| ::Kernel.raise(*args) }
          define_method(:loop) { |&block| ::Kernel.loop(&block) }
        end
      end

      def self.define_fallback_handler(klass)
        klass.define_singleton_method(:sandbox_fallback) do |name|
          SandboxMethods::FALLBACK_METHODS.fetch(name) do
            msg = "undefined method `#{name}' in sandbox. " \
                  "Use puts(tools) to see available tools, or help(:tool_name) for usage."
            ::Kernel.raise(::NoMethodError, msg)
          end
        end
      end
    end
  end
end
