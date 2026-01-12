RSpec.describe Smolagents::UserAgent do
  describe "#to_s" do
    it "generates minimal user agent without optional fields" do
      ua = described_class.new
      expect(ua.to_s).to eq(
        "Smolagents/#{Smolagents::VERSION} Ruby/#{RUBY_VERSION} " \
        "(+https://github.com/timlikesai/smolagents-ruby; bot)"
      )
    end

    it "includes model information when provided" do
      ua = described_class.new(model_id: "gpt-4-turbo")
      expect(ua.to_s).to include("Model:gpt-4-turbo")
    end

    it "includes tool information when provided" do
      ua = described_class.new(tool_name: "VisitWebpage")
      expect(ua.to_s).to include("Tool:VisitWebpage")
    end

    it "includes agent name and version when provided" do
      ua = described_class.new(agent_name: "TestAgent", agent_version: "2.0")
      expect(ua.to_s).to start_with("TestAgent/2.0")
    end

    it "uses custom contact URL when provided" do
      ua = described_class.new(contact_url: "https://example.com/docs")
      expect(ua.to_s).to include("(+https://example.com/docs; bot)")
    end

    it "includes all components in correct order" do
      ua = described_class.new(
        agent_name: "TestAgent",
        agent_version: "2.0",
        tool_name: "Search",
        model_id: "claude-3-sonnet"
      )

      string = ua.to_s
      expect(string).to match(
        %r{TestAgent/2.0 Smolagents/\S+ Tool:Search Model:claude-3-sonnet Ruby/\S+ \(.+\)}
      )
    end
  end

  describe "#with_tool" do
    it "creates new instance with tool context" do
      base = described_class.new(model_id: "gpt-4")
      with_tool = base.with_tool("WebSearch")

      expect(with_tool.to_s).to include("Tool:WebSearch")
      expect(with_tool.to_s).to include("Model:gpt-4")
    end

    it "preserves all other context" do
      base = described_class.new(
        agent_name: "Agent",
        agent_version: "1.0",
        model_id: "gpt-4",
        contact_url: "https://example.com"
      )
      with_tool = base.with_tool("MyTool")

      expect(with_tool.agent_name).to eq("Agent")
      expect(with_tool.agent_version).to eq("1.0")
      expect(with_tool.model_id).to eq("gpt-4")
      expect(with_tool.contact_url).to eq("https://example.com")
      expect(with_tool.tool_name).to eq("MyTool")
    end

    it "does not modify the original" do
      base = described_class.new(model_id: "gpt-4")
      base.with_tool("WebSearch")

      expect(base.tool_name).to be_nil
    end
  end

  describe "#with_model" do
    it "creates new instance with model context" do
      base = described_class.new(tool_name: "Search")
      with_model = base.with_model("claude-3")

      expect(with_model.to_s).to include("Model:claude-3")
      expect(with_model.to_s).to include("Tool:Search")
    end

    it "does not modify the original" do
      base = described_class.new(tool_name: "Search")
      base.with_model("claude-3")

      expect(base.model_id).to be_nil
    end
  end

  describe "model_id sanitization" do
    it "removes HuggingFace org prefixes" do
      ua = described_class.new(model_id: "meta-llama/Llama-2-7b")
      expect(ua.model_id).to eq("Llama-2-7b")
    end

    it "removes timestamp suffixes" do
      ua = described_class.new(model_id: "claude-3-sonnet-20241022")
      expect(ua.model_id).to eq("claude-3-sonnet")
    end

    it "removes .gguf extension" do
      ua = described_class.new(model_id: "./models/llama-2.gguf")
      expect(ua.model_id).to eq("llama-2")
    end

    it "removes .safetensors extension" do
      ua = described_class.new(model_id: "model.safetensors")
      expect(ua.model_id).to eq("model")
    end

    it "removes .bin extension" do
      ua = described_class.new(model_id: "model.bin")
      expect(ua.model_id).to eq("model")
    end

    it "removes .pt extension" do
      ua = described_class.new(model_id: "model.pt")
      expect(ua.model_id).to eq("model")
    end

    it "replaces invalid characters with underscores" do
      ua = described_class.new(model_id: "model<name>with|special")
      expect(ua.model_id).to eq("model_name_with_special")
    end

    it "limits length to max" do
      long_model = "a" * 100
      ua = described_class.new(model_id: long_model)
      expect(ua.model_id.length).to eq(described_class::MAX_MODEL_ID_LENGTH)
    end

    it "handles nil model_id" do
      ua = described_class.new(model_id: nil)
      expect(ua.model_id).to be_nil
    end

    it "handles empty string model_id" do
      ua = described_class.new(model_id: "")
      expect(ua.model_id).to be_nil
    end

    it "handles path with multiple components" do
      ua = described_class.new(model_id: "openai/gpt-4")
      expect(ua.model_id).to eq("gpt-4")
    end

    it "handles local path with directory" do
      ua = described_class.new(model_id: "./models/my-local-model.gguf")
      expect(ua.model_id).to eq("my-local-model")
    end
  end
end
