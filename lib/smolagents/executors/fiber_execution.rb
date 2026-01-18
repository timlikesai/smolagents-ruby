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

      # Wraps a code block in a Fiber for incremental execution.
      #
      # @example Running code with automatic batching
      #   fiber = CodeFiber.new(sandbox) { |s| s.instance_eval(code) }
      #
      #   loop do
      #     state = fiber.step
      #     break if state.completed? || state.failed?
      #
      #     # Batch contains all pending tool calls
      #     batch = state.batch
      #     puts "Running #{batch.size} tools in parallel"
      #
      #     # Execute tools in parallel, observe results
      #     results = run_in_parallel(batch.futures)
      #
      #     # Check if we should continue (e.g., retrieval before final_answer)
      #     break if should_pause?(batch, remaining_code)
      #   end
      #
      class CodeFiber
        attr_reader :batches, :state

        def initialize(sandbox, &block)
          @sandbox = sandbox
          @block = block
          @batches = []
          @state = nil
          @fiber = create_fiber
        end

        # Takes one step - runs until next batch yield or completion.
        #
        # @return [ExecutionState] Current state after step
        def step
          return @state if @state&.completed? || @state&.failed?

          result = @fiber.resume
          handle_result(result)
        end

        # @return [Boolean] True if more steps can be taken
        def alive? = @fiber.alive?

        private

        def create_fiber
          Fiber.new do
            FutureBatch.clear!
            result = with_fiber_context { @block.call(@sandbox) }
            # Flush any pending futures (e.g., final_answer that wasn't accessed)
            flush_pending_futures
            result
          rescue FinalAnswerException => e
            { type: :final_answer, value: e.value }
          rescue StandardError => e
            { type: :error, error: e }
          end
        end

        def flush_pending_futures
          pending = FutureBatch.pending
          return if pending.empty?

          # Yield the batch for resolution
          Fiber.yield(BatchYield.new(futures: pending))
        end

        def with_fiber_context
          Thread.current[:smolagents_in_code_fiber] = true
          yield
        ensure
          Thread.current[:smolagents_in_code_fiber] = false
        end

        def handle_result(result)
          case result
          when BatchYield
            @batches << result
            @state = ExecutionState.running(@batches.dup, result)
          when Hash
            handle_completion(result)
          else
            # Normal return value (code completed without final_answer)
            @state = ExecutionState.completed(result, @batches.dup)
          end
        end

        def handle_completion(result)
          @state = case result
                   in { type: :final_answer, value: }
                     ExecutionState.completed(value, @batches.dup)
                   in { type: :error, error: }
                     ExecutionState.failed("#{error.class}: #{error.message}", @batches.dup)
                   else
                     ExecutionState.completed(result, @batches.dup)
                   end
        end
      end

      # Check if we're inside a CodeFiber execution.
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
