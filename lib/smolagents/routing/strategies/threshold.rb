module Smolagents
  module Routing
    module Strategies
      # Threshold-based routing strategy (default behavior).
      #
      # Routes based on confidence score thresholds:
      # - High confidence (>= high_threshold): execute directly
      # - Medium confidence (>= low_threshold): validate with primary
      # - Low confidence (< low_threshold): delegate to primary
      #
      # @example Basic usage
      #   strategy = Threshold.new(high_threshold: 0.8, low_threshold: 0.5)
      #   decision = strategy.route(prediction, context)
      #
      # @example Custom thresholds
      #   # Aggressive - trust dispatcher more
      #   aggressive = Threshold.new(high_threshold: 0.6, low_threshold: 0.3)
      #
      #   # Conservative - validate more often
      #   conservative = Threshold.new(high_threshold: 0.9, low_threshold: 0.7)
      #
      class Threshold
        include RoutingStrategy

        def self.strategy_name = :threshold

        attr_reader :high_threshold, :low_threshold

        # @param high_threshold [Float] Threshold for direct execution (default 0.8)
        # @param low_threshold [Float] Threshold below which to delegate (default 0.5)
        def initialize(high_threshold: 0.8, low_threshold: 0.5)
          @high_threshold = high_threshold
          @low_threshold = low_threshold
        end

        # Routes based on confidence thresholds.
        #
        # @param prediction [SpeculativeToolCall] The tool call to route
        # @param _context [Hash] Routing context (unused by this strategy)
        # @return [Symbol] :execute_directly, :validate_with_primary, or :delegate_to_primary
        def route(prediction, _context = {})
          confidence = prediction.confidence

          if confidence >= high_threshold
            :execute_directly
          elsif confidence >= low_threshold
            :validate_with_primary
          else
            :delegate_to_primary
          end
        end
      end
    end
  end
end
