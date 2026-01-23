require_relative "executors/executor"
require_relative "executors/ractor"

module Smolagents
  # Code execution environment for running agent-generated code.
  #
  # All agent code runs in a single Ractor instance that maintains state
  # across the agent's lifecycle. This provides:
  #
  # - **Memory isolation** - Code runs in a separate Ractor with no shared state
  # - **State persistence** - Instance variables persist between code blocks
  # - **Resumability** - The Ractor can be paused and resumed
  # - **Tool batching** - Multiple tool calls are automatically batched
  #
  # == Architecture
  #
  # The Ractor executor spawns a long-running Ractor that:
  # 1. Receives code blocks to execute
  # 2. Maintains a persistent context (instance variables, state)
  # 3. Yields tool calls back to the orchestrator via message passing
  # 4. Returns results via a port
  #
  # This is THE execution model. All agent code flows through here.
  #
  # @example Basic execution
  #   executor = Smolagents::RactorExecutor.new
  #   result = executor.execute("[1, 2, 3].sum", language: :ruby)
  #   result.output  #=> 6
  #
  # @example With tool registration
  #   executor = Smolagents::RactorExecutor.new
  #   executor.send_tools(search: search_tool, fetch: fetch_tool)
  #   result = executor.execute('@data = search(query: "Ruby")', language: :ruby)
  #
  # @example State persistence across executions
  #   executor.execute('@count = 0', language: :ruby)
  #   executor.execute('@count += 1', language: :ruby)
  #   executor.execute('@count', language: :ruby).output  #=> 2
  #
  # @see Executor Base class defining the executor interface
  # @see Ractor The Ractor-based executor implementation
  module Executors
  end

  # Re-exports for convenience.
  Executor = Executors::Executor
  RactorExecutor = Executors::Ractor
end
