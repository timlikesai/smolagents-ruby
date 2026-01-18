module Smolagents
  module Concerns
    # Backoff calculation strategies for retry intervals.
    #
    # Supports exponential, linear, and constant backoff strategies
    # with optional jitter to prevent thundering herd problems.
    #
    # @example Calculating backoff
    #   RetryPolicyBackoff.interval_for(attempt: 2, strategy: :exponential, base: 1.0, max: 30.0)
    #   #=> 4.0  (1.0 * 2^2)
    module RetryPolicyBackoff
      # Backoff strategy multipliers
      STRATEGIES = {
        exponential: 2.0,
        linear: 1.5,
        constant: 1.0
      }.freeze

      class << self
        # Documents methods provided by this module.
        # @return [Hash<Symbol, String>] Method name to description mapping
        def provided_methods
          {
            multiplier_for: "Get multiplier for a backoff strategy",
            interval_for: "Calculate backoff interval with jitter",
            add_jitter: "Add randomness to prevent thundering herd"
          }
        end

        # Get the multiplier for a backoff strategy.
        #
        # @param strategy [Symbol] :exponential, :linear, or :constant
        # @return [Float] Multiplier value
        def multiplier_for(strategy)
          STRATEGIES.fetch(strategy, 1.0)
        end

        # Calculate backoff interval for a given retry attempt.
        #
        # @param attempt [Integer] Retry attempt number (0-indexed)
        # @param strategy [Symbol] Backoff strategy
        # @param base [Float] Base interval in seconds
        # @param max [Float] Maximum interval cap
        # @param jitter [Float, nil] Jitter range (nil to disable)
        # @return [Float] Calculated interval in seconds
        def interval_for(attempt:, strategy:, base:, max:, jitter: nil)
          multiplier = multiplier_for(strategy)
          raw = base * (multiplier**attempt)
          capped = [raw, max].min
          jitter ? add_jitter(capped, jitter) : capped
        end

        # Add randomness to an interval to prevent thundering herd.
        #
        # @param interval [Float] Base interval
        # @param jitter_range [Float] Maximum jitter to add
        # @return [Float] Interval with jitter applied
        def add_jitter(interval, jitter_range)
          interval + rand(0.0..jitter_range)
        end
      end
    end
  end
end
