module Smolagents
  module Types
    # Image data type supporting files, URLs, and base64.
    #
    # Intelligently handles local files, data URIs, and remote URLs.
    # Validates formats against ALLOWED_IMAGE_FORMATS.
    #
    # @example From file
    #   image = Types::AgentImage.from_file("photo.jpg")
    #   image.to_data_uri  # => "data:image/jpeg;base64,..."
    #
    # @example From base64
    #   image = Types::AgentImage.from_base64(encoded_data, format: "png")
    class AgentImage < AgentType
      # @return [String, nil] File path if on disk
      attr_reader :path

      # @return [String] Image format (png, jpg, etc.)
      attr_reader :format

      # Creates an AgentImage, auto-detecting source type and format.
      #
      # @param value [String, AgentImage, IO] Image source
      # @param format [String, nil] Override detected format
      def initialize(value, format: nil)
        super(value)
        @path = nil
        @raw_bytes = nil
        @format = sanitize_format(format || "png", ALLOWED_IMAGE_FORMATS)

        case value
        when AgentImage then copy_from_image(value)
        when String then parse_string_value(value)
        else @raw_bytes = value.respond_to?(:read) ? value.read : value
        end
      end

      # Creates an AgentImage from base64-encoded data.
      #
      # @param base64_string [String] Base64 encoded image data
      # @param format [String] Image format
      # @return [AgentImage]
      def self.from_base64(base64_string, format: "png")
        new(Base64.decode64(base64_string), format:)
      end

      # Creates an AgentImage from a file path.
      #
      # @param path [String] Path to image file
      # @return [AgentImage]
      def self.from_file(path) = new(path)

      # Returns raw binary image data.
      # @return [String, nil]
      def to_raw
        return @raw_bytes if @raw_bytes
        return File.binread(@path) if @path && File.exist?(@path)

        nil
      end

      # Returns base64-encoded image data.
      # @return [String, nil]
      def to_base64 = to_raw&.then { Base64.strict_encode64(it) }

      # Returns data URI suitable for HTML/API use.
      # @return [String, nil]
      def to_data_uri = to_base64&.then { "data:image/#{@format};base64,#{it}" }

      # Returns string representation (file path or temp file).
      # @return [String, nil]
      def to_string = @path || save_to_temp("agent_image_")

      # Saves image to file.
      #
      # @param output_path [String] Destination file path
      # @param format [String, nil] Format override (unused)
      # @return [String] Path written to
      def save(output_path, format: nil)
        raw = to_raw
        raise ArgumentError, "No image data to save" unless raw

        File.binwrite(output_path, raw)
        output_path
      end

      # Converts to hash for serialization.
      # @return [Hash]
      def to_h
        {
          type: "image",
          format: @format,
          path: @path,
          base64: to_base64&.slice(0, 50)&.then { |preview| "#{preview}..." }
        }.compact
      end

      private

      def copy_from_image(image)
        @path = image.path
        @raw_bytes = image.instance_variable_get(:@raw_bytes)
        @format = image.format
      end

      def parse_string_value(value)
        if file_path?(value) then parse_file_path(value)
        elsif (match = data_uri_match(value)) then parse_data_uri(match)
        elsif base64_string?(value) then @raw_bytes = Base64.decode64(value)
        elsif text_value?(value) then @path = safe_path(value)
        else @raw_bytes = value
        end
      end

      def parse_file_path(value)
        @path = safe_path(value)
        @format = format_from_extension(value)
      end

      def parse_data_uri(match)
        @format = sanitize_format(match[1], ALLOWED_IMAGE_FORMATS)
        @raw_bytes = Base64.decode64(match[2])
      end

      # String type predicates
      def file_path?(value) = value.valid_encoding? && !value.include?("\x00") && File.exist?(value)
      def data_uri_match(value) = value.start_with?("data:image") && value.match(%r{data:image/(\w+);base64,(.+)})
      def base64_string?(value) = value.valid_encoding? && value.match?(%r{^[A-Za-z0-9+/=]+$}) && value.length > 100
      def text_value?(value) = value.valid_encoding? && !value.include?("\x00")

      def format_from_extension(path)
        File.extname(path).delete(".").downcase.then do
          sanitize_format(it.empty? ? "png" : it, ALLOWED_IMAGE_FORMATS)
        end
      end
    end
  end
end
