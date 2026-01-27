require_relative "privacy/pii_detector"
require_relative "privacy/pii_protection"

module Smolagents
  # Privacy-first PII detection and protection.
  #
  # The Privacy module provides tools for detecting and protecting personally
  # identifiable information (PII) in text. It supports multiple protection
  # strategies: tokenization (reversible), masking (format-preserving), and
  # removal.
  #
  # == Components
  #
  # - {PIIDetector} - Regex-based PII detection with configurable patterns
  # - {PIIProtection} - PII redaction with tokenize/mask/remove strategies
  #
  # @example Basic protection with tokenization (reversible)
  #   protection = Smolagents::Privacy::PIIProtection.new
  #   protected = protection.protect("Email: user@example.com")
  #   protected.include?("[PII:EMAIL:")  #=> true
  #   original = protection.restore(protected)
  #   original  #=> "Email: user@example.com"
  #
  # @example Detection only
  #   detector = Smolagents::Privacy::PIIDetector.new
  #   result = detector.scan("Call 555-123-4567")
  #   result.detected?  #=> true
  #   result.types      #=> [:phone]
  #
  # @example Masking (format-preserving, not reversible)
  #   config = Smolagents::Types::PrivacyConfig.create(strategy: :mask)
  #   protection = Smolagents::Privacy::PIIProtection.new(config)
  #   protection.protect("Call 555-123-4567")
  #   # => "Call ***-***-****"
  #
  # @see Types::PrivacyConfig For configuration options
  # @see Types::PIIDetectionResult For detection results
  # @see Types::PIIToken For individual PII tokens
  module Privacy
  end
end
