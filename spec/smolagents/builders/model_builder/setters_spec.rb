require "spec_helper"

RSpec.describe Smolagents::Builders::ModelBuilderSetters do
  let(:builder_class) { Smolagents::Builders::ModelBuilder }
  let(:builder) { builder_class.create(:openai) }

  describe "#id" do
    it "sets the model ID" do
      result = builder.id("gpt-4")

      expect(result.config[:model_id]).to eq("gpt-4")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.id("gpt-4")

      expect(result).not_to equal(builder)
      expect(result).to be_a(builder_class)
    end

    it "does not mutate original builder" do
      builder.id("gpt-4")

      expect(builder.config[:model_id]).to be_nil
    end

    it "validates non-empty string" do
      expect { builder.id("") }.to raise_error(ArgumentError)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.id("gpt-4") }.to raise_error(FrozenError)
      end
    end
  end

  describe "#api_key" do
    it "sets the API key" do
      result = builder.api_key("sk-test-key")

      expect(result.config[:api_key]).to eq("sk-test-key")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.api_key("sk-test")

      expect(result).not_to equal(builder)
    end

    it "validates non-empty string" do
      expect { builder.api_key("") }.to raise_error(ArgumentError)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.api_key("sk-test") }.to raise_error(FrozenError)
      end
    end
  end

  describe "#endpoint" do
    it "sets the API base URL" do
      result = builder.endpoint("https://api.example.com/v1")

      expect(result.config[:api_base]).to eq("https://api.example.com/v1")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.endpoint("https://api.example.com/v1")

      expect(result).not_to equal(builder)
    end
  end

  describe "#temperature" do
    it "sets the temperature" do
      result = builder.temperature(0.7)

      expect(result.config[:temperature]).to eq(0.7)
    end

    it "accepts integer values" do
      result = builder.temperature(1)

      expect(result.config[:temperature]).to eq(1)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.temperature(0.5)

      expect(result).not_to equal(builder)
    end

    it "validates range 0.0-2.0" do
      expect { builder.temperature(-0.1) }.to raise_error(ArgumentError)
      expect { builder.temperature(2.1) }.to raise_error(ArgumentError)
    end

    it "accepts boundary values" do
      expect(builder.temperature(0.0).config[:temperature]).to eq(0.0)
      expect(builder.temperature(2.0).config[:temperature]).to eq(2.0)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.temperature(0.5) }.to raise_error(FrozenError)
      end
    end
  end

  describe "#timeout" do
    it "sets the timeout in seconds" do
      result = builder.timeout(30)

      expect(result.config[:timeout]).to eq(30)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.timeout(60)

      expect(result).not_to equal(builder)
    end

    it "validates positive value" do
      expect { builder.timeout(0) }.to raise_error(ArgumentError)
      expect { builder.timeout(-10) }.to raise_error(ArgumentError)
    end

    it "validates max value (600 seconds)" do
      expect { builder.timeout(601) }.to raise_error(ArgumentError)
    end

    it "accepts boundary values" do
      expect(builder.timeout(1).config[:timeout]).to eq(1)
      expect(builder.timeout(600).config[:timeout]).to eq(600)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.timeout(30) }.to raise_error(FrozenError)
      end
    end
  end

  describe "#max_tokens" do
    it "sets the maximum tokens" do
      result = builder.max_tokens(4096)

      expect(result.config[:max_tokens]).to eq(4096)
    end

    it "returns a new builder instance (immutability)" do
      result = builder.max_tokens(2048)

      expect(result).not_to equal(builder)
    end

    it "validates positive integer" do
      expect { builder.max_tokens(0) }.to raise_error(ArgumentError)
      expect { builder.max_tokens(-100) }.to raise_error(ArgumentError)
    end

    it "validates max value (100000)" do
      expect { builder.max_tokens(100_001) }.to raise_error(ArgumentError)
    end

    it "accepts boundary values" do
      expect(builder.max_tokens(1).config[:max_tokens]).to eq(1)
      expect(builder.max_tokens(100_000).config[:max_tokens]).to eq(100_000)
    end

    context "when builder is frozen" do
      it "raises FrozenError" do
        frozen = builder.freeze!

        expect { frozen.max_tokens(4096) }.to raise_error(FrozenError)
      end
    end
  end

  describe "#at" do
    it "configures host and port" do
      result = builder.at(host: "myserver.local", port: 8080)

      expect(result.config[:api_base]).to eq("http://myserver.local:8080/v1")
    end

    it "sets api_key to not-needed for local servers" do
      result = builder.at(host: "localhost", port: 1234)

      expect(result.config[:api_key]).to eq("not-needed")
    end

    it "uses /api/v1 path for ollama type" do
      result = builder_class.create(:ollama).at(host: "localhost", port: 11_434)

      expect(result.config[:api_base]).to eq("http://localhost:11434/api/v1")
    end

    it "uses /v1 path for other types" do
      result = builder_class.create(:lm_studio).at(host: "localhost", port: 1234)

      expect(result.config[:api_base]).to eq("http://localhost:1234/v1")
    end

    it "returns a new builder instance (immutability)" do
      result = builder.at(host: "test", port: 8080)

      expect(result).not_to equal(builder)
    end
  end

  describe "chaining setters" do
    it "supports chaining all setters" do
      result = builder
               .id("gpt-4")
               .api_key("sk-test")
               .endpoint("https://api.example.com/v1")
               .temperature(0.7)
               .timeout(30)
               .max_tokens(4096)

      expect(result.config[:model_id]).to eq("gpt-4")
      expect(result.config[:api_key]).to eq("sk-test")
      expect(result.config[:api_base]).to eq("https://api.example.com/v1")
      expect(result.config[:temperature]).to eq(0.7)
      expect(result.config[:timeout]).to eq(30)
      expect(result.config[:max_tokens]).to eq(4096)
    end

    it "preserves all values through the chain" do
      result = builder
               .id("model-a")
               .temperature(0.5)
               .id("model-b")

      expect(result.config[:model_id]).to eq("model-b")
      expect(result.config[:temperature]).to eq(0.5)
    end
  end
end
