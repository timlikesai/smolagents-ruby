module Smolagents
  module PromptSanitizer
    MAX_LENGTH = 5000

    SUSPICIOUS_PATTERNS = {
      /ignore.*previous.*instruct/i => "instruction override attempt",
      /disregard.*above/i => "context reset attempt",
      /you are now/i => "role redefinition attempt",
      /system.*prompt/i => "system prompt access attempt",
      /forget.*everything/i => "memory reset attempt"
    }.freeze

    def self.sanitize(text, logger: nil)
      return nil if text.to_s.empty?

      text = text[0...MAX_LENGTH]

      text = text.gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]/, "")

      text = text.gsub(/\n{4,}/, "\n\n\n")
      text = text.gsub(/ {3,}/, "  ")

      warn_suspicious_patterns(text, logger) if logger

      text.strip
    end

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
