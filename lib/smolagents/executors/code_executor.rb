# frozen_string_literal: true

module Smolagents
  # Unified code executor with automatic language detection and validation.
  # Provides high-level API for executing code in multiple languages.
  #
  # Automatically selects:
  # - Appropriate executor (Local for Ruby, Docker for others)
  # - Appropriate validator based on language
  #
  # @example Basic usage
  #   executor = CodeExecutor.new
  #   result = executor.execute("puts 2 + 2", language: :ruby)
  #   puts result.output # => 4
  #
  # @example With Docker for all languages
  #   executor = CodeExecutor.new(use_docker: true)
  #   result = executor.execute("print(2 + 2)", language: :python)
  #
  # @example Disable validation (not recommended)
  #   executor = CodeExecutor.new(validate: false)
  class CodeExecutor
    # Supported languages.
    SUPPORTED_LANGUAGES = Set.new(%i[ruby python javascript typescript]).freeze

    # @param use_docker [Boolean] use Docker for all languages (default: false for Ruby, true for others)
    # @param validate [Boolean] validate code before execution (default: true)
    # @param validators [Hash<Symbol, Validator>] custom validators per language
    # @param executors [Hash<Symbol, Executor>] custom executors per language
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

    # Execute code in specified language.
    #
    # @param code [String] code to execute
    # @param language [Symbol, String] language (:ruby, :python, :javascript, :typescript)
    # @param timeout [Integer] execution timeout in seconds
    # @param memory_mb [Integer] memory limit in MB
    # @param options [Hash] additional executor-specific options
    # @return [Executor::ExecutionResult]
    #
    # @raise [ArgumentError] if language not supported
    def execute(code, language:, timeout: 5, memory_mb: 256, **options)
      language_sym = language.to_sym
      validate_language!(language_sym)

      # Validate code if enabled
      if @validate
        validator = validator_for(language_sym)
        begin
          validator.validate!(code)
        rescue InterpreterError => e
          # Return validation error as ExecutionResult
          return Executor::ExecutionResult.new(
            output: nil,
            logs: "",
            error: e.message,
            is_final_answer: false
          )
        end
      end

      # Execute code
      executor = executor_for(language_sym)
      executor.execute(code, language: language_sym, timeout: timeout, memory_mb: memory_mb, **options)
    end

    # Send tools to executor environments.
    #
    # @param tools [Hash<String, Tool>] tools to make available
    # @return [void]
    def send_tools(tools)
      @tools = tools
      # Send to all existing executors
      @executors.each_value { |executor| executor.send_tools(tools) }
    end

    # Send variables to executor environments.
    #
    # @param variables [Hash] variables to make available
    # @return [void]
    def send_variables(variables)
      @variables = variables
      # Send to all existing executors
      @executors.each_value { |executor| executor.send_variables(variables) }
    end

    # Check if language is supported.
    #
    # @param language [Symbol, String] language to check
    # @return [Boolean]
    def supports?(language)
      SUPPORTED_LANGUAGES.include?(language.to_sym)
    end

    # Get or create validator for language.
    #
    # @param language [Symbol] language
    # @return [Validator]
    def validator_for(language)
      @validators[language] ||= create_validator(language)
    end

    # Get or create executor for language.
    #
    # @param language [Symbol] language
    # @return [Executor]
    def executor_for(language)
      @executors[language] ||= create_executor(language)
    end

    private

    # Validate language is supported.
    #
    # @param language [Symbol] language
    # @raise [ArgumentError] if not supported
    def validate_language!(language)
      unless supports?(language)
        raise ArgumentError, "Unsupported language: #{language}. Supported: #{SUPPORTED_LANGUAGES.to_a.join(', ')}"
      end
    end

    # Create validator for language.
    #
    # @param language [Symbol] language
    # @return [Validator]
    def create_validator(language)
      return @custom_validators[language] if @custom_validators.key?(language)

      case language
      when :ruby
        RubyValidator.new
      when :python
        PythonValidator.new
      when :javascript, :typescript
        JavaScriptValidator.new
      else
        raise ArgumentError, "No validator for language: #{language}"
      end
    end

    # Create executor for language.
    #
    # @param language [Symbol] language
    # @return [Executor]
    def create_executor(language)
      return @custom_executors[language] if @custom_executors.key?(language)

      executor = if @use_docker || language != :ruby
                   DockerExecutor.new
                 else
                   LocalRubyExecutor.new
                 end

      # Send existing tools/variables
      executor.send_tools(@tools)
      executor.send_variables(@variables)
      executor
    end
  end
end
