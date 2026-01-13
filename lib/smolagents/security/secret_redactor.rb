module Smolagents
  module Security
    # Redacts secrets and sensitive data from strings, hashes, and nested structures.
    #
    # SecretRedactor prevents accidental exposure of API keys, tokens, and passwords
    # in logs, error messages, and debug output. It recognizes common secret patterns
    # and sensitive hash keys.
    #
    # @example Redacting a string with embedded secrets
    #   text = "Using API key sk-1234567890abcdef1234567890abcdef"
    #   SecretRedactor.redact(text)
    #   # => "Using API key [REDACTED]"
    #
    # @example Redacting a hash with sensitive keys
    #   config = { api_key: "secret123", base_url: "https://api.example.com" }
    #   SecretRedactor.redact(config)
    #   # => {"api_key"=>"[REDACTED]", "base_url"=>"https://api.example.com"}
    #
    # @example Safe inspection for debugging
    #   SecretRedactor.safe_inspect(config)
    #   # => "{\"api_key\"=>\"[REDACTED]\", \"base_url\"=>\"https://api.example.com\"}"
    #
    module SecretRedactor
      # Placeholder text for redacted values
      REDACTED = "[REDACTED]".freeze

      # Patterns for common API key and secret formats
      SECRET_PATTERNS = [
        /sk-[a-zA-Z0-9]{20,}/, # OpenAI API keys
        /sk-proj-[a-zA-Z0-9_-]{20,}/, # OpenAI project keys
        /sk-ant-[a-zA-Z0-9_-]{20,}/, # Anthropic API keys (older format)
        /[a-z0-9]{64}/, # Generic 64-char hex tokens (many providers)
        /Bearer\s+[a-zA-Z0-9._-]+/i, # Bearer tokens
        /api[_-]?key["\s:=]+["']?[a-zA-Z0-9_-]{16,}/i, # Generic api_key patterns
        /token["\s:=]+["']?[a-zA-Z0-9._-]{16,}/i, # Generic token patterns
        /secret["\s:=]+["']?[a-zA-Z0-9._-]{16,}/i, # Generic secret patterns
        /password["\s:=]+["']?[^\s"']{8,}/i # Password patterns
      ].freeze

      class << self
        # Redacts secrets from any value, recursively handling nested structures.
        #
        # @param value [Object] Value to redact (String, Hash, Array, or other)
        # @return [Object] Value with secrets replaced by [REDACTED]
        def redact(value)
          return REDACTED if looks_like_secret?(value)

          case value
          when String
            redact_string(value)
          when Hash
            redact_hash(value)
          when Array
            value.map { |v| redact(v) }
          else
            value
          end
        end

        # Redacts secrets from a string using pattern matching.
        #
        # @param str [String] String to redact
        # @return [String] String with secret patterns replaced
        def redact_string(str)
          result = str.dup
          SECRET_PATTERNS.each do |pattern|
            result.gsub!(pattern, REDACTED)
          end
          result
        end

        # Redacts a hash, checking both keys and values.
        #
        # @param hash [Hash] Hash to redact
        # @return [Hash] Hash with sensitive values replaced
        def redact_hash(hash)
          hash.transform_keys(&:to_s).transform_values do |v|
            if sensitive_key?(hash.keys.find { |k| hash[k] == v })
              REDACTED
            else
              redact(v)
            end
          end
        end

        # Checks if a key name indicates sensitive data.
        #
        # @param key [String, Symbol, nil] Key name to check
        # @return [Boolean] True if key appears to hold sensitive data
        def sensitive_key?(key)
          return false unless key

          key_str = key.to_s.downcase
          %w[api_key apikey key token secret password auth credential].any? { |s| key_str.include?(s) }
        end

        # Checks if a value appears to be a secret based on patterns.
        #
        # @param value [Object] Value to check
        # @return [Boolean] True if value matches secret patterns
        def looks_like_secret?(value)
          return false unless value.is_a?(String)
          return false if value.length < 16

          # Check if it matches common API key patterns
          SECRET_PATTERNS.any? { |p| value.match?(p) }
        end

        # Returns a safely inspectable string with secrets redacted.
        #
        # @param value [Object] Value to inspect
        # @return [String] Redacted inspect output
        def safe_inspect(value)
          redact(value).inspect
        end
      end
    end
  end
end
