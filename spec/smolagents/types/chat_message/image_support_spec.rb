require "spec_helper"

RSpec.describe Smolagents::Types::ChatMessageComponents::ImageSupport do
  let(:test_class) do
    Class.new do
      extend Smolagents::Types::ChatMessageComponents::ImageSupport
    end
  end

  describe "#image_to_content_block" do
    context "with remote URLs" do
      it "creates url content block for https URL" do
        result = test_class.image_to_content_block("https://example.com/photo.jpg")
        expect(result).to eq({
                               type: "image_url",
                               image_url: { url: "https://example.com/photo.jpg" }
                             })
      end

      it "creates url content block for http URL" do
        result = test_class.image_to_content_block("http://example.com/image.png")
        expect(result).to eq({
                               type: "image_url",
                               image_url: { url: "http://example.com/image.png" }
                             })
      end

      it "preserves URL query parameters" do
        url = "https://cdn.example.com/img.jpg?width=800&format=webp"
        result = test_class.image_to_content_block(url)
        expect(result[:image_url][:url]).to eq(url)
      end
    end

    context "with local files" do
      let(:temp_dir) { Dir.mktmpdir }

      after { FileUtils.rm_rf(temp_dir) }

      it "encodes JPEG file as base64" do
        path = File.join(temp_dir, "test.jpg")
        File.binwrite(path, "fake jpeg data")
        result = test_class.image_to_content_block(path)

        expect(result[:type]).to eq("image_url")
        expect(result[:image_url][:url]).to start_with("data:image/jpeg;base64,")
        expect(result[:image_url][:url]).to include(Base64.strict_encode64("fake jpeg data"))
      end

      it "encodes PNG file as base64" do
        path = File.join(temp_dir, "test.png")
        File.binwrite(path, "fake png data")
        result = test_class.image_to_content_block(path)

        expect(result[:image_url][:url]).to start_with("data:image/png;base64,")
      end

      it "encodes GIF file as base64" do
        path = File.join(temp_dir, "animation.gif")
        File.binwrite(path, "GIF89a")
        result = test_class.image_to_content_block(path)

        expect(result[:image_url][:url]).to start_with("data:image/gif;base64,")
      end

      it "encodes WebP file as base64" do
        path = File.join(temp_dir, "modern.webp")
        File.binwrite(path, "RIFF")
        result = test_class.image_to_content_block(path)

        expect(result[:image_url][:url]).to start_with("data:image/webp;base64,")
      end

      it "handles .jpeg extension same as .jpg" do
        path = File.join(temp_dir, "photo.jpeg")
        File.binwrite(path, "jpeg data")
        result = test_class.image_to_content_block(path)

        expect(result[:image_url][:url]).to start_with("data:image/jpeg;base64,")
      end

      it "defaults unknown extensions to image/png" do
        path = File.join(temp_dir, "unknown.bmp")
        File.binwrite(path, "bitmap")
        result = test_class.image_to_content_block(path)

        expect(result[:image_url][:url]).to start_with("data:image/png;base64,")
      end

      it "handles uppercase extensions" do
        path = File.join(temp_dir, "PHOTO.JPG")
        File.binwrite(path, "data")
        result = test_class.image_to_content_block(path)

        expect(result[:image_url][:url]).to start_with("data:image/jpeg;base64,")
      end

      it "reads binary data correctly" do
        path = File.join(temp_dir, "binary.png")
        binary_data = (0..255).to_a.pack("C*")
        File.binwrite(path, binary_data)
        result = test_class.image_to_content_block(path)

        encoded = result[:image_url][:url].sub("data:image/png;base64,", "")
        expect(Base64.strict_decode64(encoded)).to eq(binary_data)
      end

      it "raises error for non-existent file" do
        expect do
          test_class.image_to_content_block("/nonexistent/path/image.jpg")
        end.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe "IMAGE_MIME_TYPES constant" do
    let(:mime_types) { Smolagents::Types::IMAGE_MIME_TYPES }

    it "maps common image extensions to MIME types" do
      expect(mime_types[".jpg"]).to eq("image/jpeg")
      expect(mime_types[".jpeg"]).to eq("image/jpeg")
      expect(mime_types[".png"]).to eq("image/png")
      expect(mime_types[".gif"]).to eq("image/gif")
      expect(mime_types[".webp"]).to eq("image/webp")
    end

    it "is frozen" do
      expect(mime_types).to be_frozen
    end
  end
end
