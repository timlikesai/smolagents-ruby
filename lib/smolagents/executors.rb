require_relative "executors/executor"
require_relative "executors/ruby"
require_relative "executors/ractor"

module Smolagents
  # Code execution environments for running agent-generated code.
  #
  # Provides sandboxed code execution for LLM-generated Ruby code with two
  # execution strategies optimized for different security/performance trade-offs.
  #
  # == Available Executors
  #
  # - {LocalRuby} - Fast, single-threaded execution with BasicObject sandbox
  # - {Ractor} - Full memory isolation with message-passing for tools
  #
  # == Choosing an Executor
  #
  # | Executor   | Isolation   | Overhead | Tool Support | Use Case                    |
  # |------------|-------------|----------|--------------|------------------------------|
  # | LocalRuby  | BasicObject | ~0ms     | In-process   | Trusted/simple code          |
  # | Ractor     | Full memory | ~20ms    | Message IPC  | Untrusted LLM-generated code |
  #
  # Both executors share a common interface defined by {Executor}:
  # - `execute(code, language:)` - Run code and return {ExecutionResult}
  # - `supports?(language)` - Check if language is supported (Ruby only)
  # - `send_tools(tools)` - Register callable tools
  # - `send_variables(variables)` - Register accessible variables
  #
  # @example Using LocalRuby (fast, less isolated)
  #   executor = Smolagents::Executors::LocalRuby.new(max_operations: 10_000)
  #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
  #   result.output  #=> 6
  #
  # @example Using Ractor (slower, full isolation)
  #   executor = Smolagents::Executors::Ractor.new
  #   executor.send_tools("search" => search_tool)
  #   result = executor.execute('search(query: "Ruby 4.0")', language: :ruby)
  #
  # @see Executor Base class defining the executor interface
  # @see LocalRuby Fast local execution with BasicObject sandbox
  # @see Ractor Memory-isolated execution with message-passing
  module Executors
  end

  # Re-exports for convenience.
  Executor = Executors::Executor
  LocalRubyExecutor = Executors::LocalRuby
  RactorExecutor = Executors::Ractor
end
