require_relative "tool_future"

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
      # Tools that retrieve external data - orchestrator should observe before continuing
      RETRIEVAL_TOOLS = %w[
        search web fetch wikipedia http api query
        duckduckgo google bing searxng
      ].freeze

      # What gets yielded when a tool is called.
      #
      # Contains everything the orchestrator needs to decide what to do next.
      ToolYield = Data.define(:tool_name, :arguments, :result, :duration) do
        # @return [Boolean] True if tool retrieves external data
        def retrieval? = FiberExecution::RETRIEVAL_TOOLS.any? { |t| tool_name.to_s.downcase.include?(t) }

        # @return [Boolean] True if this completes the task
        def final? = tool_name.to_s == "final_answer"

        # @return [Boolean] True if this is a subagent call
        def subagent? = tool_name.to_s.start_with?("agent_") || result.is_a?(RunResult)
      end

      # Execution state after a batch yield or completion.
      ExecutionState = Data.define(:status, :batches, :batch, :output, :error) do
        def self.running(batches,
                         current_batch) = new(status: :running, batches:, batch: current_batch, output: nil, error: nil)

        def self.completed(output, batches) = new(status: :completed, batches:, batch: nil, output:, error: nil)
        def self.failed(error, batches) = new(status: :failed, batches:, batch: nil, output: nil, error:)

        def running? = status == :running
        def completed? = status == :completed
        def failed? = status == :failed

        # All futures from all batches
        def all_futures = batches.flat_map(&:futures)

        # Current batch has retrieval tools?
        def retrieval_batch? = batch&.futures&.any? { |f| retrieval_tool?(f.tool_name) }

        # Current batch has final_answer?
        def final_answer_batch? = batch&.futures&.any? { |f| f.tool_name == "final_answer" }

        private

        def retrieval_tool?(name) = FiberExecution::RETRIEVAL_TOOLS.any? { |t| name.to_s.downcase.include?(t) }
      end

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
