# frozen_string_literal: true

module Smolagents
  # Unified code executor with automatic language detection and validation.
  class CodeExecutor
    SUPPORTED_LANGUAGES = Set.new(%i[ruby python javascript typescript]).freeze

    VALIDATORS = {
      ruby: -> { RubyValidator.new },
      python: -> { PythonValidator.new },
      javascript: -> { JavaScriptValidator.new },
      typescript: -> { JavaScriptValidator.new }
    }.freeze

    def initialize(use_docker: false, validate: true, validators: {}, executors: {})
      @use_docker = use_docker
      @validate = validate
      @custom_validators = validators
      @custom_executors = executors
      @validators = {}
      @executors = {}
      @tools = {}
      @variables = {}
    end

    def execute(code, language:, timeout: 5, memory_mb: 256, **)
      language_sym = language.to_sym
      raise ArgumentError, "Unsupported language: #{language_sym}" unless supports?(language_sym)

      if @validate
        begin
          validator_for(language_sym).validate!(code)
        rescue InterpreterError => e
          return Executor::ExecutionResult.new(output: nil, logs: "", error: e.message, is_final_answer: false)
        end
      end

      executor_for(language_sym).execute(code, language: language_sym, timeout: timeout, memory_mb: memory_mb, **)
    end

    def send_tools(tools)
      @tools = tools
      @executors.each_value { |e| e.send_tools(tools) }
    end

    def send_variables(variables)
      @variables = variables
      @executors.each_value { |e| e.send_variables(variables) }
    end

    def supports?(language) = SUPPORTED_LANGUAGES.include?(language.to_sym)
    def validator_for(language) = @validators[language] ||= create_validator(language)
    def executor_for(language) = @executors[language] ||= create_executor(language)

    private

    def create_validator(language)
      @custom_validators[language] || VALIDATORS[language]&.call || raise(ArgumentError, "No validator for: #{language}")
    end

    def create_executor(language)
      executor = @custom_executors[language] || (@use_docker || language != :ruby ? DockerExecutor.new : LocalRubyExecutor.new)
      executor.send_tools(@tools)
      executor.send_variables(@variables)
      executor
    end
  end
end
