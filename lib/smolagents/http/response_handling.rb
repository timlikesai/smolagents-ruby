require "json"
require "faraday"

module Smolagents
  module Http
    # Response parsing and error handling utilities.
    #
    # Provides methods for parsing HTTP responses and validating HTTP status codes.
    # Raises typed exceptions for different error conditions to enable proper
    # error handling by callers.
    module ResponseHandling
      # HTTP status codes that indicate rate limiting.
      RATE_LIMIT_CODES = [429, 202].freeze

      # HTTP status codes that indicate temporary unavailability.
      UNAVAILABLE_CODES = [503, 502, 504].freeze

      # Parses a JSON response body.
      #
      # @param response [Faraday::Response] The HTTP response
      # @return [Hash, Array] Parsed JSON data
      # @raise [JSON::ParserError] If the response is not valid JSON
      def parse_json_response(response)
        JSON.parse(response.body)
      end

      # Validates HTTP response status and raises appropriate errors.
      #
      # @param response [Faraday::Response] The HTTP response
      # @param url [String] The request URL (for error context)
      # @raise [RateLimitError] If response indicates rate limiting (429, 202)
      # @raise [ServiceUnavailableError] If service is unavailable (502, 503, 504)
      # @raise [HttpError] If response status is not successful (4xx, 5xx)
      def require_success!(response, url: nil)
        status = response.status
        # 202 is ambiguous - DDG uses it for rate limits BUT also sometimes returns results with 202
        # Only treat 202 as rate limit if body looks like an error (short or no result markers)
        if status == 202 && response_has_results?(response.body)
          return # 202 with actual results - treat as success
        end
        # Check for rate limiting codes first (202 is technically "success" but DDG uses it for rate limits)
        return unless !response.success? || RATE_LIMIT_CODES.include?(status)

        status = response.status
        env = response.env
        url ||= env[:url]&.to_s
        http_method = env[:method]

        case status
        when *RATE_LIMIT_CODES
          retry_after = response.headers["retry-after"]&.to_i
          raise RateLimitError.new(
            status_code: status,
            response_body: response.body,
            url:,
            method: http_method,
            retry_after:
          )
        when *UNAVAILABLE_CODES
          raise ServiceUnavailableError.new(
            status_code: status,
            response_body: response.body,
            url:,
            method: http_method
          )
        else
          raise HttpError.new(
            "HTTP #{status}: #{response.body&.slice(0, 200)}",
            status_code: status,
            response_body: response.body,
            url:,
            method: http_method
          )
        end
      end

      # Wraps an HTTP operation, letting errors propagate for proper handling.
      #
      # Unlike previous versions that swallowed errors, this method re-raises
      # HTTP and parsing errors with proper context. Callers should catch
      # specific error types they can handle.
      #
      # @example
      #   safe_api_call do
      #     response = get(url)
      #     require_success!(response)
      #     parse_json_response(response)
      #   end
      #
      # @yield Block containing HTTP operations
      # @return [Object] Result of block
      # @raise [RateLimitError] If rate limited
      # @raise [ServiceUnavailableError] If service unavailable
      # @raise [HttpError] On other HTTP errors
      # @raise [Faraday::TimeoutError] On timeout
      def safe_api_call
        yield
      end

      private

      # Checks if a response body contains actual search results.
      # Used to distinguish DDG 202 with results vs 202 rate limit.
      def response_has_results?(body)
        return false if body.nil? || body.length < 1000

        # DDG HTML results have these markers
        body.include?("result-link") || body.include?("result-snippet")
      end
    end
  end
end
