module Smolagents
  module Types
    # Configuration for PII detection and protection.
    #
    # PrivacyConfig controls which PII types are detected and how they are
    # handled. Supports tokenization (reversible), masking (format-preserving),
    # and removal strategies.
    #
    # @example Default config (tokenize common PII)
    #   config = PrivacyConfig.default
    #   config.enabled?     #=> true
    #   config.tokenize?    #=> true
    #
    # @example Strict mode (all PII types)
    #   config = PrivacyConfig.strict
    #   config.pii_types    #=> [:email, :phone, :ssn, :credit_card, :api_key, ...]
    #
    # @example Custom (specific types only)
    #   config = PrivacyConfig.create(types: [:email, :phone], strategy: :mask)
    #   config.detects?(:email)  #=> true
    #   config.detects?(:ssn)    #=> false
    #
    # @see PIIToken For token structure
    # @see PIIDetectionResult For detection results
    PrivacyConfig = Data.define(
      :enabled,           # Boolean - whether privacy protection is active
      :pii_types,         # Array<Symbol> - types to detect
      :strategy,          # Symbol - :tokenize, :mask, :remove
      :preserve_format,   # Boolean - keep structure in masks (e.g., ***-**-1234)
      :audit_detections   # Boolean - emit events for detections
    ) do
      # @return [Array<Symbol>] Common PII types
      def self.common_types = %i[email phone ssn credit_card api_key].freeze

      # @return [Array<Symbol>] All supported PII types
      def self.all_types
        %i[email phone ssn credit_card api_key ip_address name address date_of_birth].freeze
      end

      # @return [Array<Symbol>] Valid protection strategies
      def self.valid_strategies = %i[tokenize mask remove].freeze

      # @return [PrivacyConfig] Default config with common types and tokenization
      def self.default
        new(
          enabled: true,
          pii_types: common_types,
          strategy: :tokenize,
          preserve_format: true,
          audit_detections: true
        )
      end

      # @return [PrivacyConfig] Strict config detecting all PII types
      def self.strict
        new(
          enabled: true,
          pii_types: all_types,
          strategy: :tokenize,
          preserve_format: true,
          audit_detections: true
        )
      end

      # @return [PrivacyConfig] Disabled privacy protection
      def self.disabled
        new(
          enabled: false,
          pii_types: [],
          strategy: :tokenize,
          preserve_format: true,
          audit_detections: false
        )
      end

      # Creates a validated custom configuration.
      #
      # @param types [Array<Symbol>] PII types to detect
      # @param strategy [Symbol] Protection strategy (:tokenize, :mask, :remove)
      # @param preserve_format [Boolean] Keep structure in masked values
      # @param audit [Boolean] Emit detection events
      # @raise [ArgumentError] If types or strategy are invalid
      # @return [PrivacyConfig]
      def self.create(types: common_types, strategy: :tokenize, preserve_format: true, audit: true)
        validate_types!(types)
        validate_strategy!(strategy)
        new(enabled: true, pii_types: types, strategy:, preserve_format:, audit_detections: audit)
      end

      class << self
        private

        def validate_types!(types)
          invalid = Array(types) - all_types
          return if invalid.empty?

          raise ArgumentError, "Invalid PII types: #{invalid.inspect}. Valid types: #{all_types.inspect}"
        end

        def validate_strategy!(strategy)
          return if valid_strategies.include?(strategy)

          raise ArgumentError,
                "strategy must be one of #{valid_strategies.inspect}, got #{strategy.inspect}"
        end
      end

      # @return [Boolean] Whether privacy protection is enabled
      def enabled? = enabled

      # @return [Boolean] Whether using tokenization strategy
      def tokenize? = strategy == :tokenize

      # @return [Boolean] Whether using masking strategy
      def mask? = strategy == :mask

      # @return [Boolean] Whether using removal strategy
      def remove? = strategy == :remove

      # Whether a specific PII type is being detected.
      #
      # @param type [Symbol] PII type to check
      # @return [Boolean]
      def detects?(type) = pii_types.include?(type)
    end
  end
end
