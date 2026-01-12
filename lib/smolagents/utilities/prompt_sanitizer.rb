module Smolagents
  # Error raised when prompt injection is detected and blocking is enabled
  class PromptInjectionError < AgentError
    attr_reader :pattern_type, :matched_text

    def initialize(message = nil, pattern_type: nil, matched_text: nil)
      @pattern_type = pattern_type
      @matched_text = matched_text
      super(message || "Prompt injection detected: #{pattern_type}")
    end
  end

  module PromptSanitizer
    MAX_LENGTH = 5000

    # Patterns for detecting prompt injection attempts
    # Uses \s* to handle newline/space obfuscation
    SUSPICIOUS_PATTERNS = {
      /ignore\s+.{0,20}previous\s+.{0,20}instruct/i => "instruction override attempt",
      /disregard\s+.{0,20}above/i => "context reset attempt",
      /you\s+are\s+now/i => "role redefinition attempt",
      /system\s*.{0,10}prompt/i => "system prompt access attempt",
      /forget\s+.{0,20}everything/i => "memory reset attempt",
      /new\s+instruct|override\s+.{0,10}instruct/i => "instruction override attempt",
      /pretend\s+.{0,20}(you|your)\s+.{0,10}(are|instructions)/i => "role manipulation attempt",
      /reveal\s+.{0,20}(system|hidden|secret)/i => "information extraction attempt",
      /act\s+as\s+(if|though)\s+.{0,20}(no|different)/i => "role manipulation attempt"
    }.freeze

    class << self
      def sanitize(text, logger: nil, block_suspicious: false)
        return nil if text.to_s.empty?

        text = text[0...MAX_LENGTH]

        # Remove control characters (keeps newlines, tabs, carriage returns)
        text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

        # Normalize excessive whitespace
        text = text.gsub(/\n{4,}/, "\n\n\n")
        text = text.gsub(/ {3,}/, "  ")

        # Check for suspicious patterns
        check_suspicious_patterns(text, logger:, block: block_suspicious)

        text.strip
      end

      def validate!(text)
        violations = detect_suspicious_patterns(text)
        return true if violations.empty?

        raise PromptInjectionError.new(
          "Prompt contains #{violations.size} suspicious pattern(s): #{violations.map { |v| v[:type] }.join(", ")}",
          pattern_type: violations.first[:type],
          matched_text: violations.first[:excerpt]
        )
      end

      def suspicious?(text)
        detect_suspicious_patterns(text).any?
      end

      private

      def check_suspicious_patterns(text, logger:, block:)
        violations = detect_suspicious_patterns(text)
        return if violations.empty?

        violations.each do |violation|
          if block
            raise PromptInjectionError.new(
              "Blocked prompt injection: #{violation[:type]}",
              pattern_type: violation[:type],
              matched_text: violation[:excerpt]
            )
          elsif logger
            logger.warn(
              "Potentially unsafe prompt pattern detected",
              pattern: violation[:type],
              excerpt: violation[:excerpt]
            )
          end
        end
      end

      def detect_suspicious_patterns(text)
        violations = []

        # Normalize text for detection (collapse whitespace, handle unicode lookalikes)
        normalized = normalize_for_detection(text)

        SUSPICIOUS_PATTERNS.each do |pattern, description|
          next unless normalized.match?(pattern)

          match = normalized.match(pattern)
          violations << {
            type: description,
            excerpt: text[match.begin(0), 100]
          }
        end

        violations
      end

      def normalize_for_detection(text)
        text
          .gsub(/[\u200B-\u200D\uFEFF]/, "") # Remove zero-width characters
          .gsub(/[\u0400-\u04FF]/) { |c| ASCII_LOOKALIKES[c] || c } # Cyrillic lookalikes
          .downcase
      end
    end

    # Common Cyrillic characters that look like ASCII
    ASCII_LOOKALIKES = {
      "\u0430" => "a", # Cyrillic а
      "\u0435" => "e", # Cyrillic е
      "\u043E" => "o", # Cyrillic о
      "\u0440" => "p", # Cyrillic р
      "\u0441" => "c", # Cyrillic с
      "\u0443" => "y", # Cyrillic у
      "\u0445" => "x", # Cyrillic х
      "\u0456" => "i", # Cyrillic і
      "\u0458" => "j"  # Cyrillic ј
    }.freeze
  end
end
