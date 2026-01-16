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
      # Code extraction patterns - ordered from most specific to least specific
      CODE_PATTERNS = [
        /```ruby\s*\n(.+?)```/mi, /```rb\s*\n(.+?)```/mi,                    # Markdown with language
        /```ruby\s*(.+?)```/mi, /```rb\s*(.+?)```/mi,                        # No newline variant
        /```python\s*\n(.+?)```/mi, /```py\s*\n(.+?)```/mi,                  # Python (models confuse)
        /```\s*\n(.+?)```/m, /```(.+?)```/m,                                 # Generic markdown
        %r{<code>\s*(.+?)\s*</code>}mi, %r{<ruby>\s*(.+?)\s*</ruby>}mi,      # XML tags
        /<\|tool_call_start\|>\[(.+?)\]<\|tool_call_end\|>/m,                # LFM with brackets
        /<\|tool_call_start\|>(.+?)<\|tool_call_end\|>/m,                    # LFM without brackets
        /^Code:\s*(.+?)$/mi, /^Answer:\s*(.+?)$/mi, /^Ruby:\s*(.+?)$/mi,     # Prefix formats
        /^Action:\s*(.+?)$/mi, /^Output:\s*(.+?)$/mi,                        # Instruction formats
        /Thought:.*?\n(.+?)(?=\n\n|Thought:|$)/mi,                           # ReAct style
        /^(?: {4}|\t)(.+?)(?=\n\S|\n\n|\z)/m                                 # Indented code
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

        # Strip thinking tags before extraction
        cleaned = strip_thinking_tags(text)
        extract_tool_call_xml(cleaned) || extract_tool_request(cleaned) ||
          extract_harmony_code(cleaned) || extract_pattern_code(cleaned)
      end

      THINKING_TAGS = [%r{<think>.*?</think>}mi, %r{<reasoning>.*?</reasoning>}mi].freeze
      TOOL_CALL_XML = %r{<tool_call>\s*(\{.+?\})\s*</tool_call>}mi
      TOOL_REQUEST_MD = /```tool_request\s*\n(\{.+?\})\s*\n```/mi

      def self.strip_thinking_tags(text) = THINKING_TAGS.reduce(text) { |t, p| t.gsub(p, "") }

      def self.extract_tool_call_xml(text) = extract_tool_json(text, TOOL_CALL_XML)

      def self.extract_tool_request(text) = extract_tool_json(text, TOOL_REQUEST_MD)

      def self.extract_tool_json(text, pattern)
        (m = text.match(pattern)) && (d = JSON.parse(m[1])) && tool_call_to_ruby(d["name"], d["arguments"])
      rescue JSON::ParserError
        nil
      end

      def self.tool_call_to_ruby(name, args)
        name && args ? "result = #{name}(#{args.map { |k, v| "#{k}: #{v.inspect}" }.join(", ")})" : nil
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

      # Ruby syntax indicators - generous to accept code even if formatting varies
      RUBY_INDICATORS = [
        /\bdef\s+\w+/, /\bend\b/, /\bputs\b|\bprint\b/, /\w+\s*=\s*\S/, /\w+\(.*\)/,
        /\w+\s+\w+:\s/, /\bdo\s*\|/, /\.each\b|\.map\b/, /final_answer/, /\bresult\s*=/,
        /\bcalculate\b|\bsearch\b|\bduckduckgo\b/, /\breturn\b/, /\bclass\s+\w+/,
        /\bmodule\s+\w+/, /\brequire\b/, /\bnil\b|\btrue\b|\bfalse\b/, /\[\]|\{\}/
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

      ERROR_PATTERNS = { rate_limit: /rate limit/i, timeout: /timeout/i,
                         authentication: /unauthorized|invalid.*key/i }.freeze
      ERROR_CLASSES = { "Faraday::TooManyRequestsError" => :rate_limit,
                        "Faraday::TimeoutError" => :timeout, "Faraday::UnauthorizedError" => :authentication }.freeze

      def self.categorize_error(error)
        ERROR_CLASSES.find { |n, _| safe_is_a?(error, n) }&.last ||
          ERROR_PATTERNS.find { |_, p| error.message =~ p }&.first || :unknown
      end

      def self.safe_is_a?(error, class_name)
        error.is_a?(class_name.split("::").reduce(Object) { |m, n| m.const_get(n) })
      rescue NameError
        false
      end
    end
  end
end
