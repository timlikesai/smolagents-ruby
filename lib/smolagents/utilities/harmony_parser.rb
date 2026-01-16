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

      # Pattern to extract tool calls from Harmony commentary channel
      # Format: <|channel|>commentary to=tool_name<...><|message|>{"args": ...}
      TOOL_CALL_PATTERN = /
        <\|channel\|>commentary\s+to=(\w+)  # Channel declaration with tool name
        [^{]*                                # Skip any intermediate markers
        \{(.+?)\}                            # Capture JSON arguments
      /mx

      # Pattern to extract final answer content
      FINAL_CHANNEL_PATTERN = /<\|channel\|>final<\|message\|>(.+?)(?:<\||$)/m

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
          return nil if tool_calls.empty?

          # Convert tool calls to Ruby code
          code_lines = tool_calls.map { |tc| tool_call_to_ruby(tc) }
          code_lines.join("\n")
        end

        # Extract structured tool calls from Harmony format.
        #
        # @param text [String] Harmony-formatted response
        # @return [Array<Hash>] Array of {name:, arguments:} hashes
        def extract_tool_calls(text)
          text.scan(TOOL_CALL_PATTERN).filter_map { |m| parse_tool_call(m) }
        end

        def parse_tool_call(match)
          arguments = JSON.parse("{#{match[1]}}")
          { name: match[0], arguments: }
        rescue JSON::ParserError
          nil
        end

        # Extract final answer content if present.
        #
        # @param text [String] Harmony-formatted response
        # @return [String, nil] Final answer content, or nil
        def extract_final_answer(text)
          match = text.match(FINAL_CHANNEL_PATTERN)
          match&.[](1)&.strip
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
