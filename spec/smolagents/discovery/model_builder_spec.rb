require "smolagents"

RSpec.describe Smolagents::Discovery::ModelBuilder do
  let(:ctx) do
    Smolagents::Discovery::ScanContext.new(
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      timeout: 2.0,
      tls: false,
      api_key: nil
    )
  end

  describe ".build" do
    it "creates DiscoveredModel with context attributes" do
      model = described_class.build(ctx, id: "test-model")

      expect(model).to be_a(Smolagents::Discovery::DiscoveredModel)
      expect(model.id).to eq("test-model")
      expect(model.provider).to eq(:lm_studio)
      expect(model.host).to eq("localhost")
      expect(model.port).to eq(1234)
      expect(model.tls).to be false
      expect(model.api_key).to be_nil
    end

    it "uses default state of :available" do
      model = described_class.build(ctx, id: "test")

      expect(model.state).to eq(:available)
    end

    it "accepts all optional parameters" do
      model = described_class.build(
        ctx,
        id: "model",
        context_length: 8192,
        state: :loaded,
        capabilities: ["tool_use"],
        type: "vlm"
      )

      expect(model.context_length).to eq(8192)
      expect(model.state).to eq(:loaded)
      expect(model.capabilities).to eq(["tool_use"])
      expect(model.type).to eq("vlm")
    end
  end

  describe ".ctx_attrs" do
    it "extracts context attributes as hash" do
      attrs = described_class.ctx_attrs(ctx)

      expect(attrs).to eq(
        provider: :lm_studio,
        host: "localhost",
        port: 1234,
        tls: false,
        api_key: nil
      )
    end

    it "includes tls and api_key when set" do
      tls_ctx = Smolagents::Discovery::ScanContext.new(
        provider: :openai_compatible,
        host: "api.example.com",
        port: 443,
        timeout: 2.0,
        tls: true,
        api_key: "sk-test"
      )

      attrs = described_class.ctx_attrs(tls_ctx)

      expect(attrs[:tls]).to be true
      expect(attrs[:api_key]).to eq("sk-test")
    end
  end

  describe ".from_lm_studio" do
    it "parses loaded model from LM Studio format" do
      model_data = {
        "key" => "llama-3.2-1b",
        "type" => "llm",
        "max_context_length" => 131_072,
        "loaded_instances" => [{ "id" => "llama-3.2-1b-instruct" }],
        "capabilities" => { "trained_for_tool_use" => true, "vision" => false }
      }

      model = described_class.from_lm_studio(ctx, model_data)

      expect(model.id).to eq("llama-3.2-1b-instruct")
      expect(model.state).to eq(:loaded)
      expect(model.context_length).to eq(131_072)
      expect(model.capabilities).to include("tool_use")
      expect(model.type).to eq("llm")
    end

    it "uses key when no loaded instances" do
      model_data = {
        "key" => "unloaded-model",
        "loaded_instances" => []
      }

      model = described_class.from_lm_studio(ctx, model_data)

      expect(model.id).to eq("unloaded-model")
      expect(model.state).to eq(:not_loaded)
    end

    it "extracts vision capability" do
      model_data = {
        "key" => "vlm",
        "loaded_instances" => [{ "id" => "vlm" }],
        "capabilities" => { "vision" => true }
      }

      model = described_class.from_lm_studio(ctx, model_data)

      expect(model.capabilities).to include("vision")
    end
  end

  describe ".from_v0" do
    it "parses v0 API model format" do
      model_data = {
        "id" => "gpt-4-turbo",
        "max_context_length" => 128_000,
        "state" => "loaded",
        "capabilities" => %w[tool_use vision],
        "type" => "chat"
      }

      model = described_class.from_v0(ctx, model_data)

      expect(model.id).to eq("gpt-4-turbo")
      expect(model.context_length).to eq(128_000)
      expect(model.state).to eq(:loaded)
      expect(model.capabilities).to eq(%w[tool_use vision])
      expect(model.type).to eq("chat")
    end

    it "uses loaded_context_length as fallback" do
      model_data = {
        "id" => "model",
        "loaded_context_length" => 4096
      }

      model = described_class.from_v0(ctx, model_data)

      expect(model.context_length).to eq(4096)
    end

    it "defaults state to available" do
      model_data = { "id" => "model" }

      model = described_class.from_v0(ctx, model_data)

      expect(model.state).to eq(:available)
    end
  end

  describe ".from_v1" do
    it "parses v1 API model format" do
      model_data = {
        "id" => "llama-3",
        "status" => {
          "value" => "loaded",
          "args" => ["--ctx-size", "8192", "--other", "arg"]
        }
      }

      model = described_class.from_v1(ctx, model_data)

      expect(model.id).to eq("llama-3")
      expect(model.state).to eq(:loaded)
      expect(model.context_length).to eq(8192)
    end

    it "handles missing status" do
      model_data = { "id" => "model" }

      model = described_class.from_v1(ctx, model_data)

      expect(model.state).to eq(:available)
      expect(model.context_length).to be_nil
    end

    it "handles missing args" do
      model_data = {
        "id" => "model",
        "status" => { "value" => "loaded" }
      }

      model = described_class.from_v1(ctx, model_data)

      expect(model.context_length).to be_nil
    end
  end

  describe ".from_native" do
    it "parses Ollama-style model with name field" do
      model_data = { "name" => "llama2:latest" }

      model = described_class.from_native(ctx, model_data)

      expect(model.id).to eq("llama2:latest")
    end

    it "falls back to model field" do
      model_data = { "model" => "vicuna" }

      model = described_class.from_native(ctx, model_data)

      expect(model.id).to eq("vicuna")
    end

    it "prefers name over model" do
      model_data = { "name" => "preferred", "model" => "fallback" }

      model = described_class.from_native(ctx, model_data)

      expect(model.id).to eq("preferred")
    end
  end

  describe ".extract_capabilities" do
    it "extracts tool_use capability" do
      data = { "capabilities" => { "trained_for_tool_use" => true } }

      caps = described_class.extract_capabilities(data)

      expect(caps).to eq(["tool_use"])
    end

    it "extracts vision capability" do
      data = { "capabilities" => { "vision" => true } }

      caps = described_class.extract_capabilities(data)

      expect(caps).to eq(["vision"])
    end

    it "extracts multiple capabilities" do
      data = { "capabilities" => { "trained_for_tool_use" => true, "vision" => true } }

      caps = described_class.extract_capabilities(data)

      expect(caps).to contain_exactly("tool_use", "vision")
    end

    it "returns nil when no capabilities" do
      data = { "capabilities" => { "trained_for_tool_use" => false } }

      caps = described_class.extract_capabilities(data)

      expect(caps).to be_nil
    end

    it "returns nil when capabilities key missing" do
      data = {}

      caps = described_class.extract_capabilities(data)

      expect(caps).to be_nil
    end
  end

  describe ".extract_state" do
    it "returns :loaded for loaded status" do
      data = { "status" => { "value" => "loaded" } }

      expect(described_class.extract_state(data)).to eq(:loaded)
    end

    it "returns :loading for loading status" do
      data = { "status" => { "value" => "loading" } }

      expect(described_class.extract_state(data)).to eq(:loading)
    end

    it "returns :unloaded for unloaded status" do
      data = { "status" => { "value" => "unloaded" } }

      expect(described_class.extract_state(data)).to eq(:unloaded)
    end

    it "returns :available for unknown status" do
      data = { "status" => { "value" => "unknown" } }

      expect(described_class.extract_state(data)).to eq(:available)
    end

    it "returns :available when status missing" do
      data = {}

      expect(described_class.extract_state(data)).to eq(:available)
    end
  end

  describe ".extract_context" do
    it "extracts context size from args" do
      data = { "status" => { "args" => ["--ctx-size", "8192"] } }

      expect(described_class.extract_context(data)).to eq(8192)
    end

    it "finds ctx-size among multiple args" do
      data = { "status" => { "args" => ["--other", "val", "--ctx-size", "16384", "--more", "args"] } }

      expect(described_class.extract_context(data)).to eq(16_384)
    end

    it "returns nil when ctx-size not present" do
      data = { "status" => { "args" => ["--other", "arg"] } }

      expect(described_class.extract_context(data)).to be_nil
    end

    it "returns nil when args empty" do
      data = { "status" => { "args" => [] } }

      expect(described_class.extract_context(data)).to be_nil
    end

    it "returns nil when args missing" do
      data = { "status" => {} }

      expect(described_class.extract_context(data)).to be_nil
    end

    it "returns nil when ctx-size is last element" do
      data = { "status" => { "args" => ["--ctx-size"] } }

      expect(described_class.extract_context(data)).to be_nil
    end
  end
end
