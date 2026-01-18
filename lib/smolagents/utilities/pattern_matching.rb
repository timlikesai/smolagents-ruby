require_relative "harmony_parser"
require_relative "pattern_matching/code_extraction"
require_relative "pattern_matching/final_answer"
require_relative "pattern_matching/tool_call_parsing"
require_relative "pattern_matching/ruby_detection"
require_relative "pattern_matching/error_categorization"
require_relative "pattern_matching/json_extraction"

module Smolagents
  module Utilities
    # Pattern matching utilities for extracting code and structured data from LLM responses.
    # Delegates to specialized sub-modules for each extraction type.
    module PatternMatching
      # Re-export constants for compatibility
      CODE_PATTERNS = CodeExtraction::PATTERNS
      SPECIAL_TOKEN_PATTERNS = CodeExtraction::SPECIAL_TOKEN_PATTERNS
      THINKING_TAGS = CodeExtraction::THINKING_TAGS
      TOOL_CALLS_SUFFIX = CodeExtraction::TOOL_CALLS_SUFFIX
      TOOL_CALL_XML = ToolCallParsing::TOOL_CALL_XML
      TOOL_REQUEST_MD = ToolCallParsing::TOOL_REQUEST_MD
      RUBY_INDICATORS = RubyDetection::INDICATORS
      ERROR_PATTERNS = ErrorCategorization::PATTERNS
      ERROR_CLASSES = ErrorCategorization::CLASSES
      ParseState = FinalAnswer::ParseState

      EXTRACTORS = %i[extract_tool_call_xml extract_tool_request extract_harmony_code extract_pattern_code].freeze

      class << self
        def extract_code(text)
          return nil if text.nil? || text.empty?

          cleaned = strip_thinking_tags(text)
          code = EXTRACTORS.lazy.filter_map { |m| send(m, cleaned) }.first
          code = FinalAnswer.maybe_append(code, cleaned) if code
          code || FinalAnswer.extract_standalone(cleaned)
        end

        # FinalAnswer delegates
        def extract_standalone_final_answer(text) = FinalAnswer.extract_standalone(text)
        def maybe_append_final_answer(code, text) = FinalAnswer.maybe_append(code, text)
        def extract_balanced_value(str) = FinalAnswer.extract_balanced_value(str)
        def clean_answer_value(str) = FinalAnswer.clean_answer_value(str)
        def balance_parens(str) = FinalAnswer.balance_parens(str)

        # CodeExtraction delegates
        def strip_thinking_tags(text) = CodeExtraction.strip_thinking_tags(text)
        def strip_special_tokens(text) = CodeExtraction.strip_special_tokens(text)
        def extract_pattern_code(text) = CodeExtraction.extract_pattern_code(text, method(:looks_like_ruby?))
        def extract_all_code_blocks(text) = CodeExtraction.extract_all_code_blocks(text, method(:looks_like_ruby?))
        def extract_match(text, pattern) = CodeExtraction.extract_match(text, pattern, method(:looks_like_ruby?))

        # ToolCallParsing delegates
        def extract_tool_call_xml(text) = ToolCallParsing.extract_tool_call_xml(text)
        def extract_tool_request(text) = ToolCallParsing.extract_tool_request(text)
        def extract_tool_json(text, pattern) = ToolCallParsing.extract_tool_json(text, pattern)
        def tool_call_to_ruby(name, args) = ToolCallParsing.tool_call_to_ruby(name, args)

        # RubyDetection delegates
        def looks_like_ruby?(code) = RubyDetection.looks_like_ruby?(code)
        def prose_like?(code) = RubyDetection.prose_like?(code)

        # ErrorCategorization delegates
        def categorize_error(error) = ErrorCategorization.categorize(error)
        def safe_is_a?(error, class_name) = ErrorCategorization.send(:safe_is_a?, error, class_name)

        # JsonExtraction delegate
        def extract_json(text) = JsonExtraction.extract(text)

        # Harmony format extraction
        def extract_harmony_code(text)
          HarmonyParser.harmony_format?(text) ? HarmonyParser.to_ruby_code(text) : nil
        end
      end
    end
  end
end
