begin
  require "openai"
rescue LoadError
  nil # Optional dependency - tests use mocks
end

# rubocop:disable Lint/MissingSuper -- test classes intentionally skip parent initialization
RSpec.describe Smolagents::Models::Model::Capabilities do
  # Create a test model class for testing the mixin in isolation
  let(:test_model_class) do
    Class.new(Smolagents::Models::Model) do
      def initialize(**); end
    end
  end

  let(:model) { test_model_class.new }

  describe "ClassMethods" do
    describe ".default_capabilities" do
      it "returns unknown capabilities by default" do
        caps = test_model_class.default_capabilities
        expect(caps).to be_a(Smolagents::Types::ServerCapability)
        expect(caps.unknown?).to be true
      end

      it "returns a capability with nil values for unknown state" do
        caps = test_model_class.default_capabilities
        expect(caps.supports_tools).to be_nil
        expect(caps.supports_vision).to be_nil
        expect(caps.supports_json_schema).to be_nil
        expect(caps.supports_json_object).to be_nil
        expect(caps.max_context_length).to be_nil
        expect(caps.max_tokens_limit).to be_nil
      end
    end

    context "when subclass overrides default_capabilities" do
      let(:custom_model_class) do
        Class.new(Smolagents::Models::Model) do
          def initialize(**); end

          def self.default_capabilities
            Smolagents::Types::ServerCapability.from_server_type(
              Smolagents::Types::ServerType.lookup(:openai)
            )
          end
        end
      end

      it "uses the subclass default" do
        caps = custom_model_class.default_capabilities
        expect(caps.supports_tools).to be true
        expect(caps.supports_json_schema).to be true
        expect(caps.base?).to be true
      end
    end
  end

  describe "#capabilities" do
    it "returns ServerCapability instance" do
      expect(model.capabilities).to be_a(Smolagents::Types::ServerCapability)
    end

    it "lazily initializes capabilities (called once)" do
      # First call builds capabilities
      first_call = model.capabilities
      # Second call returns cached instance
      second_call = model.capabilities
      expect(first_call).to be(second_call)
    end

    it "uses default_capabilities via build_capabilities" do
      caps = model.capabilities
      expect(caps.unknown?).to be true
    end
  end

  describe "predicate delegates" do
    context "with unknown capabilities" do
      it "returns nil for supports_tools?" do
        expect(model.supports_tools?).to be_nil
      end

      it "returns nil for supports_vision?" do
        expect(model.supports_vision?).to be_nil
      end

      it "returns nil for supports_json_schema?" do
        expect(model.supports_json_schema?).to be_nil
      end

      it "returns nil for supports_json_object?" do
        expect(model.supports_json_object?).to be_nil
      end
    end

    context "with known capabilities" do
      let(:model_with_caps) do
        klass = Class.new(Smolagents::Models::Model) do
          def initialize(**); end

          private

          def build_capabilities
            Smolagents::Types::ServerCapability.from_server_type(
              Smolagents::Types::ServerType.lookup(:openai)
            )
          end
        end
        klass.new
      end

      it "returns true for supports_tools?" do
        expect(model_with_caps.supports_tools?).to be true
      end

      it "returns false for supports_vision? (OpenAI base does not include vision)" do
        expect(model_with_caps.supports_vision?).to be false
      end

      it "returns true for supports_json_schema?" do
        expect(model_with_caps.supports_json_schema?).to be true
      end

      it "returns true for supports_json_object?" do
        expect(model_with_caps.supports_json_object?).to be true
      end
    end
  end

  describe "context limit accessors" do
    context "with unknown capabilities" do
      it "returns nil for capability_context_window" do
        expect(model.capability_context_window).to be_nil
      end

      it "returns nil for capability_max_output_tokens" do
        expect(model.capability_max_output_tokens).to be_nil
      end
    end

    context "with probed capabilities (has context limits)" do
      let(:model_with_limits) do
        klass = Class.new(Smolagents::Models::Model) do
          def initialize(**); end

          private

          def build_capabilities
            model_caps = Smolagents::Concerns::Resilience::LmStudioProbe::ModelCapabilities.new(
              model_key: "test-model",
              trained_for_tool_use: true,
              vision: false,
              max_context_length: 128_000,
              format: "gguf",
              architecture: "llama",
              quantization: "q8_0"
            )
            Smolagents::Types::ServerCapability.from_lm_studio_probe(model_caps)
          end
        end
        klass.new
      end

      it "returns context window from probed capabilities" do
        expect(model_with_limits.capability_context_window).to eq(128_000)
      end

      it "returns nil for max_output_tokens (not set by probe)" do
        expect(model_with_limits.capability_max_output_tokens).to be_nil
      end
    end
  end

  describe "subclass override of build_capabilities" do
    let(:lm_studio_model) do
      klass = Class.new(Smolagents::Models::Model) do
        def initialize(**); end

        private

        def build_capabilities
          Smolagents::Types::ServerCapability.from_url("http://localhost:1234/v1")
        end
      end
      klass.new
    end

    it "uses inferred server type" do
      caps = lm_studio_model.capabilities
      expect(caps.server_type.name).to eq(:lm_studio)
    end

    it "reflects LM Studio-specific capabilities" do
      caps = lm_studio_model.capabilities
      expect(caps.supports_tools).to eq(:model_dependent)
      expect(caps.supports_json_object).to be false
      expect(caps.supports_json_schema).to be true
    end
  end
end
# rubocop:enable Lint/MissingSuper

RSpec.describe Smolagents::Models::OpenAIModel do
  describe "#capabilities" do
    let(:client) { instance_double(OpenAI::Client) }

    context "with LM Studio URL" do
      let(:model) do
        described_class.new(
          model_id: "test-model",
          api_base: "http://localhost:1234/v1",
          api_key: "not-needed",
          client:
        )
      end

      it "returns capabilities based on detected server type" do
        caps = model.capabilities
        expect(caps).to be_a(Smolagents::Types::ServerCapability)
        expect(caps.server_type.name).to eq(:lm_studio)
      end

      it "exposes predicate methods correctly" do
        expect(model.supports_tools?).to eq(:model_dependent)
        expect(model.supports_json_object?).to be false
        expect(model.supports_json_schema?).to be true
      end
    end

    context "with llama.cpp URL" do
      let(:model) do
        described_class.new(
          model_id: "test-model",
          api_base: "http://llama-cpp-server.local/v1",
          api_key: "not-needed",
          client:
        )
      end

      it "detects llama_cpp server type" do
        expect(model.capabilities.server_type.name).to eq(:llama_cpp)
      end

      it "reflects llama.cpp tool conflict" do
        expect(model.capabilities.tools_response_format_conflict?).to be true
      end
    end

    context "without api_base (uses default capabilities)" do
      let(:model) do
        described_class.new(
          model_id: "gpt-4",
          api_key: "sk-test",
          client:
        )
      end

      it "falls back to unknown capabilities when no server detected" do
        caps = model.capabilities
        expect(caps.unknown?).to be true
      end
    end
  end
end
