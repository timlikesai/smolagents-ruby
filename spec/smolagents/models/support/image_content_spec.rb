require "smolagents/models/support/image_content"

RSpec.describe Smolagents::Models::ModelSupport::ImageContent do
  let(:model_class) do
    Class.new do
      include Smolagents::Models::ModelSupport::ImageContent

      # Implement provider-specific image_block format
      def image_block(image)
        { type: "image", url: image }
      end
    end
  end
  let(:model) { model_class.new }

  describe "#build_content_with_images" do
    it "builds content array starting with text block" do
      message = Smolagents::ChatMessage.user("Look at this image", images: ["image.png"])

      result = model.build_content_with_images(message)

      expect(result[0]).to have_key(:type)
      expect(result[0][:type]).to eq("text")
    end

    it "includes message content in text block" do
      message = Smolagents::ChatMessage.user("Look at this image", images: ["image.png"])

      result = model.build_content_with_images(message)

      expect(result[0][:text]).to eq("Look at this image")
    end

    it "appends image blocks after text" do
      message = Smolagents::ChatMessage.user("Look at this", images: ["image1.png", "image2.jpg"])

      result = model.build_content_with_images(message)

      expect(result.length).to eq(3) # text + 2 images
      expect(result[1][:type]).to eq("image")
      expect(result[2][:type]).to eq("image")
    end

    it "delegates image formatting to image_block method" do
      message = Smolagents::ChatMessage.user("Text", images: ["image.png"])

      allow(model).to receive(:image_block).and_call_original

      model.build_content_with_images(message)

      expect(model).to have_received(:image_block).with("image.png")
    end

    it "handles empty message content as empty string" do
      message = Smolagents::ChatMessage.user(nil, images: ["image.png"])

      result = model.build_content_with_images(message)

      expect(result[0][:text]).to eq("")
    end

    it "preserves text content as-is" do
      content = "Analyze this image with unicode: 你好"
      message = Smolagents::ChatMessage.user(content, images: ["image.png"])

      result = model.build_content_with_images(message)

      expect(result[0][:text]).to eq(content)
    end

    it "handles multiple images in order" do
      images = ["first.png", "second.jpg", "third.webp"]
      message = Smolagents::ChatMessage.user("Multiple", images:)

      result = model.build_content_with_images(message)

      image_blocks = result[1..]
      expect(image_blocks.map { |b| b[:url] }).to eq(images)
    end

    it "handles single image" do
      message = Smolagents::ChatMessage.user("Text", images: ["image.png"])

      result = model.build_content_with_images(message)

      expect(result.length).to eq(2)
      expect(result[1][:url]).to eq("image.png")
    end

    it "returns proper multipart content structure" do
      message = Smolagents::ChatMessage.user("Look", images: ["img.png"])

      result = model.build_content_with_images(message)

      expect(result).to be_an(Array)
      expect(result.all?(Hash)).to be true
      expect(result.all? { |item| item.key?(:type) }).to be true
    end

    context "with OpenAI-like image_block implementation" do
      let(:openai_class) do
        Class.new do
          include Smolagents::Models::ModelSupport::ImageContent

          def image_block(image)
            { type: "image_url", image_url: { url: image } }
          end
        end
      end
      let(:openai_model) { openai_class.new }

      it "builds OpenAI-compatible format" do
        message = Smolagents::ChatMessage.user("Analyze", images: ["https://example.com/image.png"])

        result = openai_model.build_content_with_images(message)

        expect(result[1][:type]).to eq("image_url")
        expect(result[1][:image_url][:url]).to eq("https://example.com/image.png")
      end
    end

    context "with Anthropic-like image_block implementation" do
      let(:anthropic_class) do
        Class.new do
          include Smolagents::Models::ModelSupport::ImageContent

          def image_block(image)
            { type: "image", source: { type: "url", url: image } }
          end
        end
      end
      let(:anthropic_model) { anthropic_class.new }

      it "builds Anthropic-compatible format" do
        message = Smolagents::ChatMessage.user("Describe", images: ["https://example.com/pic.jpg"])

        result = anthropic_model.build_content_with_images(message)

        expect(result[1][:type]).to eq("image")
        expect(result[1][:source][:url]).to eq("https://example.com/pic.jpg")
      end
    end

    context "with provider-specific transformations" do
      it "applies image_block transformation consistently" do
        message = Smolagents::ChatMessage.user("Text", images: ["img1.png", "img2.png"])

        # Default implementation in model_class
        result = model.build_content_with_images(message)

        # Each image should be passed through image_block
        expect(result[1][:url]).to eq("img1.png")
        expect(result[2][:url]).to eq("img2.png")
      end
    end
  end

  describe "integration with ChatMessage" do
    it "works with messages that have images" do
      skip "Requires ChatMessage to have image support methods"
    end

    it "handles nil image array" do
      message = Smolagents::ChatMessage.user("Text")

      expect do
        model.build_content_with_images(message)
      end.to raise_error(NoMethodError, /for nil/)
    end

    it "handles empty image array" do
      message = Smolagents::ChatMessage.user("Text", images: [])

      result = model.build_content_with_images(message)

      expect(result.length).to eq(1)
      expect(result[0][:type]).to eq("text")
    end
  end
end
