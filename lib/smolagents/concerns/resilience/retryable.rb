module Smolagents
  module Concerns
    # Immediate retry without sleeping.
    #
    # Retries failed operations immediately up to max_attempts times.
    # NO SLEEP. NO TIMEOUT. Just immediate retries.
    #
    # @example Basic retry
    #   with_retry(on: [Faraday::Error], tries: 3) do
    #     api_call
    #   end
    #
    module Retryable
      # Retry a block immediately on specified errors.
      #
      # @param on [Array<Class>] Error classes to retry on
      # @param tries [Integer] Maximum attempts (default: 3)
      # @yield Block to execute
      # @return [Object] Result of the block
      # @raise [StandardError] Last error if all retries fail
      def with_retry(on:, tries: 3)
        attempt = 0
        begin
          attempt += 1
          yield
        rescue *on => e
          raise e if attempt >= tries

          retry
        end
      end
    end
  end
end
