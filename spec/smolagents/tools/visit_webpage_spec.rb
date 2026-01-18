require "spec_helper"
require "webmock/rspec"

RSpec.describe Smolagents::VisitWebpageTool do
  let(:tool) { described_class.new }

  describe "#execute" do
    let(:html_content) do
      <<~HTML
        <!DOCTYPE html>
        <html>
        <head><title>Test Page</title></head>
        <body>
          <h1>Main Title</h1>
          <p>This is a paragraph with <strong>bold</strong> and <em>italic</em> text.</p>
          <ul>
            <li>Item 1</li>
            <li>Item 2</li>
          </ul>
          <a href="https://example.com">Example Link</a>
        </body>
        </html>
      HTML
    end

    before do
      stub_request(:get, "https://example.com/test")
        .to_return(status: 200, body: html_content, headers: { "Content-Type" => "text/html" })
    end

    it "converts HTML to markdown" do
      result = tool.execute(url: "https://example.com/test")

      expect(result).to include("Main Title")
      expect(result).to include("paragraph")
      expect(result).to include("bold")
      expect(result).to include("italic")
    end

    it "converts headings to markdown format" do
      result = tool.execute(url: "https://example.com/test")

      expect(result).to match(/#+.*Main Title/)
    end

    it "converts links to markdown format" do
      result = tool.execute(url: "https://example.com/test")

      expect(result).to include("[Example Link](https://example.com)")
    end

    it "converts lists to markdown format" do
      result = tool.execute(url: "https://example.com/test")

      expect(result).to include("Item 1")
      expect(result).to include("Item 2")
    end

    it "removes script tags" do
      html_with_script = <<~HTML
        <html><body>
          <script>alert('xss')</script>
          <p>Safe content</p>
        </body></html>
      HTML

      stub_request(:get, "https://example.com/script")
        .to_return(status: 200, body: html_with_script)

      result = tool.execute(url: "https://example.com/script")

      expect(result).not_to include("alert")
      expect(result).to include("Safe content")
    end

    it "removes style tags" do
      html_with_style = <<~HTML
        <html><body>
          <style>.hidden { display: none; }</style>
          <p>Visible content</p>
        </body></html>
      HTML

      stub_request(:get, "https://example.com/style")
        .to_return(status: 200, body: html_with_style)

      result = tool.execute(url: "https://example.com/style")

      expect(result).not_to include("display: none")
      expect(result).to include("Visible content")
    end

    it "collapses multiple newlines" do
      html_with_spacing = <<~HTML
        <html><body>
          <p>First</p>



          <p>Second</p>
        </body></html>
      HTML

      stub_request(:get, "https://example.com/spacing")
        .to_return(status: 200, body: html_with_spacing)

      result = tool.execute(url: "https://example.com/spacing")

      expect(result).not_to include("\n\n\n")
    end

    context "with truncation" do
      let(:long_tool) { described_class.new(max_length: 50) }

      it "truncates long content" do
        stub_request(:get, "https://example.com/long")
          .to_return(status: 200, body: "<html><body><p>#{"x" * 100}</p></body></html>")

        result = long_tool.execute(url: "https://example.com/long")

        expect(result.length).to be <= 70 # 50 + truncation message
        expect(result).to include("_Truncated_")
      end
    end

    context "with errors" do
      it "handles timeout errors" do
        stub_request(:get, "https://example.com/timeout")
          .to_raise(Faraday::TimeoutError.new("execution expired"))

        result = tool.execute(url: "https://example.com/timeout")

        expect(result).to eq("Request timed out.")
      end

      it "handles connection errors" do
        stub_request(:get, "https://example.com/error")
          .to_raise(Faraday::ConnectionFailed.new("Connection refused"))

        result = tool.execute(url: "https://example.com/error")

        expect(result).to eq("Connection failed.")
      end
    end
  end

  describe "tool metadata" do
    it "has correct name" do
      expect(tool.name).to eq("visit_webpage")
    end

    it "has description" do
      expect(tool.description).to include("webpage")
    end

    it "has url input" do
      expect(tool.inputs).to have_key(:url)
    end

    it "returns string output" do
      expect(tool.output_type).to eq("string")
    end
  end

  describe "DSL configuration" do
    let(:custom_subclass) do
      Class.new(described_class) do
        self.tool_name = "compact_webpage"
        self.description = "Fetches webpages with compact settings"

        configure do |config|
          config.max_length 5_000
          config.timeout 10
        end
      end
    end

    it "applies class-level configuration" do
      tool = custom_subclass.new
      expect(tool.max_length).to eq(5_000)
    end

    it "allows instance override of class config" do
      tool = custom_subclass.new(max_length: 10_000)
      expect(tool.max_length).to eq(10_000)
    end

    it "config returns a Config object" do
      expect(custom_subclass.config).to be_a(described_class::Config)
    end

    it "config.to_h returns configuration values" do
      config = custom_subclass.config.to_h
      expect(config[:max_length]).to eq(5_000)
      expect(config[:timeout]).to eq(10)
    end

    it "uses defaults when no configuration provided" do
      expect(tool.max_length).to eq(40_000)
    end
  end
end
