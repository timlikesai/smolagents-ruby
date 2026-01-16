require "json"
require "faraday"

module Smolagents
  module Http
    # Response parsing and error handling utilities.
    #
    # Provides methods for parsing HTTP responses and validating HTTP status codes.
    # Raises typed exceptions for different error conditions to enable proper
    # error handling by callers.
    #
    # Includes UTF-8 sanitization to handle malformed responses from external APIs.
    module ResponseHandling
      # Default rate limit status codes. Override rate_limit_codes method for service-specific codes.
      DEFAULT_RATE_LIMIT_CODES = [429].freeze

      # Default unavailable status codes. Override unavailable_codes method for service-specific codes.
      DEFAULT_UNAVAILABLE_CODES = [503, 502, 504].freeze

      # Status codes indicating rate limiting. Override for service-specific behavior.
      def rate_limit_codes = DEFAULT_RATE_LIMIT_CODES

      # Status codes indicating temporary unavailability. Override for service-specific behavior.
      def unavailable_codes = DEFAULT_UNAVAILABLE_CODES

      # Sanitize string to valid UTF-8.
      # Replaces invalid/undefined bytes with replacement character.
      # @param string [String] String to sanitize
      # @return [String] Valid UTF-8 string
      def sanitize_utf8(string)
        return "" if string.nil?

        string.encode("UTF-8", invalid: :replace, undef: :replace, replace: "\uFFFD")
      end

      # Parses a JSON response body.
      # Sanitizes UTF-8 before parsing to handle malformed responses.
      #
      # @param response [Faraday::Response] The HTTP response
      # @return [Hash, Array] Parsed JSON data
      # @raise [JSON::ParserError] If the response is not valid JSON
      def parse_json_response(response)
        JSON.parse(sanitize_utf8(response.body))
      end

      # Validates HTTP response status and raises appropriate errors.
      #
      # @param response [Faraday::Response] The HTTP response
      # @param url [String] The request URL (for error context)
      # @raise [RateLimitError] If response indicates rate limiting (see #rate_limit_codes)
      # @raise [ServiceUnavailableError] If service is unavailable (see #unavailable_codes)
      # @raise [HttpError] If response status is not successful (4xx, 5xx)
      def require_success!(response, url: nil)
        return if successful_response?(response)

        raise_error_for_status(response, url)
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

      # Determines if a response should be treated as successful.
      # Can be overridden by including classes to handle service-specific quirks.
      def successful_response?(response)
        return true if response.success? && !rate_limit_codes.include?(response.status)

        # Hook: allow services to define custom success conditions for ambiguous codes
        ambiguous_response_successful?(response)
      end

      # Hook for services with ambiguous status codes (like 202).
      # Override in tools that need custom success detection.
      # @return [Boolean] Whether the response should be treated as successful
      def ambiguous_response_successful?(_response) = false

      # Raises the appropriate error type based on status code.
      def raise_error_for_status(response, url)
        context = request_context(response, url)
        status = response.status

        if rate_limit_codes.include?(status)
          raise_rate_limit_error(response, context)
        elsif unavailable_codes.include?(status)
          raise_unavailable_error(context)
        else
          raise_http_error(response, context)
        end
      end

      # Extracts common request context from response.
      def request_context(response, url)
        env = response.env
        {
          status_code: response.status,
          response_body: response.body,
          url: url || env[:url]&.to_s,
          method: env[:method]
        }
      end

      # Raises RateLimitError with retry-after header if present.
      def raise_rate_limit_error(response, context)
        retry_after = response.headers["retry-after"]&.to_i
        raise RateLimitError.new(**context, retry_after:)
      end

      # Raises ServiceUnavailableError for 502/503/504.
      def raise_unavailable_error(context)
        raise ServiceUnavailableError.new(**context)
      end

      # Raises generic HttpError with truncated body preview.
      def raise_http_error(response, context)
        message = "HTTP #{response.status}: #{response.body&.slice(0, 200)}"
        raise HttpError.new(message, **context)
      end
    end
  end
end
