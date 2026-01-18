module Smolagents
  module Utilities
    module PatternMatching
      # Extracts code blocks from LLM responses.
      # Handles markdown code fences, HTML tags, and model-specific formats.
      module CodeExtraction
        # Code extraction patterns - most specific to least specific
        PATTERNS = [
          /```ruby\s*\n?(.+?)```/mi,
          /```rb\s*\n?(.+?)```/mi,
          /```python\s*\n(.+?)```/mi,
          /```\s*\n?(.+?)```/m,
          %r{<code>\s*(.+?)\s*</code>}mi,
          %r{<ruby>\s*(.+?)\s*</ruby>}mi,
          /<\|tool_call_start\|>\[?(.+?)\]?<\|tool_call_end\|>/m,
          /^(?:Code|Answer|Ruby|Action|Output):\s*(.+?)$/mi,
          /Thought:.*?\n(.+?)(?=\n\n|$)/mi
        ].freeze

        # Model-specific special tokens to strip
        SPECIAL_TOKEN_PATTERNS = [
          /<\|[^|>]+\|>/,
          /<unused\d+>/
        ].freeze

        # Thinking/reasoning tags to strip before extraction
        THINKING_TAGS = [
          %r{<think>.*?</think>}mi,
          %r{<reasoning>.*?</reasoning>}mi
        ].freeze

        # granite-tiny appends [TOOL_CALLS]name{json} after code blocks
        TOOL_CALLS_SUFFIX = /\[TOOL_CALLS\].+$/mi

        class << self
          def extract_pattern_code(text, ruby_detector)
            # First try to extract ALL code blocks and combine them
            all_blocks = extract_all_code_blocks(text, ruby_detector)
            return all_blocks if all_blocks

            # Fallback: try patterns on original text
            code = try_patterns(text, ruby_detector)
            return code if code

            # Then try on cleaned text
            cleaned = strip_special_tokens(text)
            return nil if cleaned == text

            try_patterns(cleaned, ruby_detector)
          end

          def extract_all_code_blocks(text, ruby_detector)
            blocks = text.scan(/```(?:ruby|rb)?\s*\n?(.+?)```/mi).flatten
            return nil if blocks.empty?

            ruby_blocks = blocks.map(&:strip).select { |b| ruby_detector.call(b) }
            return nil if ruby_blocks.empty?

            combined = ruby_blocks.join("\n")
            ruby_detector.call(combined) ? combined : nil
          end

          def strip_thinking_tags(text)
            result = THINKING_TAGS.reduce(text) { |t, p| t.gsub(p, "") }
            result.gsub(TOOL_CALLS_SUFFIX, "")
          end

          def strip_special_tokens(text)
            result = text.dup
            SPECIAL_TOKEN_PATTERNS.each { |pattern| result.gsub!(pattern, "") }
            result
          end

          def extract_match(text, pattern, ruby_detector)
            match = text.match(pattern)
            return nil unless match

            code = match[1]&.strip
            code if code && ruby_detector.call(code)
          end

          private

          def try_patterns(text, ruby_detector)
            PATTERNS.each do |pattern|
              code = extract_match(text, pattern, ruby_detector)
              return code if code
            end
            nil
          end
        end
      end
    end
  end
end
