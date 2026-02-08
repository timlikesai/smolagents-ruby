RSpec.describe Smolagents::Config::Profiles do
  before { described_class.reset! }

  describe ".register" do
    it "registers a custom profile" do
      profile = Smolagents::Types::ConfigProfile.new(
        name: :staging, description: "Staging", overrides: { max_steps: 15 }
      )
      described_class.register(profile)

      expect(described_class[:staging]).to eq(profile)
    end
  end

  describe ".names" do
    it "includes built-in profiles" do
      expect(described_class.names).to include(:local_gpu, :development, :cloud_api, :default)
    end
  end

  describe ".registered?" do
    it "returns true for built-in profiles" do
      expect(described_class.registered?(:local_gpu)).to be(true)
    end

    it "returns false for unknown profiles" do
      expect(described_class.registered?(:unknown)).to be(false)
    end
  end

  describe ".[]" do
    it "retrieves a registered profile by name" do
      profile = described_class[:local_gpu]

      expect(profile).to be_a(Smolagents::Types::ConfigProfile)
      expect(profile.name).to eq(:local_gpu)
    end

    it "returns nil for unregistered profiles" do
      expect(described_class[:nonexistent]).to be_nil
    end
  end

  describe ".apply" do
    let(:config) { Smolagents::Config::Configuration.new }

    it "applies local_gpu profile overrides" do
      described_class.apply(:local_gpu, config)

      expect(config.max_steps).to eq(10)
    end

    it "applies development profile overrides" do
      described_class.apply(:development, config)

      expect(config.log_level).to eq(:debug)
    end

    it "applies cloud_api profile overrides" do
      described_class.apply(:cloud_api, config)

      expect(config.max_steps).to eq(20)
    end

    it "returns the configuration" do
      result = described_class.apply(:development, config)

      expect(result).to equal(config)
    end

    it "raises ArgumentError for unknown profile" do
      expect { described_class.apply(:nonexistent, config) }
        .to raise_error(ArgumentError, /Unknown profile/)
    end

    it "includes available profiles in error message" do
      expect { described_class.apply(:nonexistent, config) }
        .to raise_error(ArgumentError, /local_gpu/)
    end

    it "applies default profile without changing config" do
      original_steps = config.max_steps
      described_class.apply(:default, config)

      expect(config.max_steps).to eq(original_steps)
    end
  end

  describe ".reset!" do
    it "removes custom profiles and restores built-ins" do
      described_class.register(
        Smolagents::Types::ConfigProfile.new(name: :custom, description: "Custom", overrides: {})
      )
      described_class.reset!

      expect(described_class.registered?(:custom)).to be(false)
      expect(described_class.registered?(:local_gpu)).to be(true)
    end
  end
end
