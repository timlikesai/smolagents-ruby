require "spec_helper"

RSpec.describe Smolagents::Models::LiteLLM::ProviderRouting do
  # Create a test class that includes the module to test private methods
  let(:test_class) do
    Class.new do
      include Smolagents::Models::LiteLLM::ProviderRouting

      # Expose private methods for testing
      public :parse_model_id, :local_server?, :local_server_method
    end
  end

  let(:router) { test_class.new }

  describe "PROVIDERS" do
    let(:providers) { Smolagents::Models::LiteLLM::ProviderRouting::PROVIDERS }

    it "includes openai provider" do
      expect(providers).to include("openai" => :openai)
    end

    it "includes anthropic provider" do
      expect(providers).to include("anthropic" => :anthropic)
    end

    it "includes azure provider" do
      expect(providers).to include("azure" => :azure)
    end

    it "includes ollama provider" do
      expect(providers).to include("ollama" => :ollama)
    end

    it "includes lm_studio provider" do
      expect(providers).to include("lm_studio" => :lm_studio)
    end

    it "includes llama_cpp provider" do
      expect(providers).to include("llama_cpp" => :llama_cpp)
    end

    it "includes mlx_lm provider" do
      expect(providers).to include("mlx_lm" => :mlx_lm)
    end

    it "includes vllm provider" do
      expect(providers).to include("vllm" => :vllm)
    end

    it "is frozen" do
      expect(providers).to be_frozen
    end
  end

  describe "LOCAL_SERVERS" do
    let(:local_servers) { Smolagents::Models::LiteLLM::ProviderRouting::LOCAL_SERVERS }

    it "includes ollama" do
      expect(local_servers).to include("ollama" => :ollama)
    end

    it "includes lm_studio" do
      expect(local_servers).to include("lm_studio" => :lm_studio)
    end

    it "includes llama_cpp" do
      expect(local_servers).to include("llama_cpp" => :llama_cpp)
    end

    it "includes mlx_lm" do
      expect(local_servers).to include("mlx_lm" => :mlx_lm)
    end

    it "includes vllm" do
      expect(local_servers).to include("vllm" => :vllm)
    end

    it "does not include openai" do
      expect(local_servers).not_to have_key("openai")
    end

    it "does not include anthropic" do
      expect(local_servers).not_to have_key("anthropic")
    end

    it "does not include azure" do
      expect(local_servers).not_to have_key("azure")
    end

    it "is frozen" do
      expect(local_servers).to be_frozen
    end
  end

  describe "#parse_model_id" do
    context "with provider prefix" do
      it "parses openai/model format" do
        provider, resolved = router.parse_model_id("openai/gpt-4")

        expect(provider).to eq("openai")
        expect(resolved).to eq("gpt-4")
      end

      it "parses anthropic/model format" do
        provider, resolved = router.parse_model_id("anthropic/claude-3-opus")

        expect(provider).to eq("anthropic")
        expect(resolved).to eq("claude-3-opus")
      end

      it "parses azure/model format" do
        provider, resolved = router.parse_model_id("azure/gpt-4-deployment")

        expect(provider).to eq("azure")
        expect(resolved).to eq("gpt-4-deployment")
      end

      it "parses ollama/model format" do
        provider, resolved = router.parse_model_id("ollama/llama2")

        expect(provider).to eq("ollama")
        expect(resolved).to eq("llama2")
      end

      it "parses lm_studio/model format" do
        provider, resolved = router.parse_model_id("lm_studio/local-model")

        expect(provider).to eq("lm_studio")
        expect(resolved).to eq("local-model")
      end

      it "parses llama_cpp/model format" do
        provider, resolved = router.parse_model_id("llama_cpp/model")

        expect(provider).to eq("llama_cpp")
        expect(resolved).to eq("model")
      end

      it "parses mlx_lm/model format" do
        provider, resolved = router.parse_model_id("mlx_lm/model")

        expect(provider).to eq("mlx_lm")
        expect(resolved).to eq("model")
      end

      it "parses vllm/model format" do
        provider, resolved = router.parse_model_id("vllm/model")

        expect(provider).to eq("vllm")
        expect(resolved).to eq("model")
      end
    end

    context "without provider prefix" do
      it "defaults to openai for simple model names" do
        provider, resolved = router.parse_model_id("gpt-4o")

        expect(provider).to eq("openai")
        expect(resolved).to eq("gpt-4o")
      end

      it "defaults to openai for unknown provider prefix" do
        provider, resolved = router.parse_model_id("unknown/model")

        expect(provider).to eq("openai")
        expect(resolved).to eq("unknown/model")
      end

      it "defaults to openai for org/model format with unknown org" do
        provider, resolved = router.parse_model_id("org/gpt-4-custom")

        expect(provider).to eq("openai")
        expect(resolved).to eq("org/gpt-4-custom")
      end
    end

    context "with multiple slashes" do
      it "only splits on first slash for known providers" do
        provider, resolved = router.parse_model_id("openai/accounts/models/gpt-4")

        expect(provider).to eq("openai")
        expect(resolved).to eq("accounts/models/gpt-4")
      end

      it "preserves full path for unknown providers" do
        provider, resolved = router.parse_model_id("org/models/gpt-4")

        expect(provider).to eq("openai")
        expect(resolved).to eq("org/models/gpt-4")
      end
    end
  end

  describe "#local_server?" do
    it "returns true for ollama" do
      expect(router.local_server?("ollama")).to be true
    end

    it "returns true for lm_studio" do
      expect(router.local_server?("lm_studio")).to be true
    end

    it "returns true for llama_cpp" do
      expect(router.local_server?("llama_cpp")).to be true
    end

    it "returns true for mlx_lm" do
      expect(router.local_server?("mlx_lm")).to be true
    end

    it "returns true for vllm" do
      expect(router.local_server?("vllm")).to be true
    end

    it "returns false for openai" do
      expect(router.local_server?("openai")).to be false
    end

    it "returns false for anthropic" do
      expect(router.local_server?("anthropic")).to be false
    end

    it "returns false for azure" do
      expect(router.local_server?("azure")).to be false
    end

    it "returns false for unknown provider" do
      expect(router.local_server?("unknown")).to be false
    end
  end

  describe "#local_server_method" do
    it "returns :ollama for ollama provider" do
      expect(router.local_server_method("ollama")).to eq(:ollama)
    end

    it "returns :lm_studio for lm_studio provider" do
      expect(router.local_server_method("lm_studio")).to eq(:lm_studio)
    end

    it "returns :llama_cpp for llama_cpp provider" do
      expect(router.local_server_method("llama_cpp")).to eq(:llama_cpp)
    end

    it "returns :mlx_lm for mlx_lm provider" do
      expect(router.local_server_method("mlx_lm")).to eq(:mlx_lm)
    end

    it "returns :vllm for vllm provider" do
      expect(router.local_server_method("vllm")).to eq(:vllm)
    end

    it "returns nil for openai" do
      expect(router.local_server_method("openai")).to be_nil
    end

    it "returns nil for anthropic" do
      expect(router.local_server_method("anthropic")).to be_nil
    end

    it "returns nil for azure" do
      expect(router.local_server_method("azure")).to be_nil
    end

    it "returns nil for unknown provider" do
      expect(router.local_server_method("unknown")).to be_nil
    end
  end
end
