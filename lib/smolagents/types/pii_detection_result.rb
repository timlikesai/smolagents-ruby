module Smolagents
  module Types
    # Result of scanning text for PII.
    #
    # PIIDetectionResult encapsulates the outcome of PII detection, including
    # all found tokens and scan timing. Provides convenience methods for
    # querying detection results.
    #
    # @example No PII found
    #   result = PIIDetectionResult.none("Hello world")
    #   result.detected?  #=> false
    #
    # @example PII found
    #   tokens = [PIIToken.create(:email, "user@example.com")]
    #   result = PIIDetectionResult.found("Email: user@example.com", tokens, scan_time_ms: 5)
    #   result.detected?  #=> true
    #   result.count      #=> 1
    #   result.types      #=> [:email]
    #
    # @see PIIToken For individual token structure
    # @see PrivacyConfig For configuration options
    PIIDetectionResult = Data.define(:text, :detections, :scan_time_ms) do
      # Whether any PII was detected.
      #
      # @return [Boolean]
      def detected? = detections.any?

      # Number of PII tokens detected.
      #
      # @return [Integer]
      def count = detections.size

      # Unique PII types detected.
      #
      # @return [Array<Symbol>]
      def types = detections.map(&:pii_type).uniq

      # Position ranges of detected PII.
      #
      # @return [Array<Range>]
      def positions = detections.map { |d| d.position_start..d.position_end }

      # Creates a result indicating no PII was found.
      #
      # @param text [String] The scanned text
      # @return [PIIDetectionResult]
      def self.none(text)
        new(text:, detections: [], scan_time_ms: 0)
      end

      # Creates a result with detected PII tokens.
      #
      # @param text [String] The scanned text
      # @param detections [Array<PIIToken>] Detected PII tokens
      # @param scan_time_ms [Numeric] Time taken to scan in milliseconds
      # @return [PIIDetectionResult]
      def self.found(text, detections, scan_time_ms:)
        new(text:, detections: Array(detections), scan_time_ms:)
      end
    end
  end
end
