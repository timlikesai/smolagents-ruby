# frozen_string_literal: true

module Smolagents
  class Executor
    ExecutionResult = Data.define(:output, :logs, :error, :is_final_answer) do
      def initialize(output: nil, logs: "", error: nil, is_final_answer: false) = super
      def success? = error.nil?
      def failure? = !success?
    end

    def execute(code, language:, timeout: 5, memory_mb: 256, **options)
      raise NotImplementedError, "#{self.class} must implement #execute"
    end

    def supports?(language)
      raise NotImplementedError, "#{self.class} must implement #supports?"
    end

    def send_tools(tools) = @tools = tools
    def send_variables(variables) = @variables = variables

    protected

    attr_reader :tools, :variables

    def validate_execution_params!(code, language)
      raise ArgumentError, "Code cannot be empty" if code.nil? || code.empty?
      raise ArgumentError, "Language not supported: #{language}" unless supports?(language)
    end
  end

  module Executors
    autoload :Ruby, "smolagents/executors/ruby"
    autoload :Docker, "smolagents/executors/docker"
  end
end
