require "json"
require "faraday"

module Smolagents
  module Http
    # Response parsing and error handling utilities.
    #
    # Provides methods for parsing HTTP responses and converting HTTP errors
    # to user-friendly messages. Designed to be mixed into HTTP client modules.
    module ResponseHandling
      # Parses a JSON response body, returning error hash on parse failure.
      #
      # @param response [Faraday::Response] The HTTP response
      # @return [Hash, Array] Parsed JSON data, or error hash if parsing fails
      def parse_json_response(response)
        JSON.parse(response.body)
      rescue JSON::ParserError => e
        { error: "JSON parse error: #{e.message}" }
      end

      # Converts HTTP errors to user-friendly messages.
      #
      # @param error [StandardError] The error to handle
      # @return [String] Human-readable error message
      def handle_http_error(error)
        case error
        when Faraday::TimeoutError then "The request timed out. Please try again later."
        else "Error: #{error.message}"
        end
      end

      # Wraps an HTTP operation with standardized error handling.
      #
      # Catches common HTTP and parsing errors, returning user-friendly
      # error messages instead of raising exceptions.
      #
      # @example
      #   safe_api_call do
      #     response = get(url)
      #     parse_json_response(response)
      #   end
      #
      # @yield Block containing HTTP operations
      # @return [Object] Result of block, or error string on failure
      def safe_api_call
        yield
      rescue Faraday::TimeoutError => e
        handle_http_error(e)
      rescue Faraday::Error, JSON::ParserError => e
        "Error: #{e.message}"
      end
    end
  end
end
