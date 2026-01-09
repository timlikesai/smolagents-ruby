# frozen_string_literal: true

RSpec.describe Smolagents::Configuration do
  # Reset configuration before each test
  before do
    Smolagents.reset_configuration!
  end

  describe "#initialize" do
    it "sets default values" do
      config = described_class.new

      expect(config.custom_instructions).to be_nil
      expect(config.max_steps).to eq(20)
      expect(config.authorized_imports).to eq(Smolagents::CodeAgent::DEFAULT_AUTHORIZED_IMPORTS)
    end
  end

  describe "#reset!" do
    it "resets to defaults" do
      config = described_class.new
      config.custom_instructions = "test"
      config.max_steps = 50

      config.reset!

      expect(config.custom_instructions).to be_nil
      expect(config.max_steps).to eq(20)
    end
  end

  describe "#validate!" do
    it "validates positive max_steps" do
      config = described_class.new
      config.max_steps = 0

      expect { config.validate! }.to raise_error(ArgumentError, /max_steps must be positive/)
    end

    it "validates authorized_imports is array" do
      config = described_class.new
      config.authorized_imports = "not an array"

      expect { config.validate! }.to raise_error(ArgumentError, /authorized_imports must be an array/)
    end

    it "validates custom_instructions length" do
      config = described_class.new
      config.custom_instructions = "a" * 10_001

      expect { config.validate! }.to raise_error(ArgumentError, /custom_instructions too long/)
    end

    it "returns true when valid" do
      config = described_class.new

      expect(config.validate!).to be true
    end
  end
end

RSpec.describe Smolagents, ".configure" do
  before do
    Smolagents.reset_configuration!
  end

  it "yields configuration object" do
    expect { |b| Smolagents.configure(&b) }.to yield_with_args(Smolagents::Configuration)
  end

  it "sets configuration values" do
    Smolagents.configure do |config|
      config.custom_instructions = "Be concise"
      config.max_steps = 15
    end

    expect(Smolagents.configuration.custom_instructions).to eq("Be concise")
    expect(Smolagents.configuration.max_steps).to eq(15)
  end

  it "validates configuration after setting" do
    expect {
      Smolagents.configure do |config|
        config.max_steps = -1
      end
    }.to raise_error(ArgumentError, /max_steps must be positive/)
  end

  it "returns configuration" do
    result = Smolagents.configure do |config|
      config.max_steps = 10
    end

    expect(result).to be_a(Smolagents::Configuration)
    expect(result.max_steps).to eq(10)
  end
end

RSpec.describe Smolagents, ".configuration" do
  before do
    Smolagents.reset_configuration!
  end

  it "returns same instance on multiple calls" do
    config1 = Smolagents.configuration
    config2 = Smolagents.configuration

    expect(config1).to be(config2)
  end

  it "persists changes" do
    Smolagents.configuration.custom_instructions = "test"

    expect(Smolagents.configuration.custom_instructions).to eq("test")
  end
end

RSpec.describe Smolagents, ".reset_configuration!" do
  it "resets to defaults" do
    Smolagents.configure do |config|
      config.custom_instructions = "test"
      config.max_steps = 50
    end

    Smolagents.reset_configuration!

    expect(Smolagents.configuration.custom_instructions).to be_nil
    expect(Smolagents.configuration.max_steps).to eq(20)
  end
end
