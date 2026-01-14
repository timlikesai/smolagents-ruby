require "base64"
require "tempfile"
require "securerandom"

module Smolagents
  module Types
    # Permitted image file formats for AgentImage.
    #
    # Restricts image handling to common web and universal formats.
    # Used by AgentImage to validate and sanitize format parameters.
    #
    # @return [Set<String>] Immutable set of allowed formats
    # @example Check if format is allowed
    #   ALLOWED_IMAGE_FORMATS.include?("png")  # => true
    #   ALLOWED_IMAGE_FORMATS.include?("heic")  # => false
    ALLOWED_IMAGE_FORMATS = Set.new(%w[png jpg jpeg gif webp bmp tiff svg ico]).freeze

    # Permitted audio file formats for AgentAudio.
    #
    # Restricts audio handling to common compressed and uncompressed formats.
    # Used by AgentAudio to validate and sanitize format parameters.
    #
    # @return [Set<String>] Immutable set of allowed formats
    # @example Check if format is allowed
    #   ALLOWED_AUDIO_FORMATS.include?("wav")  # => true
    #   ALLOWED_AUDIO_FORMATS.include?("m4a")  # => true
    ALLOWED_AUDIO_FORMATS = Set.new(%w[mp3 wav ogg flac m4a aac wma aiff]).freeze

    # Base class for agent-compatible data types.
    #
    # AgentType wraps values to provide consistent serialization and
    # conversion methods across different data types (text, image, audio).
    # Enables agents to work with multiple modalities in a unified way.
    #
    # Subclasses override to_raw, to_string, and optionally to_h for
    # type-specific handling.
    #
    # @abstract Subclass and implement conversion methods
    # @see AgentText For text data
    # @see AgentImage For image data
    # @see AgentAudio For audio data
    class AgentType
      # @return [Object] The wrapped value (String, bytes, path, etc.)
      attr_reader :value

      # Creates a new AgentType wrapping the given value.
      #
      # @param value [Object] The value to wrap (type depends on subclass)
      # @return [AgentType] Initialized wrapper
      # @example
      #   text = AgentText.new("Hello")
      #   image = AgentImage.new("/path/to/image.jpg")
      def initialize(value)
        @value = value
      end

      # Converts to string (uses to_string).
      #
      # @return [String] String representation
      # @example
      #   text.to_s  # => "Hello"
      def to_s
        to_string
      end

      # Returns the raw unwrapped value.
      #
      # Subclasses override to provide type-specific raw representation
      # (e.g., file bytes for images, PCM bytes for audio).
      #
      # @return [Object] Raw value for tool execution
      # @example
      #   image.to_raw  # => binary file content
      def to_raw
        @value
      end

      # Returns a string representation suitable for agent input.
      #
      # Subclasses override to provide type-specific string output
      # (e.g., file path for images, JSON for audio metadata).
      #
      # @return [String] String representation for agents
      # @example
      #   image.to_string  # => "/tmp/agent_image_xyz.jpg"
      def to_string
        @value.to_s
      end

      # Converts to hash for serialization.
      #
      # Default implementation includes type and stringified value.
      # Subclasses override to include format, paths, etc.
      #
      # @return [Hash] Hash with :type and :value keys
      # @example
      #   text.to_h  # => { type: "agenttext", value: "Hello" }
      def to_h
        { type: self.class.name.split("::").last.downcase, value: to_string }
      end
    end

    # Text data type for agent communication.
    #
    # Wraps string content for consistent handling with other agent types
    # (image, audio). Provides string-like methods and concatenation.
    #
    # @example Creating text
    #   text = Types::AgentText.new("Hello, world!")
    #   text.length  # => 13
    #   text.to_s    # => "Hello, world!"
    #
    # @example String operations
    #   combined = AgentText.new("Hello") + AgentText.new(" world")
    #   combined.to_s  # => "Hello world"
    #
    # @see AgentType For base class
    # @see AgentImage For binary data
    class AgentText < AgentType
      # Returns raw string value.
      #
      # @return [String] The wrapped text
      # @example
      #   text.to_raw  # => "Hello"
      def to_raw
        value.to_s
      end

      # Returns string representation (same as raw for text).
      #
      # @return [String] The wrapped text
      # @example
      #   text.to_string  # => "Hello"
      def to_string
        value.to_s
      end

      # Concatenates two AgentText objects.
      #
      # @param other [AgentText, #to_s] Object to concatenate
      # @return [AgentText] New combined text
      # @example
      #   text1 = AgentText.new("Hello")
      #   text2 = AgentText.new(" world")
      #   combined = text1 + text2  # => "Hello world"
      def +(other)
        AgentText.new(value.to_s + other.to_s)
      end

      # Returns the length of the text.
      #
      # @return [Integer] Number of characters
      # @example
      #   AgentText.new("hello").length  # => 5
      def length
        value.to_s.length
      end

      # Checks if text is empty.
      #
      # @return [Boolean] True if text has zero length
      # @example
      #   AgentText.new("").empty?  # => true
      def empty?
        value.to_s.empty?
      end

      # Checks equality with another text object.
      #
      # @param other [AgentText, #to_s] Object to compare
      # @return [Boolean] True if string representations match
      # @example
      #   AgentText.new("hello") == AgentText.new("hello")  # => true
      def ==(other)
        to_string == other.to_s
      end
    end

    # Image data type supporting files, URLs, and base64.
    #
    # Intelligently handles local files, data URIs, and remote URLs.
    # Automatically detects format and handles encoding/decoding.
    # Validates formats against ALLOWED_IMAGE_FORMATS.
    #
    # @example From file
    #   image = Types::AgentImage.from_file("photo.jpg")
    #   image.to_data_uri  # => "data:image/jpeg;base64,..."
    #
    # @example From base64
    #   image = Types::AgentImage.from_base64(encoded_data, format: "png")
    #   image.to_raw  # => binary PNG data
    #
    # @example Converting to data URI
    #   image.to_data_uri  # => "data:image/png;base64,..."
    #
    # @see AgentType For base class
    # @see AgentAudio For audio files
    class AgentImage < AgentType
      # @return [String, nil] File path if this image is on disk
      attr_reader :path

      # @return [String] Image format (png, jpg, etc.)
      attr_reader :format

      # Creates an AgentImage, auto-detecting source type and format.
      #
      # Intelligently handles:
      # - File paths (validates file exists and detects format from extension)
      # - Data URIs (base64 encoded)
      # - Raw base64 strings
      # - Binary data
      # - AgentImage instances (copies)
      #
      # @param value [String, AgentImage, IO, #read] Image source
      # @param format [String, nil] Override detected format (png, jpg, etc.)
      # @return [AgentImage] Initialized image wrapper
      # @example
      #   AgentImage.new("photo.jpg")  # File path
      #   AgentImage.new("data:image/png;base64,...")  # Data URI
      #   AgentImage.new(binary_data, format: "png")  # Raw bytes
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

      # Creates an AgentImage from base64-encoded data.
      #
      # @param base64_string [String] Base64 encoded image data
      # @param format [String] Image format (png, jpg, etc.)
      # @return [AgentImage] Image wrapper with decoded bytes
      # @example
      #   image = AgentImage.from_base64(encoded_png, format: "png")
      def self.from_base64(base64_string, format: "png")
        bytes = Base64.decode64(base64_string)
        new(bytes, format:)
      end

      # Creates an AgentImage from a file path.
      #
      # @param path [String] Path to image file
      # @return [AgentImage] Image wrapper
      # @raise [ArgumentError] If file doesn't exist
      # @example
      #   image = AgentImage.from_file("photo.jpg")
      def self.from_file(path)
        new(path)
      end

      # Returns raw binary image data.
      #
      # Reads from in-memory bytes or disk file as needed.
      #
      # @return [String, nil] Binary image data, or nil if unavailable
      # @example
      #   raw = image.to_raw  # => "\x89PNG\r\n\x1a\n..."
      def to_raw
        return @raw_bytes if @raw_bytes
        return File.binread(@path) if @path && File.exist?(@path)

        nil
      end

      # Returns base64-encoded image data.
      #
      # @return [String, nil] Base64 string, or nil if no data
      # @example
      #   b64 = image.to_base64  # => "iVBORw0KGgoAAAA..."
      def to_base64
        raw = to_raw
        raw ? Base64.strict_encode64(raw) : nil
      end

      # Returns data URI suitable for HTML/API use.
      #
      # @return [String, nil] Data URI (data:image/format;base64,...), or nil
      # @example
      #   uri = image.to_data_uri
      #   # => "data:image/png;base64,iVBORw0KGgoAAAA..."
      def to_data_uri
        encoded = to_base64
        encoded ? "data:image/#{@format};base64,#{encoded}" : nil
      end

      # Returns string representation (file path or temp file).
      #
      # For file-backed images, returns the path. For bytes,
      # saves to temp file and returns temp path.
      #
      # @return [String, nil] File path to image
      # @example
      #   path = image.to_string  # => "/tmp/agent_image_xyz.png"
      def to_string
        return @path if @path

        save_to_temp
      end

      # Saves image to file.
      #
      # @param output_path [String] Destination file path
      # @param format [String, nil] Format override (unused, kept for compatibility)
      # @return [String] Path written to
      # @raise [ArgumentError] If image has no data to write
      # @example
      #   image.save("output.png")  # => "output.png"
      def save(output_path, format: nil)
        raw = to_raw
        raise ArgumentError, "No image data to save" unless raw

        File.binwrite(output_path, raw)
        output_path
      end

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :type, :format, :path, and :base64 preview
      # @example
      #   image.to_h  # => { type: "image", format: "png", path: "/tmp/...", base64: "iVBORw0..." }
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
    # Wraps audio content with format and sample rate information.
    # Handles file paths, raw bytes, and automatically calculates
    # duration for WAV files. Validates formats against ALLOWED_AUDIO_FORMATS.
    #
    # @example From file
    #   audio = Types::AgentAudio.from_file("recording.wav", samplerate: 44100)
    #   audio.duration  # => 3.5 (seconds)
    #
    # @example From raw bytes
    #   audio = Types::AgentAudio.new(pcm_bytes, samplerate: 16000, format: "wav")
    #   audio.to_string  # => "/tmp/agent_audio_xyz.wav"
    #
    # @example Converting to file
    #   audio.save("output.wav")  # => "output.wav"
    #
    # @see AgentType For base class
    # @see AgentImage For image files
    class AgentAudio < AgentType
      # @return [String, nil] File path if this audio is on disk
      attr_reader :path

      # @return [Integer] Sample rate in Hz (typically 16000 or 44100)
      attr_reader :samplerate

      # @return [String] Audio format (wav, mp3, etc.)
      attr_reader :format

      # Creates an AgentAudio, auto-detecting source and format.
      #
      # Intelligently handles:
      # - File paths (validates file exists and detects format from extension)
      # - Raw byte data
      # - AgentAudio instances (copies with sample rate preservation)
      # - IO objects with read method
      #
      # @param value [String, AgentAudio, IO, #read] Audio source
      # @param samplerate [Integer] Sample rate in Hz (default 16000)
      # @param format [String, nil] Override detected format (wav, mp3, etc.)
      # @return [AgentAudio] Initialized audio wrapper
      # @example
      #   AgentAudio.new("recording.wav")  # File path
      #   AgentAudio.new(pcm_bytes, samplerate: 16000, format: "wav")  # Raw bytes
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

      # Creates an AgentAudio from a file path.
      #
      # @param path [String] Path to audio file
      # @param samplerate [Integer, nil] Override sample rate in Hz
      # @return [AgentAudio] Audio wrapper
      # @raise [ArgumentError] If file doesn't exist
      # @example
      #   audio = AgentAudio.from_file("recording.wav", samplerate: 44100)
      def self.from_file(path, samplerate: nil)
        audio = new(path)
        audio.instance_variable_set(:@samplerate, samplerate) if samplerate
        audio
      end

      # Returns raw binary audio data.
      #
      # Reads from in-memory bytes or disk file as needed.
      #
      # @return [String, nil] Binary audio data, or nil if unavailable
      # @example
      #   raw = audio.to_raw  # => PCM/WAV bytes
      def to_raw
        return @raw_bytes if @raw_bytes
        return File.binread(@path) if @path && File.exist?(@path)

        nil
      end

      # Returns base64-encoded audio data.
      #
      # @return [String, nil] Base64 string, or nil if no data
      # @example
      #   b64 = audio.to_base64  # => "UklGRiY..."
      def to_base64
        raw = to_raw
        raw ? Base64.strict_encode64(raw) : nil
      end

      # Returns string representation (file path or temp file).
      #
      # For file-backed audio, returns the path. For bytes,
      # saves to temp file and returns temp path.
      #
      # @return [String, nil] File path to audio
      # @example
      #   path = audio.to_string  # => "/tmp/agent_audio_xyz.wav"
      def to_string
        return @path if @path

        save_to_temp
      end

      # Saves audio to file.
      #
      # @param output_path [String] Destination file path
      # @return [String] Path written to
      # @raise [ArgumentError] If audio has no data to write
      # @example
      #   audio.save("output.wav")  # => "output.wav"
      def save(output_path)
        raw = to_raw
        raise ArgumentError, "No audio data to save" unless raw

        File.binwrite(output_path, raw)
        output_path
      end

      # Calculates audio duration in seconds.
      #
      # Only works for WAV format. Uses WAV header to calculate
      # based on sample rate and byte size.
      #
      # @return [Float, nil] Duration in seconds, or nil if not WAV or no data
      # @example
      #   audio.duration  # => 3.456
      def duration
        raw = to_raw
        return nil unless raw && @format == "wav"

        data_size = raw.bytesize - 44
        return nil if data_size <= 0

        samples = data_size / 2
        samples.to_f / @samplerate
      end

      # Converts to hash for serialization.
      #
      # @return [Hash] Hash with :type, :format, :samplerate, :path, :duration
      # @example
      #   audio.to_h
      #   # => { type: "audio", format: "wav", samplerate: 16000, path: "/tmp/...", duration: 3.456 }
      def to_h
        {
          type: "audio",
          format: @format,
          samplerate: @samplerate,
          path: @path,
          duration:
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

    # Maps type strings to AgentType classes for dynamic wrapper instantiation.
    #
    # Enables tools to specify output types as strings, which are then converted
    # to the appropriate AgentType wrapper class. Aliases like "string" and "text"
    # both map to AgentText for convenience.
    #
    # @return [Hash{String => Class}] Immutable mapping of type names to AgentType classes
    #
    # @example Get wrapper class for type
    #   AGENT_TYPE_MAPPING["text"]   # => AgentText
    #   AGENT_TYPE_MAPPING["image"]  # => AgentImage
    #   AGENT_TYPE_MAPPING["audio"]  # => AgentAudio
    #
    # @example Use in tool output handling
    #   type_class = AGENT_TYPE_MAPPING[output_type]
    #   wrapped = type_class.new(raw_value) if type_class
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
