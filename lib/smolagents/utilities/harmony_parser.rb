module Smolagents
  module Utilities
    # Parser for OpenAI Harmony response format used by gpt-oss models.
    #
    # gpt-oss-20b and gpt-oss-120b use a special "Harmony" format for tool calls
    # instead of standard code blocks. This parser extracts tool calls and converts
    # them to Ruby code, maintaining the single "code execution" paradigm.
    #
    # @example Detecting Harmony format
    #   HarmonyParser.harmony_format?(response)
    #   # => true if response contains <|channel|> markers
    #
    # @example Converting to Ruby code
    #   code = HarmonyParser.to_ruby_code(response)
    #   # => "result = searxng_search(query: \"hello\")"
    #
    # @see https://github.com/openai/harmony
    # @see https://pypi.org/project/openai-harmony/
    module HarmonyParser
      # Harmony format markers
      CHANNEL_MARKER = "<|channel|>".freeze
      MESSAGE_MARKER = "<|message|>".freeze
      START_MARKER = "<|start|>".freeze
      END_MARKER = "<|end|>".freeze

      # Patterns to extract tool calls from Harmony format (gpt-oss models)
      # Multiple formats supported:
      #   1. <|channel|>commentary to=tool_name<|message|>{"args": ...}
      #   2. <|channel|>commentary to=tool_name code<|message|>{"args": ...}
      #   3. <|channel|>commentary to=tool_name <|constrain|>json<|message|>{"args": ...}
      #   4. <|channel|>tool_name<|message|>{"args": ...}  (direct tool call)
      TOOL_CALL_PATTERNS = [
        # Commentary format with optional "code" or constrain markers
        /
          <\|channel\|>commentary\s+to=(\w+)  # Channel declaration with tool name
          (?:\s+code)?                         # Optional "code" suffix
          (?:\s*<\|constrain\|>\w+)?           # Optional constrain marker
          <\|message\|>\{(.+?)\}               # JSON arguments after message marker
        /mx,
        # Direct tool call format: <|channel|>tool_name<|message|>{...}
        /
          <\|channel\|>(\w+)                   # Direct tool name (not "commentary")
          <\|message\|>\{(.+?)\}               # JSON arguments
        /mx
      ].freeze

      # Pattern to extract final answer content (multiple formats)
      FINAL_ANSWER_PATTERNS = [
        /<\|channel\|>final<\|message\|>(.+?)(?:<\||$)/m,
        /<\|channel\|>final_answer<\|message\|>\{[^}]*"answer"\s*:\s*"([^"]+)"/m,
        /<\|channel\|>final_answer<\|message\|>(.+?)(?:<\||$)/m
      ].freeze

      class << self
        # Check if text appears to be in Harmony format.
        #
        # @param text [String] Response text to check
        # @return [Boolean] True if Harmony markers are present
        def harmony_format?(text)
          return false if text.nil? || text.empty?

          text.include?(CHANNEL_MARKER)
        end

        # Extract tool calls from Harmony format and convert to Ruby code.
        #
        # @param text [String] Harmony-formatted response
        # @return [String, nil] Ruby code equivalent, or nil if no tool calls found
        def to_ruby_code(text)
          return nil unless harmony_format?(text)

          tool_calls = extract_tool_calls(text)

          # If no tool calls but there's a final answer, convert that to code
          if tool_calls.empty?
            final = extract_final_answer(text)
            return "final_answer(answer: #{final.inspect})" if final

            return nil
          end

          # Convert tool calls to Ruby code
          code_lines = tool_calls.map { |tc| tool_call_to_ruby(tc) }
          code_lines.join("\n")
        end

        # Extract structured tool calls from Harmony format.
        #
        # @param text [String] Harmony-formatted response
        # @return [Array<Hash>] Array of {name:, arguments:} hashes
        def extract_tool_calls(text)
          TOOL_CALL_PATTERNS.each do |pattern|
            matches = text.scan(pattern)
            next if matches.empty?

            calls = matches.filter_map { |m| parse_tool_call(m) }
            return calls unless calls.empty?
          end
          []
        end

        def parse_tool_call(match)
          tool_name = match[0]
          # Skip "final" and "commentary" as they're not real tools
          return nil if %w[final commentary].include?(tool_name)

          json_content = match[1]
          # Handle both complete JSON and just the inner content
          json_str = json_content.start_with?("{") ? json_content : "{#{json_content}}"
          arguments = JSON.parse(json_str)
          { name: tool_name, arguments: }
        rescue JSON::ParserError
          nil
        end

        # Extract final answer content if present.
        #
        # @param text [String] Harmony-formatted response
        # @return [String, nil] Final answer content, or nil
        def extract_final_answer(text)
          FINAL_ANSWER_PATTERNS.each do |pattern|
            match = text.match(pattern)
            return match[1].strip if match
          end
          nil
        end

        # Strip all Harmony markers from text for cleaner output.
        #
        # @param text [String] Text with Harmony markers
        # @return [String] Cleaned text
        def strip_markers(text)
          text
            .gsub(/<\|[^|>]+\|>/, "")
            .gsub(/commentary\s+to=\w+/, "")
            .strip
        end

        private

        def tool_call_to_ruby(tool_call)
          name = tool_call[:name]
          args = tool_call[:arguments]

          # Format arguments as Ruby keyword args
          formatted_args = args.map do |key, value|
            formatted_value = value.is_a?(String) ? "\"#{value}\"" : value.inspect
            "#{key}: #{formatted_value}"
          end.join(", ")

          "result = #{name}(#{formatted_args})"
        end
      end
    end
  end
end
