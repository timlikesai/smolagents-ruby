# frozen_string_literal: true

require "json"

module Smolagents
  # Pattern matching utilities for agent responses.
  module PatternMatching
    # Extract code blocks from text.
    def self.extract_code(text)
      text.match(/```ruby\n(.+?)```/m)&.[](1)&.strip ||
        text.match(/```\n(.+?)```/m)&.[](1)&.strip ||
        text.match(%r{<code>(.+?)</code>}m)&.[](1)&.strip
    end

    # Extract JSON from text.
    def self.extract_json(text)
      json_str = text.match(/```json\n(.+?)```/m)&.[](1) || text.match(/\{.+\}/m)&.[](0)
      json_str && JSON.parse(json_str)
    rescue JSON::ParserError
      nil
    end

    # Categorize errors for retry logic.
    ERROR_PATTERNS = {
      rate_limit: /rate limit/i,
      timeout: /timeout/i,
      authentication: /unauthorized|invalid.*key/i,
      client_error: /4\d{2}/i,
      server_error: /5\d{2}/i
    }.freeze

    def self.categorize_error(error)
      return :rate_limit if defined?(Faraday::TooManyRequestsError) && error.is_a?(Faraday::TooManyRequestsError)
      return :timeout if defined?(Faraday::TimeoutError) && error.is_a?(Faraday::TimeoutError)
      return :authentication if defined?(Faraday::UnauthorizedError) && error.is_a?(Faraday::UnauthorizedError)

      ERROR_PATTERNS.find { |_, pattern| error.message =~ pattern }&.first || :unknown
    end
  end
end
