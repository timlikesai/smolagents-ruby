require_relative "executors/executor"
require_relative "executors/ruby"
require_relative "executors/docker"
require_relative "executors/ractor"

module Smolagents
  # Code execution environments for running agent-generated code.
  #
  # The Executors module contains all executor implementations that provide
  # sandboxed code execution for agents. Each executor handles a specific
  # execution context with appropriate security measures.
  #
  # Available executors:
  # - {LocalRuby} - Local Ruby execution with BasicObject sandbox
  # - {Docker} - Multi-language execution in Docker containers
  # - {Ractor} - Ruby 3.0+ Ractor-based parallel execution
  #
  # All executors share a common interface defined by {Executor} base class:
  # - `execute(code, language:, timeout:)` - Run code and return {Executor::ExecutionResult}
  # - `supports?(language)` - Check if language is supported
  # - `send_tools(tools)` - Register callable tools
  # - `send_variables(variables)` - Register accessible variables
  #
  # @example Using LocalRuby executor
  #   executor = Smolagents::Executors::LocalRuby.new(max_operations: 10_000)
  #   executor.send_tools("search" => search_tool)
  #   result = executor.execute("search(query: 'Ruby')", language: :ruby)
  #
  # @example Using backward-compatible aliases
  #   executor = Smolagents::LocalRubyExecutor.new
  #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
  #
  # @see Executor Base class defining the executor interface
  # @see LocalRuby Local Ruby execution with sandbox
  # @see Docker Multi-language Docker container execution
  # @see Ractor Ractor-based parallel execution
  module Executors
  end

  # Backward compatibility re-exports.
  # These allow existing code to use Smolagents::ClassName
  # instead of the full Smolagents::Executors::ClassName path.

  # @!parse
  #   # @deprecated Use {Executors::Executor} instead
  #   Executor = Executors::Executor
  Executor = Executors::Executor

  # @!parse
  #   # @deprecated Use {Executors::LocalRuby} instead
  #   LocalRubyExecutor = Executors::LocalRuby
  LocalRubyExecutor = Executors::LocalRuby

  # @!parse
  #   # @deprecated Use {Executors::Docker} instead
  #   DockerExecutor = Executors::Docker
  DockerExecutor = Executors::Docker

  # @!parse
  #   # @deprecated Use {Executors::Ractor} instead
  #   RactorExecutor = Executors::Ractor
  RactorExecutor = Executors::Ractor
end
