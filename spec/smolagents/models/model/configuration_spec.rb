require "smolagents/models/model"

RSpec.describe Smolagents::Models::Model::Configuration do
  describe "#initialize_configuration" do
    context "with config object" do
      it "initializes from config object" do
        config = double(
          model_id: "gpt-4",
          api_key: "test-key",
          api_base: "https://api.openai.com",
          temperature: 0.8,
          max_tokens: 200,
          extras: { custom: "value" }
        )

        model = Smolagents::Model.new(config:)

        expect(model.model_id).to eq("gpt-4")
        expect(model.temperature).to eq(0.8)
        expect(model.max_tokens).to eq(200)
        expect(model.config).to eq(config)
      end

      it "extracts extras as kwargs" do
        config = double(
          model_id: "gpt-4",
          api_key: "test-key",
          api_base: nil,
          temperature: 0.7,
          max_tokens: nil,
          extras: { custom: "value", another: 42 }
        )

        model = Smolagents::Model.new(config:)

        expect(model.instance_variable_get(:@kwargs)).to eq({ custom: "value", another: 42 })
      end

      it "handles config with nil extras" do
        config = double(
          model_id: "gpt-4",
          api_key: "test-key",
          api_base: nil,
          temperature: 0.7,
          max_tokens: nil,
          extras: nil
        )

        model = Smolagents::Model.new(config:)

        expect(model.instance_variable_get(:@kwargs)).to eq({})
      end
    end

    context "with keyword parameters" do
      it "initializes from keyword parameters" do
        model = Smolagents::Model.new(
          model_id: "gpt-4",
          api_key: "test-key",
          api_base: "https://api.openai.com",
          temperature: 0.8,
          max_tokens: 200
        )

        expect(model.model_id).to eq("gpt-4")
        expect(model.temperature).to eq(0.8)
        expect(model.max_tokens).to eq(200)
        expect(model.config).to be_nil
      end

      it "sets default temperature to 0.7 when not provided" do
        model = Smolagents::Model.new(model_id: "gpt-4")

        expect(model.temperature).to eq(0.7)
      end

      it "preserves custom kwargs" do
        model = Smolagents::Model.new(
          model_id: "gpt-4",
          custom_param: "value",
          another: 42
        )

        kwargs = model.instance_variable_get(:@kwargs)
        expect(kwargs).to include(custom_param: "value", another: 42)
      end

      it "filters out known parameters from kwargs" do
        model = Smolagents::Model.new(
          model_id: "gpt-4",
          api_key: "test-key",
          api_base: "https://api.openai.com",
          temperature: 0.8,
          max_tokens: 200,
          config: nil,
          custom: "value"
        )

        kwargs = model.instance_variable_get(:@kwargs)
        expect(kwargs).to include(custom: "value")
        expect(kwargs).not_to include(:model_id, :api_key, :api_base, :temperature, :max_tokens, :config)
      end
    end
  end

  describe "#model_id" do
    it "returns the model identifier" do
      model = Smolagents::Model.new(model_id: "gpt-4")
      expect(model.model_id).to eq("gpt-4")
    end
  end

  describe "#config" do
    it "returns the config object when initialized with config" do
      config = double(model_id: "gpt-4", api_key: "key", api_base: nil, temperature: 0.7, max_tokens: nil, extras: nil)
      model = Smolagents::Model.new(config:)

      expect(model.config).to eq(config)
    end

    it "returns nil when initialized without config" do
      model = Smolagents::Model.new(model_id: "gpt-4")
      expect(model.config).to be_nil
    end
  end

  describe "#temperature" do
    it "returns the temperature value" do
      model = Smolagents::Model.new(model_id: "gpt-4", temperature: 0.5)
      expect(model.temperature).to eq(0.5)
    end

    it "defaults to 0.7 when not specified" do
      model = Smolagents::Model.new(model_id: "gpt-4")
      expect(model.temperature).to eq(0.7)
    end
  end

  describe "#max_tokens" do
    it "returns the max_tokens value" do
      model = Smolagents::Model.new(model_id: "gpt-4", max_tokens: 500)
      expect(model.max_tokens).to eq(500)
    end

    it "returns nil when not specified" do
      model = Smolagents::Model.new(model_id: "gpt-4")
      expect(model.max_tokens).to be_nil
    end
  end

  describe "#logger" do
    it "returns nil by default" do
      model = Smolagents::Model.new(model_id: "gpt-4")
      expect(model.logger).to be_nil
    end

    it "allows setting a logger" do
      model = Smolagents::Model.new(model_id: "gpt-4")
      logger = Logger.new($stdout)

      model.logger = logger
      expect(model.logger).to eq(logger)
    end
  end
end
