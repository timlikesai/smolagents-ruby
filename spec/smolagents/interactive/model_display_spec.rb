RSpec.describe Smolagents::Interactive::ModelDisplay do
  before { Smolagents::Interactive::Colors.enabled = true }
  after { Smolagents::Interactive::Colors.enabled = nil }

  let(:loaded_model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "gemma-3n-e4b",
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      context_length: 32_000,
      state: :loaded,
      capabilities: ["tool_use"],
      type: "llm",
      tls: false,
      api_key: nil
    )
  end

  let(:unloaded_model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "llama-3.2-8b",
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      context_length: 128_000,
      state: :unloaded,
      capabilities: nil,
      type: "llm",
      tls: false,
      api_key: nil
    )
  end

  let(:vision_model) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "llava-1.6",
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      context_length: 8_000,
      state: :loaded,
      capabilities: ["vision"],
      type: "vlm",
      tls: false,
      api_key: nil
    )
  end

  let(:model_without_context) do
    Smolagents::Discovery::DiscoveredModel.new(
      id: "basic-model",
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      context_length: nil,
      state: :loaded,
      capabilities: nil,
      type: "llm",
      tls: false,
      api_key: nil
    )
  end

  let(:server) do
    Smolagents::Discovery::LocalServer.new(
      provider: :lm_studio,
      host: "localhost",
      port: 1234,
      models: [loaded_model, unloaded_model],
      error: nil
    )
  end

  describe ".server_models" do
    it "outputs server header with name and URL" do
      expect { described_class.server_models(server) }.to output(/LM Studio.*localhost:1234/).to_stdout
    end

    it "shows loaded models" do
      expect { described_class.server_models(server) }.to output(/gemma-3n-e4b/).to_stdout
    end

    it "shows ready status for loaded models" do
      expect { described_class.server_models(server) }.to output(/ready/).to_stdout
    end

    it "shows unloaded models in separate section" do
      expect { described_class.server_models(server) }.to output(/llama-3.2-8b.*not loaded/).to_stdout
    end
  end

  describe ".model_line" do
    context "with ready model" do
      it "includes model id in bold" do
        line = described_class.model_line(loaded_model, ready: true)
        expect(line).to include("gemma-3n-e4b")
        expect(line).to include("\e[1m") # bold
      end

      it "includes context length in K format" do
        line = described_class.model_line(loaded_model, ready: true)
        expect(line).to include("32K")
      end

      it "shows ready status in green" do
        line = described_class.model_line(loaded_model, ready: true)
        expect(line).to include("ready")
        expect(line).to include("\e[92m") # bright green
      end
    end

    context "with vision model" do
      it "includes vision capability indicator" do
        line = described_class.model_line(vision_model, ready: true)
        expect(line).to include("[")
        expect(line).to include("vision")
        expect(line).to include("]")
      end

      it "shows vision in magenta" do
        line = described_class.model_line(vision_model, ready: true)
        expect(line).to include("\e[35m") # magenta
      end
    end

    context "with unready model" do
      it "shows not loaded status in yellow" do
        line = described_class.model_line(unloaded_model, ready: false)
        expect(line).to include("not loaded")
        expect(line).to include("\e[33m") # yellow
      end
    end

    context "with model without context length" do
      it "omits context length" do
        line = described_class.model_line(model_without_context, ready: true)
        expect(line).not_to include("K")
      end
    end
  end

  describe ".show_unloaded" do
    it "shows nothing for empty list" do
      expect { described_class.show_unloaded([]) }.not_to output.to_stdout
    end

    it "shows first 3 unloaded models" do
      models = (1..5).map do |i|
        unloaded_model.with(id: "model-#{i}")
      end
      output = capture_stdout { described_class.show_unloaded(models) }
      expect(output).to include("model-1")
      expect(output).to include("model-2")
      expect(output).to include("model-3")
      expect(output).not_to include("model-4")
      expect(output).not_to include("model-5")
    end

    it "shows hidden count when more than 3" do
      models = (1..5).map { |i| unloaded_model.with(id: "model-#{i}") }
      expect { described_class.show_unloaded(models) }.to output(/\+2 more unloaded/).to_stdout
    end

    it "does not show hidden count when 3 or less" do
      models = [unloaded_model, unloaded_model.with(id: "other")]
      expect { described_class.show_unloaded(models) }.not_to output(/more unloaded/).to_stdout
    end
  end

  describe ".unloaded_line" do
    it "shows model id" do
      line = described_class.unloaded_line(unloaded_model)
      expect(line).to include("llama-3.2-8b")
    end

    it "shows context length" do
      line = described_class.unloaded_line(unloaded_model)
      expect(line).to include("128K")
    end

    it "shows not loaded status" do
      line = described_class.unloaded_line(unloaded_model)
      expect(line).to include("not loaded")
    end

    it "applies dim styling" do
      line = described_class.unloaded_line(unloaded_model)
      expect(line).to include("\e[2m") # dim
    end

    it "omits context when nil" do
      line = described_class.unloaded_line(model_without_context)
      expect(line).not_to include("K")
    end
  end

  describe ".model_detail_line" do
    it "shows model id and ready status" do
      line = described_class.model_detail_line(loaded_model)
      expect(line).to include("gemma-3n-e4b")
      expect(line).to include("ready")
    end

    it "shows context length with label" do
      line = described_class.model_detail_line(loaded_model)
      expect(line).to include("32K context")
    end

    it "shows not loaded for unloaded model" do
      line = described_class.model_detail_line(unloaded_model)
      expect(line).to include("not loaded")
    end

    it "omits context when nil" do
      line = described_class.model_detail_line(model_without_context)
      expect(line).not_to include("context")
    end
  end

  describe ".filter_models" do
    let(:models) { [loaded_model, unloaded_model] }

    it "returns ready models for :ready filter" do
      result = described_class.filter_models(models, :ready)
      expect(result).to eq([loaded_model])
    end

    it "returns ready models for :loaded filter" do
      result = described_class.filter_models(models, :loaded)
      expect(result).to eq([loaded_model])
    end

    it "returns unloaded models for :unloaded filter" do
      result = described_class.filter_models(models, :unloaded)
      expect(result).to eq([unloaded_model])
    end

    it "returns all models for :all filter" do
      result = described_class.filter_models(models, :all)
      expect(result).to eq(models)
    end

    it "returns all models for unknown filter" do
      result = described_class.filter_models(models, :other)
      expect(result).to eq(models)
    end
  end

  describe ".show_models_with_examples" do
    it "shows model detail and code example" do
      output = capture_stdout { described_class.show_models_with_examples(server, [loaded_model], :ready) }
      expect(output).to include("gemma-3n-e4b")
    end

    it "shows hidden count when filtered" do
      output = capture_stdout { described_class.show_models_with_examples(server, [loaded_model], :ready) }
      expect(output).to include("1 more")
    end
  end

  describe ".show_hidden_count" do
    it "shows nothing when no hidden models" do
      srv = server.with(models: [loaded_model])
      expect { described_class.show_hidden_count(srv, [loaded_model], :ready) }.not_to output.to_stdout
    end

    it "shows nothing for :all filter" do
      expect { described_class.show_hidden_count(server, [loaded_model], :all) }.not_to output.to_stdout
    end

    it "shows hidden count when filtered" do
      expect { described_class.show_hidden_count(server, [loaded_model], :ready) }.to output(/1 more/).to_stdout
    end

    it "shows hint about all: true" do
      expect { described_class.show_hidden_count(server, [loaded_model], :ready) }.to output(/all: true/).to_stdout
    end
  end

  private

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end
end
