module Smolagents
  module Concerns
    module SandboxMethods
      FALLBACK_METHODS = { nil?: false, class: ::Object }.freeze

      def self.define_on(klass)
        klass.class_eval do
          def puts(*) = @output_buffer.puts(*) || nil
          def print(*) = @output_buffer.print(*) || nil
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
