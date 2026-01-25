require_relative "future_base"

module Smolagents
  module Executors
    # Deferred sub-agent execution with completion tracking.
    #
    # AgentFuture wraps asynchronous sub-agent runs, enabling parallel
    # execution of multiple agents with result aggregation.
    #
    # @example Basic usage
    #   future = AgentFuture.new(
    #     agent: sub_agent,
    #     task: "Research topic X",
    #     context: { parent_id: agent.id }
    #   )
    #   future.execute! # Starts execution in background
    #   result = future.value # Blocks until complete
    #
    # @note Uses underscore-prefixed methods (see FutureBase for rationale)
    # @api private
    class AgentFuture
      include FutureBase

      attr_reader :agent, :task, :context, :started_at, :completed_at

      # @param agent [Agent] The agent to execute
      # @param task [String] Task for the agent
      # @param context [Hash] Execution context (parent_id, etc.)
      # @param timeout [Numeric, nil] Optional timeout in seconds
      def initialize(agent:, task:, context: {}, timeout: nil)
        @agent = agent
        @task = task
        @context = context.freeze
        @timeout = timeout
        @started_at = nil
        @completed_at = nil
        @thread = nil
        @cancelled = false
        @mutex = Mutex.new
        _init_future_state
      end

      # Starts agent execution in a background thread.
      # @return [self]
      def execute!
        @mutex.synchronize do
          return self if @thread || @resolved

          @started_at = Time.now
          @thread = Thread.new { run_agent }
        end
        self
      end

      # Blocks until the agent completes and returns the result.
      # @return [Object] The agent's output
      # @raise [StandardError] If the agent failed
      def value
        _ensure_resolved!
        raise @error if @error

        @result
      end

      # Blocks until complete, returns result or nil on error.
      # @return [Object, nil]
      def value_or_nil
        _ensure_resolved!
        @error ? nil : @result
      end

      # Cancels the execution if still pending.
      # @return [Boolean] True if cancelled, false if already resolved
      def cancel!
        @mutex.synchronize do
          return false if @resolved

          @cancelled = true
          @thread&.kill
          _reject!(CancellationError.new("Agent execution cancelled"))
          @completed_at = Time.now
          true
        end
      end

      # @return [Boolean] True if execution was cancelled
      def cancelled? = @cancelled

      # @return [Boolean] True if execution succeeded
      def success? = @resolved && @error.nil?

      # @return [Boolean] True if execution failed
      def failed? = @resolved && !@error.nil?

      # Execution duration in seconds.
      # @return [Float, nil] Duration or nil if not started
      def duration
        return nil unless @started_at

        (@completed_at || Time.now) - @started_at
      end

      def inspect
        status = if @cancelled
                   "cancelled"
                 elsif @resolved
                   @error ? "failed" : "resolved"
                 elsif @thread
                   "running"
                 else
                   "pending"
                 end
        "#<AgentFuture:#{status} task=#{@task.to_s[0, 30].inspect}>"
      end

      private

      # rubocop:disable Metrics/MethodLength -- thread execution with error handling
      def run_agent
        result = @agent.run(@task)
        @mutex.synchronize do
          return if @cancelled

          _resolve!(result.respond_to?(:output) ? result.output : result)
          @completed_at = Time.now
        end
      rescue StandardError => e
        @mutex.synchronize do
          return if @cancelled

          _reject!(e)
          @completed_at = Time.now
        end
      end
      # rubocop:enable Metrics/MethodLength

      def _ensure_resolved!
        return if @resolved

        @thread&.join(@timeout)
        return if @resolved

        # Timeout occurred
        cancel!
        raise TimeoutError, "Agent execution timed out after #{@timeout}s"
      end
    end

    # Raised when agent execution is cancelled.
    class CancellationError < StandardError; end

    # Raised when agent execution times out.
    class TimeoutError < StandardError; end
  end
end
