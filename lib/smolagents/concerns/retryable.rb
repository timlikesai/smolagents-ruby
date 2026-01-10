# frozen_string_literal: true

module Smolagents
  module Concerns
    # Retry logic with exponential backoff for API calls.
    module Retryable
      DEFAULT_CONFIG = { max_attempts: 3, base_delay: 1.0, max_delay: 60.0, exponential_base: 2, jitter: true }.freeze

      def with_retry(max_attempts: DEFAULT_CONFIG[:max_attempts], base_delay: DEFAULT_CONFIG[:base_delay], max_delay: DEFAULT_CONFIG[:max_delay],
                     exponential_base: DEFAULT_CONFIG[:exponential_base], jitter: DEFAULT_CONFIG[:jitter], on: [StandardError])
        attempts = 0
        loop do
          attempts += 1
          return yield
        rescue *on => e
          raise e if attempts >= max_attempts

          delay = [base_delay * (exponential_base**(attempts - 1)), max_delay].min
          delay += delay * rand(0.0..0.25) if jitter
          logger&.warn("Attempt #{attempts}/#{max_attempts} failed: #{e.message}. Retrying in #{delay.round(2)}s...")
          sleep(delay)
        end
      end

      private

      def calculate_delay(attempt:, base:, max:, exponential_base:, jitter:)
        delay = [base * (exponential_base**(attempt - 1)), max].min
        jitter ? delay + (delay * rand(0.0..0.25)) : delay
      end

      def logger = defined?(@logger) ? @logger : nil
    end
  end
end
