require "smolagents"

RSpec.describe Smolagents::Discovery::ResponseParsers do
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

  describe ".parse_lm_studio_response" do
    it "parses LM Studio API v1 models response" do
      response = JSON.generate({
                                 "models" => [
                                   {
                                     "key" => "llama-3.2-1b",
                                     "type" => "llm",
                                     "max_context_length" => 8192,
                                     "loaded_instances" => [{ "id" => "llama-3.2-1b-instruct" }],
                                     "capabilities" => { "trained_for_tool_use" => true, "vision" => false }
                                   }
                                 ]
                               })

      models = described_class.parse_lm_studio_response(response, ctx)

      expect(models.length).to eq(1)
      expect(models.first.id).to eq("llama-3.2-1b-instruct")
      expect(models.first.state).to eq(:loaded)
      expect(models.first.context_length).to eq(8192)
      expect(models.first.capabilities).to include("tool_use")
    end

    it "uses key as ID when no loaded instances" do
      response = JSON.generate({
                                 "models" => [
                                   {
                                     "key" => "unloaded-model",
                                     "type" => "llm",
                                     "loaded_instances" => []
                                   }
                                 ]
                               })

      models = described_class.parse_lm_studio_response(response, ctx)

      expect(models.first.id).to eq("unloaded-model")
      expect(models.first.state).to eq(:not_loaded)
    end

    it "returns empty array for invalid JSON" do
      models = described_class.parse_lm_studio_response("not json", ctx)

      expect(models).to eq([])
    end

    it "returns empty array when models key is missing" do
      response = JSON.generate({ "other" => "data" })

      models = described_class.parse_lm_studio_response(response, ctx)

      expect(models).to eq([])
    end
  end

  describe ".parse_v0_response" do
    it "parses v0 API models response" do
      response = JSON.generate({
                                 "data" => [
                                   {
                                     "id" => "gpt-4-turbo",
                                     "max_context_length" => 128_000,
                                     "state" => "loaded",
                                     "capabilities" => ["tool_use"],
                                     "type" => "llm"
                                   }
                                 ]
                               })

      models = described_class.parse_v0_response(response, ctx)

      expect(models.length).to eq(1)
      expect(models.first.id).to eq("gpt-4-turbo")
      expect(models.first.state).to eq(:loaded)
      expect(models.first.context_length).to eq(128_000)
    end

    it "uses loaded_context_length as fallback" do
      response = JSON.generate({
                                 "data" => [
                                   {
                                     "id" => "model",
                                     "loaded_context_length" => 4096
                                   }
                                 ]
                               })

      models = described_class.parse_v0_response(response, ctx)

      expect(models.first.context_length).to eq(4096)
    end

    it "defaults state to available when not specified" do
      response = JSON.generate({
                                 "data" => [{ "id" => "model" }]
                               })

      models = described_class.parse_v0_response(response, ctx)

      expect(models.first.state).to eq(:available)
    end
  end

  describe ".parse_v1_response" do
    it "parses v1 API models response" do
      response = JSON.generate({
                                 "data" => [
                                   {
                                     "id" => "llama-3",
                                     "status" => {
                                       "value" => "loaded",
                                       "args" => ["--ctx-size", "8192"]
                                     }
                                   }
                                 ]
                               })

      models = described_class.parse_v1_response(response, ctx)

      expect(models.length).to eq(1)
      expect(models.first.id).to eq("llama-3")
      expect(models.first.state).to eq(:loaded)
      expect(models.first.context_length).to eq(8192)
    end

    it "handles loading state" do
      response = JSON.generate({
                                 "data" => [
                                   { "id" => "model", "status" => { "value" => "loading" } }
                                 ]
                               })

      models = described_class.parse_v1_response(response, ctx)

      expect(models.first.state).to eq(:loading)
    end

    it "handles unloaded state" do
      response = JSON.generate({
                                 "data" => [
                                   { "id" => "model", "status" => { "value" => "unloaded" } }
                                 ]
                               })

      models = described_class.parse_v1_response(response, ctx)

      expect(models.first.state).to eq(:unloaded)
    end

    it "defaults to available for unknown state" do
      response = JSON.generate({
                                 "data" => [
                                   { "id" => "model", "status" => { "value" => "unknown" } }
                                 ]
                               })

      models = described_class.parse_v1_response(response, ctx)

      expect(models.first.state).to eq(:available)
    end

    it "returns nil context_length when no ctx-size arg" do
      response = JSON.generate({
                                 "data" => [
                                   { "id" => "model", "status" => { "args" => ["--other", "value"] } }
                                 ]
                               })

      models = described_class.parse_v1_response(response, ctx)

      expect(models.first.context_length).to be_nil
    end
  end

  describe ".parse_native_response" do
    it "parses Ollama-style native response with name field" do
      response = JSON.generate({
                                 "models" => [
                                   { "name" => "llama2:latest" },
                                   { "name" => "codellama:7b" }
                                 ]
                               })

      models = described_class.parse_native_response(response, ctx)

      expect(models.length).to eq(2)
      expect(models.first.id).to eq("llama2:latest")
      expect(models.last.id).to eq("codellama:7b")
    end

    it "uses model field as fallback" do
      response = JSON.generate({
                                 "models" => [{ "model" => "vicuna" }]
                               })

      models = described_class.parse_native_response(response, ctx)

      expect(models.first.id).to eq("vicuna")
    end
  end

  describe ".parse_json_models" do
    it "parses JSON and maps models" do
      response = JSON.generate({ "items" => [{ "value" => 1 }, { "value" => 2 }] })

      result = described_class.parse_json_models(response, "items") { |m| m["value"] * 2 }

      expect(result).to eq([2, 4])
    end

    it "returns empty array for invalid JSON" do
      result = described_class.parse_json_models("invalid", "items") { |m| m }

      expect(result).to eq([])
    end

    it "returns empty array when key not found" do
      response = JSON.generate({ "other" => "data" })

      result = described_class.parse_json_models(response, "items") { |m| m }

      expect(result).to eq([])
    end
  end
end
