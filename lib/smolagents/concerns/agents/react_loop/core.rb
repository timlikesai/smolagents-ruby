require_relative "setup"
require_relative "run_entry"
require_relative "fiber_execution"
require_relative "fiber_consumption"

module Smolagents
  module Concerns
    module ReActLoop
      # Agent setup, run entry points, and memory access.
      #
      # Core is a composition of focused concerns that together provide:
      #
      # - {Setup} - Agent initialization and configuration
      # - {RunEntry} - Main `run` entry point with instrumentation
      # - {FiberExecution} - Fiber-based execution via `run_fiber`
      # - {FiberConsumption} - Consuming fibers in sync/stream modes
      #
      # == Lifecycle
      #
      # 1. Agent includes {ReActLoop} (which includes Core)
      # 2. Agent calls {Setup#setup_agent} with configuration
      # 3. User calls {RunEntry#run} or {FiberExecution#run_fiber} to execute tasks
      # 4. Core delegates to {Execution} for the main loop
      #
      # @example Setup in a custom agent with SetupConfig
      #   class MyAgent
      #     include Concerns::ReActLoop
      #
      #     def initialize(model:, tools:)
      #       config = Types::SetupConfig.create(model:, tools:, max_steps: 10)
      #       setup_agent(config)
      #     end
      #   end
      #
      # @see Setup For initialization
      # @see RunEntry For the `run` method
      # @see FiberExecution For the `run_fiber` method
      # @see Execution For the main loop implementation
      module Core
        def self.included(base)
          base.include(Setup)
          base.include(RunEntry)
          base.include(FiberExecution)
          base.include(FiberConsumption)
        end
      end
    end
  end
end
