RSpec.describe Smolagents::Config::Configuration, "#apply_profile" do
  subject(:config) { described_class.new }

  after { config.reset! }

  describe "#apply_profile" do
    it "applies local_gpu profile overrides" do
      config.apply_profile(:local_gpu)
      expect(config.max_steps).to eq(Smolagents::Types::ConfigProfile.local_gpu.overrides[:max_steps])
    end

    it "applies development profile overrides" do
      config.apply_profile(:development)
      expect(config.log_level).to eq(:debug)
    end

    it "raises for unknown profile" do
      expect { config.apply_profile(:nonexistent) }.to raise_error(ArgumentError, /Unknown profile/)
    end

    it "raises when frozen" do
      config.freeze!
      expect { config.apply_profile(:local_gpu) }.to raise_error(FrozenError)
    end

    it "returns self for chaining" do
      expect(config.apply_profile(:default)).to be(config)
    end
  end
end
