module Smolagents
  class RubySandbox < ::BasicObject
    def initialize(tools:, variables:, output_buffer:)
      @tools = tools
      @variables = variables
      @output_buffer = output_buffer
    end

    def method_missing(name, *, **)
      name_str = name.to_s
      return @tools[name_str].call(*, **) if @tools.key?(name_str)
      return @variables[name_str] if @variables.key?(name_str)

      { nil?: false, class: ::Object }[name] || ::Kernel.raise(::NoMethodError, "undefined method `#{name}' in sandbox")
    end

    def respond_to_missing?(name, _ = false) = @tools.key?(name.to_s) || @variables.key?(name.to_s)

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
  end
end
