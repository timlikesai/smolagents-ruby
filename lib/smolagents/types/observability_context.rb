module Smolagents
  module Types
    # Thread-local context for tracking observability data across agent hierarchies.
    #
    # ObservabilityContext aggregates metrics from parent and child agents:
    # - Token usage (input/output tokens from all model calls)
    # - Step counts (across all agents in hierarchy)
    # - Tool invocations (what tools were called, how often)
    # - Timing (total duration including sub-agents)
    # - Trace IDs (for distributed tracing correlation)
    #
    # The context is propagated via thread-local storage so sub-agents
    # automatically contribute their metrics to the parent.
    #
    # @example Basic usage
    #   ObservabilityContext.with_context(trace_id: "abc123") do
    #     agent.run("task")
    #     # All nested agent calls contribute to this context
    #   end
    #   puts ObservabilityContext.current.total_tokens
    #
    # @example Accessing metrics
    #   ctx = ObservabilityContext.current
    #   ctx.total_tokens.total_tokens  # => 1500
    #   ctx.total_steps                # => 7
    #   ctx.sub_agent_count            # => 2
    #
    class ObservabilityContext
      THREAD_KEY = :smolagents_observability_context

      attr_reader :trace_id, :parent_trace_id, :depth

      def initialize(trace_id: nil, parent_trace_id: nil, depth: 0)
        @trace_id = trace_id || generate_trace_id
        @parent_trace_id = parent_trace_id
        @depth = depth
        @mutex = Mutex.new
        @total_tokens = TokenUsage.zero
        @total_steps = 0
        @sub_agent_runs = []
        @tool_invocations = Hash.new(0)
        @evaluation_results = []
        @start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      # Thread-local current context
      class << self
        def current = Thread.current[THREAD_KEY]

        def with_context(trace_id: nil, parent_trace_id: nil)
          parent = current
          child_depth = parent ? parent.depth + 1 : 0
          child_trace = trace_id || generate_trace_id
          parent_id = parent_trace_id || parent&.trace_id

          ctx = new(trace_id: child_trace, parent_trace_id: parent_id, depth: child_depth)
          Thread.current[THREAD_KEY] = ctx
          yield ctx
        ensure
          # Aggregate child metrics into parent before restoring
          parent&.merge_child(ctx) if parent && ctx
          Thread.current[THREAD_KEY] = parent
        end

        def generate_trace_id = SecureRandom.hex(8)
      end

      # Record token usage from a model call
      def add_tokens(usage)
        return unless usage

        @mutex.synchronize { @total_tokens += usage }
      end

      # Record a step completion
      def record_step(step_number)
        @mutex.synchronize { @total_steps = [@total_steps, step_number].max }
      end

      # Record a tool invocation
      def record_tool_call(tool_name)
        @mutex.synchronize { @tool_invocations[tool_name.to_s] += 1 }
      end

      # Record an evaluation result
      def record_evaluation(result)
        @mutex.synchronize { @evaluation_results << result }
      end

      # Record a sub-agent run completion
      def record_sub_agent(agent_name:, token_usage:, step_count:, duration:, outcome:)
        @mutex.synchronize do
          @sub_agent_runs << {
            agent_name:,
            token_usage:,
            step_count:,
            duration:,
            outcome:,
            timestamp: Time.now.utc.iso8601
          }
        end
      end

      # Merge metrics from a child context (called when child scope exits)
      def merge_child(child)
        return unless child

        @mutex.synchronize do
          @total_tokens += child.total_tokens
          @total_steps += child.total_steps
          child.tool_invocations.each { |k, v| @tool_invocations[k] += v }
          @sub_agent_runs.concat(child.sub_agent_runs)
          @evaluation_results.concat(child.evaluation_results)
        end
      end

      # Accessors for aggregated metrics
      def total_tokens
        @mutex.synchronize { @total_tokens }
      end

      def total_steps
        @mutex.synchronize { @total_steps }
      end

      def tool_invocations
        @mutex.synchronize { @tool_invocations.dup }
      end

      def sub_agent_runs
        @mutex.synchronize { @sub_agent_runs.dup }
      end

      def sub_agent_count
        @mutex.synchronize { @sub_agent_runs.size }
      end

      def evaluation_results
        @mutex.synchronize { @evaluation_results.dup }
      end

      def evaluation_count
        @mutex.synchronize { @evaluation_results.size }
      end

      def goal_achieved_by_evaluation?
        @mutex.synchronize { @evaluation_results.any? { |r| r.respond_to?(:goal_achieved?) && r.goal_achieved? } }
      end

      def elapsed_time
        Process.clock_gettime(Process::CLOCK_MONOTONIC) - @start_time
      end

      # Full summary for logging/debugging
      def to_h
        @mutex.synchronize do
          {
            trace_id:,
            parent_trace_id:,
            depth:,
            total_tokens: @total_tokens.to_h,
            total_steps: @total_steps,
            tool_invocations: @tool_invocations.dup,
            sub_agent_count: @sub_agent_runs.size,
            evaluation_count: @evaluation_results.size,
            elapsed_time: elapsed_time.round(3)
          }
        end
      end

      private

      def generate_trace_id = self.class.generate_trace_id
    end
  end
end
