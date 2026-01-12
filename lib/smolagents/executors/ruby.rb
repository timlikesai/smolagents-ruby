require "stringio"
require "timeout"

module Smolagents
  class LocalRubyExecutor < Executor
    include Concerns::RubySafety

    DEFAULT_MAX_OPERATIONS = 100_000

    def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: 50_000)
      super()
      @max_operations = max_operations
      @max_output_length = max_output_length
      @tools = {}
      @variables = {}
    end

    def send_tools(tools)
      tools.each do |name, tool|
        name_str = name.to_s
        raise ArgumentError, "Cannot register tool with dangerous name: #{name_str}" if DANGEROUS_METHODS.include?(name_str)

        @tools[name_str] = tool
      end
    end

    def send_variables(variables)
      variables.each { |name, value| @variables[name.to_s] = value }
    end

    def execute(code, language: :ruby, timeout: 5, **_options)
      Instrumentation.instrument("smolagents.executor.execute", executor_class: self.class.name, language: language) do
        validate_execution_params!(code, language)
        output_buffer = StringIO.new

        begin
          validate_ruby_code!(code)
          result = Timeout.timeout(timeout) do
            with_operation_limit { create_sandbox(output_buffer).instance_eval(code) }
          end
          build_result(result, output_buffer)
        rescue FinalAnswerException => e
          build_result(e.value, output_buffer, is_final: true)
        rescue Timeout::Error
          build_result(nil, output_buffer, error: "Execution timeout after #{timeout} seconds")
        rescue InterpreterError => e
          build_result(nil, output_buffer, error: e.message)
        rescue StandardError => e
          build_result(nil, output_buffer, error: "#{e.class}: #{e.message}")
        end
      end
    end

    def supports?(language) = language.to_sym == :ruby

    private

    def create_sandbox(output_buffer)
      Sandbox.new(tools: @tools, variables: @variables, output_buffer: output_buffer)
    end

    def with_operation_limit
      operations = 0
      trace = TracePoint.new(:line) do
        operations += 1
        if operations > @max_operations
          trace.disable
          raise InterpreterError, "Operation limit exceeded: #{@max_operations}"
        end
      end
      trace.enable
      yield
    ensure
      trace&.disable
    end

    def build_result(output, buffer, error: nil, is_final: false)
      ExecutionResult.new(output: output, logs: buffer&.string&.byteslice(0, @max_output_length) || "", error: error, is_final_answer: is_final)
    end

    class Sandbox < ::BasicObject
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
end
