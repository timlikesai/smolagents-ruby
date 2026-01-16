require "json"
require_relative "harmony_parser"

module Smolagents
  module Utilities
    # Pattern matching utilities for extracting structured data from LLM responses.
    #
    # Provides methods to extract code blocks, JSON, and categorize errors from
    # text responses. Essential for agents which need to parse Ruby code
    # from LLM outputs.
    #
    # Automatically handles OpenAI Harmony format (used by gpt-oss models) by
    # converting tool calls to Ruby code.
    #
    # @example Extract Ruby code from response
    #   response = "Here's the code:\n```ruby\nputs 'Hello'\n```"
    #   code = PatternMatching.extract_code(response)
    #   # => "puts 'Hello'"
    #
    # @example Extract from Harmony format (gpt-oss models)
    #   response = "<|channel|>commentary to=search<|message|>{\"query\": \"hello\"}"
    #   code = PatternMatching.extract_code(response)
    #   # => "result = search(query: \"hello\")"
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
        # Tool call tokens (LFM and similar): <|tool_call_start|>[tool(...)]<|tool_call_end|>
        /<\|tool_call_start\|>\[(.+?)\]<\|tool_call_end\|>/m,
        # "Code:" prefix format (LFM and similar models)
        /^Code:\s*(.+?)$/mi,
        # Fallback: indented code block (4+ spaces or tab at start of lines)
        /^(?: {4}|\t)(.+?)(?=\n\S|\n\n|\z)/m
      ].freeze

      # Model-specific special tokens to strip before parsing.
      # Different models emit various internal tokens in their responses:
      # - gpt-oss, llama, etc: <|start|>, <|end|>, <|im_start|>, <|im_end|>
      # - medgemma: <unused94>, <unused95>, etc.
      SPECIAL_TOKEN_PATTERNS = [
        /<\|[^|>]+\|>/,    # Generic <|token|> format
        /<unused\d+>/      # <unusedNN> tokens (medgemma, etc.)
      ].freeze

      def self.extract_code(text)
        return nil if text.nil? || text.empty?

        extract_harmony_code(text) || extract_pattern_code(text)
      end

      def self.extract_harmony_code(text)
        return nil unless HarmonyParser.harmony_format?(text)

        HarmonyParser.to_ruby_code(text)
      end

      def self.extract_pattern_code(text)
        # First try patterns on original text (some patterns need special tokens)
        CODE_PATTERNS.each { |p| (code = extract_match(text, p)) && (return code) }
        # Then try on cleaned text (for patterns that work better without tokens)
        cleaned = strip_special_tokens(text)
        return nil if cleaned == text # Already tried

        CODE_PATTERNS.each { |p| (code = extract_match(cleaned, p)) && (return code) }
        nil
      end

      def self.strip_special_tokens(text)
        result = text.dup
        SPECIAL_TOKEN_PATTERNS.each { |pattern| result.gsub!(pattern, "") }
        result
      end

      def self.extract_match(text, pattern)
        match = text.match(pattern)
        return nil unless match

        code = match[1]&.strip
        code if code && looks_like_ruby?(code)
      end

      RUBY_INDICATORS = [
        /\bdef\s+\w+/, /\bend\b/, /\bputs\b|\bprint\b/, /\w+\s*=\s*\S/, /\w+\(.*\)/,
        /\w+\s+\w+:\s/, /\bdo\s*\|/, /\.each\b|\.map\b/, /final_answer/, /\bcalculate\b|\bsearch\b/
      ].freeze

      # Heuristic check that extracted text resembles Ruby code
      def self.looks_like_ruby?(code)
        return false if code.nil? || code.empty? || code.length < 3
        return false if prose_like?(code)

        RUBY_INDICATORS.any? { it.match?(code) }
      end

      def self.prose_like?(code) = code.scan(/[a-z]{4,}/i).length > 10 && code.count("()={}[]") < 3

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

      ERROR_CLASS_MAPPING = {
        "Faraday::TooManyRequestsError" => :rate_limit,
        "Faraday::TimeoutError" => :timeout,
        "Faraday::UnauthorizedError" => :authentication
      }.freeze

      def self.categorize_error(error)
        categorize_by_class(error) || categorize_by_pattern(error.message)
      end

      def self.categorize_by_class(error)
        ERROR_CLASS_MAPPING.find { |name, _| class_matches?(error, name) }&.last
      end

      def self.class_matches?(error, class_name)
        const = class_name.split("::").reduce(Object) { |mod, name| mod.const_get(name) }
        error.is_a?(const)
      rescue NameError
        false
      end

      def self.categorize_by_pattern(message)
        ERROR_PATTERNS.find { |_, pattern| message =~ pattern }&.first || :unknown
      end
    end
  end
end
