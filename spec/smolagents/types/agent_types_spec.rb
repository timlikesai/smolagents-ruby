require "smolagents"
require "tempfile"

RSpec.describe Smolagents::Types::AgentType do
  describe "#initialize" do
    it "stores the value" do
      type = described_class.new("test")
      expect(type.value).to eq("test")
    end

    it "stores nil values" do
      type = described_class.new(nil)
      expect(type.value).to be_nil
    end

    it "stores numeric values" do
      type = described_class.new(42)
      expect(type.value).to eq(42)
    end

    it "stores objects with to_s method" do
      obj = double("object", to_s: "stringified")
      type = described_class.new(obj)
      expect(type.value).to eq(obj)
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      type = described_class.new("test")
      expect(type.to_s).to eq("test")
    end

    it "converts to_string from subclass" do
      type = described_class.new("test")
      expect(type.to_s).to eq(type.to_string)
    end

    it "handles nil values" do
      type = described_class.new(nil)
      expect(type.to_s).to eq("")
    end
  end

  describe "#to_raw" do
    it "returns the raw value by default" do
      type = described_class.new("raw data")
      expect(type.to_raw).to eq("raw data")
    end

    it "returns value for nil" do
      type = described_class.new(nil)
      expect(type.to_raw).to be_nil
    end
  end

  describe "#to_string" do
    it "returns string conversion by default" do
      type = described_class.new("test")
      expect(type.to_string).to eq("test")
    end

    it "calls to_s on value" do
      type = described_class.new(123)
      expect(type.to_string).to eq("123")
    end
  end

  describe "#to_h" do
    it "returns hash with type and value" do
      type = described_class.new("test")
      hash = type.to_h
      expect(hash).to include(:type, :value)
    end

    it "includes downcased class name as type" do
      type = described_class.new("test")
      hash = type.to_h
      expect(hash[:type]).to eq("agenttype")
    end

    it "includes string value" do
      type = described_class.new("test")
      hash = type.to_h
      expect(hash[:value]).to eq("test")
    end

    it "handles numeric values in hash" do
      type = described_class.new(42)
      hash = type.to_h
      expect(hash[:value]).to eq("42")
    end
  end
end

RSpec.describe Smolagents::Types::AgentText do
  describe "#initialize" do
    it "wraps text value" do
      text = described_class.new("hello world")
      expect(text.to_raw).to eq("hello world")
    end

    it "wraps numeric values" do
      text = described_class.new(42)
      expect(text.value).to eq(42)
    end

    it "wraps nil values" do
      text = described_class.new(nil)
      expect(text.value).to be_nil
    end

    it "wraps empty strings" do
      text = described_class.new("")
      expect(text.value).to eq("")
    end
  end

  describe "#to_raw" do
    it "returns string representation" do
      text = described_class.new("hello")
      expect(text.to_raw).to eq("hello")
    end

    it "converts numeric values to string" do
      text = described_class.new(123)
      expect(text.to_raw).to eq("123")
    end

    it "converts nil to empty string" do
      text = described_class.new(nil)
      expect(text.to_raw).to eq("")
    end
  end

  describe "#to_string" do
    it "returns the text" do
      text = described_class.new("hello")
      expect(text.to_string).to eq("hello")
    end

    it "converts to string representation" do
      text = described_class.new(456)
      expect(text.to_string).to eq("456")
    end

    it "handles nil values" do
      text = described_class.new(nil)
      expect(text.to_string).to eq("")
    end

    it "handles empty strings" do
      text = described_class.new("")
      expect(text.to_string).to eq("")
    end
  end

  describe "#+" do
    it "concatenates texts" do
      text1 = described_class.new("hello ")
      text2 = described_class.new("world")
      result = text1 + text2
      expect(result).to be_a(described_class)
      expect(result.to_s).to eq("hello world")
    end

    it "concatenates with string objects" do
      text = described_class.new("hello")
      result = "#{text} world"
      expect(result.to_s).to eq("hello world")
    end

    it "concatenates with empty strings" do
      text1 = described_class.new("hello")
      text2 = described_class.new("")
      result = text1 + text2
      expect(result.to_s).to eq("hello")
    end

    it "concatenates empty with non-empty" do
      text1 = described_class.new("")
      text2 = described_class.new("world")
      result = text1 + text2
      expect(result.to_s).to eq("world")
    end

    it "concatenates multiple times" do
      result = described_class.new("a") + described_class.new("b") + described_class.new("c")
      expect(result.to_s).to eq("abc")
    end

    it "concatenates numeric values" do
      text = described_class.new("count: ")
      num = described_class.new(42)
      result = text + num
      expect(result.to_s).to eq("count: 42")
    end
  end

  describe "#length" do
    it "returns string length" do
      text = described_class.new("hello")
      expect(text.length).to eq(5)
    end

    it "returns zero for empty string" do
      text = described_class.new("")
      expect(text.length).to be_zero
    end

    it "returns length of numeric strings" do
      text = described_class.new(123)
      expect(text.length).to eq(3)
    end

    it "counts unicode characters" do
      text = described_class.new("你好")
      expect(text.length).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns true for empty string" do
      expect(described_class.new("").empty?).to be true
    end

    it "returns false for non-empty string" do
      expect(described_class.new("hello").empty?).to be false
    end

    it "returns true for empty string from number" do
      # nil converts to empty string
      text = described_class.new(nil)
      expect(text.empty?).to be true
    end

    it "returns false for non-zero numbers" do
      text = described_class.new(42)
      expect(text.empty?).to be false
    end

    it "returns true for zero as string" do
      text = described_class.new(0)
      expect(text.empty?).to be false # "0" is not empty
    end
  end

  describe "#==" do
    it "compares with strings" do
      text = described_class.new("hello")
      expect(text == "hello").to be true
      expect(text == "world").to be false
    end

    it "compares with other AgentText" do
      text1 = described_class.new("hello")
      text2 = described_class.new("hello")
      expect(text1 == text2).to be true
    end

    it "compares empty strings" do
      text = described_class.new("")
      expect(text == "").to be true
    end

    it "compares numeric strings" do
      text = described_class.new(42)
      expect(text == "42").to be true
      expect(text == "43").to be false
    end

    it "compares case sensitively" do
      text = described_class.new("Hello")
      expect(text == "hello").to be false
      expect(text == "Hello").to be true
    end

    it "compares with whitespace" do
      text = described_class.new("hello world")
      expect(text == "hello world").to be true
      expect(text == "hello  world").to be false
    end

    it "returns false for different types" do
      text = described_class.new("hello")
      expect(text == 123).to be false
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      text = described_class.new("hello")
      hash = text.to_h
      expect(hash[:type]).to eq("agenttext")
      expect(hash[:value]).to eq("hello")
    end

    it "handles empty strings" do
      text = described_class.new("")
      hash = text.to_h
      expect(hash[:value]).to eq("")
    end

    it "handles numeric values" do
      text = described_class.new(42)
      hash = text.to_h
      expect(hash[:value]).to eq("42")
    end
  end

  describe "#to_s" do
    it "returns string via to_s" do
      text = described_class.new("test")
      expect(text.to_s).to eq("test")
    end
  end
end

RSpec.describe Smolagents::Types::AgentImage do
  let(:png_bytes) { "\x89PNG\r\n\u001A\n#{"\x00" * 100}".b }

  describe "#initialize" do
    context "with file path" do
      it "stores the path" do
        tmpfile = Tempfile.new(["test", ".png"])
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        image = described_class.new(tmpfile.path)
        expect(image.path).to eq(tmpfile.path)
        expect(image.format).to eq("png")
      ensure
        tmpfile&.unlink
      end
    end

    context "with file path and different formats" do
      it "detects format from jpg extension" do
        tmpfile = Tempfile.new(["test", ".jpg"])
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        image = described_class.new(tmpfile.path)
        expect(image.format).to eq("jpg")
      ensure
        tmpfile&.unlink
      end

      it "detects format from jpeg extension" do
        tmpfile = Tempfile.new(["test", ".jpeg"])
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        image = described_class.new(tmpfile.path)
        expect(image.format).to eq("jpeg")
      ensure
        tmpfile&.unlink
      end

      it "detects format from gif extension" do
        tmpfile = Tempfile.new(["test", ".gif"])
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        image = described_class.new(tmpfile.path)
        expect(image.format).to eq("gif")
      ensure
        tmpfile&.unlink
      end

      it "detects format from webp extension" do
        tmpfile = Tempfile.new(["test", ".webp"])
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        image = described_class.new(tmpfile.path)
        expect(image.format).to eq("webp")
      ensure
        tmpfile&.unlink
      end

      it "defaults to png if no extension" do
        tmpfile = Tempfile.new("test")
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        image = described_class.new(tmpfile.path)
        expect(image.format).to eq("png")
      ensure
        tmpfile&.unlink
      end
    end

    context "with raw bytes" do
      it "stores the bytes" do
        image = described_class.new(png_bytes)
        expect(image.to_raw).to eq(png_bytes)
      end

      it "defaults to png format for raw bytes" do
        image = described_class.new(png_bytes)
        expect(image.format).to eq("png")
      end

      it "respects format override" do
        image = described_class.new(png_bytes, format: "jpg")
        expect(image.format).to eq("jpg")
      end
    end

    context "with another AgentImage" do
      it "copies the data" do
        original = described_class.new(png_bytes, format: "jpg")
        copy = described_class.new(original)
        expect(copy.format).to eq("jpg")
        expect(copy.to_raw).to eq(png_bytes)
      end

      it "copies path from original" do
        tmpfile = Tempfile.new(["test", ".png"])
        tmpfile.binmode
        tmpfile.write(png_bytes)
        tmpfile.close

        original = described_class.new(tmpfile.path)
        copy = described_class.new(original)
        expect(copy.path).to eq(tmpfile.path)
      ensure
        tmpfile&.unlink
      end
    end

    context "with data URI" do
      it "decodes base64 from data URI" do
        base64 = Base64.strict_encode64(png_bytes)
        uri = "data:image/png;base64,#{base64}"
        image = described_class.new(uri)
        expect(image.to_raw).to eq(png_bytes)
        expect(image.format).to eq("png")
      end

      it "extracts format from data URI" do
        base64 = Base64.strict_encode64(png_bytes)
        uri = "data:image/jpeg;base64,#{base64}"
        image = described_class.new(uri)
        expect(image.format).to eq("jpeg")
      end

      it "handles data URI with different formats" do
        base64 = Base64.strict_encode64(png_bytes)
        uri = "data:image/gif;base64,#{base64}"
        image = described_class.new(uri)
        expect(image.format).to eq("gif")
      end
    end

    context "with base64 string" do
      it "decodes long base64 strings" do
        base64 = Base64.strict_encode64(png_bytes)
        image = described_class.new(base64, format: "png")
        expect(image.to_raw).to eq(png_bytes)
      end
    end

    context "with IO-like objects" do
      it "reads from IO with read method" do
        io = double("io", read: png_bytes)
        image = described_class.new(io)
        expect(image.to_raw).to eq(png_bytes)
      end
    end

    context "with format sanitization" do
      it "sanitizes uppercase format" do
        image = described_class.new(png_bytes, format: "PNG")
        expect(image.format).to eq("png")
      end

      it "sanitizes format with special characters" do
        image = described_class.new(png_bytes, format: "p@ng!")
        expect(image.format).to eq("png")
      end

      it "defaults to first allowed format if invalid" do
        image = described_class.new(png_bytes, format: "xyz")
        expect(image.format).to eq("png")  # First in ALLOWED_IMAGE_FORMATS
      end
    end
  end

  describe ".from_file" do
    it "creates image from file path" do
      tmpfile = Tempfile.new(["test", ".png"])
      tmpfile.binmode
      tmpfile.write(png_bytes)
      tmpfile.close

      image = described_class.from_file(tmpfile.path)
      expect(image.path).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end
  end

  describe ".from_base64" do
    it "creates image from base64 string" do
      base64 = Base64.strict_encode64(png_bytes)
      image = described_class.from_base64(base64, format: "png")
      expect(image.to_raw).to eq(png_bytes)
    end

    it "defaults to png format" do
      base64 = Base64.strict_encode64(png_bytes)
      image = described_class.from_base64(base64)
      expect(image.format).to eq("png")
    end

    it "accepts custom format" do
      base64 = Base64.strict_encode64(png_bytes)
      image = described_class.from_base64(base64, format: "jpg")
      expect(image.format).to eq("jpg")
    end
  end

  describe "#to_raw" do
    it "returns bytes from raw bytes" do
      image = described_class.new(png_bytes)
      expect(image.to_raw).to eq(png_bytes)
    end

    it "returns bytes from file" do
      tmpfile = Tempfile.new(["test", ".png"])
      tmpfile.binmode
      tmpfile.write(png_bytes)
      tmpfile.close

      image = described_class.new(tmpfile.path)
      expect(image.to_raw).to eq(png_bytes)
    ensure
      tmpfile&.unlink
    end

    it "returns nil if file doesn't exist" do
      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, "/nonexistent/file.png")
      image.instance_variable_set(:@raw_bytes, nil)
      expect(image.to_raw).to be_nil
    end

    it "prioritizes raw_bytes over file" do
      tmpfile = Tempfile.new(["test", ".png"])
      tmpfile.binmode
      tmpfile.write("\x00\x00\x00".b)
      tmpfile.close

      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, tmpfile.path)
      expect(image.to_raw).to eq(png_bytes)
    ensure
      tmpfile&.unlink
    end
  end

  describe "#to_base64" do
    it "returns base64 encoded data" do
      image = described_class.new(png_bytes)
      expect(image.to_base64).to eq(Base64.strict_encode64(png_bytes))
    end

    it "returns nil if no data available" do
      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, "/nonexistent/file.png")
      image.instance_variable_set(:@raw_bytes, nil)
      expect(image.to_base64).to be_nil
    end

    it "uses strict encoding" do
      image = described_class.new(png_bytes)
      base64 = image.to_base64
      expect(base64).not_to include("\n")  # strict_encode64 doesn't add newlines
    end
  end

  describe "#to_data_uri" do
    it "returns data URI with format" do
      image = described_class.new(png_bytes, format: "png")
      uri = image.to_data_uri
      expect(uri).to start_with("data:image/png;base64,")
    end

    it "includes base64 content" do
      image = described_class.new(png_bytes, format: "png")
      uri = image.to_data_uri
      base64 = Base64.strict_encode64(png_bytes)
      expect(uri).to include(base64)
    end

    it "returns nil if no data available" do
      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, "/nonexistent/file.png")
      image.instance_variable_set(:@raw_bytes, nil)
      expect(image.to_data_uri).to be_nil
    end

    it "handles different formats in URI" do
      image = described_class.new(png_bytes, format: "jpeg")
      uri = image.to_data_uri
      expect(uri).to start_with("data:image/jpeg;base64,")
    end
  end

  describe "#to_string" do
    it "returns path for file-backed images" do
      tmpfile = Tempfile.new(["test", ".png"])
      tmpfile.binmode
      tmpfile.write(png_bytes)
      tmpfile.close

      image = described_class.new(tmpfile.path)
      expect(image.to_string).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "saves bytes to temp file and returns path" do
      image = described_class.new(png_bytes)
      path = image.to_string
      expect(path).not_to be_nil
      expect(File.exist?(path)).to be true
      expect(File.binread(path)).to eq(png_bytes)
      File.unlink(path) if path
    end

    it "returns path even if file doesn't exist" do
      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, "/nonexistent/file.png")
      image.instance_variable_set(:@raw_bytes, nil)
      # to_string returns @path if set, doesn't check existence
      expect(image.to_string).to eq("/nonexistent/file.png")
    end

    it "caches temp file path" do
      image = described_class.new(png_bytes)
      path1 = image.to_string
      path2 = image.to_string
      expect(path1).to eq(path2)
      File.unlink(path1) if path1
    end
  end

  describe "#save" do
    it "saves image to file" do
      image = described_class.new(png_bytes)
      tmpfile = Tempfile.new(["output", ".png"])
      tmpfile.close

      image.save(tmpfile.path)
      expect(File.binread(tmpfile.path)).to eq(png_bytes)
    ensure
      tmpfile&.unlink
    end

    it "returns the output path" do
      image = described_class.new(png_bytes)
      tmpfile = Tempfile.new(["output", ".png"])
      tmpfile.close

      result = image.save(tmpfile.path)
      expect(result).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "raises error if no data to save" do
      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, "/nonexistent/file.png")
      image.instance_variable_set(:@raw_bytes, nil)
      expect { image.save("/tmp/output.png") }.to raise_error(ArgumentError, "No image data to save")
    end

    it "creates new file" do
      image = described_class.new(png_bytes)
      tmpdir = Dir.mktmpdir
      output_path = File.join(tmpdir, "new_image.png")

      image.save(output_path)
      expect(File.exist?(output_path)).to be true
      expect(File.binread(output_path)).to eq(png_bytes)
    ensure
      File.unlink(output_path) if output_path && File.exist?(output_path)
      Dir.rmdir(tmpdir) if tmpdir && Dir.exist?(tmpdir)
    end

    it "overwrites existing file" do
      image = described_class.new(png_bytes)
      tmpfile = Tempfile.new(["output", ".png"])
      tmpfile.write("old content")
      tmpfile.close

      image.save(tmpfile.path)
      expect(File.binread(tmpfile.path)).to eq(png_bytes)
    ensure
      tmpfile&.unlink
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      image = described_class.new(png_bytes, format: "png")
      hash = image.to_h
      expect(hash[:type]).to eq("image")
      expect(hash[:format]).to eq("png")
    end

    it "includes path if available" do
      tmpfile = Tempfile.new(["test", ".png"])
      tmpfile.binmode
      tmpfile.write(png_bytes)
      tmpfile.close

      image = described_class.new(tmpfile.path)
      hash = image.to_h
      expect(hash[:path]).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "includes base64 preview" do
      image = described_class.new(png_bytes, format: "png")
      hash = image.to_h
      expect(hash[:base64]).not_to be_nil
      expect(hash[:base64]).to end_with("...")
    end

    it "compacts hash excluding nil values" do
      image = described_class.new(png_bytes)
      image.instance_variable_set(:@path, nil)
      hash = image.to_h
      expect(hash.keys).not_to include(:path)
    end

    it "handles different formats" do
      image = described_class.new(png_bytes, format: "jpeg")
      hash = image.to_h
      expect(hash[:format]).to eq("jpeg")
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      image = described_class.new(png_bytes)
      result = image.to_s
      expect(result).to be_a(String)
    end
  end
end

RSpec.describe Smolagents::Types::AgentAudio do
  let(:wav_bytes) { "RIFF#{"\x00" * 40}data#{"\x00" * 100}".b }

  describe "#initialize" do
    context "with file path" do
      it "stores the path" do
        tmpfile = Tempfile.new(["test", ".wav"])
        tmpfile.binmode
        tmpfile.write(wav_bytes)
        tmpfile.close

        audio = described_class.new(tmpfile.path)
        expect(audio.path).to eq(tmpfile.path)
        expect(audio.format).to eq("wav")
      ensure
        tmpfile&.unlink
      end

      it "detects format from mp3 extension" do
        tmpfile = Tempfile.new(["test", ".mp3"])
        tmpfile.binmode
        tmpfile.write(wav_bytes)
        tmpfile.close

        audio = described_class.new(tmpfile.path)
        expect(audio.format).to eq("mp3")
      ensure
        tmpfile&.unlink
      end

      it "detects format from ogg extension" do
        tmpfile = Tempfile.new(["test", ".ogg"])
        tmpfile.binmode
        tmpfile.write(wav_bytes)
        tmpfile.close

        audio = described_class.new(tmpfile.path)
        expect(audio.format).to eq("ogg")
      ensure
        tmpfile&.unlink
      end

      it "detects format from flac extension" do
        tmpfile = Tempfile.new(["test", ".flac"])
        tmpfile.binmode
        tmpfile.write(wav_bytes)
        tmpfile.close

        audio = described_class.new(tmpfile.path)
        expect(audio.format).to eq("flac")
      ensure
        tmpfile&.unlink
      end

      it "defaults to wav for non-existent file path" do
        audio = described_class.new("/nonexistent/path.txt")
        expect(audio.format).to eq("wav")
      end

      it "defaults to wav if no extension" do
        tmpfile = Tempfile.new("test")
        tmpfile.binmode
        tmpfile.write(wav_bytes)
        tmpfile.close

        audio = described_class.new(tmpfile.path)
        expect(audio.format).to eq("wav")
      ensure
        tmpfile&.unlink
      end
    end

    context "with raw bytes" do
      it "stores the bytes with samplerate" do
        audio = described_class.new(wav_bytes, samplerate: 44_100)
        expect(audio.to_raw).to eq(wav_bytes)
        expect(audio.samplerate).to eq(44_100)
      end

      it "defaults to 16000 samplerate" do
        audio = described_class.new(wav_bytes)
        expect(audio.samplerate).to eq(16_000)
      end

      it "defaults to wav format" do
        audio = described_class.new(wav_bytes)
        expect(audio.format).to eq("wav")
      end

      it "respects format override" do
        audio = described_class.new(wav_bytes, format: "mp3")
        expect(audio.format).to eq("mp3")
      end

      it "respects samplerate override" do
        audio = described_class.new(wav_bytes, samplerate: 48_000)
        expect(audio.samplerate).to eq(48_000)
      end
    end

    context "with tuple" do
      it "extracts samplerate and data" do
        audio = described_class.new([48_000, wav_bytes])
        expect(audio.samplerate).to eq(48_000)
        expect(audio.to_raw).to eq(wav_bytes)
      end

      it "uses tuple samplerate over default" do
        audio = described_class.new([22_050, wav_bytes])
        expect(audio.samplerate).to eq(22_050)
      end

      it "respects tuple format" do
        audio = described_class.new([16_000, wav_bytes], format: "mp3")
        expect(audio.format).to eq("mp3")
      end
    end

    context "with another AgentAudio" do
      it "copies the data" do
        original = described_class.new(wav_bytes, samplerate: 22_050)
        copy = described_class.new(original)
        expect(copy.samplerate).to eq(22_050)
        expect(copy.to_raw).to eq(wav_bytes)
      end

      it "copies path from original" do
        tmpfile = Tempfile.new(["test", ".wav"])
        tmpfile.binmode
        tmpfile.write(wav_bytes)
        tmpfile.close

        original = described_class.new(tmpfile.path)
        copy = described_class.new(original)
        expect(copy.path).to eq(tmpfile.path)
      ensure
        tmpfile&.unlink
      end

      it "copies format from original" do
        original = described_class.new(wav_bytes, format: "mp3")
        copy = described_class.new(original)
        expect(copy.format).to eq("mp3")
      end
    end

    context "with IO-like objects" do
      it "reads from IO with read method" do
        io = double("io", read: wav_bytes)
        audio = described_class.new(io)
        expect(audio.to_raw).to eq(wav_bytes)
      end
    end

    context "with format sanitization" do
      it "sanitizes uppercase format" do
        audio = described_class.new(wav_bytes, format: "WAV")
        expect(audio.format).to eq("wav")
      end

      it "sanitizes format with special characters, defaults to first if invalid" do
        audio = described_class.new(wav_bytes, format: "w@v!")
        # "w@v!" becomes "wv" after removing special chars, which is invalid
        # so defaults to first allowed format which is "mp3"
        expect(audio.format).to eq("mp3")
      end

      it "defaults to first allowed format if invalid" do
        audio = described_class.new(wav_bytes, format: "xyz")
        expect(audio.format).to eq("mp3") # First in ALLOWED_AUDIO_FORMATS
      end
    end
  end

  describe ".from_file" do
    it "creates audio from file path" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write(wav_bytes)
      tmpfile.close

      audio = described_class.from_file(tmpfile.path)
      expect(audio.path).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "accepts samplerate override" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write(wav_bytes)
      tmpfile.close

      audio = described_class.from_file(tmpfile.path, samplerate: 48_000)
      expect(audio.samplerate).to eq(48_000)
    ensure
      tmpfile&.unlink
    end

    it "defaults to 16000 samplerate if not specified" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write(wav_bytes)
      tmpfile.close

      audio = described_class.from_file(tmpfile.path)
      expect(audio.samplerate).to eq(16_000)
    ensure
      tmpfile&.unlink
    end
  end

  describe "#to_raw" do
    it "returns bytes from raw bytes" do
      audio = described_class.new(wav_bytes)
      expect(audio.to_raw).to eq(wav_bytes)
    end

    it "returns bytes from file" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write(wav_bytes)
      tmpfile.close

      audio = described_class.new(tmpfile.path)
      expect(audio.to_raw).to eq(wav_bytes)
    ensure
      tmpfile&.unlink
    end

    it "returns nil if file doesn't exist" do
      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, "/nonexistent/file.wav")
      audio.instance_variable_set(:@raw_bytes, nil)
      expect(audio.to_raw).to be_nil
    end

    it "prioritizes raw_bytes over file" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write("\x00\x00\x00".b)
      tmpfile.close

      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, tmpfile.path)
      expect(audio.to_raw).to eq(wav_bytes)
    ensure
      tmpfile&.unlink
    end
  end

  describe "#to_base64" do
    it "returns base64 encoded data" do
      audio = described_class.new(wav_bytes)
      expect(audio.to_base64).to eq(Base64.strict_encode64(wav_bytes))
    end

    it "returns nil if no data available" do
      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, "/nonexistent/file.wav")
      audio.instance_variable_set(:@raw_bytes, nil)
      expect(audio.to_base64).to be_nil
    end

    it "uses strict encoding" do
      audio = described_class.new(wav_bytes)
      base64 = audio.to_base64
      expect(base64).not_to include("\n")
    end
  end

  describe "#to_string" do
    it "returns path for file-backed audio" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write(wav_bytes)
      tmpfile.close

      audio = described_class.new(tmpfile.path)
      expect(audio.to_string).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "saves bytes to temp file and returns path" do
      audio = described_class.new(wav_bytes)
      path = audio.to_string
      expect(path).not_to be_nil
      expect(File.exist?(path)).to be true
      expect(File.binread(path)).to eq(wav_bytes)
      File.unlink(path) if path
    end

    it "returns path even if file doesn't exist" do
      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, "/nonexistent/file.wav")
      audio.instance_variable_set(:@raw_bytes, nil)
      # to_string returns @path if set, doesn't check existence
      expect(audio.to_string).to eq("/nonexistent/file.wav")
    end

    it "caches temp file path" do
      audio = described_class.new(wav_bytes)
      path1 = audio.to_string
      path2 = audio.to_string
      expect(path1).to eq(path2)
      File.unlink(path1) if path1
    end
  end

  describe "#save" do
    it "saves audio to file" do
      audio = described_class.new(wav_bytes)
      tmpfile = Tempfile.new(["output", ".wav"])
      tmpfile.close

      audio.save(tmpfile.path)
      expect(File.binread(tmpfile.path)).to eq(wav_bytes)
    ensure
      tmpfile&.unlink
    end

    it "returns the output path" do
      audio = described_class.new(wav_bytes)
      tmpfile = Tempfile.new(["output", ".wav"])
      tmpfile.close

      result = audio.save(tmpfile.path)
      expect(result).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "raises error if no data to save" do
      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, "/nonexistent/file.wav")
      audio.instance_variable_set(:@raw_bytes, nil)
      expect { audio.save("/tmp/output.wav") }.to raise_error(ArgumentError, "No audio data to save")
    end

    it "creates new file" do
      audio = described_class.new(wav_bytes)
      tmpdir = Dir.mktmpdir
      output_path = File.join(tmpdir, "new_audio.wav")

      audio.save(output_path)
      expect(File.exist?(output_path)).to be true
      expect(File.binread(output_path)).to eq(wav_bytes)
    ensure
      File.unlink(output_path) if output_path && File.exist?(output_path)
      Dir.rmdir(tmpdir) if tmpdir && Dir.exist?(tmpdir)
    end

    it "overwrites existing file" do
      audio = described_class.new(wav_bytes)
      tmpfile = Tempfile.new(["output", ".wav"])
      tmpfile.write("old content")
      tmpfile.close

      audio.save(tmpfile.path)
      expect(File.binread(tmpfile.path)).to eq(wav_bytes)
    ensure
      tmpfile&.unlink
    end
  end

  describe "#duration" do
    it "calculates duration for wav format" do
      audio = described_class.new(wav_bytes, samplerate: 16_000)
      duration = audio.duration
      expect(duration).to be_a(Float)
      expect(duration).to be > 0
    end

    it "returns nil for non-wav format" do
      audio = described_class.new(wav_bytes, format: "mp3", samplerate: 16_000)
      expect(audio.duration).to be_nil
    end

    it "returns nil if no data available" do
      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, "/nonexistent/file.wav")
      audio.instance_variable_set(:@raw_bytes, nil)
      expect(audio.duration).to be_nil
    end

    it "returns nil if data size is too small" do
      small_wav = "RIFF\x00\x00\x00\x00data".b
      audio = described_class.new(small_wav, samplerate: 16_000)
      expect(audio.duration).to be_nil
    end

    it "handles different sample rates" do
      audio1 = described_class.new(wav_bytes, samplerate: 16_000)
      audio2 = described_class.new(wav_bytes, samplerate: 44_100)
      duration1 = audio1.duration
      duration2 = audio2.duration
      expect(duration1).not_to eq(duration2)
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      audio = described_class.new(wav_bytes, samplerate: 16_000)
      hash = audio.to_h
      expect(hash[:type]).to eq("audio")
      expect(hash[:format]).to eq("wav")
      expect(hash[:samplerate]).to eq(16_000)
    end

    it "includes path if available" do
      tmpfile = Tempfile.new(["test", ".wav"])
      tmpfile.binmode
      tmpfile.write(wav_bytes)
      tmpfile.close

      audio = described_class.new(tmpfile.path)
      hash = audio.to_h
      expect(hash[:path]).to eq(tmpfile.path)
    ensure
      tmpfile&.unlink
    end

    it "includes duration if available" do
      audio = described_class.new(wav_bytes, samplerate: 16_000)
      hash = audio.to_h
      expect(hash[:duration]).not_to be_nil
    end

    it "compacts hash excluding nil values" do
      audio = described_class.new(wav_bytes)
      audio.instance_variable_set(:@path, nil)
      hash = audio.to_h
      expect(hash.keys).not_to include(:path)
    end

    it "handles different samplerates" do
      audio = described_class.new(wav_bytes, samplerate: 48_000)
      hash = audio.to_h
      expect(hash[:samplerate]).to eq(48_000)
    end

    it "handles different formats" do
      audio = described_class.new(wav_bytes, format: "mp3")
      hash = audio.to_h
      expect(hash[:format]).to eq("mp3")
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      audio = described_class.new(wav_bytes)
      result = audio.to_s
      expect(result).to be_a(String)
    end
  end
end

RSpec.describe "Smolagents.handle_agent_input_types" do
  it "converts AgentType args to raw values" do
    text = Smolagents::Types::AgentText.new("hello")
    args, kwargs = Smolagents.handle_agent_input_types(text, "world", key: text)

    expect(args).to eq(%w[hello world])
    expect(kwargs[:key]).to eq("hello")
  end

  it "preserves non-AgentType args unchanged" do
    args, kwargs = Smolagents.handle_agent_input_types("plain", 42, key: "value")
    expect(args).to eq(["plain", 42])
    expect(kwargs[:key]).to eq("value")
  end

  it "converts multiple AgentType args" do
    text1 = Smolagents::Types::AgentText.new("hello")
    text2 = Smolagents::Types::AgentText.new("world")
    args, _kwargs = Smolagents.handle_agent_input_types(text1, text2)
    expect(args).to eq(%w[hello world])
  end

  it "converts AgentType in kwargs" do
    text = Smolagents::Types::AgentText.new("hello")
    _args, kwargs = Smolagents.handle_agent_input_types(key1: text, key2: "plain")
    expect(kwargs[:key1]).to eq("hello")
    expect(kwargs[:key2]).to eq("plain")
  end

  it "handles empty args and kwargs" do
    args, kwargs = Smolagents.handle_agent_input_types
    expect(args).to eq([])
    expect(kwargs).to eq({})
  end

  it "handles nil values in args and kwargs" do
    text = Smolagents::Types::AgentText.new("hello")
    args, kwargs = Smolagents.handle_agent_input_types(nil, text, key: nil)
    expect(args).to eq([nil, "hello"])
    expect(kwargs[:key]).to be_nil
  end

  it "converts AgentImage to raw bytes" do
    png_bytes = "\x89PNG\r\n\u001A\n#{"\x00" * 100}".b
    image = Smolagents::Types::AgentImage.new(png_bytes)
    args, _kwargs = Smolagents.handle_agent_input_types(image)
    expect(args[0]).to eq(png_bytes)
  end

  it "converts AgentAudio to raw bytes" do
    wav_bytes = "RIFF#{"\x00" * 40}data#{"\x00" * 100}".b
    audio = Smolagents::Types::AgentAudio.new(wav_bytes)
    args, _kwargs = Smolagents.handle_agent_input_types(audio)
    expect(args[0]).to eq(wav_bytes)
  end

  it "preserves mixed AgentType and non-AgentType" do
    text = Smolagents::Types::AgentText.new("hello")
    args, _kwargs = Smolagents.handle_agent_input_types(text, 42, "world")
    expect(args).to eq(["hello", 42, "world"])
  end
end

RSpec.describe "Smolagents.handle_agent_output_types" do
  let(:png_bytes) { "\x89PNG\r\n\u001A\n#{"\x00" * 100}".b }

  it "wraps string output in AgentText" do
    result = Smolagents.handle_agent_output_types("hello", output_type: "string")
    expect(result).to be_a(Smolagents::Types::AgentText)
    expect(result.to_s).to eq("hello")
  end

  it "wraps output with text output_type" do
    result = Smolagents.handle_agent_output_types("hello", output_type: "text")
    expect(result).to be_a(Smolagents::Types::AgentText)
    expect(result.to_s).to eq("hello")
  end

  it "wraps output based on output_type" do
    result = Smolagents.handle_agent_output_types("data", output_type: "image")
    expect(result).to be_a(Smolagents::Types::AgentImage)
  end

  it "wraps audio output_type" do
    result = Smolagents.handle_agent_output_types("data", output_type: "audio")
    expect(result).to be_a(Smolagents::Types::AgentAudio)
  end

  it "auto-wraps strings without output_type" do
    result = Smolagents.handle_agent_output_types("hello")
    expect(result).to be_a(Smolagents::Types::AgentText)
    expect(result.to_s).to eq("hello")
  end

  it "returns AgentType unchanged" do
    text = Smolagents::Types::AgentText.new("hello")
    result = Smolagents.handle_agent_output_types(text)
    expect(result).to equal(text)
  end

  it "returns non-string non-AgentType unchanged" do
    obj = { key: "value" }
    result = Smolagents.handle_agent_output_types(obj)
    expect(result).to equal(obj)
  end

  it "handles nil output" do
    result = Smolagents.handle_agent_output_types(nil, output_type: "string")
    expect(result).to be_a(Smolagents::Types::AgentText)
  end

  it "ignores unknown output_type" do
    result = Smolagents.handle_agent_output_types("data", output_type: "unknown")
    expect(result).to be_a(Smolagents::Types::AgentText)
  end

  it "returns array unchanged" do
    arr = [1, 2, 3]
    result = Smolagents.handle_agent_output_types(arr)
    expect(result).to equal(arr)
  end

  it "returns numeric unchanged" do
    num = 42
    result = Smolagents.handle_agent_output_types(num)
    expect(result).to equal(num)
  end

  it "returns boolean unchanged" do
    result = Smolagents.handle_agent_output_types(true)
    expect(result).to be true
  end

  it "wraps bytes as AgentImage when requested" do
    result = Smolagents.handle_agent_output_types(png_bytes, output_type: "image")
    expect(result).to be_a(Smolagents::Types::AgentImage)
    expect(result.to_raw).to eq(png_bytes)
  end

  it "wraps bytes as AgentAudio when requested" do
    wav_bytes = "RIFF#{"\x00" * 40}data#{"\x00" * 100}".b
    result = Smolagents.handle_agent_output_types(wav_bytes, output_type: "audio")
    expect(result).to be_a(Smolagents::Types::AgentAudio)
    expect(result.to_raw).to eq(wav_bytes)
  end
end

RSpec.describe "Agent type constants" do
  describe "ALLOWED_IMAGE_FORMATS" do
    it "includes common image formats" do
      expect(Smolagents::Types::ALLOWED_IMAGE_FORMATS).to include("png", "jpg", "jpeg", "gif", "webp")
    end

    it "includes additional supported formats" do
      expect(Smolagents::Types::ALLOWED_IMAGE_FORMATS).to include("bmp", "tiff", "svg", "ico")
    end

    it "excludes unsupported formats" do
      expect(Smolagents::Types::ALLOWED_IMAGE_FORMATS).not_to include("heic")
    end

    it "is frozen" do
      expect(Smolagents::Types::ALLOWED_IMAGE_FORMATS).to be_frozen
    end

    it "is a Set" do
      expect(Smolagents::Types::ALLOWED_IMAGE_FORMATS).to be_a(Set)
    end
  end

  describe "ALLOWED_AUDIO_FORMATS" do
    it "includes common audio formats" do
      expect(Smolagents::Types::ALLOWED_AUDIO_FORMATS).to include("wav", "mp3", "ogg", "flac", "m4a")
    end

    it "includes additional supported formats" do
      expect(Smolagents::Types::ALLOWED_AUDIO_FORMATS).to include("aac", "wma", "aiff")
    end

    it "excludes unsupported formats" do
      expect(Smolagents::Types::ALLOWED_AUDIO_FORMATS).not_to include("opus")
    end

    it "is frozen" do
      expect(Smolagents::Types::ALLOWED_AUDIO_FORMATS).to be_frozen
    end

    it "is a Set" do
      expect(Smolagents::Types::ALLOWED_AUDIO_FORMATS).to be_a(Set)
    end
  end

  describe "AGENT_TYPE_MAPPING" do
    it "maps string types to AgentText" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING["string"]).to eq(Smolagents::Types::AgentText)
    end

    it "maps text types to AgentText" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING["text"]).to eq(Smolagents::Types::AgentText)
    end

    it "maps image types to AgentImage" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING["image"]).to eq(Smolagents::Types::AgentImage)
    end

    it "maps audio types to AgentAudio" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING["audio"]).to eq(Smolagents::Types::AgentAudio)
    end

    it "is frozen" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING).to be_frozen
    end

    it "is a Hash" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING).to be_a(Hash)
    end

    it "has correct size" do
      expect(Smolagents::Types::AGENT_TYPE_MAPPING.size).to eq(4)
    end
  end
end
