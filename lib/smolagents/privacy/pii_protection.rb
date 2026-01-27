module Smolagents
  module Privacy
    # Protects text by redacting/tokenizing PII.
    #
    # PIIProtection provides a complete protect/restore cycle for sensitive data.
    # By default, it uses tokenization (reversible) so original values can be
    # restored after processing. Alternative strategies include masking and removal.
    #
    # @example Basic usage (tokenize - default, reversible)
    #   protection = PIIProtection.new
    #   protected_text = protection.protect("Email: user@example.com")
    #   protected_text.include?("[PII:EMAIL:")  #=> true
    #   original = protection.restore(protected_text)
    #   original  #=> "Email: user@example.com"
    #
    # @example Masking (not reversible)
    #   config = Types::PrivacyConfig.create(strategy: :mask)
    #   protection = PIIProtection.new(config)
    #   protection.protect("Call 555-123-4567")
    #   # => "Call ***-***-****"
    #
    # @example Removal (not reversible)
    #   config = Types::PrivacyConfig.create(strategy: :remove)
    #   protection = PIIProtection.new(config)
    #   protection.protect("Email: user@example.com")
    #   # => "Email: "
    #
    # @see Types::PrivacyConfig For configuration options
    # @see Types::PIIToken For token structure
    # @see PIIDetector For detection implementation
    class PIIProtection
      # @return [Types::PrivacyConfig] Current privacy configuration
      attr_reader :config

      # Creates a new PIIProtection instance.
      #
      # @param config [Types::PrivacyConfig] Privacy configuration
      def initialize(config = Types::PrivacyConfig.default)
        @config = config
        @detector = PIIDetector.new(config)
        @token_registry = {}
        @mutex = Mutex.new
      end

      # Protect text by redacting PII according to configured strategy.
      #
      # @param text [String] Text to protect
      # @return [String] Protected text with PII redacted/tokenized/removed
      def protect(text)
        return text unless @config.enabled?

        result = @detector.scan(text)
        return text unless result.detected?

        apply_protection(text, result.detections)
      end

      # Restore original text from protected version.
      #
      # Only works with :tokenize strategy. For :mask and :remove strategies,
      # the original values cannot be recovered.
      #
      # @param text [String] Protected text with tokens
      # @return [String] Original text with PII values restored
      def restore(text)
        return text unless @config.tokenize?

        @mutex.synchronize do
          result = text.dup
          @token_registry.each_value do |token|
            result.gsub!(token.placeholder, token.original)
          end
          result
        end
      end

      # Clear the token registry, releasing stored PII values.
      #
      # Call this after restore when tokens are no longer needed.
      #
      # @return [void]
      def clear_registry
        @mutex.synchronize { @token_registry.clear }
      end

      # Number of tokens currently stored in the registry.
      #
      # @return [Integer] Token count
      def registry_size
        @mutex.synchronize { @token_registry.size }
      end

      private

      def apply_protection(text, detections)
        result = text.dup
        # Apply in reverse order to preserve positions
        detections.sort_by(&:position_start).reverse_each do |token|
          replacement = replacement_for(token)
          result[token.position_start...token.position_end] = replacement
        end
        result
      end

      def replacement_for(token)
        case @config.strategy
        when :tokenize
          register_token(token)
          token.placeholder
        when :mask
          mask_value(token)
        when :remove
          ""
        end
      end

      def register_token(token)
        @mutex.synchronize { @token_registry[token.id] = token }
      end

      def mask_value(token)
        if @config.preserve_format
          token.original.gsub(/[a-zA-Z0-9]/, "*")
        else
          "*" * token.length
        end
      end
    end
  end
end
