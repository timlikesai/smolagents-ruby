require "base64"
require "tempfile"
require "securerandom"

module Smolagents
  module Types
    ALLOWED_IMAGE_FORMATS = Set.new(%w[png jpg jpeg gif webp bmp tiff svg ico]).freeze
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
      attr_reader :value

      def initialize(value)
        @value = value
      end

      def to_s
        to_string
      end

      def to_raw
        @value
      end

      def to_string
        @value.to_s
      end

      def to_h
        { type: self.class.name.split("::").last.downcase, value: to_string }
      end
    end

    # Text data type for agent communication.
    #
    # @example Creating text
    #   text = Types::AgentText.new("Hello, world!")
    #   text.length  # => 13
    class AgentText < AgentType
      def to_raw
        value.to_s
      end

      def to_string
        value.to_s
      end

      def +(other)
        AgentText.new(value.to_s + other.to_s)
      end

      def length
        value.to_s.length
      end

      def empty?
        value.to_s.empty?
      end

      def ==(other)
        to_string == other.to_s
      end
    end

    # Image data type supporting files, URLs, and base64.
    #
    # @example From file
    #   image = Types::AgentImage.from_file("photo.jpg")
    #
    # @example From base64
    #   image = Types::AgentImage.from_base64(encoded_data, format: "png")
    #
    # @example Converting to data URI
    #   image.to_data_uri  # => "data:image/png;base64,..."
    class AgentImage < AgentType
      attr_reader :path, :format

      def initialize(value, format: nil)
        super(value)
        @path = nil
        @raw_bytes = nil
        @format = sanitize_format(format || "png", ALLOWED_IMAGE_FORMATS)

        case value
        when AgentImage
          @path = value.path
          @raw_bytes = value.instance_variable_get(:@raw_bytes)
          @format = value.format
        when String
          if value.valid_encoding? && !value.include?("\x00") && File.exist?(value)
            @path = safe_path(value)
            ext = File.extname(value).delete(".").downcase
            @format = sanitize_format(ext.empty? ? "png" : ext, ALLOWED_IMAGE_FORMATS)
          elsif value.start_with?("data:image")
            match = value.match(%r{data:image/(\w+);base64,(.+)})
            if match
              @format = sanitize_format(match[1], ALLOWED_IMAGE_FORMATS)
              @raw_bytes = Base64.decode64(match[2])
            end
          elsif value.valid_encoding? && value.match?(%r{^[A-Za-z0-9+/=]+$}) && value.length > 100
            @raw_bytes = Base64.decode64(value)
          elsif value.valid_encoding? && !value.include?("\x00")
            @path = safe_path(value)
          else
            @raw_bytes = value
          end
        else
          @raw_bytes = value.respond_to?(:read) ? value.read : value
        end
      end

      def self.from_base64(base64_string, format: "png")
        bytes = Base64.decode64(base64_string)
        new(bytes, format: format)
      end

      def self.from_file(path)
        new(path)
      end

      def to_raw
        return @raw_bytes if @raw_bytes
        return File.binread(@path) if @path && File.exist?(@path)

        nil
      end

      def to_base64
        raw = to_raw
        raw ? Base64.strict_encode64(raw) : nil
      end

      def to_data_uri
        encoded = to_base64
        encoded ? "data:image/#{@format};base64,#{encoded}" : nil
      end

      def to_string
        return @path if @path

        save_to_temp
      end

      def save(output_path, format: nil)
        raw = to_raw
        raise ArgumentError, "No image data to save" unless raw

        File.binwrite(output_path, raw)
        output_path
      end

      def to_h
        {
          type: "image",
          format: @format,
          path: @path,
          base64: to_base64&.slice(0, 50)&.then { |preview| "#{preview}..." }
        }.compact
      end

      private

      def save_to_temp
        return @path if @path

        raw = to_raw
        return nil unless raw

        tmpfile = Tempfile.new(["agent_image_", ".#{@format}"])
        tmpfile.binmode
        tmpfile.write(raw)
        tmpfile.close
        @path = tmpfile.path
        @path
      end

      def sanitize_format(fmt, allowed)
        clean = fmt.to_s.downcase.gsub(/[^a-z0-9]/, "")
        allowed.include?(clean) ? clean : allowed.first
      end

      def safe_path(path)
        return path unless path.is_a?(String)

        expanded = File.expand_path(path)
        expanded.include?("..") ? nil : expanded
      end
    end

    # Audio data type supporting files and raw bytes.
    #
    # @example From file
    #   audio = Types::AgentAudio.from_file("recording.wav", samplerate: 44100)
    #
    # @example Checking duration
    #   audio.duration  # => 3.5 (seconds)
    class AgentAudio < AgentType
      attr_reader :path, :samplerate, :format

      def initialize(value, samplerate: 16_000, format: nil)
        super(value)
        @samplerate = samplerate
        @path = nil
        @raw_bytes = nil
        @format = sanitize_format(format || "wav", ALLOWED_AUDIO_FORMATS)

        case value
        when AgentAudio
          @path = value.path
          @raw_bytes = value.instance_variable_get(:@raw_bytes)
          @samplerate = value.samplerate
          @format = value.format
        when String
          if value.valid_encoding? && !value.include?("\x00") && File.exist?(value)
            @path = safe_path(value)
            ext = File.extname(value).delete(".").downcase
            @format = sanitize_format(ext.empty? ? "wav" : ext, ALLOWED_AUDIO_FORMATS)
          elsif value.valid_encoding? && !value.include?("\x00")
            @path = safe_path(value)
          else
            @raw_bytes = value
          end
        when Array
          @samplerate = value[0]
          @raw_bytes = value[1]
        else
          @raw_bytes = value.respond_to?(:read) ? value.read : value
        end
      end

      def self.from_file(path, samplerate: nil)
        audio = new(path)
        audio.instance_variable_set(:@samplerate, samplerate) if samplerate
        audio
      end

      def to_raw
        return @raw_bytes if @raw_bytes
        return File.binread(@path) if @path && File.exist?(@path)

        nil
      end

      def to_base64
        raw = to_raw
        raw ? Base64.strict_encode64(raw) : nil
      end

      def to_string
        return @path if @path

        save_to_temp
      end

      def save(output_path)
        raw = to_raw
        raise ArgumentError, "No audio data to save" unless raw

        File.binwrite(output_path, raw)
        output_path
      end

      def duration
        raw = to_raw
        return nil unless raw && @format == "wav"

        data_size = raw.bytesize - 44
        return nil if data_size <= 0

        samples = data_size / 2
        samples.to_f / @samplerate
      end

      def to_h
        {
          type: "audio",
          format: @format,
          samplerate: @samplerate,
          path: @path,
          duration: duration
        }.compact
      end

      private

      def save_to_temp
        return @path if @path

        raw = to_raw
        return nil unless raw

        tmpfile = Tempfile.new(["agent_audio_", ".#{@format}"])
        tmpfile.binmode
        tmpfile.write(raw)
        tmpfile.close
        @path = tmpfile.path
        @path
      end

      def sanitize_format(fmt, allowed)
        clean = fmt.to_s.downcase.gsub(/[^a-z0-9]/, "")
        allowed.include?(clean) ? clean : allowed.first
      end

      def safe_path(path)
        return path unless path.is_a?(String)

        expanded = File.expand_path(path)
        expanded.include?("..") ? nil : expanded
      end
    end

    AGENT_TYPE_MAPPING = {
      "string" => AgentText,
      "text" => AgentText,
      "image" => AgentImage,
      "audio" => AgentAudio
    }.freeze
  end

  # Helper to convert AgentType instances to raw values for tool input.
  #
  # @param args [Array] Positional arguments
  # @param kwargs [Hash] Keyword arguments
  # @return [Array<Array, Hash>] Converted args and kwargs
  def self.handle_agent_input_types(*args, **kwargs)
    args = args.map { |arg| arg.is_a?(Types::AgentType) ? arg.to_raw : arg }
    kwargs = kwargs.transform_values { |val| val.is_a?(Types::AgentType) ? val.to_raw : val }
    [args, kwargs]
  end

  # Helper to wrap tool output in appropriate AgentType.
  #
  # @param output [Object] Raw tool output
  # @param output_type [String, nil] Expected output type
  # @return [AgentType, Object] Wrapped or original output
  def self.handle_agent_output_types(output, output_type: nil)
    return Types::AGENT_TYPE_MAPPING[output_type].new(output) if output_type && Types::AGENT_TYPE_MAPPING[output_type]

    case output
    when String
      Types::AgentText.new(output)
    when Types::AgentType
      output
    else
      output
    end
  end
end
