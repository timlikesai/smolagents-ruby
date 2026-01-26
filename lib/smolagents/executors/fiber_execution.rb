require_relative "tool_future"
require_relative "../types/executors/fiber_execution_types"

module Smolagents
  module Executors
    # Fiber-based execution with lazy tool evaluation and automatic parallelization.
    #
    # This is THE execution model. Agent code runs in a Fiber. Tool calls return
    # ToolFutures immediately. When results are accessed, all pending futures
    # are batched and executed in parallel.
    #
    # == Architecture
    #
    #   Agent Code (in Fiber)              Orchestrator
    #   ─────────────────────────────      ────────────────────────
    #   ruby = search(query: "Ruby")       # Returns ToolFuture (instant)
    #   python = search(query: "Python")   # Returns ToolFuture (instant)
    #
    #   ruby.first['title']                # ACCESS triggers batch!
    #      │
    #      └──── Fiber.yield(BatchYield) ──►  Run both in parallel
    #                                          Observe results
    #      ◄──── resume ────────────────────   Futures resolved
    #
    #   final_answer(answer: combined)
    #      │
    #      └──── Fiber.yield(BatchYield) ──►  Complete task
    #
    # == Why This Matters
    #
    # 1. **Automatic parallelization**: Multiple tool calls batch automatically
    # 2. **Observation before continuation**: Orchestrator sees results first
    # 3. **Natural code**: Agents write `var = tool()` without async keywords
    #
    # == Tools Are Everything
    #
    # - Search tools → futures that batch
    # - Subagents → futures (they're just tools!)
    # - final_answer → triggers resolution, completes task
    #
    module FiberExecution
      # Check if we're inside fiber-based execution.
      #
      # Tools use this to know whether to yield or return directly.
      def self.in_fiber? = Thread.current[:smolagents_in_code_fiber] == true

      # Called by tools to yield control back to the orchestrator.
      #
      # @param tool_name [String] Name of the tool
      # @param arguments [Hash] Arguments passed to tool
      # @param result [Object] Tool's return value
      # @param duration [Float] Execution time in seconds
      # @return [Object] The result (passed through for code to use)
      def self.yield_tool(tool_name:, arguments:, result:, duration:)
        return result unless in_fiber?

        Fiber.yield(ToolYield.new(tool_name:, arguments:, result:, duration:))
        result
      end
    end
  end
end
