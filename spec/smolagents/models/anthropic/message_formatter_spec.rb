require "base64"
require "smolagents/models/model"
require "smolagents/models/anthropic_model"
require "smolagents/models/anthropic/message_formatter"

RSpec.describe Smolagents::Models::Anthropic::MessageFormatter do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::Anthropic::MessageFormatter
    end
  end
  let(:formatter) { model_class.new }

  describe "#format_messages" do
    it "formats array of ChatMessages" do
      messages = [
        Smolagents::ChatMessage.user("Hello"),
        Smolagents::ChatMessage.assistant("Hi")
      ]

      result = formatter.format_messages(messages)

      expect(result).to be_an(Array)
      expect(result.length).to eq(2)
    end

    it "returns each message as a hash" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = formatter.format_messages(messages)

      expect(result[0]).to be_a(Hash)
      expect(result[0]).to have_key(:role)
      expect(result[0]).to have_key(:content)
    end

    it "handles empty message array" do
      result = formatter.format_messages([])

      expect(result).to eq([])
    end

    it "maps user role correctly" do
      messages = [Smolagents::ChatMessage.user("Hello")]

      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("user")
    end

    it "maps assistant role correctly" do
      messages = [Smolagents::ChatMessage.assistant("Hi")]

      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("assistant")
    end

    it "maps system role to user" do
      messages = [Smolagents::ChatMessage.system("You are helpful")]

      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("user")
    end

    it "maps tool_call role to user (Anthropic-specific handling)" do
      tool_call = Smolagents::ToolCall.new(id: "tool_1", name: "search", arguments: {})
      messages = [Smolagents::ChatMessage.tool_call(tool_calls: [tool_call])]

      result = formatter.format_messages(messages)

      # Anthropic API treats tool_call as assistant role implicitly through tool_use blocks
      # but for message formatting, non-assistant roles map to user
      expect(result[0][:role]).to eq("user")
    end

    it "maps tool_response role to user" do
      messages = [Smolagents::ChatMessage.tool_response("result")]

      result = formatter.format_messages(messages)

      expect(result[0][:role]).to eq("user")
    end

    it "includes message content" do
      messages = [Smolagents::ChatMessage.user("Hello world")]

      result = formatter.format_messages(messages)

      expect(result[0][:content]).to eq("Hello world")
    end

    it "defaults to empty string for nil content" do
      messages = [Smolagents::ChatMessage.assistant(nil)]

      result = formatter.format_messages(messages)

      expect(result[0][:content]).to eq("")
    end

    it "formats multiple messages in sequence" do
      messages = [
        Smolagents::ChatMessage.system("You are helpful"),
        Smolagents::ChatMessage.user("Question"),
        Smolagents::ChatMessage.assistant("Answer")
      ]

      result = formatter.format_messages(messages)

      expect(result.length).to eq(3)
      expect(result[0][:role]).to eq("user")
      expect(result[1][:role]).to eq("user")
      expect(result[2][:role]).to eq("assistant")
    end
  end

  describe "image formatting" do
    it "handles messages with images" do
      skip "Image handling requires file fixtures"
    end
  end

  describe "#image_block" do
    context "with URL image" do
      it "returns URL-based image block for http URLs" do
        result = formatter.send(:image_block, "http://example.com/image.png")

        expect(result).to be_a(Hash)
        expect(result[:type]).to eq("image")
        expect(result[:source]).to have_key(:type)
        expect(result[:source][:type]).to eq("url")
        expect(result[:source][:url]).to eq("http://example.com/image.png")
      end

      it "returns URL-based image block for https URLs" do
        result = formatter.send(:image_block, "https://example.com/image.png")

        expect(result).to be_a(Hash)
        expect(result[:source][:type]).to eq("url")
        expect(result[:source][:url]).to eq("https://example.com/image.png")
      end
    end

    context "with local file image" do
      let(:temp_file) do
        file = Tempfile.new(["test", ".png"], binmode: true)
        file.write("\x89PNG\r\n\x1a\n")
        file.close
        file
      end

      after { temp_file.unlink }

      it "returns base64-encoded image block for local files" do
        result = formatter.send(:image_block, temp_file.path)

        expect(result[:type]).to eq("image")
        expect(result[:source][:type]).to eq("base64")
        expect(result[:source]).to have_key(:media_type)
        expect(result[:source]).to have_key(:data)
      end

      it "includes correct mime type for png" do
        result = formatter.send(:image_block, temp_file.path)

        expect(result[:source][:media_type]).to eq("image/png")
      end

      it "base64 encodes file content" do
        result = formatter.send(:image_block, temp_file.path)
        data = result[:source][:data]

        # Verify it's valid base64
        expect { Base64.strict_decode64(data) }.not_to raise_error
      end
    end

    context "mime type detection" do
      it "detects jpeg from .jpg extension" do
        skip "Requires temp file setup"
      end

      it "detects jpeg from .jpeg extension" do
        skip "Requires temp file setup"
      end

      it "defaults to image/png for unknown extension" do
        temp_file = Tempfile.new(["test", ".unknown"], binmode: true)
        temp_file.write("data")
        temp_file.close

        result = formatter.send(:image_block, temp_file.path)

        expect(result[:source][:media_type]).to eq("image/png")

        temp_file.unlink
      end
    end
  end

  describe "#mime_type_for" do
    it "returns image/jpeg for .jpg" do
      result = formatter.send(:mime_type_for, "image.jpg")

      expect(result).to eq("image/jpeg")
    end

    it "returns image/jpeg for .jpeg" do
      result = formatter.send(:mime_type_for, "image.jpeg")

      expect(result).to eq("image/jpeg")
    end

    it "returns image/png for .png" do
      result = formatter.send(:mime_type_for, "image.png")

      expect(result).to eq("image/png")
    end

    it "returns image/gif for .gif" do
      result = formatter.send(:mime_type_for, "image.gif")

      expect(result).to eq("image/gif")
    end

    it "returns image/webp for .webp" do
      result = formatter.send(:mime_type_for, "image.webp")

      expect(result).to eq("image/webp")
    end

    it "defaults to image/png for unknown extension" do
      result = formatter.send(:mime_type_for, "image.unknown")

      expect(result).to eq("image/png")
    end

    it "is case-insensitive" do
      expect(formatter.send(:mime_type_for, "image.PNG")).to eq("image/png")
      expect(formatter.send(:mime_type_for, "image.JPG")).to eq("image/jpeg")
    end
  end

  describe "mime type constants" do
    it "includes mapping for common image formats" do
      mime_types = Smolagents::Models::Anthropic::MessageFormatter::MIME_TYPES

      expect(mime_types).to have_key(".jpg")
      expect(mime_types).to have_key(".jpeg")
      expect(mime_types).to have_key(".png")
      expect(mime_types).to have_key(".gif")
      expect(mime_types).to have_key(".webp")
    end

    it "maps to correct mime types" do
      mime_types = Smolagents::Models::Anthropic::MessageFormatter::MIME_TYPES

      expect(mime_types[".jpg"]).to eq("image/jpeg")
      expect(mime_types[".png"]).to eq("image/png")
    end

    it "is frozen for immutability" do
      mime_types = Smolagents::Models::Anthropic::MessageFormatter::MIME_TYPES

      expect(mime_types).to be_frozen
    end
  end
end
