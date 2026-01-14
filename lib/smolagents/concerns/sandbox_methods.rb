module Smolagents
  module Concerns
    # Sandboxed method definitions for code execution context
    #
    # Dynamically defines safe methods on executor sandboxes for:
    # - Output capturing (puts, print, p)
    # - State access (state, rand)
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
          SandboxMethods::FALLBACK_METHODS.fetch(name) { ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox") }
        end
      end
    end
  end
end
