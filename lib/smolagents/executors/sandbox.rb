module Smolagents
  module Executors
    # Base sandbox for Ractor-based code execution.
    #
    # Provides a minimal, secure execution environment inheriting from BasicObject.
    # Subclasses add specific capabilities (tools, variables, etc).
    #
    # == Design
    #
    # BasicObject inheritance provides maximum isolation - only explicitly defined
    # methods are available to executed code. Output is captured to a buffer,
    # and common Ruby operations are safely delegated to Kernel.
    #
    # @example Subclassing
    #   class CustomSandbox < Sandbox
    #     def method_missing(name, *args, **kwargs)
    #       # Custom resolution logic
    #       super # Falls through to handle_unknown_method
    #     end
    #   end
    #
    # @abstract Subclass and implement method_missing for custom resolution
    # @api private
    class Sandbox < ::BasicObject
      # @param variables [Hash{String => Object}] Accessible variables
      # @param output_buffer [StringIO] Buffer for stdout capture
      def initialize(variables:, output_buffer:)
        @variables = variables
        @output_buffer = output_buffer
      end

      # Returns the variables hash for debugging.
      # @return [Hash{String => Object}]
      def state = @variables

      # == Output Methods ==

      # @api private
      def puts(*) = @output_buffer.puts(*) || nil

      # @api private
      def print(*) = @output_buffer.print(*) || nil

      # @api private
      def p(*args)
        @output_buffer.puts(args.map(&:inspect).join(", "))
        args.length <= 1 ? args.first : args
      end

      # == Kernel Delegation ==

      # @api private
      def rand(max = nil) = max ? ::Kernel.rand(max) : ::Kernel.rand

      # @api private
      def raise(*) = ::Kernel.raise(*)

      # @api private
      def loop(&) = ::Kernel.loop(&)

      # == Type Checking (always false in sandbox) ==

      # @api private
      def is_a?(_) = false

      # @api private
      def kind_of?(_) = false

      # @api private
      def ==(other) = equal?(other)

      # @api private
      def !=(other) = !equal?(other)

      # Handles special methods that need sandbox-specific behavior.
      # @api private
      def handle_unknown_method(name)
        case name
        when :nil? then false
        when :class then ::Object
        else ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
        end
      end
    end
  end
end
