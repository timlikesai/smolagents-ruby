module Smolagents
  module SecretRedactor
    REDACTED = "[REDACTED]".freeze

    # Patterns for common API key formats
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

      def redact_string(str)
        result = str.dup
        SECRET_PATTERNS.each do |pattern|
          result.gsub!(pattern, REDACTED)
        end
        result
      end

      def redact_hash(hash)
        hash.transform_keys(&:to_s).transform_values do |v|
          if sensitive_key?(hash.keys.find { |k| hash[k] == v })
            REDACTED
          else
            redact(v)
          end
        end
      end

      def sensitive_key?(key)
        return false unless key

        key_str = key.to_s.downcase
        %w[api_key apikey key token secret password auth credential].any? { |s| key_str.include?(s) }
      end

      def looks_like_secret?(value)
        return false unless value.is_a?(String)
        return false if value.length < 16

        # Check if it matches common API key patterns
        SECRET_PATTERNS.any? { |p| value.match?(p) }
      end

      def safe_inspect(value)
        redact(value).inspect
      end
    end
  end
end
