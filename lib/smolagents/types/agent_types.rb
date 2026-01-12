require "base64"
require "tempfile"
require "securerandom"

module Smolagents
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

  class AgentText < AgentType
    def to_raw
      @value.to_s
    end

    def to_string
      @value.to_s
    end

    def +(other)
      AgentText.new(@value.to_s + other.to_s)
    end

    def length
      @value.to_s.length
    end

    def empty?
      @value.to_s.empty?
    end

    def ==(other)
      to_string == other.to_s
    end
  end

  class AgentImage < AgentType
    attr_reader :path, :format

    def initialize(value, format: nil)
      super(value)
      @path = nil
      @raw_bytes = nil
      @format = format || "png"

      case value
      when AgentImage
        @path = value.path
        @raw_bytes = value.instance_variable_get(:@raw_bytes)
        @format = value.format
      when String
        if value.valid_encoding? && !value.include?("\x00") && File.exist?(value)
          @path = value
          @format = File.extname(value).delete(".").downcase
          @format = "png" if @format.empty?
        elsif value.start_with?("data:image")
          match = value.match(%r{data:image/(\w+);base64,(.+)})
          if match
            @format = match[1]
            @raw_bytes = Base64.decode64(match[2])
          end
        elsif value.valid_encoding? && value.match?(%r{^[A-Za-z0-9+/=]+$}) && value.length > 100
          @raw_bytes = Base64.decode64(value)
        elsif value.valid_encoding? && !value.include?("\x00")
          @path = value
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
      base64 = to_base64
      base64 ? "data:image/#{@format};base64,#{base64}" : nil
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
        base64: to_base64&.slice(0, 50)&.then { |s| "#{s}..." }
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
  end

  class AgentAudio < AgentType
    attr_reader :path, :samplerate, :format

    def initialize(value, samplerate: 16_000, format: nil)
      super(value)
      @samplerate = samplerate
      @path = nil
      @raw_bytes = nil
      @format = format || "wav"

      case value
      when AgentAudio
        @path = value.path
        @raw_bytes = value.instance_variable_get(:@raw_bytes)
        @samplerate = value.samplerate
        @format = value.format
      when String
        if value.valid_encoding? && !value.include?("\x00") && File.exist?(value)
          @path = value
          @format = File.extname(value).delete(".").downcase
          @format = "wav" if @format.empty?
        elsif value.valid_encoding? && !value.include?("\x00")
          @path = value
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
  end

  AGENT_TYPE_MAPPING = {
    "string" => AgentText,
    "text" => AgentText,
    "image" => AgentImage,
    "audio" => AgentAudio
  }.freeze

  def self.handle_agent_input_types(*args, **kwargs)
    args = args.map { |arg| arg.is_a?(AgentType) ? arg.to_raw : arg }
    kwargs = kwargs.transform_values { |v| v.is_a?(AgentType) ? v.to_raw : v }
    [args, kwargs]
  end

  def self.handle_agent_output_types(output, output_type: nil)
    return AGENT_TYPE_MAPPING[output_type].new(output) if output_type && AGENT_TYPE_MAPPING[output_type]

    case output
    when String
      AgentText.new(output)
    when AgentType
      output
    else
      output
    end
  end
end
