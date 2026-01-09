# frozen_string_literal: true

require_relative "executors/executor"
require_relative "executors/validator"
require_relative "executors/ruby_validator"
require_relative "executors/python_validator"
require_relative "executors/javascript_validator"
require_relative "executors/local_ruby_executor"
require_relative "executors/docker_executor"
require_relative "executors/code_executor"

module Smolagents
  # Executors module provides secure code execution in multiple languages.
  #
  # Available executors:
  # - {LocalRubyExecutor} - Sandboxed Ruby execution
  # - {DockerExecutor} - Multi-language Docker execution
  # - {CodeExecutor} - Unified high-level interface
  #
  # Available validators:
  # - {RubyValidator} - Ruby AST validation
  # - {PythonValidator} - Python pattern validation
  # - {JavaScriptValidator} - JavaScript/TypeScript pattern validation
  #
  # @example Quick start with CodeExecutor
  #   executor = Smolagents::CodeExecutor.new
  #   result = executor.execute("puts 'Hello'", language: :ruby)
  #   puts result.output
  #
  # @example Multi-language execution
  #   executor = Smolagents::CodeExecutor.new
  #   executor.execute("puts 2 + 2", language: :ruby)
  #   executor.execute("print(2 + 2)", language: :python)
  #   executor.execute("console.log(2 + 2)", language: :javascript)
  module Executors
  end
end
