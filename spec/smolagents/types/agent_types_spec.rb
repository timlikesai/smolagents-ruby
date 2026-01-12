require "smolagents"
require "tempfile"

RSpec.describe Smolagents::AgentType do
  describe "#initialize" do
    it "stores the value" do
      type = described_class.new("test")
      expect(type.value).to eq("test")
    end
  end

  describe "#to_s" do
    it "returns string representation" do
      type = described_class.new("test")
      expect(type.to_s).to eq("test")
    end
  end

  describe "#to_h" do
    it "returns hash with type and value" do
      type = described_class.new("test")
      expect(type.to_h).to include(:type, :value)
    end
  end
end

RSpec.describe Smolagents::AgentText do
  describe "#initialize" do
    it "wraps text value" do
      text = described_class.new("hello world")
      expect(text.to_raw).to eq("hello world")
    end
  end

  describe "#to_string" do
    it "returns the text" do
      text = described_class.new("hello")
      expect(text.to_string).to eq("hello")
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
  end

  describe "#length" do
    it "returns string length" do
      text = described_class.new("hello")
      expect(text.length).to eq(5)
    end
  end

  describe "#empty?" do
    it "returns true for empty string" do
      expect(described_class.new("").empty?).to be true
    end

    it "returns false for non-empty string" do
      expect(described_class.new("hello").empty?).to be false
    end
  end

  describe "#==" do
    it "compares with strings" do
      text = described_class.new("hello")
      expect(text == "hello").to be true
      expect(text == "world").to be false
    end
  end
end

RSpec.describe Smolagents::AgentImage do
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

    context "with raw bytes" do
      it "stores the bytes" do
        image = described_class.new(png_bytes)
        expect(image.to_raw).to eq(png_bytes)
      end
    end

    context "with another AgentImage" do
      it "copies the data" do
        original = described_class.new(png_bytes, format: "jpg")
        copy = described_class.new(original)
        expect(copy.format).to eq("jpg")
        expect(copy.to_raw).to eq(png_bytes)
      end
    end
  end

  describe ".from_base64" do
    it "creates image from base64 string" do
      base64 = Base64.strict_encode64(png_bytes)
      image = described_class.from_base64(base64, format: "png")
      expect(image.to_raw).to eq(png_bytes)
    end
  end

  describe "#to_base64" do
    it "returns base64 encoded data" do
      image = described_class.new(png_bytes)
      expect(image.to_base64).to eq(Base64.strict_encode64(png_bytes))
    end
  end

  describe "#to_data_uri" do
    it "returns data URI" do
      image = described_class.new(png_bytes, format: "png")
      uri = image.to_data_uri
      expect(uri).to start_with("data:image/png;base64,")
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
  end

  describe "#to_h" do
    it "returns hash representation" do
      image = described_class.new(png_bytes, format: "png")
      hash = image.to_h
      expect(hash[:type]).to eq("image")
      expect(hash[:format]).to eq("png")
    end
  end
end

RSpec.describe Smolagents::AgentAudio do
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
    end

    context "with raw bytes" do
      it "stores the bytes with samplerate" do
        audio = described_class.new(wav_bytes, samplerate: 44_100)
        expect(audio.to_raw).to eq(wav_bytes)
        expect(audio.samplerate).to eq(44_100)
      end
    end

    context "with tuple" do
      it "extracts samplerate and data" do
        audio = described_class.new([48_000, wav_bytes])
        expect(audio.samplerate).to eq(48_000)
        expect(audio.to_raw).to eq(wav_bytes)
      end
    end

    context "with another AgentAudio" do
      it "copies the data" do
        original = described_class.new(wav_bytes, samplerate: 22_050)
        copy = described_class.new(original)
        expect(copy.samplerate).to eq(22_050)
        expect(copy.to_raw).to eq(wav_bytes)
      end
    end
  end

  describe "#to_base64" do
    it "returns base64 encoded data" do
      audio = described_class.new(wav_bytes)
      expect(audio.to_base64).to eq(Base64.strict_encode64(wav_bytes))
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
  end

  describe "#to_h" do
    it "returns hash representation" do
      audio = described_class.new(wav_bytes, samplerate: 16_000)
      hash = audio.to_h
      expect(hash[:type]).to eq("audio")
      expect(hash[:format]).to eq("wav")
      expect(hash[:samplerate]).to eq(16_000)
    end
  end
end

RSpec.describe "Smolagents.handle_agent_input_types" do
  it "converts AgentType args to raw values" do
    text = Smolagents::AgentText.new("hello")
    args, kwargs = Smolagents.handle_agent_input_types(text, "world", key: text)

    expect(args).to eq(%w[hello world])
    expect(kwargs[:key]).to eq("hello")
  end
end

RSpec.describe "Smolagents.handle_agent_output_types" do
  it "wraps string output in AgentText" do
    result = Smolagents.handle_agent_output_types("hello", output_type: "string")
    expect(result).to be_a(Smolagents::AgentText)
    expect(result.to_s).to eq("hello")
  end

  it "wraps output based on output_type" do
    result = Smolagents.handle_agent_output_types("data", output_type: "image")
    expect(result).to be_a(Smolagents::AgentImage)
  end

  it "auto-wraps strings without output_type" do
    result = Smolagents.handle_agent_output_types("hello")
    expect(result).to be_a(Smolagents::AgentText)
  end
end
