require "base64"
require "tempfile"
require "securerandom"

module Smolagents
  module Types
    # Permitted image file formats for AgentImage.
    #
    # @return [Set<String>] Immutable set of allowed formats
    ALLOWED_IMAGE_FORMATS = Set.new(%w[png jpg jpeg gif webp bmp tiff svg ico]).freeze

    # Permitted audio file formats for AgentAudio.
    #
    # @return [Set<String>] Immutable set of allowed formats
    ALLOWED_AUDIO_FORMATS = Set.new(%w[mp3 wav ogg flac m4a aac wma aiff]).freeze

    # Base class for agent-compatible data types.
    #
    # AgentType wraps values to provide consistent serialization and
    # conversion methods across different data types (text, image, audio).
    #
    # @abstract Subclass and implement conversion methods
    # @see AgentText For text data
    # @see AgentImage For image data
    # @see AgentAudio For audio data
    class AgentType
      # @return [Object] The wrapped value
      attr_reader :value

      # Creates a new AgentType wrapping the given value.
      #
      # @param value [Object] The value to wrap
      def initialize(value)
        @value = value
      end

      # Converts to string (uses to_string).
      # @return [String]
      def to_s = to_string

      # Returns the raw unwrapped value.
      # @return [Object]
      def to_raw = @value

      # Returns a string representation suitable for agent input.
      # @return [String]
      def to_string = @value.to_s

      # Converts to hash for serialization.
      # @return [Hash]
      def to_h = { type: self.class.name.split("::").last.downcase, value: to_string }

      private

      # Sanitizes a format string to only contain allowed characters.
      #
      # @param fmt [String] Format to sanitize
      # @param allowed [Set<String>] Allowed format values
      # @return [String] Sanitized format, or first allowed value if invalid
      def sanitize_format(fmt, allowed)
        cleaned = fmt.to_s.downcase.gsub(/[^a-z0-9]/, "")
        allowed.include?(cleaned) ? cleaned : allowed.first
      end

      # Validates and expands a file path, preventing directory traversal.
      #
      # @param path [String] Path to validate
      # @return [String, nil] Expanded path, or nil if path traversal detected
      def safe_path(path)
        return path unless path.is_a?(String)

        File.expand_path(path).then { it.include?("..") ? nil : it }
      end

      # Saves binary data to a temp file with the given prefix.
      #
      # @param prefix [String] Prefix for temp filename
      # @return [String, nil] Path to temp file, or nil if no data
      def save_to_temp(prefix)
        return @path if @path

        raw = to_raw
        return nil unless raw

        tmpfile = Tempfile.new([prefix, ".#{@format}"])
        tmpfile.binmode
        tmpfile.write(raw)
        tmpfile.close
        @path = tmpfile.path
      end
    end
  end
end
