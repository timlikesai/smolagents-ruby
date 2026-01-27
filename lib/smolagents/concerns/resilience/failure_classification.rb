module Smolagents
  module Concerns
    # Unified failure classification for smart recovery decisions.
    #
    # Categories: TRANSIENT (retry with backoff), PERMANENT (no retry),
    # SEMANTIC (alternative approach needed for loops, drift, etc.)
    #
    # @example result = FailureClassification.classify(error); result.retriable?
    # @see Types::RetryPolicy, GoalDrift, ReActLoop::Repetition
    module FailureClassification
      # Classification result with category and strategy.
      ClassificationResult = Data.define(:category, :subcategory, :strategy, :details) do
        def transient? = category == :transient
        def permanent? = category == :permanent
        def semantic? = category == :semantic
        def retriable? = transient?
        def needs_alternative? = semantic?
      end

      # Retry strategies for each failure category.
      STRATEGIES = {
        transient: :exponential_backoff,
        permanent: :no_retry,
        semantic: :alternative_approach,
        unknown: :limited_retry
      }.freeze

      # Transient errors - worth retrying with backoff.
      TRANSIENT_PATTERNS = {
        network_timeout: [Faraday::TimeoutError, /time.*out|timed out/i],
        connection_failed: [Faraday::ConnectionFailed, /connection.*fail/i],
        rate_limit: [RateLimitError, /rate.*limit|429|too many request/i],
        server_error: [Faraday::ServerError, ServiceUnavailableError, /50[0234]|unavailable/i]
      }.freeze

      # Permanent errors - never retry.
      PERMANENT_PATTERNS = {
        auth_failed: [Faraday::UnauthorizedError, /unauthorized|invalid.*key|auth.*fail/i],
        invalid_input: [ArgumentError, AgentConfigurationError, /invalid.*input|validation.*fail/i],
        permission_denied: [/permission.*denied|forbidden|403/i],
        resource_not_found: [/not.*found|404|missing.*resource/i]
      }.freeze

      # Semantic subcategories (detected via result objects, not exceptions).
      SEMANTIC_SUBCATEGORIES =
        %i[loop_detected goal_drift incoherent_response confidence_decay repeated_failure].freeze

      class << self
        # Classify a failure for appropriate recovery strategy.
        #
        # @param failure [Exception, Hash, Object] Error, result hash, or result object
        # @return [ClassificationResult] Classification with category and strategy
        def classify(failure)
          return classify_semantic(failure) if semantic_result?(failure)
          return classify_exception(failure) if failure.is_a?(Exception)

          unknown_result(failure)
        end

        # Check if failure is retriable (transient category).
        #
        # @param failure [Exception, Object] Failure to check
        # @return [Boolean] True if worth retrying
        def retriable?(failure) = classify(failure).retriable?

        # Get retry strategy for a failure.
        #
        # @param failure [Exception, Object] Failure to check
        # @return [Symbol] Strategy (:exponential_backoff, :no_retry, etc.)
        def strategy_for(failure) = classify(failure).strategy

        private

        def semantic_result?(result)
          result.respond_to?(:detected?) || result.respond_to?(:drifting?) ||
            (result.is_a?(Hash) && result[:semantic_failure])
        end

        def classify_semantic(result)
          subcategory = detect_semantic_subcategory(result)
          ClassificationResult.new(
            category: :semantic,
            subcategory:,
            strategy: STRATEGIES[:semantic],
            details: extract_semantic_details(result)
          )
        end

        def detect_semantic_subcategory(result)
          return :loop_detected if result.respond_to?(:detected?) && result.detected?
          return :goal_drift if result.respond_to?(:drifting?) && result.drifting?
          return result[:subcategory] if result.is_a?(Hash) && result[:subcategory]

          :unspecified
        end

        def extract_semantic_details(result)
          return result[:details] if result.is_a?(Hash) && result[:details]
          return result.to_h if result.respond_to?(:to_h)

          { result: result.inspect }
        end

        def classify_exception(error)
          subcategory, category = find_match(error)
          ClassificationResult.new(
            category:,
            subcategory:,
            strategy: STRATEGIES.fetch(category, STRATEGIES[:unknown]),
            details: { error_class: error.class.name, message: error.message[0..200] }
          )
        end

        def find_match(error)
          transient = match_patterns(error, TRANSIENT_PATTERNS)
          return [transient, :transient] if transient

          permanent = match_patterns(error, PERMANENT_PATTERNS)
          return [permanent, :permanent] if permanent

          %i[unknown unknown]
        end

        def match_patterns(error, patterns)
          patterns.each do |subcategory, matchers|
            return subcategory if matchers.any? { |m| matches?(error, m) }
          end
          nil
        end

        def matches?(error, matcher)
          case matcher
          when Class then error.is_a?(matcher)
          when Regexp then error.message =~ matcher
          else false
          end
        end

        def unknown_result(failure)
          ClassificationResult.new(
            category: :unknown,
            subcategory: :unclassified,
            strategy: STRATEGIES[:unknown],
            details: { failure: failure.inspect[0..200] }
          )
        end
      end
    end
  end
end
