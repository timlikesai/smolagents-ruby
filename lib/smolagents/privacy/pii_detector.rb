module Smolagents
  module Privacy
    # Detects PII in text using regex patterns.
    #
    # PIIDetector scans text for personally identifiable information using
    # configurable regex patterns. It supports common PII types like emails,
    # phone numbers, SSNs, and API keys. The detector is designed for
    # comprehensive coverage with minimal false positives.
    #
    # @example Basic usage
    #   detector = PIIDetector.new
    #   result = detector.scan("Contact me at user@example.com")
    #   result.detected?  #=> true
    #   result.types      #=> [:email]
    #
    # @example With custom config
    #   config = Types::PrivacyConfig.create(types: [:email, :phone])
    #   detector = PIIDetector.new(config)
    #   result = detector.scan("Call 555-123-4567 or email test@example.com")
    #   result.count  #=> 2
    #
    # @example Scanning for API keys
    #   detector = PIIDetector.new
    #   result = detector.scan("Use API key sk_live_abc123def456ghi789jkl012")
    #   result.types.include?(:api_key)  #=> true
    #
    # @see Types::PIIDetectionResult For result structure
    # @see Types::PIIToken For individual token details
    # @see Types::PrivacyConfig For configuration options
    class PIIDetector
      # Regex patterns for detecting various PII types.
      # Each pattern is designed to balance coverage with precision.
      PATTERNS = {
        # Email: standard format with common TLDs
        email: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b/,

        # Phone: US formats with optional country code and various separators
        phone: /\b(?:\+?1[-.\s]?)?(?:\(?[0-9]{3}\)?[-.\s]?)?[0-9]{3}[-.\s]?[0-9]{4}\b/,

        # SSN: XXX-XX-XXXX format (strict dash separator)
        ssn: /\b\d{3}-\d{2}-\d{4}\b/,

        # Credit card: 16 digits with optional separators
        credit_card: /\b(?:\d{4}[-\s]?){3}\d{4}\b/,

        # API key: common prefixes followed by alphanumeric strings
        api_key: /\b(?:sk|pk|api|key|token|secret)[-_]?[a-zA-Z0-9]{20,}\b/i,

        # IP address: IPv4 format (basic validation)
        ip_address: /\b(?:\d{1,3}\.){3}\d{1,3}\b/,

        # Name: capitalized words (2-3 word names, conservative matching)
        name: /\b[A-Z][a-z]+\s+(?:[A-Z][a-z]+\s+)?[A-Z][a-z]+\b/,

        # Address: US street address pattern
        address: /\b\d+\s+[A-Za-z]+(?:\s+[A-Za-z]+)*\s+(?:St|Ave|Rd|Blvd|Dr|Ln|Ct|Way|Pl)\b\.?/i,

        # Date of birth: common date formats (MM/DD/YYYY, YYYY-MM-DD)
        date_of_birth: %r{\b(?:\d{1,2}[/-]\d{1,2}[/-]\d{2,4}|\d{4}[/-]\d{1,2}[/-]\d{1,2})\b}
      }.freeze

      # Creates a new PII detector with the given configuration.
      #
      # @param config [Types::PrivacyConfig] Configuration for detection
      def initialize(config = Types::PrivacyConfig.default)
        @config = config
        @active_patterns = build_active_patterns
      end

      # Scans text for PII and returns detection results.
      #
      # @param text [String] Text to scan for PII
      # @return [Types::PIIDetectionResult] Detection results with tokens
      def scan(text)
        return Types::PIIDetectionResult.none(text) unless @config.enabled?

        start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        detections = find_all_matches(text)
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round(2)

        if detections.any?
          Types::PIIDetectionResult.found(text, detections, scan_time_ms: elapsed_ms)
        else
          Types::PIIDetectionResult.none(text)
        end
      end

      # Returns the pattern for a specific PII type.
      #
      # @param type [Symbol] PII type to get pattern for
      # @return [Regexp, nil] Pattern or nil if not found
      def self.pattern_for(type)
        PATTERNS[type]
      end

      # Returns all supported PII types.
      #
      # @return [Array<Symbol>] All pattern type keys
      def self.supported_types
        PATTERNS.keys
      end

      private

      def build_active_patterns
        @config.pii_types.filter_map do |type|
          pattern = PATTERNS[type]
          [type, pattern] if pattern
        end.to_h
      end

      def find_all_matches(text)
        @active_patterns.flat_map { |type, pattern| matches_for_pattern(text, type, pattern) }
                        .sort_by(&:position_start)
      end

      def matches_for_pattern(text, type, pattern)
        [].tap do |tokens|
          text.scan(pattern) { tokens << token_from_match(type, Regexp.last_match) }
        end
      end

      def token_from_match(type, match)
        Types::PIIToken.create(type, match[0], position_start: match.begin(0), position_end: match.end(0))
      end
    end
  end
end
