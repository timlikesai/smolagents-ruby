module Smolagents
  module Types
    # Audio data type supporting files and raw bytes.
    #
    # Wraps audio content with format and sample rate information.
    # Validates formats against ALLOWED_AUDIO_FORMATS.
    #
    # @example From file
    #   audio = Types::AgentAudio.from_file("recording.wav", samplerate: 44100)
    #   audio.duration  # => 3.5 (seconds)
    #
    # @example From raw bytes
    #   audio = Types::AgentAudio.new(pcm_bytes, samplerate: 16000, format: "wav")
    class AgentAudio < AgentType
      # @return [String, nil] File path if on disk
      attr_reader :path

      # @return [Integer] Sample rate in Hz
      attr_reader :samplerate

      # @return [String] Audio format (wav, mp3, etc.)
      attr_reader :format

      # Creates an AgentAudio, auto-detecting source and format.
      #
      # @param value [String, AgentAudio, IO] Audio source
      # @param samplerate [Integer] Sample rate in Hz (default 16000)
      # @param format [String, nil] Override detected format
      def initialize(value, samplerate: 16_000, format: nil)
        super(value)
        @samplerate = samplerate
        @path = nil
        @raw_bytes = nil
        @format = sanitize_format(format || "wav", ALLOWED_AUDIO_FORMATS)
        parse_audio_value(value)
      end

      # Creates an AgentAudio from a file path.
      #
      # @param path [String] Path to audio file
      # @param samplerate [Integer, nil] Override sample rate
      # @return [AgentAudio]
      def self.from_file(path, samplerate: nil)
        audio = new(path)
        audio.instance_variable_set(:@samplerate, samplerate) if samplerate
        audio
      end

      # Returns raw binary audio data.
      # @return [String, nil]
      def to_raw
        return @raw_bytes if @raw_bytes
        return File.binread(@path) if @path && File.exist?(@path)

        nil
      end

      # Returns base64-encoded audio data.
      # @return [String, nil]
      def to_base64 = to_raw&.then { Base64.strict_encode64(it) }

      # Returns string representation (file path or temp file).
      # @return [String, nil]
      def to_string = @path || save_to_temp("agent_audio_")

      # Saves audio to file.
      #
      # @param output_path [String] Destination file path
      # @return [String] Path written to
      def save(output_path)
        raw = to_raw
        raise ArgumentError, "No audio data to save" unless raw

        File.binwrite(output_path, raw)
        output_path
      end

      # Calculates audio duration in seconds.
      # Only works for WAV format.
      #
      # @return [Float, nil] Duration in seconds
      def duration
        raw = to_raw
        return nil unless raw && @format == "wav"

        data_size = raw.bytesize - 44
        return nil if data_size <= 0

        samples = data_size / 2
        samples.to_f / @samplerate
      end

      # Converts to hash for serialization.
      # @return [Hash]
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

      def parse_audio_value(value)
        case value
        when AgentAudio then copy_from_audio(value)
        when String then parse_audio_string(value)
        when Array then @samplerate, @raw_bytes = value
        else @raw_bytes = value.respond_to?(:read) ? value.read : value
        end
      end

      def copy_from_audio(audio)
        @path = audio.path
        @raw_bytes = audio.instance_variable_get(:@raw_bytes)
        @samplerate = audio.samplerate
        @format = audio.format
      end

      def parse_audio_string(value)
        if audio_file_path?(value)
          @path = safe_path(value)
          @format = audio_format_from_extension(value)
        elsif audio_text_value?(value)
          @path = safe_path(value)
        else
          @raw_bytes = value
        end
      end

      def audio_file_path?(value) = value.valid_encoding? && !value.include?("\x00") && File.exist?(value)
      def audio_text_value?(value) = value.valid_encoding? && !value.include?("\x00")

      def audio_format_from_extension(path)
        ext = File.extname(path).delete(".").downcase
        sanitize_format(ext.empty? ? "wav" : ext, ALLOWED_AUDIO_FORMATS)
      end
    end
  end
end
