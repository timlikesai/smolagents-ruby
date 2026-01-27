require "securerandom"

module Smolagents
  module Types
    # Token representing redacted PII. Supports reversible tokenization.
    #
    # PIIToken captures the original value and its position in text, allowing
    # for both redaction and restoration. The placeholder uses a short UUID
    # prefix for human readability while maintaining uniqueness.
    #
    # @example Creating a token
    #   token = PIIToken.create(:email, "user@example.com")
    #   token.placeholder  #=> "[PII:EMAIL:a1b2c3]"
    #   token.original     #=> "user@example.com"
    #
    # @example Token with position info
    #   token = PIIToken.create(:phone, "555-1234", position_start: 10, position_end: 18)
    #   token.length  #=> 8
    #
    # @see PIIDetectionResult For detection results containing tokens
    # @see PrivacyConfig For configuration options
    PIIToken = Data.define(:id, :pii_type, :original, :position_start, :position_end) do
      # Generates a placeholder string for this token.
      #
      # @return [String] Placeholder in format "[PII:TYPE:id_prefix]"
      def placeholder = "[PII:#{pii_type.to_s.upcase}:#{id[0..5]}]"

      # Length of the original PII text.
      #
      # @return [Integer] Character count of original text
      def length = position_end - position_start

      # Creates a new PIIToken with generated UUID.
      #
      # @param pii_type [Symbol] Type of PII (:email, :phone, :ssn, etc.)
      # @param original [String] Original PII value
      # @param position_start [Integer] Start position in source text
      # @param position_end [Integer, nil] End position (defaults to start + original length)
      # @return [PIIToken]
      def self.create(pii_type, original, position_start: 0, position_end: nil)
        actual_end = position_end || (position_start + original.to_s.length)
        new(
          id: SecureRandom.uuid,
          pii_type:,
          original:,
          position_start:,
          position_end: actual_end
        )
      end
    end
  end
end
