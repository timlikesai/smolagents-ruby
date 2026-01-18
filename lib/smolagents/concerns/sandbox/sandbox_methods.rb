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

      SANDBOX_HELP_TEXT = <<~HELP.freeze
        SANDBOX QUICK REFERENCE:
        - puts(tools)     # List available tools
        - puts(vars)      # List current variables
        - puts(budget)    # Show step budget (current/max/remaining)
        - help(:search)   # Get help for a tool
        - result * 2      # Tool results support arithmetic
        - result.first    # Tool results are chainable

        VARIABLE PERSISTENCE:
        - self.results = search(query: "test")  # Persists between code blocks
        - remember(:results, search(...))       # Alternative syntax
        - results = search(...)                 # Local only, lost after block
      HELP

      def self.define_help_methods(klass)
        define_tool_discovery(klass)
        define_introspection(klass)
      end

      def self.define_tool_discovery(klass)
        klass.class_eval do
          def tools = @tools.map { |name, tool| "#{name}: #{tool.description.split(".").first}" }.join("\n")

          def help(tool_name = nil)
            return tools unless tool_name

            tool = @tools[tool_name.to_s]
            tool ? tool.help : "Unknown tool: #{tool_name}. Available: #{@tools.keys.join(", ")}"
          end

          def sandbox_help = SandboxMethods::SANDBOX_HELP_TEXT
        end
      end

      def self.define_introspection(klass)
        define_vars_method(klass)
        define_budget_methods(klass)
        define_persistence_methods(klass)
      end

      def self.define_persistence_methods(klass)
        klass.define_method(:remember) do |name, value|
          name_str = name.to_s
          @variables[name_str] = value
          (@defined_vars ||= []) << name_str unless @defined_vars&.include?(name_str)
          value
        end
      end

      def self.define_vars_method(klass)
        klass.define_method(:vars) do
          return "No variables set" if @variables.empty?

          @variables.map { |name, val| "#{name} = #{val.inspect[0..50]}" }.join("\n")
        end
      end

      def self.define_budget_methods(klass)
        klass.define_method(:budget) do
          step = (@variables["_step"] || 0) + 1
          max = @variables["_max_steps"] || "?"
          remaining = @variables["_steps_remaining"] || "?"
          "Step #{step}/#{max} (#{remaining} remaining)"
        end
        klass.define_method(:low_budget?) { (r = @variables["_steps_remaining"]) && r < 3 }
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
