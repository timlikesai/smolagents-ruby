# frozen_string_literal: true

module Smolagents
  module Concerns
    # Retry logic with exponential backoff for API calls.
    # Provides a clean Ruby interface for handling transient failures.
    #
    # @example Basic retry
    #   class MyModel < Model
    #     include Concerns::Retryable
    #
    #     def generate(messages, **kwargs)
    #       with_retry(max_attempts: 3) do
    #         api_call(messages)
    #       end
    #     end
    #   end
    #
    # @example Custom error handling
    #   with_retry(
    #     max_attempts: 5,
    #     base_delay: 2.0,
    #     max_delay: 60.0,
    #     jitter: true,
    #     on: [Faraday::ConnectionFailed, Faraday::TimeoutError]
    #   ) do
    #     risky_operation
    #   end
    module Retryable
      # Default retry configuration
      DEFAULT_MAX_ATTEMPTS = 3
      DEFAULT_BASE_DELAY = 1.0
      DEFAULT_MAX_DELAY = 60.0
      DEFAULT_EXPONENTIAL_BASE = 2
      DEFAULT_JITTER = true

      # Execute a block with retry logic.
      #
      # @param max_attempts [Integer] maximum number of attempts
      # @param base_delay [Float] initial delay in seconds
      # @param max_delay [Float] maximum delay in seconds
      # @param exponential_base [Integer] base for exponential backoff
      # @param jitter [Boolean] add random jitter to delays
      # @param on [Array<Class>] exception classes to retry on (default: StandardError)
      # @yield block to execute with retry
      # @return [Object] result of the block
      # @raise [Exception] if all retry attempts fail
      def with_retry(
        max_attempts: DEFAULT_MAX_ATTEMPTS,
        base_delay: DEFAULT_BASE_DELAY,
        max_delay: DEFAULT_MAX_DELAY,
        exponential_base: DEFAULT_EXPONENTIAL_BASE,
        jitter: DEFAULT_JITTER,
        on: [StandardError]
      )
        attempts = 0
        last_error = nil

        loop do
          attempts += 1

          begin
            return yield
          rescue *on => e
            last_error = e

            raise e if attempts >= max_attempts

            delay = calculate_delay(
              attempt: attempts,
              base: base_delay,
              max: max_delay,
              exponential_base: exponential_base,
              jitter: jitter
            )

            logger&.warn("Attempt #{attempts}/#{max_attempts} failed: #{e.message}. Retrying in #{delay.round(2)}s...")
            sleep(delay)
          end
        end
      end

      private

      # Calculate delay with exponential backoff and optional jitter.
      #
      # @param attempt [Integer] current attempt number
      # @param base [Float] base delay
      # @param max [Float] maximum delay
      # @param exponential_base [Integer] exponential base
      # @param jitter [Boolean] add jitter
      # @return [Float] calculated delay in seconds
      def calculate_delay(attempt:, base:, max:, exponential_base:, jitter:)
        delay = base * (exponential_base**(attempt - 1))
        delay = [delay, max].min

        if jitter
          # Add random jitter between 0% and 25% of delay
          jitter_amount = delay * rand(0.0..0.25)
          delay += jitter_amount
        end

        delay
      end

      # Get logger if available (agents/models might have one).
      #
      # @return [Logger, nil]
      def logger
        @logger if defined?(@logger)
      end
    end
  end
end
