# frozen_string_literal: true

module Smolagents
  # Sanitizes custom instructions to prevent prompt injection and token exhaustion.
  # Implements OWASP LLM security best practices.
  module PromptSanitizer
    # Maximum length for custom instructions (prevents token exhaustion)
    MAX_LENGTH = 5000

    # Dangerous patterns that may indicate prompt injection attempts
    SUSPICIOUS_PATTERNS = {
      /ignore.*previous.*instruct/i => "instruction override attempt",
      /disregard.*above/i => "context reset attempt",
      /you are now/i => "role redefinition attempt",
      /system.*prompt/i => "system prompt access attempt",
      /forget.*everything/i => "memory reset attempt"
    }.freeze

    # Sanitize custom instructions text.
    #
    # @param text [String, nil] custom instructions to sanitize
    # @param logger [Monitoring::AgentLogger, nil] optional logger for warnings
    # @return [String, nil] sanitized text or nil
    #
    # @example
    #   sanitized = PromptSanitizer.sanitize("Be concise\x00invalid")
    #   # => "Be concise invalid"
    def self.sanitize(text, logger: nil)
      return nil if text.nil? || text.empty?

      # Truncate to max length
      text = text[0...MAX_LENGTH]

      # Strip control characters (preserve newlines, tabs)
      text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

      # Normalize excessive whitespace
      text = text.gsub(/\n{4,}/, "\n\n\n")
      text = text.gsub(/ {3,}/, "  ")

      # Warn on suspicious patterns
      warn_suspicious_patterns(text, logger) if logger

      text.strip
    end

    # Check for suspicious patterns and log warnings.
    #
    # @param text [String] text to check
    # @param logger [Monitoring::AgentLogger] logger for warnings
    # @return [void]
    def self.warn_suspicious_patterns(text, logger)
      SUSPICIOUS_PATTERNS.each do |pattern, description|
        next unless text.match?(pattern)

        match = text.match(pattern)
        excerpt = text[match.begin(0), 100]

        logger.warn(
          "Potentially unsafe prompt pattern detected",
          pattern: description,
          excerpt: excerpt
        )
      end
    end

    private_class_method :warn_suspicious_patterns
  end
end
