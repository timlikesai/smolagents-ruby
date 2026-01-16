require "json"
require_relative "harmony_parser"

module Smolagents
  module Utilities
    # Pattern matching utilities for extracting code and structured data from LLM responses.
    # Handles markdown, XML, Harmony (gpt-oss), tool calls, and various model-specific formats.
    module PatternMatching
      # Code extraction patterns - most specific to least specific
      CODE_PATTERNS = [
        /```ruby\s*\n?(.+?)```/mi, /```rb\s*\n?(.+?)```/mi, /```python\s*\n(.+?)```/mi,
        /```\s*\n?(.+?)```/m, %r{<code>\s*(.+?)\s*</code>}mi, %r{<ruby>\s*(.+?)\s*</ruby>}mi,
        /<\|tool_call_start\|>\[?(.+?)\]?<\|tool_call_end\|>/m,
        /^(?:Code|Answer|Ruby|Action|Output):\s*(.+?)$/mi, /Thought:.*?\n(.+?)(?=\n\n|$)/mi
      ].freeze

      # Model-specific special tokens to strip (<|token|>, <unusedNN>, etc.)
      SPECIAL_TOKEN_PATTERNS = [/<\|[^|>]+\|>/, /<unused\d+>/].freeze

      EXTRACTORS = %i[extract_tool_call_xml extract_tool_request extract_harmony_code extract_pattern_code].freeze

      def self.extract_code(text)
        return nil if text.nil? || text.empty?

        cleaned = strip_thinking_tags(text)
        code = EXTRACTORS.lazy.filter_map { |m| send(m, cleaned) }.first
        code = maybe_append_final_answer(code, cleaned) if code
        code || extract_standalone_final_answer(cleaned)
      end

      def self.maybe_append_final_answer(code, text)
        return code if code.include?("final_answer")

        (fa = extract_standalone_final_answer(text)) ? "#{code}\n#{fa}" : code
      end

      def self.extract_standalone_final_answer(text)
        match = text.match(/final_answer\s*\(\s*answer:\s*(.+)\s*\)\s*$/mi)
        match ? "final_answer(answer: #{balance_parens(match[1].strip)})" : nil
      end

      def self.balance_parens(str)
        d = 0
        str.each_char.with_index do |c, i|
          d += { "(" => 1, ")" => -1 }.fetch(c, 0)
          return str[0...i] if d.negative?
        end
        str
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
        /\bmodule\s+\w+/, /\brequire\b/, /\bnil\b|\btrue\b|\bfalse\b/, /\[\]|\{\}/,
        %r{\d+\s*[+\-*/]\s*\d+} # Math expressions (47 * 23, etc.)
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
