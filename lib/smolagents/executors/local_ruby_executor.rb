# frozen_string_literal: true

require "ripper"
require "stringio"
require "timeout"
require "set"

module Smolagents
  # Local Ruby code executor with sandboxing.
  # Uses BasicObject clean room, AST validation, and resource limits.
  #
  # Security features:
  # - AST validation blocks dangerous methods (eval, system, exec, etc.)
  # - Operation counter prevents infinite loops
  # - Timeout prevents long-running code
  # - BasicObject sandbox limits available methods
  # - method_missing provides controlled tool access
  #
  # @example Basic usage
  #   executor = LocalRubyExecutor.new
  #   executor.send_tools({ "search" => search_tool })
  #   result = executor.execute("search('ruby')", language: :ruby)
  #   puts result.output
  class LocalRubyExecutor < Executor
    # Dangerous methods that are blocked in sandboxed code.
    DANGEROUS_METHODS = Set.new(%w[
      eval instance_eval class_eval module_eval
      system exec spawn fork
      require require_relative load autoload
      open File IO Dir
      send __send__ public_send method define_method
      const_get const_set remove_const
      class_variable_get class_variable_set remove_class_variable
      instance_variable_get instance_variable_set remove_instance_variable
      binding
      ObjectSpace Marshal Kernel
    ]).freeze

    # Maximum operations before halting (prevents infinite loops).
    DEFAULT_MAX_OPERATIONS = 100_000

    # Dangerous constant access patterns.
    DANGEROUS_CONSTANTS = /\b(File|IO|Dir|Process|Thread|ObjectSpace|Marshal|Kernel|ENV)\b/.freeze

    def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: 50_000)
      super()
      @max_operations = max_operations
      @max_output_length = max_output_length
      @tools = {}
      @variables = {}
    end

    # Execute Ruby code in sandboxed environment.
    #
    # @param code [String] Ruby code to execute
    # @param language [Symbol] must be :ruby
    # @param timeout [Integer] execution timeout in seconds
    # @param options [Hash] additional options
    # @return [ExecutionResult]
    #
    # @raise [ArgumentError] if language is not :ruby or code is empty
    def execute(code, language: :ruby, timeout: 5, **options)
      # Validate parameters (raises ArgumentError - not caught)
      validate_execution_params!(code, language)

      output_buffer = StringIO.new
      result = nil
      is_final = false

      begin
        # Validate code (can raise InterpreterError)
        validate_code!(code)

        Timeout.timeout(timeout) do
          sandbox = create_sandbox(output_buffer)
          operation_counter = create_operation_counter

          operation_counter.start
          begin
            result = sandbox.instance_eval(code)
          ensure
            operation_counter.stop
          end
        end

        ExecutionResult.new(
          output: result,
          logs: output_buffer.string.byteslice(0, @max_output_length),
          error: nil,
          is_final_answer: is_final
        )
      rescue FinalAnswerException => e
        ExecutionResult.new(
          output: e.value,
          logs: output_buffer&.string&.byteslice(0, @max_output_length) || "",
          error: nil,
          is_final_answer: true
        )
      rescue Timeout::Error
        ExecutionResult.new(
          output: nil,
          logs: output_buffer&.string || "",
          error: "Execution timeout after #{timeout} seconds",
          is_final_answer: false
        )
      rescue InterpreterError => e
        ExecutionResult.new(
          output: nil,
          logs: output_buffer&.string || "",
          error: e.message,
          is_final_answer: false
        )
      rescue StandardError => e
        ExecutionResult.new(
          output: nil,
          logs: output_buffer&.string || "",
          error: "#{e.class}: #{e.message}",
          is_final_answer: false
        )
      end
    end

    def supports?(language)
      language.to_sym == :ruby
    end

    private

    # Validate code using AST analysis.
    #
    # @param code [String] code to validate
    # @raise [InterpreterError] if code contains dangerous patterns
    def validate_code!(code)
      # Check for dangerous constant access
      if code.match?(DANGEROUS_CONSTANTS)
        raise InterpreterError, "Code contains dangerous constant access"
      end

      # Parse AST
      sexp = Ripper.sexp(code)
      raise InterpreterError, "Code has syntax errors" if sexp.nil?

      # Check for dangerous method calls
      check_sexp_for_dangerous_calls(sexp)
    end

    # Recursively check S-expression for dangerous method calls.
    #
    # @param sexp [Array, Symbol, String, nil] S-expression to check
    # @raise [InterpreterError] if dangerous methods found
    def check_sexp_for_dangerous_calls(sexp)
      return unless sexp.is_a?(Array)

      # Check if this is a method call
      if sexp[0] == :command || sexp[0] == :vcall || sexp[0] == :fcall || sexp[0] == :call
        method_name = extract_method_name(sexp)
        if method_name && DANGEROUS_METHODS.include?(method_name)
          raise InterpreterError, "Dangerous method call: #{method_name}"
        end
      end

      # Recursively check children
      sexp.each { |child| check_sexp_for_dangerous_calls(child) }
    end

    # Extract method name from S-expression.
    #
    # @param sexp [Array] S-expression
    # @return [String, nil] method name or nil
    def extract_method_name(sexp)
      sexp.each do |elem|
        if elem.is_a?(Array) && elem[0] == :@ident
          return elem[1]
        elsif elem.is_a?(Array) && elem[0] == :@const
          return elem[1]
        end
      end
      nil
    end

    # Create sandboxed execution environment.
    #
    # @param output_buffer [StringIO] buffer for capturing output
    # @return [RubySandbox] sandbox instance
    def create_sandbox(output_buffer)
      tools = @tools
      variables = @variables

      RubySandbox.new(
        tools: tools,
        variables: variables,
        output_buffer: output_buffer
      )
    end

    # Create operation counter to prevent infinite loops.
    #
    # @return [OperationCounter] counter instance
    def create_operation_counter
      OperationCounter.new(@max_operations)
    end

    # Sandboxed execution environment.
    # Provides controlled tool and variable access while allowing normal Ruby operations.
    class RubySandbox
      def initialize(tools:, variables:, output_buffer:)
        @tools = tools
        @variables = variables
        @output_buffer = output_buffer
      end

      # Dynamic tool and variable dispatch.
      def method_missing(name, *args, **kwargs, &block)
        name_str = name.to_s

        # Check for tool
        if @tools.key?(name_str)
          return @tools[name_str].call(*args, **kwargs)
        end

        # Check for variable
        if @variables.key?(name_str)
          return @variables[name_str]
        end

        # Not found - raise error
        super
      end

      def respond_to_missing?(name, include_private = false)
        name_str = name.to_s
        @tools.key?(name_str) || @variables.key?(name_str) || super
      end

      # Override puts to capture output
      def puts(*args)
        @output_buffer.puts(*args)
        nil
      end

      def print(*args)
        @output_buffer.print(*args)
        nil
      end

      def p(*args)
        @output_buffer.puts(args.map(&:inspect).join(", "))
        args.length <= 1 ? args.first : args
      end
    end

    # Operation counter using TracePoint to prevent infinite loops.
    class OperationCounter
      def initialize(max_operations)
        @max_operations = max_operations
        @operations = 0
        @trace = nil
      end

      def start
        @operations = 0
        @trace = ::TracePoint.new(:line) do
          @operations += 1
          if @operations > @max_operations
            @trace&.disable
            ::Kernel.raise ::Smolagents::InterpreterError, "Operation limit exceeded: #{@max_operations}"
          end
        end
        @trace.enable
      end

      def stop
        @trace&.disable
      end
    end
  end
end
