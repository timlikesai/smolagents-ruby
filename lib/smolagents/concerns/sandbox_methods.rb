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
        klass.class_eval do
          # Output methods - capture to buffer instead of real stdout
          # @return [nil] Always nil for consistency
          def puts(*) = @output_buffer.puts(*) || nil

          # Print without newline - capture to buffer
          # @return [nil] Always nil for consistency
          def print(*) = @output_buffer.print(*) || nil

          # Inspect and print objects - capture to buffer
          # @return [Object, Array] Last argument or array of arguments
          def p(*args) = @output_buffer.puts(args.map(&:inspect).join(", ")) || (args.length <= 1 ? args.first : args)

          # Random number generation - delegates to ::Kernel.rand
          #
          # @param max [Integer, Float, nil] Upper bound (exclusive)
          # @return [Numeric] Random number
          def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand

          # Access sandbox state variables
          #
          # @return [Hash] Mutable state from executor
          def state = @variables

          # Type checking - always returns false in sandbox
          #
          # Prevents access to dangerous methods via is_a? polymorphism
          #
          # @param _type [Class] Type to check
          # @return [Boolean] Always false
          def is_a?(_) = false

          # Type checking - always returns false in sandbox
          #
          # @param _type [Class] Type to check
          # @return [Boolean] Always false
          def kind_of?(_) = false

          # Equality - only true for same object
          #
          # @param other [Object] Object to compare
          # @return [Boolean] true if same object
          def ==(other) = equal?(other)

          # Inequality - only true for different objects
          #
          # @param other [Object] Object to compare
          # @return [Boolean] true if different objects
          def !=(other) = !equal?(other)

          # Raise exceptions - delegates to ::Kernel.raise
          #
          # @param args [Array] Exception class, message, or Exception instance
          # @return [void]
          # @raise [StandardError] The specified exception
          define_method(:raise) { |*args| ::Kernel.raise(*args) }

          # Loop indefinitely - delegates to ::Kernel.loop
          #
          # @yield Executed repeatedly until break or error
          # @return [Object] Break value or nil
          define_method(:loop) { |&block| ::Kernel.loop(&block) }

          # Get fallback method values for undefined methods
          #
          # Provides safe fallbacks for methods like nil? and class
          # that might be called on sandbox objects.
          #
          # @param name [Symbol, String] Method name
          # @return [Object] Fallback value
          # @raise [NoMethodError] If no fallback defined
          # @api private
          def self.sandbox_fallback(name)
            SandboxMethods::FALLBACK_METHODS.fetch(name) do
              ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
            end
          end
        end
      end
    end
  end
end
