require "json"

module Smolagents
  module Utilities
    # Pattern matching utilities for extracting structured data from LLM responses.
    #
    # Provides methods to extract code blocks, JSON, and categorize errors from
    # text responses. Essential for CodeAgent which needs to parse Ruby code
    # from LLM outputs.
    #
    # @example Extract Ruby code from response
    #   response = "Here's the code:\n```ruby\nputs 'Hello'\n```"
    #   code = PatternMatching.extract_code(response)
    #   # => "puts 'Hello'"
    #
    # @example Extract JSON from response
    #   response = "Result: ```json\n{\"key\": \"value\"}\n```"
    #   data = PatternMatching.extract_json(response)
    #   # => {"key" => "value"}
    #
    # @example Categorize an error
    #   begin
    #     api.call
    #   rescue => e
    #     category = PatternMatching.categorize_error(e)
    #     # => :rate_limit, :timeout, :authentication, etc.
    #   end
    #
    module PatternMatching
      # Ordered from most specific to least specific
      CODE_PATTERNS = [
        # Standard markdown with language
        /```ruby\s*\n(.+?)```/mi,
        /```rb\s*\n(.+?)```/mi,
        # Markdown with language, no newline
        /```ruby(.+?)```/mi,
        /```rb(.+?)```/mi,
        # Markdown without language
        /```\s*\n(.+?)```/m,
        /```(.+?)```/m,
        # XML-style tags (case insensitive)
        %r{<code>\s*(.+?)\s*</code>}mi,
        %r{<ruby>\s*(.+?)\s*</ruby>}mi,
        # Fallback: indented code block (4+ spaces or tab at start of lines)
        /^(?: {4}|\t)(.+?)(?=\n\S|\n\n|\z)/m
      ].freeze

      def self.extract_code(text)
        return nil if text.nil? || text.empty?

        CODE_PATTERNS.each do |pattern|
          match = text.match(pattern)
          next unless match

          code = match[1]&.strip
          # Validate it looks like Ruby code
          return code if code && looks_like_ruby?(code)
        end

        nil
      end

      # Heuristic check that extracted text resembles Ruby code
      def self.looks_like_ruby?(code)
        return false if code.nil? || code.empty?
        return false if code.length < 3

        # Reject if it looks like prose (mostly words, few symbols)
        words = code.scan(/[a-z]{4,}/i)
        return false if words.length > 10 && code.count("()={}[]") < 3

        # Accept if it contains Ruby indicators
        ruby_indicators = [
          /\bdef\s+\w+/,           # Method definition
          /\bend\b/,               # End keyword
          /\bputs\b|\bprint\b/,    # Output methods
          /\w+\s*=\s*\S/,          # Assignment
          /\w+\(.*\)/,             # Method call with parens
          /\w+\s+\w+:\s/,          # Keyword arguments
          /\bdo\s*\|/,             # Block with params
          /\.each\b|\.map\b/,      # Common iterators
          /final_answer/,          # Agent-specific
          /\bcalculate\b|\bsearch\b/ # Common tools
        ]

        ruby_indicators.any? { |pattern| code.match?(pattern) }
      end

      def self.extract_json(text)
        json_str = text.match(/```json\n(.+?)```/m)&.[](1) || text.match(/\{.+\}/m)&.[](0)
        json_str && JSON.parse(json_str)
      rescue JSON::ParserError
        nil
      end

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
end
