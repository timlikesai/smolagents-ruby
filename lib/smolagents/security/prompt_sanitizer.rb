module Smolagents
  module Security
    # Sanitizes and validates prompts to detect prompt injection attacks.
    #
    # PromptSanitizer provides defense-in-depth against prompt injection by:
    # - Removing control characters and excessive whitespace
    # - Detecting suspicious patterns that indicate injection attempts
    # - Optionally blocking detected injections with descriptive errors
    #
    # The sanitizer normalizes text to catch obfuscation attempts including:
    # - Newline/whitespace manipulation
    # - Zero-width characters
    # - Cyrillic character substitution (homoglyph attacks)
    #
    # @example Sanitizing user input (warning mode)
    #   sanitized = PromptSanitizer.sanitize(user_input, logger: Rails.logger)
    #   # Logs warning if suspicious patterns detected, but continues
    #
    # @example Blocking suspicious prompts
    #   sanitized = PromptSanitizer.sanitize(user_input, block_suspicious: true)
    #   # Raises PromptInjectionError if injection detected
    #
    # @example Validation without sanitization
    #   PromptSanitizer.validate!(user_input)  # Raises if suspicious
    #   PromptSanitizer.suspicious?(user_input)  # Returns boolean
    #
    module PromptSanitizer
      # @return [Integer] Maximum prompt length (5000 characters) after sanitization
      MAX_LENGTH = 5000

      # Patterns for detecting prompt injection attempts.
      # Uses \s* to handle newline/space obfuscation.
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
        # Sanitizes text by removing control characters, normalizing whitespace,
        # and optionally detecting/blocking suspicious patterns.
        #
        # @param text [String, nil] Text to sanitize
        # @param logger [#warn, nil] Logger for warning about suspicious patterns
        # @param block_suspicious [Boolean] If true, raises on suspicious patterns
        # @return [String, nil] Sanitized text, or nil if input was empty
        # @raise [PromptInjectionError] If block_suspicious is true and injection detected
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

        # Validates text for suspicious patterns, raising if any found.
        #
        # @param text [String] Text to validate
        # @return [true] If text is safe
        # @raise [PromptInjectionError] If suspicious patterns detected
        def validate!(text)
          violations = detect_suspicious_patterns(text)
          return true if violations.empty?

          raise PromptInjectionError.new(
            "Prompt contains #{violations.size} suspicious pattern(s): #{violations.map { |v| v[:type] }.join(", ")}",
            pattern_type: violations.first[:type],
            matched_text: violations.first[:excerpt]
          )
        end

        # Checks if text contains any suspicious patterns.
        #
        # @param text [String] Text to check
        # @return [Boolean] True if suspicious patterns found
        def suspicious?(text)
          detect_suspicious_patterns(text).any?
        end

        private

        # Checks patterns and reports violations via logging or blocking.
        #
        # @param text [String] Text to check
        # @param logger [#warn, nil] Logger for warnings
        # @param block [Boolean] Whether to raise on violation
        # @return [void]
        def check_suspicious_patterns(text, logger:, block:)
          detect_suspicious_patterns(text).each { |v| report_violation(v, logger:, block:) }
        end

        # Reports a detected violation by logging or raising.
        #
        # @param violation [Hash] Violation with :type and :excerpt
        # @param logger [#warn, nil] Logger for warnings
        # @param block [Boolean] Whether to raise
        # @return [void]
        # @raise [PromptInjectionError] If block is true
        def report_violation(violation, logger:, block:)
          if block
            raise PromptInjectionError.new("Blocked prompt injection: #{violation[:type]}",
                                           pattern_type: violation[:type], matched_text: violation[:excerpt])
          elsif logger
            logger.warn("Potentially unsafe prompt pattern detected", pattern: violation[:type],
                                                                      excerpt: violation[:excerpt])
          end
        end

        # Detects suspicious patterns in text.
        #
        # @param text [String] Text to analyze
        # @return [Array<Hash>] Array of violations with :type and :excerpt
        def detect_suspicious_patterns(text)
          normalized = normalize_for_detection(text)
          SUSPICIOUS_PATTERNS.filter_map do |pattern, description|
            next unless (match = normalized.match(pattern))

            { type: description, excerpt: text[match.begin(0), 100] }
          end
        end

        # Normalizes text for pattern detection (handles obfuscation).
        #
        # @param text [String] Text to normalize
        # @return [String] Normalized lowercase text with Cyrillic converted to ASCII
        def normalize_for_detection(text)
          text
            .gsub(/[\u200B-\u200D\uFEFF]/, "") # Remove zero-width characters
            .gsub(/[\u0400-\u04FF]/) { |c| ASCII_LOOKALIKES[c] || c } # Cyrillic lookalikes
            .downcase
        end
      end

      # Common Cyrillic characters that look like ASCII (homoglyph attack vectors)
      ASCII_LOOKALIKES = {
        "\u0430" => "a", # Cyrillic a
        "\u0435" => "e", # Cyrillic e
        "\u043E" => "o", # Cyrillic o
        "\u0440" => "p", # Cyrillic p
        "\u0441" => "c", # Cyrillic c
        "\u0443" => "y", # Cyrillic y
        "\u0445" => "x", # Cyrillic x
        "\u0456" => "i", # Cyrillic i
        "\u0458" => "j"  # Cyrillic j
      }.freeze
    end
  end
end
