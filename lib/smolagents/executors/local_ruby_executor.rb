# frozen_string_literal: true

require "ripper"
require "stringio"
require "timeout"

module Smolagents
  # Local Ruby code executor with sandboxing using BasicObject clean room.
  class LocalRubyExecutor < Executor
    DANGEROUS_METHODS = Set.new(%w[
                                  eval instance_eval class_eval module_eval system exec spawn fork
                                  require require_relative load autoload open File IO Dir
                                  send __send__ public_send method define_method
                                  const_get const_set remove_const class_variable_get class_variable_set remove_class_variable
                                  instance_variable_get instance_variable_set remove_instance_variable
                                  binding ObjectSpace Marshal Kernel
                                ]).freeze

    DANGEROUS_CONSTANTS = /(?<![A-Za-z0-9_])(File|IO|Dir|Process|Thread|ObjectSpace|Marshal|Kernel|ENV|FileUtils|Pathname|Socket|TCPSocket|UDPSocket|BasicSocket)(?![A-Za-z0-9_])/
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
      variables.each do |name, value|
        @variables[name.to_s] = value
      end
    end

    def execute(code, language: :ruby, timeout: 5, **_options)
      validate_execution_params!(code, language)
      output_buffer = StringIO.new

      begin
        validate_code!(code)
        result = Timeout.timeout(timeout) do
          sandbox = RubySandbox.new(tools: @tools, variables: @variables, output_buffer: output_buffer)
          counter = OperationCounter.new(@max_operations)
          counter.start
          begin sandbox.instance_eval(code) ensure counter.stop end
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

    def supports?(language) = language.to_sym == :ruby

    private

    def build_result(output, buffer, error: nil, is_final: false)
      ExecutionResult.new(output: output, logs: buffer&.string&.byteslice(0, @max_output_length) || "", error: error, is_final_answer: is_final)
    end

    def validate_code!(code)
      raise InterpreterError, "Code contains dangerous constant access" if code.match?(DANGEROUS_CONSTANTS)

      sexp = Ripper.sexp(code) or raise InterpreterError, "Code has syntax errors"
      check_sexp_for_dangerous_calls(sexp)
    end

    def check_sexp_for_dangerous_calls(sexp)
      return unless sexp.is_a?(Array)

      if %i[command vcall fcall call].include?(sexp[0])
        method_name = sexp.find { |e| e.is_a?(Array) && %i[@ident @const].include?(e[0]) }&.[](1)
        raise InterpreterError, "Dangerous method call: #{method_name}" if method_name && DANGEROUS_METHODS.include?(method_name)
      end
      sexp.each { |child| check_sexp_for_dangerous_calls(child) }
    end

    # Sandboxed execution environment using BasicObject - no Kernel methods leaked.
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

    # Operation counter using TracePoint to prevent infinite loops.
    class OperationCounter
      def initialize(max_operations)
        (@max_operations = max_operations
         @operations = 0
         @trace = nil)
      end

      def start
        @operations = 0
        @trace = ::TracePoint.new(:line) do
          @operations += 1
          if @operations > @max_operations
            (@trace&.disable
             ::Kernel.raise(::Smolagents::InterpreterError, "Operation limit exceeded: #{@max_operations}"))
          end
        end
        @trace.enable
      end

      def stop = @trace&.disable
    end
  end
end
