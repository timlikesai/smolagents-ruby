module Smolagents
  module Telemetry
    # Tracks API costs for model generations.
    #
    # CostTracker subscribes to :model_generate_completed events and
    # accumulates costs based on token usage. Thread-safe for concurrent
    # agent execution.
    #
    # @example Basic usage
    #   tracker = CostTracker.new
    #   agent.connect_to(tracker)
    #   agent.run("task")
    #   puts tracker.total_cost  # => 0.0042
    #
    # @example Per-model costs
    #   tracker.cost_by_model  # => { "gpt-4" => 0.003, "gpt-3.5-turbo" => 0.0012 }
    #
    class CostTracker
      include Events::Consumer

      # Cost per 1000 tokens (prompt + completion combined for simplicity).
      # Prices are approximate and should be updated based on current rates.
      COST_PER_1K_TOKENS = {
        "gpt-4" => 0.03,
        "gpt-4-turbo" => 0.01,
        "gpt-3.5-turbo" => 0.0015,
        "claude-opus-4-5" => 0.015,
        "claude-sonnet-4-5" => 0.003,
        "claude-haiku-4" => 0.00025,
        :default => 0.01
      }.freeze

      def initialize
        @costs = {}
        @mutex = Mutex.new
        setup_subscriptions
      end

      # Total cost across all models.
      # @return [Float]
      def total_cost
        @mutex.synchronize { @costs.values.sum }
      end

      # Cost breakdown by model.
      # @return [Hash{String => Float}]
      def cost_by_model
        @mutex.synchronize { @costs.dup }
      end

      # Clears all tracked costs.
      # @return [self]
      def reset!
        @mutex.synchronize { @costs.clear }
        self
      end

      private

      def setup_subscriptions
        on(:model_generate_completed) { |e| track_cost(e) }
      end

      def track_cost(event)
        return unless event.token_usage

        tokens = total_tokens(event)
        cost = calculate_cost(event.model_id, tokens)

        @mutex.synchronize do
          @costs[event.model_id] ||= 0.0
          @costs[event.model_id] += cost
        end
      end

      def total_tokens(event)
        usage = event.token_usage
        return 0 unless usage.is_a?(Hash)

        (usage[:prompt_tokens] || 0) + (usage[:completion_tokens] || 0)
      end

      def calculate_cost(model_id, tokens)
        rate = COST_PER_1K_TOKENS[model_id] || COST_PER_1K_TOKENS[:default]
        (tokens / 1000.0) * rate
      end
    end

    # Tracks costs for a single request with finalization.
    #
    # RequestCostTracker is a specialized tracker that records costs
    # for a single request and can produce a final report.
    #
    # @example Request tracking
    #   tracker = RequestCostTracker.new(request_id: "req-123")
    #   agent.connect_to(tracker)
    #   agent.run("task")
    #
    #   report = tracker.finalize
    #   # => { request_id: "req-123", total_cost: 0.042, cost_by_model: {...}, timestamp: ... }
    #
    class RequestCostTracker < CostTracker
      attr_reader :request_id

      def initialize(request_id:)
        @request_id = request_id
        super()
      end

      # Finalizes tracking and returns a report.
      #
      # @return [Hash] Report with request_id, total_cost, cost_by_model, timestamp
      def finalize
        {
          request_id: @request_id,
          total_cost:,
          cost_by_model:,
          timestamp: Time.now.utc.iso8601
        }
      end
    end
  end
end
