require "spec_helper"

RSpec.describe Smolagents::Config::Configuration::Freezable do
  let(:config) { Smolagents::Config::Configuration.new }

  describe "#frozen?" do
    it "returns false by default" do
      expect(config).not_to be_frozen
    end

    it "returns true after freeze!" do
      config.freeze!

      expect(config).to be_frozen
    end
  end

  describe "#freeze!" do
    it "freezes the configuration" do
      config.freeze!

      expect(config.frozen).to be true
    end

    it "returns self for chaining" do
      result = config.freeze!

      expect(result).to be(config)
    end

    it "prevents further modifications" do
      config.freeze!

      expect { config.max_steps = 10 }.to raise_error(FrozenError)
    end
  end

  describe "#freeze" do
    it "returns a frozen duplicate" do
      original = config
      frozen = config.freeze

      expect(frozen).not_to be(original)
      expect(frozen).to be_frozen
    end

    it "leaves original unfrozen" do
      _frozen = config.freeze

      expect(config).not_to be_frozen
    end
  end

  describe "#reset!" do
    it "restores default values" do
      config.max_steps = 100
      config.reset!

      expect(config.max_steps).to eq(Smolagents::Config::DEFAULTS[:max_steps])
    end

    it "unfreezes the configuration" do
      config.freeze!
      config.reset!

      expect(config).not_to be_frozen
    end

    it "returns self for chaining" do
      result = config.reset!

      expect(result).to be(config)
    end

    it "loads environment variables" do
      original = ENV.fetch("SMOLAGENTS_SEARCH_PROVIDER", nil)
      ENV["SMOLAGENTS_SEARCH_PROVIDER"] = "google"

      config.reset!

      expect(config.search_provider).to eq(:google)
    ensure
      ENV["SMOLAGENTS_SEARCH_PROVIDER"] = original
    end
  end

  describe "#reset" do
    it "returns a reset duplicate" do
      config.max_steps = 100
      reset = config.reset

      expect(reset).not_to be(config)
      expect(reset.max_steps).to eq(Smolagents::Config::DEFAULTS[:max_steps])
    end

    it "leaves original unchanged" do
      config.max_steps = 100
      _reset = config.reset

      expect(config.max_steps).to eq(100)
    end
  end
end
