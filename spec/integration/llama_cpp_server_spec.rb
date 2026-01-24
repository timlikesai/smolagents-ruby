# Integration tests for llama.cpp server in router mode.
#
# Run with:
#   LLAMA_CPP_URL=https://your-server.example.com bundle exec rspec spec/integration/llama_cpp_server_spec.rb
#
RSpec.describe "LlamaCpp Server Integration", :integration, :slow, max_time: 30 do
  let(:api_base) { ENV.fetch("LLAMA_CPP_URL", nil) }
  let(:server) { Smolagents::Servers::LlamaCpp.new(api_base:) }

  before do
    skip "Set LLAMA_CPP_URL to run integration tests" unless api_base
    WebMock.allow_net_connect!
  end

  after do
    WebMock.disable_net_connect!
  end

  describe "server connectivity" do
    it "reports healthy" do
      expect(server.healthy?).to be true
    end
  end

  describe "model listing" do
    it "lists available models" do
      models = server.models
      expect(models).to be_an(Array)
      expect(models).not_to be_empty
      expect(models.first).to be_a(Smolagents::Servers::LlamaCpp::ModelInfo)
    end

    it "includes model status" do
      models = server.models
      statuses = models.map(&:status).uniq
      expect(statuses).to include("loaded").or include("unloaded")
    end

    it "returns model IDs" do
      ids = server.model_ids
      expect(ids).to all(be_a(String))
      expect(ids).not_to be_empty
    end
  end

  describe "model status" do
    it "returns status for existing model" do
      first_model = server.model_ids.first
      status = server.model_status(first_model)
      expect(status).to be_a(Smolagents::Servers::LlamaCpp::ModelInfo)
    end

    it "returns nil for non-existent model" do
      expect(server.model_status("definitely-not-a-real-model")).to be_nil
    end
  end

  describe "loaded models" do
    it "returns only loaded models" do
      loaded = server.loaded_models
      expect(loaded).to all(satisfy(&:loaded?))
    end
  end

  describe "slots" do
    it "returns slot info for loaded model", :slow do
      loaded = server.loaded_models.first
      skip "No models currently loaded" unless loaded

      slots = server.slots(loaded.id)
      expect(slots).to be_an(Array)
      expect(slots.first).to be_a(Smolagents::Servers::LlamaCpp::SlotInfo)
    end
  end

  describe "model warmup" do
    # Use a small, fast model for warmup test
    let(:test_model) { ENV.fetch("LLAMA_CPP_TEST_MODEL", "LFM2.5-1.2B-Instruct-Q8_0") }

    it "warms up a model", :slow do
      skip "Set LLAMA_CPP_TEST_MODEL for warmup test" unless server.model_ids.include?(test_model)

      result = server.warmup(test_model, timeout: 120)
      expect(result).to be_a(Smolagents::Servers::LlamaCpp::ModelInfo)
      expect(result.loaded?).to be true
    end
  end

  describe "creating OpenAI model" do
    let(:test_model) { server.loaded_models.first&.id || server.model_ids.first }

    it "creates configured OpenAIModel" do
      model = server.model(test_model)
      expect(model).to be_a(Smolagents::Models::OpenAIModel)
      expect(model.model_id).to eq(test_model)
    end

    it "generates responses", :slow do
      skip "No models available" if server.model_ids.empty?

      model = server.model(test_model)
      response = model.generate([Smolagents::ChatMessage.user("Say 'hello' and nothing else.")])

      expect(response).to be_a(Smolagents::ChatMessage)
      expect(response.content.downcase).to include("hello")
    end
  end

  describe "agent integration", :slow do
    let(:test_model) { server.loaded_models.first&.id || server.model_ids.first }

    it "runs agent with server model" do
      skip "No models available" if server.model_ids.empty?

      model = server.model(test_model)
      agent = Smolagents.agent
                        .model { model }
                        .tools(:final_answer)
                        .max_steps(5)
                        .build

      result = agent.run("Use final_answer to return the number 42")

      expect(result.output.to_s).to include("42")
    end
  end
end
