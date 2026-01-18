module Smolagents
  module Http
    class UserAgent
      # Model ID sanitization for User-Agent strings.
      #
      # Transforms raw model identifiers into safe, consistent strings by:
      # - Removing path components (org prefixes, directories)
      # - Removing file extensions (.gguf, .bin, .pt, .safetensors)
      # - Removing date stamps (8+ digit suffixes)
      # - Replacing invalid characters with underscores
      # - Limiting length to MAX_MODEL_ID_LENGTH
      module Sanitizer
        # File extensions commonly used for model files
        EXTENSIONS = %w[gguf bin pt safetensors].freeze

        # Regex patterns for sanitization transformations
        PATTERNS = {
          extension: /\.(#{EXTENSIONS.join("|")})$/i,
          date_stamp: /-\d{8,}$/,
          invalid_chars: /[^a-zA-Z0-9\-_.]/
        }.freeze

        # Sanitizes a model ID for use in User-Agent strings.
        #
        # @param model_id [String, nil] Raw model identifier
        # @param max_length [Integer] Maximum allowed length
        # @return [String, nil] Sanitized model identifier, or nil if empty
        def self.sanitize(model_id, max_length:)
          return nil if model_id.nil? || model_id.to_s.empty?

          base = extract_base_name(model_id)
          return nil if base.nil? || base.empty?

          sanitized = apply_transformations(base, max_length)
          sanitized.empty? ? nil : sanitized
        end

        # Extracts the base filename from a path.
        #
        # @param model_id [String] Model identifier possibly containing path
        # @return [String, nil] Base filename
        def self.extract_base_name(model_id)
          model_id.to_s.split("/").last
        end

        # Applies all sanitization transformations.
        #
        # @param base [String] Base model name
        # @param max_length [Integer] Maximum allowed length
        # @return [String] Sanitized model name
        def self.apply_transformations(base, max_length)
          base
            .gsub(PATTERNS[:extension], "")
            .gsub(PATTERNS[:date_stamp], "")
            .gsub(PATTERNS[:invalid_chars], "_")
            .slice(0, max_length)
        end

        private_class_method :extract_base_name, :apply_transformations
      end
    end
  end
end
