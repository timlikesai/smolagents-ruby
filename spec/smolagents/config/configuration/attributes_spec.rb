require "spec_helper"

RSpec.describe Smolagents::Config::Configuration::Attributes do
  # Test via the Configuration class which includes the module
  let(:config) { Smolagents::Config::Configuration.new }

  describe ".included" do
    it "defines readers for all DEFAULTS keys" do
      Smolagents::Config::DEFAULTS.each_key do |key|
        expect(config).to respond_to(key)
      end
    end
  end

  describe "generated setters" do
    it "defines setters for all DEFAULTS keys" do
      Smolagents::Config::DEFAULTS.each_key do |key|
        expect(config).to respond_to(:"#{key}=")
      end
    end

    it "raises FrozenError when configuration is frozen" do
      config.freeze!

      expect { config.max_steps = 10 }.to raise_error(FrozenError, "Configuration is frozen")
    end

    it "runs validator for attribute" do
      expect { config.log_format = :invalid }.to raise_error(ArgumentError, /log_format must be/)
    end

    it "deep-freezes values before storage" do
      config.authorized_imports = %w[json csv]

      expect(config.authorized_imports).to be_frozen
      expect(config.authorized_imports.first).to be_frozen
    end

    it "accepts valid values" do
      config.max_steps = 50
      config.log_level = :debug

      expect(config.max_steps).to eq(50)
      expect(config.log_level).to eq(:debug)
    end
  end
end
