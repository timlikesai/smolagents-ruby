module Smolagents
  class Executor
    include Concerns::RubySafety

    DEFAULT_MAX_OPERATIONS = 100_000
    DEFAULT_MAX_OUTPUT_LENGTH = 50_000

    ExecutionResult = Data.define(:output, :logs, :error, :is_final_answer) do
      def initialize(output: nil, logs: "", error: nil, is_final_answer: false) = super
      def self.success(output:, logs: "", is_final_answer: false) = new(output:, logs:, error: nil, is_final_answer:)
      def self.failure(error:, logs: "") = new(output: nil, logs:, error:, is_final_answer: false)
      def success? = error.nil?
      def failure? = !success?
    end

    def initialize(max_operations: DEFAULT_MAX_OPERATIONS, max_output_length: DEFAULT_MAX_OUTPUT_LENGTH)
      @max_operations = max_operations
      @max_output_length = max_output_length
      @tools = {}
      @variables = {}
    end

    def execute(_code, language:, timeout: 5, memory_mb: 256, **_options)
      raise NotImplementedError, "#{self.class} must implement #execute"
    end

    def supports?(_language)
      raise NotImplementedError, "#{self.class} must implement #supports?"
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

    protected

    attr_reader :tools, :variables, :max_operations, :max_output_length

    def validate_execution_params!(code, language)
      raise ArgumentError, "Code cannot be empty" if code.to_s.empty?
      raise ArgumentError, "Language not supported: #{language}" unless supports?(language)
    end

    def validate_execution_params(code, language)
      code && !code.to_s.empty? && supports?(language)
    end
    alias valid_execution_params? validate_execution_params

    def build_result(output, logs, error: nil, is_final: false)
      ExecutionResult.new(
        output: output,
        logs: logs.to_s.byteslice(0, @max_output_length) || "",
        error: error,
        is_final_answer: is_final
      )
    end
  end

  module Executors
    autoload :Ruby, "smolagents/executors/ruby"
    autoload :Docker, "smolagents/executors/docker"
  end
end
